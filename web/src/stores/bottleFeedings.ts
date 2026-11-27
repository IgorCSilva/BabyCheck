import { defineStore } from "pinia";
import { apiRequest, ApiError } from "@/lib/api";
import { useOutboxStore } from "@/stores/outbox";

export interface BottleFeeding {
  id: number;
  baby_id: number;
  logged_at: string;
  water_ml: number;
  formula_g: number;
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

interface BottleFeedingsState {
  feedings: BottleFeeding[];
  loading: boolean;
}

export const DEFAULT_WATER_ML = 30;
export const DEFAULT_FORMULA_G = 10;

function buildQuery(range: DateRange): string {
  const params = new URLSearchParams({
    from: range.from.toISOString(),
    to: range.to.toISOString(),
  });
  return params.toString();
}

export const useBottleFeedingsStore = defineStore("bottleFeedings", {
  state: (): BottleFeedingsState => ({
    feedings: [],
    loading: false,
  }),

  actions: {
    async fetchFeedings(babyId: number, range: DateRange) {
      this.loading = true;
      try {
        this.feedings = await apiRequest<BottleFeeding[]>(
          `/api/babies/${babyId}/bottle_feedings?${buildQuery(range)}`,
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
    quickLog(babyId: number): { tempId: number; promise: Promise<BottleFeeding> } {
      const tempId = -Date.now();
      const payload = {
        logged_at: new Date().toISOString(),
        water_ml: DEFAULT_WATER_ML,
        formula_g: DEFAULT_FORMULA_G,
      };
      this.feedings.unshift({ id: tempId, baby_id: babyId, ...payload });

      const promise = apiRequest<BottleFeeding>(`/api/babies/${babyId}/bottle_feedings`, {
        method: "POST",
        body: { ...payload, client_request_id: String(tempId) },
      })
        .then((feeding) => {
          this.resolvePending(tempId, feeding);
          return feeding;
        })
        .catch((error) => {
          if (error instanceof ApiError) {
            this.feedings = this.feedings.filter((entry) => entry.id !== tempId);
            throw error;
          }

          const row = this.feedings.find((entry) => entry.id === tempId);
          if (row) row._queued = true;
          return useOutboxStore().enqueue({
            tempId,
            metric: "bottle",
            baby_id: babyId,
            payload,
          }) as Promise<BottleFeeding>;
        });

      return { tempId, promise };
    },

    resolvePending(tempId: number, feeding: BottleFeeding) {
      const index = this.feedings.findIndex((entry) => entry.id === tempId);
      if (index !== -1) this.feedings.splice(index, 1, feeding);
    },

    // Reconciles the outbox's persisted view with this store's in-memory
    // `feedings` — needed because a reload while still offline starts with
    // an empty store, so an entry queued before the reload would otherwise
    // vanish from view until it eventually syncs, even though it was never
    // actually lost.
    restoreQueued(babyId: number) {
      for (const entry of useOutboxStore().entriesFor("bottle", babyId)) {
        if (this.feedings.some((feeding) => feeding.id === entry.tempId)) continue;
        this.feedings.unshift({
          id: entry.tempId,
          baby_id: babyId,
          ...(entry.payload as { logged_at: string; water_ml: number; formula_g: number }),
          _queued: true,
        });
      }
      this.feedings.sort((a, b) => b.logged_at.localeCompare(a.logged_at));
    },

    // Undo on an entry that hasn't synced yet: cancel it before it's ever
    // sent, instead of awaiting a promise that won't resolve until
    // reconnect. Returns whether it actually was still queued — the caller
    // falls back to the normal await-then-delete flow otherwise.
    tryDiscard(tempId: number): boolean {
      if (!useOutboxStore().cancelIfQueued(tempId)) return false;
      this.feedings = this.feedings.filter((entry) => entry.id !== tempId);
      return true;
    },

    async updateFeeding(
      id: number,
      attrs: { logged_at: string; water_ml: number; formula_g: number },
    ) {
      const feeding = await apiRequest<BottleFeeding>(`/api/bottle_feedings/${id}`, {
        method: "PUT",
        body: attrs,
      });
      const index = this.feedings.findIndex((entry) => entry.id === id);
      if (index !== -1) this.feedings.splice(index, 1, feeding);
      this.feedings.sort((a, b) => b.logged_at.localeCompare(a.logged_at));
      return feeding;
    },

    async deleteFeeding(id: number) {
      await apiRequest<void>(`/api/bottle_feedings/${id}`, { method: "DELETE" });
      this.feedings = this.feedings.filter((entry) => entry.id !== id);
    },

    reset() {
      this.feedings = [];
      this.loading = false;
    },
  },
});
