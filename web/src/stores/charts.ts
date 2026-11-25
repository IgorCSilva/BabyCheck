import { defineStore } from "pinia";
import { apiRequest } from "@/lib/api";

export interface ChartPoint {
  date: string;
  count: number;
}

export interface ChartData {
  diaper: ChartPoint[];
  bottle: ChartPoint[];
  breastfeeding: ChartPoint[];
}

export interface DateRange {
  from: Date;
  to: Date;
}

interface ChartsState {
  data: ChartData;
  loading: boolean;
  lastBabyId: number | null;
  lastRange: DateRange | null;
}

function buildQuery(range: DateRange): string {
  const params = new URLSearchParams({
    from: range.from.toISOString(),
    to: range.to.toISOString(),
  });
  return params.toString();
}

export const useChartsStore = defineStore("charts", {
  state: (): ChartsState => ({
    data: { diaper: [], bottle: [], breastfeeding: [] },
    loading: false,
    lastBabyId: null,
    lastRange: null,
  }),

  actions: {
    async fetchCharts(babyId: number, range: DateRange) {
      this.lastBabyId = babyId;
      this.lastRange = range;
      this.loading = true;
      try {
        this.data = await apiRequest<ChartData>(
          `/api/babies/${babyId}/charts?${buildQuery(range)}`,
          { method: "GET" },
        );
      } finally {
        this.loading = false;
      }
    },

    // Lets a mutation made elsewhere (the global quick-log bar) bring an
    // already-open Charts page back in sync without it having to expose its
    // own locally-computed range to anything outside itself.
    async refresh() {
      if (this.lastBabyId === null || this.lastRange === null) return;
      await this.fetchCharts(this.lastBabyId, this.lastRange);
    },

    reset() {
      this.data = { diaper: [], bottle: [], breastfeeding: [] };
      this.loading = false;
      this.lastBabyId = null;
      this.lastRange = null;
    },
  },
});
