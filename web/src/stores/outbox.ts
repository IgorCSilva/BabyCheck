import { defineStore } from "pinia";
import { apiRequest, ApiError } from "@/lib/api";
import { outboxDb } from "@/lib/outboxDb";
import { useBabiesStore } from "@/stores/babies";
import { useDiaperLogsStore } from "@/stores/diaperLogs";
import { useBottleFeedingsStore } from "@/stores/bottleFeedings";
import { useBreastfeedingLogsStore } from "@/stores/breastfeedingLogs";
import { useFeedStore } from "@/stores/feed";

export type Metric = "diaper" | "bottle" | "breastfeeding";

export interface OutboxEntry {
  tempId: number;
  metric: Metric;
  baby_id: number;
  payload: Record<string, unknown>;
}

const FLUSH_RETRY_MS = 20_000;

const ENDPOINTS: Record<Metric, string> = {
  diaper: "diaper_logs",
  bottle: "bottle_feedings",
  breastfeeding: "breastfeeding_logs",
};

// Resolvers for entries enqueued in *this* session, so `quickLog`'s returned
// promise (and QuickLogBar's existing Undo flow) still settles once the
// outbox eventually syncs it. Deliberately not persisted/reactive — an entry
// restored after a reload (see `restoreQueued` on each log store) has no
// live caller awaiting it, so there's nothing to resolve for those, only the
// store update `flush()` performs directly below.
const resolvers = new Map<number, { resolve: (log: unknown) => void; reject: (error: unknown) => void }>();

function resolveInStore(metric: Metric, tempId: number, log: unknown) {
  if (metric === "diaper") useDiaperLogsStore().resolvePending(tempId, log as never);
  else if (metric === "bottle") useBottleFeedingsStore().resolvePending(tempId, log as never);
  else useBreastfeedingLogsStore().resolvePending(tempId, log as never);
}

interface OutboxState {
  entries: OutboxEntry[];
  online: boolean;
  flushing: boolean;
}

export const useOutboxStore = defineStore("outbox", {
  state: (): OutboxState => ({
    entries: [],
    online: typeof navigator === "undefined" ? true : navigator.onLine,
    flushing: false,
  }),

  actions: {
    async init() {
      this.entries = await outboxDb.getAll<OutboxEntry>();

      window.addEventListener("online", () => {
        this.online = true;
        this.flush();
      });
      window.addEventListener("offline", () => {
        this.online = false;
      });
      setInterval(() => this.flush(), FLUSH_RETRY_MS);

      this.flush();
    },

    enqueue(entry: OutboxEntry): Promise<unknown> {
      this.entries.push(entry);
      outboxDb.put(entry);

      const promise = new Promise<unknown>((resolve, reject) => {
        resolvers.set(entry.tempId, { resolve, reject });
      });
      this.flush();
      return promise;
    },

    // Removes a still-queued entry before it's ever sent — used for Undo on
    // an entry that hasn't synced yet. Returns whether it was actually
    // queued (if it already flushed, the caller falls back to a normal
    // delete-by-id instead).
    cancelIfQueued(tempId: number): boolean {
      const index = this.entries.findIndex((entry) => entry.tempId === tempId);
      if (index === -1) return false;

      this.entries.splice(index, 1);
      outboxDb.remove(tempId);
      resolvers.delete(tempId);
      return true;
    },

    entriesFor(metric: Metric, babyId: number): OutboxEntry[] {
      return this.entries.filter((entry) => entry.metric === metric && entry.baby_id === babyId);
    },

    async flush() {
      if (this.flushing || !this.entries.length) return;

      this.flushing = true;
      try {
        // Only ever send entries for babies the *current* account owns — a
        // different account logging into the same browser just never
        // matches here (left harmlessly queued), and the original account's
        // entries resume syncing automatically once they log back in. No
        // logout-time wipe needed.
        const ownedBabyIds = new Set(useBabiesStore().babies.map((baby) => baby.id));

        for (const entry of [...this.entries]) {
          if (!ownedBabyIds.has(entry.baby_id)) continue;

          try {
            const log = await apiRequest(`/api/babies/${entry.baby_id}/${ENDPOINTS[entry.metric]}`, {
              method: "POST",
              body: { ...entry.payload, client_request_id: String(entry.tempId) },
            });

            this.entries = this.entries.filter((pending) => pending.tempId !== entry.tempId);
            outboxDb.remove(entry.tempId);
            resolveInStore(entry.metric, entry.tempId, log);
            resolvers.get(entry.tempId)?.resolve(log);
            resolvers.delete(entry.tempId);
            // Keeps the global feed honest even when nothing in the current
            // session is still awaiting this entry's own promise (e.g. it
            // was restored after a reload) — otherwise its synthetic queued
            // row would just vanish from the feed without the now-synced
            // real row ever taking its place.
            useFeedStore()
              .fetchFeed()
              .catch(() => {});
          } catch (error) {
            if (error instanceof ApiError) {
              // Can't succeed right now (e.g. not authenticated) but isn't
              // permanently invalid either — the payload is always the
              // fixed quick-log defaults, so leave it queued and retry later
              // rather than ever silently dropping a log.
              continue;
            }
            // A network-type failure (offline, flaky connection) — stop
            // this pass; the next online event or retry interval tries again.
            break;
          }
        }
      } finally {
        this.flushing = false;
      }
    },

    reset() {
      this.entries = [];
      resolvers.clear();
    },
  },
});
