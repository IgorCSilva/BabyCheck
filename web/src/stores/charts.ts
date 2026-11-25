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
  }),

  actions: {
    async fetchCharts(babyId: number, range: DateRange) {
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

    reset() {
      this.data = { diaper: [], bottle: [], breastfeeding: [] };
      this.loading = false;
    },
  },
});
