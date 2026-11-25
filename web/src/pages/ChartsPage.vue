<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  LinearScale,
  Tooltip,
} from "chart.js";
import { Bar } from "vue-chartjs";
import { useBabiesStore } from "@/stores/babies";
import { useChartsStore, type ChartPoint } from "@/stores/charts";

ChartJS.register(BarElement, CategoryScale, LinearScale, Tooltip);

type Preset = "today" | "7d" | "30d" | "custom";
type Metric = "diaper" | "bottle" | "breastfeeding";

const METRICS: Metric[] = ["diaper", "bottle", "breastfeeding"];
const METRIC_ICONS: Record<Metric, string> = {
  diaper: "🧷",
  bottle: "🍼",
  breastfeeding: "🤱",
};

const babies = useBabiesStore();
const charts = useChartsStore();
const { t, locale } = useI18n();

const preset = ref<Preset>("7d");
const customFrom = ref(toDateInputValue(new Date()));
const customTo = ref(toDateInputValue(new Date()));

function toDateInputValue(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function startOfDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function endOfDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(23, 59, 59, 999);
  return copy;
}

function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

const activeRange = computed(() => {
  const now = new Date();

  if (preset.value === "today") return { from: startOfDay(now), to: endOfDay(now) };
  if (preset.value === "7d") return { from: startOfDay(addDays(now, -6)), to: endOfDay(now) };
  if (preset.value === "30d") return { from: startOfDay(addDays(now, -29)), to: endOfDay(now) };

  return {
    from: startOfDay(new Date(`${customFrom.value}T00:00`)),
    to: endOfDay(new Date(`${customTo.value}T00:00`)),
  };
});

async function reload() {
  if (!babies.activeBaby) return;
  await charts.fetchCharts(babies.activeBaby.id, activeRange.value);
}

onMounted(reload);
watch(() => babies.activeBabyId, reload);
watch(activeRange, reload);

function selectPreset(next: Preset) {
  preset.value = next;
}

function dayLabel(iso: string): string {
  return new Date(`${iso}T00:00`).toLocaleDateString(locale.value, {
    month: "short",
    day: "numeric",
  });
}

function metricSeries(metric: Metric): ChartPoint[] {
  return charts.data[metric];
}

function metricTotal(metric: Metric): number {
  return metricSeries(metric).reduce((sum, point) => sum + point.count, 0);
}

// Canvas fillStyle can't resolve CSS custom properties the way DOM styles
// can, so the fixed metric accents have to be read as literal computed
// values rather than passed through as "var(--color-diaper)" strings.
function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function metricColor(metric: Metric): string {
  if (metric === "diaper") return cssVar("--color-diaper");
  if (metric === "bottle") return cssVar("--color-bottle");
  return cssVar("--color-breastfeeding");
}

function metricTitle(metric: Metric): string {
  if (metric === "diaper") return t("diaperLog.total");
  if (metric === "bottle") return t("bottleFeeding.total");
  return t("breastfeedingLog.total");
}

function metricIcon(metric: Metric): string {
  return METRIC_ICONS[metric];
}

function chartData(metric: Metric) {
  const points = metricSeries(metric);
  return {
    labels: points.map((point) => dayLabel(point.date)),
    datasets: [
      {
        data: points.map((point) => point.count),
        backgroundColor: metricColor(metric),
        borderRadius: 4,
        maxBarThickness: 28,
      },
    ],
  };
}

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { grid: { display: false } },
    y: { beginAtZero: true, ticks: { precision: 0 } },
  },
};
</script>

<template>
  <div class="charts-page">
    <div class="range-header">
      <h1 class="charts-heading heading">{{ t("charts.heading") }}</h1>

      <div class="preset-tabs">
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'today' }"
          @click="selectPreset('today')"
        >
          {{ t("charts.today") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '7d' }"
          @click="selectPreset('7d')"
        >
          {{ t("charts.sevenDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '30d' }"
          @click="selectPreset('30d')"
        >
          {{ t("charts.thirtyDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'custom' }"
          @click="selectPreset('custom')"
        >
          {{ t("charts.custom") }}
        </button>
      </div>

      <div v-if="preset === 'custom'" class="custom-range">
        <input v-model="customFrom" type="date" />
        <span>{{ t("charts.to") }}</span>
        <input v-model="customTo" type="date" />
      </div>
    </div>

    <div v-for="metric in METRICS" :key="metric" class="chart-card">
      <h2 class="chart-card-title">
        <span>{{ metricIcon(metric) }}</span>
        <span>{{ metricTitle(metric) }}</span>
      </h2>

      <div v-if="metricTotal(metric) === 0" class="chart-empty">{{ t("charts.empty") }}</div>
      <div v-else class="chart-canvas">
        <Bar :data="chartData(metric)" :options="chartOptions" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.charts-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: var(--space-3) var(--space-2) var(--space-4);
}

.range-header {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-3);
  text-align: center;
  margin-bottom: var(--space-3);
}

.charts-heading {
  margin: 0 0 var(--space-2);
  font-size: 1.25rem;
}

.preset-tabs {
  display: flex;
  gap: 6px;
  justify-content: center;
}

.preset-tab {
  border: 1px solid var(--color-border);
  background: var(--color-bg);
  color: var(--color-ink-secondary);
  border-radius: var(--radius-pill);
  padding: 6px 12px;
  font-size: 0.8125rem;
  cursor: pointer;
}

.preset-tab.active {
  background: var(--color-accent);
  border-color: var(--color-accent);
  color: #ffffff;
  font-weight: 600;
}

.custom-range {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: var(--space-2);
  font-size: 0.8125rem;
  color: var(--color-ink-secondary);
}

.custom-range input {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 6px 8px;
}

.chart-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-3);
  margin-bottom: var(--space-2);
}

.chart-card-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 0 var(--space-2);
  font-size: 1rem;
}

.chart-canvas {
  height: 220px;
}

.chart-empty {
  text-align: center;
  color: var(--color-ink-secondary);
  font-size: 0.875rem;
  padding: var(--space-3) 0;
}
</style>
