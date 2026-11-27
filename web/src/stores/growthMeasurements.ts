import { defineStore } from "pinia";
import { apiRequest, apiRequestBlob } from "@/lib/api";
import { i18n } from "@/i18n";

export interface GrowthMeasurement {
  id: number;
  baby_id: number;
  weight_kg: number | null;
  height_cm: number | null;
  measured_at: string;
}

export interface GrowthMeasurementInput {
  weight_kg: number | null;
  height_cm: number | null;
  measured_at: string;
}

interface GrowthMeasurementsState {
  measurements: GrowthMeasurement[];
  loading: boolean;
}

export const useGrowthMeasurementsStore = defineStore("growthMeasurements", {
  state: (): GrowthMeasurementsState => ({
    measurements: [],
    loading: false,
  }),

  actions: {
    // Unlike the Phase 2 quick-logs, these are occasional, deliberately
    // entered measurements — no optimistic insert, no offline outbox: a
    // weigh-in form submit can just wait for the real response.
    async fetchMeasurements(babyId: number) {
      this.loading = true;
      try {
        this.measurements = await apiRequest<GrowthMeasurement[]>(
          `/api/babies/${babyId}/growth_measurements`,
          { method: "GET" },
        );
      } finally {
        this.loading = false;
      }
    },

    async createMeasurement(babyId: number, input: GrowthMeasurementInput) {
      const measurement = await apiRequest<GrowthMeasurement>(
        `/api/babies/${babyId}/growth_measurements`,
        { method: "POST", body: { ...input } },
      );
      this.measurements.unshift(measurement);
      this.measurements.sort((a, b) => b.measured_at.localeCompare(a.measured_at));
      return measurement;
    },

    async updateMeasurement(id: number, input: GrowthMeasurementInput) {
      const measurement = await apiRequest<GrowthMeasurement>(`/api/growth_measurements/${id}`, {
        method: "PUT",
        body: { ...input },
      });
      const index = this.measurements.findIndex((entry) => entry.id === id);
      if (index !== -1) this.measurements.splice(index, 1, measurement);
      this.measurements.sort((a, b) => b.measured_at.localeCompare(a.measured_at));
      return measurement;
    },

    async deleteMeasurement(id: number) {
      await apiRequest<void>(`/api/growth_measurements/${id}`, { method: "DELETE" });
      this.measurements = this.measurements.filter((entry) => entry.id !== id);
    },

    // Mirrors charts.ts's exportSummary — a dedicated PDF for this page
    // alone (not bundled with the Step 12 diaper/bottle/breastfeeding
    // export), since the Growth page has no date-range picker of its own
    // and always exports the full history shown on screen.
    async exportPdf(babyId: number): Promise<void> {
      const params = new URLSearchParams({ locale: i18n.global.locale.value });
      const { blob, filename } = await apiRequestBlob(
        `/api/babies/${babyId}/growth_measurements/export?${params.toString()}`,
      );

      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename || "babycheck-growth.pdf";
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    },

    reset() {
      this.measurements = [];
      this.loading = false;
    },
  },
});
