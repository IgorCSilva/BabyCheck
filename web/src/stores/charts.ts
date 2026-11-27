import { defineStore } from "pinia";
import { apiRequest, apiRequestBlob } from "@/lib/api";
import { i18n } from "@/i18n";

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

    // Fetches the Step 12 PDF summary and triggers a browser download —
    // the same aggregate query/range the on-screen charts already use, so
    // this never needs its own loading/range state beyond what's passed in.
    // The PDF is rendered server-side with no session locale of its own, so
    // the currently active UI locale rides along as a query param.
    async exportSummary(babyId: number, range: DateRange): Promise<void> {
      const params = new URLSearchParams({
        from: range.from.toISOString(),
        to: range.to.toISOString(),
        locale: i18n.global.locale.value,
      });
      const { blob, filename } = await apiRequestBlob(
        `/api/babies/${babyId}/export?${params.toString()}`,
      );

      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename || "babycheck-summary.pdf";
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    },

    reset() {
      this.data = { diaper: [], bottle: [], breastfeeding: [] };
      this.loading = false;
      this.lastBabyId = null;
      this.lastRange = null;
    },
  },
});
