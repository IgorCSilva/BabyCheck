import { defineStore } from "pinia";
import { apiRequest } from "@/lib/api";

export interface BottleFeeding {
  id: number;
  baby_id: number;
  logged_at: string;
  water_ml: number;
  formula_g: number;
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
    quickLog(babyId: number): { tempId: number; promise: Promise<BottleFeeding> } {
      const tempId = -Date.now();
      this.feedings.unshift({
        id: tempId,
        baby_id: babyId,
        logged_at: new Date().toISOString(),
        water_ml: DEFAULT_WATER_ML,
        formula_g: DEFAULT_FORMULA_G,
      });

      const promise = apiRequest<BottleFeeding>(`/api/babies/${babyId}/bottle_feedings`, {
        method: "POST",
      })
        .then((feeding) => {
          const index = this.feedings.findIndex((entry) => entry.id === tempId);
          if (index !== -1) this.feedings.splice(index, 1, feeding);
          return feeding;
        })
        .catch((error) => {
          this.feedings = this.feedings.filter((entry) => entry.id !== tempId);
          throw error;
        });

      return { tempId, promise };
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
