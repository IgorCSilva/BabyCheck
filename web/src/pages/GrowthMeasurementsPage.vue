<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import {
  CategoryScale,
  Chart as ChartJS,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from "chart.js";
import { Line } from "vue-chartjs";
import { useBabiesStore } from "@/stores/babies";
import {
  useGrowthMeasurementsStore,
  type GrowthMeasurement,
} from "@/stores/growthMeasurements";
import { ApiError } from "@/lib/api";
import { translateApiError, translateFieldErrors } from "@/i18n";

ChartJS.register(CategoryScale, LinearScale, LineElement, PointElement, Tooltip);

const babies = useBabiesStore();
const measurements = useGrowthMeasurementsStore();
const { t, locale } = useI18n();

const formCard = ref<HTMLElement | null>(null);
const editingId = ref<number | null>(null);
const weight = ref("");
const height = ref("");
const measuredAt = ref(toDateInputValue(new Date()));
const submitting = ref(false);
const errorMessage = ref("");
const fieldErrors = ref<Record<string, string[]>>({});

const isEditing = computed(() => editingId.value !== null);

const exporting = ref(false);
const exportError = ref(false);

function toDateInputValue(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

async function reload() {
  if (!babies.activeBaby) return;
  await measurements.fetchMeasurements(babies.activeBaby.id);
}

onMounted(reload);
watch(() => babies.activeBabyId, reload);

function resetForm() {
  editingId.value = null;
  weight.value = "";
  height.value = "";
  measuredAt.value = toDateInputValue(new Date());
  errorMessage.value = "";
  fieldErrors.value = {};
}

function startEdit(measurement: GrowthMeasurement) {
  editingId.value = measurement.id;
  weight.value = measurement.weight_kg === null ? "" : String(measurement.weight_kg);
  height.value = measurement.height_cm === null ? "" : String(measurement.height_cm);
  measuredAt.value = measurement.measured_at;
  errorMessage.value = "";
  fieldErrors.value = {};

  // The row being edited can be well below the form in the history list, so
  // the field values updating is invisible unless the form itself scrolls
  // into view. A plain scrollIntoView has no way to leave a gap above the
  // card (it would butt it right up against the viewport's top edge), so
  // the target offset is computed manually instead.
  nextTick(() => {
    if (!formCard.value) return;
    const top = formCard.value.getBoundingClientRect().top + window.scrollY - 180;
    window.scrollTo({ top, behavior: "smooth" });
  });
}

async function onSubmit() {
  if (!babies.activeBaby) return;

  submitting.value = true;
  errorMessage.value = "";
  fieldErrors.value = {};

  const input = {
    weight_kg: weight.value === "" ? null : Number(weight.value),
    height_cm: height.value === "" ? null : Number(height.value),
    measured_at: measuredAt.value,
  };

  try {
    if (editingId.value !== null) {
      await measurements.updateMeasurement(editingId.value, input);
    } else {
      await measurements.createMeasurement(babies.activeBaby.id, input);
    }
    resetForm();
  } catch (error) {
    if (error instanceof ApiError) {
      errorMessage.value = Object.keys(error.fieldErrors).length ? "" : translateApiError(error);
      fieldErrors.value = translateFieldErrors(error.fieldErrors);
    } else {
      errorMessage.value = t("auth.genericError");
    }
  } finally {
    submitting.value = false;
  }
}

async function onDelete(measurement: GrowthMeasurement) {
  if (!window.confirm(t("growth.confirmDelete"))) return;
  await measurements.deleteMeasurement(measurement.id).catch(() => {});
  if (editingId.value === measurement.id) resetForm();
}

async function exportPdf() {
  if (!babies.activeBaby || exporting.value) return;
  exporting.value = true;
  exportError.value = false;
  try {
    await measurements.exportPdf(babies.activeBaby.id);
  } catch {
    exportError.value = true;
  } finally {
    exporting.value = false;
  }
}

function dateLabel(isoDate: string): string {
  return new Date(`${isoDate}T00:00`).toLocaleDateString(locale.value, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function yearLabel(isoDate: string): string {
  return isoDate.slice(0, 4);
}

const groupedMeasurements = computed(() => {
  const groups: { label: string; entries: GrowthMeasurement[] }[] = [];

  for (const entry of measurements.measurements) {
    const label = yearLabel(entry.measured_at);
    const lastGroup = groups[groups.length - 1];
    if (lastGroup && lastGroup.label === label) {
      lastGroup.entries.push(entry);
    } else {
      groups.push({ label, entries: [entry] });
    }
  }

  return groups;
});

// Trend charts read left-to-right as time passing, the opposite of the
// history list below (which, like every other list page, shows the
// newest entry first).
const chronological = computed(() =>
  [...measurements.measurements].sort((a, b) => a.measured_at.localeCompare(b.measured_at)),
);

function trendData(field: "weight_kg" | "height_cm", color: string) {
  const points = chronological.value.filter((entry) => entry[field] !== null);
  return {
    labels: points.map((entry) => dateLabel(entry.measured_at)),
    datasets: [
      {
        data: points.map((entry) => entry[field]),
        borderColor: color,
        backgroundColor: color,
        tension: 0.3,
        pointRadius: 3,
      },
    ],
  };
}

const weightTrendData = computed(() => trendData("weight_kg", "#9FDFC0"));
const heightTrendData = computed(() => trendData("height_cm", "#9DC8E8"));

const hasWeightData = computed(() =>
  measurements.measurements.some((entry) => entry.weight_kg !== null),
);
const hasHeightData = computed(() =>
  measurements.measurements.some((entry) => entry.height_cm !== null),
);

const trendOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { grid: { display: false } },
    y: { beginAtZero: false },
  },
};
</script>

<template>
  <div class="growth-page">
    <h1 class="heading growth-heading">{{ t("growth.heading") }}</h1>

    <div class="export-row">
      <button type="button" class="export-button" :disabled="exporting" @click="exportPdf">
        {{ exporting ? t("growth.exporting") : t("growth.export") }}
      </button>
      <p v-if="exportError" class="field-error">{{ t("growth.exportError") }}</p>
    </div>

    <div ref="formCard" class="growth-card">
      <h2 class="growth-form-title">
        {{ isEditing ? t("growth.editTitle") : t("growth.addTitle") }}
      </h2>

      <form @submit.prevent="onSubmit">
        <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

        <div class="field">
          <label for="growth-weight">{{ t("growth.weightLabel") }}</label>
          <input
            id="growth-weight"
            v-model="weight"
            type="number"
            step="0.01"
            min="0"
            inputmode="decimal"
          />
          <p v-if="fieldErrors.weight_kg" class="field-error">
            {{ fieldErrors.weight_kg.join(", ") }}
          </p>
        </div>

        <div class="field">
          <label for="growth-height">{{ t("growth.heightLabel") }}</label>
          <input
            id="growth-height"
            v-model="height"
            type="number"
            step="0.1"
            min="0"
            inputmode="decimal"
          />
          <p v-if="fieldErrors.height_cm" class="field-error">
            {{ fieldErrors.height_cm.join(", ") }}
          </p>
        </div>

        <div class="field">
          <label for="growth-date">{{ t("growth.dateLabel") }}</label>
          <input id="growth-date" v-model="measuredAt" type="date" required />
          <p v-if="fieldErrors.measured_at" class="field-error">
            {{ fieldErrors.measured_at.join(", ") }}
          </p>
        </div>

        <button class="btn-primary" type="submit" :disabled="submitting">
          {{
            submitting
              ? t("growth.saving")
              : isEditing
                ? t("growth.saveSubmit")
                : t("growth.addSubmit")
          }}
        </button>

        <button v-if="isEditing" class="helper-link" type="button" @click="resetForm">
          {{ t("growth.cancel") }}
        </button>
      </form>
    </div>

    <div v-if="measurements.measurements.length === 0" class="empty-state">
      {{ t("growth.empty") }}
    </div>

    <template v-else>
      <div v-if="hasWeightData" class="chart-card">
        <h2 class="chart-card-title">{{ t("growth.weightTrend") }}</h2>
        <div class="chart-canvas">
          <Line :data="weightTrendData" :options="trendOptions" />
        </div>
      </div>

      <div v-if="hasHeightData" class="chart-card">
        <h2 class="chart-card-title">{{ t("growth.heightTrend") }}</h2>
        <div class="chart-canvas">
          <Line :data="heightTrendData" :options="trendOptions" />
        </div>
      </div>

      <div v-for="group in groupedMeasurements" :key="group.label" class="year-group">
        <h2 class="year-header">{{ group.label }}</h2>

        <div v-for="entry in group.entries" :key="entry.id" class="measurement-row">
          <span class="measurement-row-date">{{ dateLabel(entry.measured_at) }}</span>
          <span class="measurement-row-values">
            <span v-if="entry.weight_kg !== null">{{ entry.weight_kg }}{{ t("growth.weightUnit") }}</span>
            <span v-if="entry.height_cm !== null">{{ entry.height_cm }}{{ t("growth.heightUnit") }}</span>
          </span>
          <button class="measurement-row-action" type="button" @click="startEdit(entry)">
            {{ t("growth.edit") }}
          </button>
          <button
            class="measurement-row-action measurement-row-delete"
            type="button"
            @click="onDelete(entry)"
          >
            {{ t("growth.delete") }}
          </button>
        </div>
      </div>
    </template>

    <router-link class="helper-link" to="/">{{ t("growth.backHome") }}</router-link>
  </div>
</template>

<style scoped>
.growth-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: var(--space-3) var(--space-2)
    calc(56px + var(--space-4) + env(safe-area-inset-bottom, 0px));
}

.growth-heading {
  text-align: center;
  font-size: 1.25rem;
  margin: 0 0 var(--space-3);
}

.export-row {
  text-align: center;
  margin-bottom: var(--space-3);
}

.export-button {
  border: 1px solid var(--color-accent);
  background: var(--color-bg);
  color: var(--color-accent);
  border-radius: var(--radius-pill);
  padding: 8px 16px;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

.export-button:disabled {
  opacity: 0.6;
  cursor: default;
}

.growth-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-3);
  margin-bottom: var(--space-3);
}

.growth-form-title {
  margin: 0 0 var(--space-2);
  font-size: 1rem;
}

.empty-state {
  text-align: center;
  color: var(--color-ink-secondary);
  font-size: 0.875rem;
  padding: var(--space-3) 0;
}

.chart-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-3);
  margin-bottom: var(--space-2);
}

.chart-card-title {
  margin: 0 0 var(--space-2);
  font-size: 1rem;
}

.chart-canvas {
  height: 180px;
}

.year-group {
  margin-bottom: var(--space-2);
}

.year-header {
  font-size: 0.8125rem;
  color: var(--color-ink-secondary);
  font-family: var(--font-body);
  font-weight: 600;
  margin: 0 0 6px;
}

.measurement-row {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: 10px 0;
  border-bottom: 1px solid var(--color-border);
}

.measurement-row-date {
  font-weight: 600;
  min-width: 96px;
}

.measurement-row-values {
  flex: 1;
  display: flex;
  gap: 8px;
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
}

.measurement-row-action {
  border: none;
  background: none;
  color: var(--color-accent);
  font-size: 0.8125rem;
  cursor: pointer;
  padding: 6px 10px;
  border-radius: var(--radius-pill);
}

.measurement-row-delete {
  color: var(--color-danger);
}
</style>
