import { defineStore } from "pinia";
import { apiRequest } from "@/lib/api";

export interface BreastfeedingLog {
  id: number;
  baby_id: number;
  logged_at: string;
}

export interface DateRange {
  from: Date;
  to: Date;
}

interface BreastfeedingLogsState {
  logs: BreastfeedingLog[];
  loading: boolean;
}

function buildQuery(range: DateRange): string {
  const params = new URLSearchParams({
    from: range.from.toISOString(),
    to: range.to.toISOString(),
  });
  return params.toString();
}

export const useBreastfeedingLogsStore = defineStore("breastfeedingLogs", {
  state: (): BreastfeedingLogsState => ({
    logs: [],
    loading: false,
  }),

  actions: {
    async fetchLogs(babyId: number, range: DateRange) {
      this.loading = true;
      try {
        this.logs = await apiRequest<BreastfeedingLog[]>(
          `/api/babies/${babyId}/breastfeeding_logs?${buildQuery(range)}`,
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
    quickLog(babyId: number): { tempId: number; promise: Promise<BreastfeedingLog> } {
      const tempId = -Date.now();
      this.logs.unshift({
        id: tempId,
        baby_id: babyId,
        logged_at: new Date().toISOString(),
      });

      const promise = apiRequest<BreastfeedingLog>(
        `/api/babies/${babyId}/breastfeeding_logs`,
        { method: "POST" },
      )
        .then((log) => {
          const index = this.logs.findIndex((entry) => entry.id === tempId);
          if (index !== -1) this.logs.splice(index, 1, log);
          return log;
        })
        .catch((error) => {
          this.logs = this.logs.filter((entry) => entry.id !== tempId);
          throw error;
        });

      return { tempId, promise };
    },

    async updateLog(id: number, attrs: { logged_at: string }) {
      const log = await apiRequest<BreastfeedingLog>(`/api/breastfeeding_logs/${id}`, {
        method: "PUT",
        body: attrs,
      });
      const index = this.logs.findIndex((entry) => entry.id === id);
      if (index !== -1) this.logs.splice(index, 1, log);
      this.logs.sort((a, b) => b.logged_at.localeCompare(a.logged_at));
      return log;
    },

    async deleteLog(id: number) {
      await apiRequest<void>(`/api/breastfeeding_logs/${id}`, { method: "DELETE" });
      this.logs = this.logs.filter((entry) => entry.id !== id);
    },

    reset() {
      this.logs = [];
      this.loading = false;
    },
  },
});
