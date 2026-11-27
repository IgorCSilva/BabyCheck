import { defineStore } from "pinia";
import { apiRequest, ApiError } from "@/lib/api";
import { useOutboxStore } from "@/stores/outbox";

export interface DiaperLog {
  id: number;
  baby_id: number;
  logged_at: string;
  peed: boolean;
  pooped: boolean;
  // Set on a row still sitting in the offline outbox, waiting for
  // connectivity — distinct from the brief in-flight `id < 0` window every
  // optimistic insert goes through, which usually resolves in well under a
  // second.
  _queued?: boolean;
}

export interface DateRange {
  from: Date;
  to: Date;
}

interface DiaperLogsState {
  logs: DiaperLog[];
  loading: boolean;
}

function buildQuery(range: DateRange): string {
  const params = new URLSearchParams({
    from: range.from.toISOString(),
    to: range.to.toISOString(),
  });
  return params.toString();
}

export const useDiaperLogsStore = defineStore("diaperLogs", {
  state: (): DiaperLogsState => ({
    logs: [],
    loading: false,
  }),

  actions: {
    async fetchLogs(babyId: number, range: DateRange) {
      this.loading = true;
      try {
        this.logs = await apiRequest<DiaperLog[]>(
          `/api/babies/${babyId}/diaper_logs?${buildQuery(range)}`,
          { method: "GET" },
        );
      } finally {
        this.loading = false;
      }
    },

    // Inserts a placeholder immediately (negative id, guaranteed to never
    // collide with a real serial id) so the UI reflects the tap instantly,
    // then swaps it for the server's record once the request resolves. The
    // returned promise lets the caller's "Undo" button await the real id
    // before issuing the delete, even if clicked before the request lands.
    //
    // The request is always attempted immediately, online or not — only a
    // genuine network failure (not a real server error) falls back to the
    // offline outbox, so a flaky connection gets the same safety net as a
    // hard offline state, not just whatever `navigator.onLine` happens to
    // report.
    quickLog(babyId: number): { tempId: number; promise: Promise<DiaperLog> } {
      const tempId = -Date.now();
      const payload = { logged_at: new Date().toISOString(), peed: true, pooped: true };
      this.logs.unshift({ id: tempId, baby_id: babyId, ...payload });

      const promise = apiRequest<DiaperLog>(`/api/babies/${babyId}/diaper_logs`, {
        method: "POST",
        body: { ...payload, client_request_id: String(tempId) },
      })
        .then((log) => {
          this.resolvePending(tempId, log);
          return log;
        })
        .catch((error) => {
          if (error instanceof ApiError) {
            this.logs = this.logs.filter((entry) => entry.id !== tempId);
            throw error;
          }

          const row = this.logs.find((entry) => entry.id === tempId);
          if (row) row._queued = true;
          return useOutboxStore().enqueue({
            tempId,
            metric: "diaper",
            baby_id: babyId,
            payload,
          }) as Promise<DiaperLog>;
        });

      return { tempId, promise };
    },

    resolvePending(tempId: number, log: DiaperLog) {
      const index = this.logs.findIndex((entry) => entry.id === tempId);
      if (index !== -1) this.logs.splice(index, 1, log);
    },

    // Reconciles the outbox's persisted view with this store's in-memory
    // `logs` — needed because a reload while still offline starts with an
    // empty store, so an entry queued before the reload would otherwise
    // vanish from view until it eventually syncs, even though it was never
    // actually lost.
    restoreQueued(babyId: number) {
      for (const entry of useOutboxStore().entriesFor("diaper", babyId)) {
        if (this.logs.some((log) => log.id === entry.tempId)) continue;
        this.logs.unshift({
          id: entry.tempId,
          baby_id: babyId,
          ...(entry.payload as { logged_at: string; peed: boolean; pooped: boolean }),
          _queued: true,
        });
      }
      this.logs.sort((a, b) => b.logged_at.localeCompare(a.logged_at));
    },

    // Undo on an entry that hasn't synced yet: cancel it before it's ever
    // sent, instead of awaiting a promise that won't resolve until
    // reconnect. Returns whether it actually was still queued — the caller
    // falls back to the normal await-then-delete flow otherwise.
    tryDiscard(tempId: number): boolean {
      if (!useOutboxStore().cancelIfQueued(tempId)) return false;
      this.logs = this.logs.filter((entry) => entry.id !== tempId);
      return true;
    },

    async updateLog(id: number, attrs: { logged_at: string; peed: boolean; pooped: boolean }) {
      const log = await apiRequest<DiaperLog>(`/api/diaper_logs/${id}`, {
        method: "PUT",
        body: attrs,
      });
      const index = this.logs.findIndex((entry) => entry.id === id);
      if (index !== -1) this.logs.splice(index, 1, log);
      this.logs.sort((a, b) => b.logged_at.localeCompare(a.logged_at));
      return log;
    },

    async deleteLog(id: number) {
      await apiRequest<void>(`/api/diaper_logs/${id}`, { method: "DELETE" });
      this.logs = this.logs.filter((entry) => entry.id !== id);
    },

    reset() {
      this.logs = [];
      this.loading = false;
    },
  },
});
