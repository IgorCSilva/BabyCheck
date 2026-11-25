<script setup lang="ts">
import { reactive, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";
import { useDiaperLogsStore } from "@/stores/diaperLogs";
import { useBottleFeedingsStore } from "@/stores/bottleFeedings";
import { useBreastfeedingLogsStore } from "@/stores/breastfeedingLogs";
import { useFeedStore } from "@/stores/feed";
import { useChartsStore } from "@/stores/charts";

type Metric = "diaper" | "bottle" | "breastfeeding";

const METRICS: Metric[] = ["diaper", "bottle", "breastfeeding"];
const METRIC_ICONS: Record<Metric, string> = {
  diaper: "🧷",
  bottle: "🍼",
  breastfeeding: "🤱",
};
const VIBRATE_MS = 30;
const TOAST_DURATION_MS = 5000;

const babies = useBabiesStore();
const diaperLogs = useDiaperLogsStore();
const bottleFeedings = useBottleFeedingsStore();
const breastfeedingLogs = useBreastfeedingLogsStore();
const feed = useFeedStore();
const charts = useChartsStore();
const { t } = useI18n();

const glowing = reactive<Record<Metric, boolean>>({
  diaper: false,
  bottle: false,
  breastfeeding: false,
});
const glowTimeouts: Partial<Record<Metric, ReturnType<typeof setTimeout>>> = {};

const toast = ref<{ metric: Metric; tempId: number; promise: Promise<{ id: number }> } | null>(
  null,
);
let toastTimeout: ReturnType<typeof setTimeout> | null = null;

function metricIcon(metric: Metric): string {
  return METRIC_ICONS[metric];
}

function quickLogLabel(metric: Metric): string {
  if (metric === "diaper") return t("diaperLog.quickLog");
  if (metric === "bottle") return t("bottleFeeding.quickLog");
  return t("breastfeedingLog.quickLog");
}

function toastMessage(metric: Metric): string {
  if (metric === "diaper") return t("diaperLog.toastLogged");
  if (metric === "bottle") return t("bottleFeeding.toastLogged");
  return t("breastfeedingLog.toastLogged");
}

function undoLabel(metric: Metric): string {
  if (metric === "diaper") return t("diaperLog.undo");
  if (metric === "bottle") return t("bottleFeeding.undo");
  return t("breastfeedingLog.undo");
}

function quickLogFor(metric: Metric, babyId: number) {
  if (metric === "diaper") return diaperLogs.quickLog(babyId);
  if (metric === "bottle") return bottleFeedings.quickLog(babyId);
  return breastfeedingLogs.quickLog(babyId);
}

function deleteFor(metric: Metric, id: number) {
  if (metric === "diaper") return diaperLogs.deleteLog(id);
  if (metric === "bottle") return bottleFeedings.deleteFeeding(id);
  return breastfeedingLogs.deleteLog(id);
}

// The bar can log from anywhere, including while the Feed or Charts page is
// already open behind it — but both of those read from their own separately
// fetched aggregates (the merged feed, the per-day chart buckets), not from
// diaperLogs/bottleFeedings/breastfeedingLogs directly, so a log made here
// wouldn't otherwise show up on them until their own next reload. Refetching
// both after every confirmed mutation keeps them live without requiring a
// manual page refresh.
function refreshDependents() {
  feed.fetchFeed().catch(() => {});
  feed.fetchSummary().catch(() => {});
  charts.refresh().catch(() => {});
}

function pulseGlow(metric: Metric) {
  glowing[metric] = false;
  requestAnimationFrame(() => {
    glowing[metric] = true;
    if (glowTimeouts[metric]) clearTimeout(glowTimeouts[metric]);
    glowTimeouts[metric] = setTimeout(() => (glowing[metric] = false), 700);
  });
}

async function onQuickLog(metric: Metric) {
  const baby = babies.activeBaby;
  if (!baby) return;

  pulseGlow(metric);
  navigator.vibrate?.(VIBRATE_MS);

  const entry = quickLogFor(metric, baby.id);
  toast.value = { metric, tempId: entry.tempId, promise: entry.promise };
  if (toastTimeout) clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => {
    if (toast.value?.tempId === entry.tempId) toast.value = null;
  }, TOAST_DURATION_MS);

  entry.promise.then(refreshDependents).catch(() => {});
}

async function onUndo() {
  const entry = toast.value;
  if (!entry) return;
  toast.value = null;
  if (toastTimeout) clearTimeout(toastTimeout);

  try {
    const logged = await entry.promise;
    await deleteFor(entry.metric, logged.id);
    refreshDependents();
  } catch {
    // The create itself failed — the optimistic row was already rolled back.
  }
}
</script>

<template>
  <div v-if="babies.activeBaby" class="quick-log-bar">
    <button
      v-for="metric in METRICS"
      :key="metric"
      class="quick-log-btn"
      :class="[`quick-log-btn-${metric}`, { glow: glowing[metric] }]"
      :style="{ '--baby-color': babies.activeBaby.theme_color }"
      type="button"
      :aria-label="quickLogLabel(metric)"
      @click="onQuickLog(metric)"
    >
      <span aria-hidden="true">{{ metricIcon(metric) }}</span>
    </button>

    <div v-if="toast" class="quick-log-toast">
      {{ toastMessage(toast.metric) }}
      <button type="button" @click="onUndo">{{ undoLabel(toast.metric) }}</button>
    </div>
  </div>
</template>

<style scoped>
/* Docked to the bottom edge, in the thumb-reachable zone on mobile, so
   logging never requires navigating to a metric's own page first. Capped
   at 480px and centered, same as every other surface in the app, which
   doubles as the "floating panel" look on wider screens. */
.quick-log-bar {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 20;
  display: flex;
  justify-content: center;
  gap: var(--space-2);
  max-width: 480px;
  margin: 0 auto;
  padding: var(--space-2) var(--space-2) calc(var(--space-2) + env(safe-area-inset-bottom, 0px));
}

.quick-log-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 56px;
  min-width: 56px;
  border: none;
  border-radius: var(--radius-pill);
  color: #ffffff;
  font-size: 1.5rem;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.16);
  position: relative;
}

.quick-log-btn-diaper {
  background: var(--color-diaper);
}

.quick-log-btn-bottle {
  background: var(--color-bottle);
}

.quick-log-btn-breastfeeding {
  background: var(--color-breastfeeding);
}

.quick-log-btn.glow::before {
  content: "";
  position: absolute;
  inset: -14px;
  border-radius: inherit;
  background: radial-gradient(
    circle,
    color-mix(in srgb, var(--baby-color, var(--color-accent)) 50%, transparent) 0%,
    transparent 70%
  );
  z-index: -1;
}

.quick-log-toast {
  position: fixed;
  left: 50%;
  bottom: calc(56px + var(--space-3) * 2 + env(safe-area-inset-bottom, 0px));
  transform: translateX(-50%);
  z-index: 21;
  background: var(--color-ink);
  color: #ffffff;
  border-radius: var(--radius-pill);
  padding: 10px 18px;
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 0.875rem;
  white-space: nowrap;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
}

.quick-log-toast button {
  border: none;
  background: none;
  color: var(--color-accent);
  font-weight: 700;
  cursor: pointer;
}
</style>
