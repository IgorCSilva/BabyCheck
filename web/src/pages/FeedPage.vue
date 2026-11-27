<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";
import { useFeedStore, type BabyActivitySummary, type FeedEntry } from "@/stores/feed";
import { useOutboxStore } from "@/stores/outbox";
import { dimForTheme } from "@/theme";

type Metric = "diaper" | "bottle" | "breastfeeding";
type DisplayFeedEntry = FeedEntry & { _queued?: boolean };

const METRICS: Metric[] = ["diaper", "bottle", "breastfeeding"];
const METRIC_ICONS: Record<Metric, string> = { diaper: "🧷", bottle: "🍼", breastfeeding: "🤱" };
const SUMMARY_POLL_MS = 15_000;
const GLOW_DURATION_MS = 1500;

const babies = useBabiesStore();
const feed = useFeedStore();
const outbox = useOutboxStore();
const { t, locale } = useI18n();

// Entries still sitting in the offline outbox, shown as a dashed-border row
// right alongside confirmed ones — reactive to `outbox.entries` directly
// rather than copied into `feed.entries`, so a row just disappears here the
// moment it's no longer queued (synced or cancelled), no separate
// reconciliation step needed.
const displayEntries = computed<DisplayFeedEntry[]>(() => {
  const queuedRows: DisplayFeedEntry[] = outbox.entries.map((entry) => {
    const baby = babies.babies.find((candidate) => candidate.id === entry.baby_id);
    const payload = entry.payload as Record<string, unknown>;
    return {
      type: entry.metric,
      id: entry.tempId,
      baby_id: entry.baby_id,
      baby_name: baby?.name ?? "",
      baby_theme_color: baby?.theme_color ?? "",
      logged_at: payload.logged_at as string,
      peed: (payload.peed as boolean | undefined) ?? null,
      pooped: (payload.pooped as boolean | undefined) ?? null,
      water_ml: (payload.water_ml as number | undefined) ?? null,
      formula_g: (payload.formula_g as number | undefined) ?? null,
      _queued: true,
    };
  });

  return [...queuedRows, ...feed.entries].sort((a, b) => b.logged_at.localeCompare(a.logged_at));
});

const sentinel = ref<HTMLElement | null>(null);
const glowingChips = ref(new Set<string>());
let observer: IntersectionObserver | null = null;
let pollInterval: ReturnType<typeof setInterval> | null = null;
let summaryLoadedOnce = false;

function chipKey(babyId: number, metric: Metric): string {
  return `${babyId}-${metric}`;
}

function metricIcon(metric: Metric): string {
  return METRIC_ICONS[metric];
}

function metricLastLoggedAt(summary: BabyActivitySummary, metric: Metric): string | null {
  if (metric === "diaper") return summary.diaper_last_logged_at;
  if (metric === "bottle") return summary.bottle_last_logged_at;
  return summary.breastfeeding_last_logged_at;
}

function metricAvgPerDay(summary: BabyActivitySummary, metric: Metric): number {
  if (metric === "diaper") return summary.diaper_avg_per_day_7d;
  if (metric === "bottle") return summary.bottle_avg_per_day_7d;
  return summary.breastfeeding_avg_per_day_7d;
}

function metricLongGap(summary: BabyActivitySummary, metric: Metric): boolean {
  if (metric === "diaper") return summary.diaper_long_gap;
  if (metric === "bottle") return summary.bottle_long_gap;
  return summary.breastfeeding_long_gap;
}

function formatAvg(avg: number): string {
  return avg.toFixed(1);
}

function detectFreshUpdates(previous: BabyActivitySummary[], next: BabyActivitySummary[]) {
  const previousByBabyId = new Map(previous.map((entry) => [entry.baby_id, entry]));

  for (const entry of next) {
    const before = previousByBabyId.get(entry.baby_id);
    if (!before) continue;

    for (const metric of METRICS) {
      if (metricLastLoggedAt(before, metric) !== metricLastLoggedAt(entry, metric)) {
        const key = chipKey(entry.baby_id, metric);
        glowingChips.value.add(key);
        setTimeout(() => glowingChips.value.delete(key), GLOW_DURATION_MS);
      }
    }
  }
}

async function refreshSummary() {
  const previous = feed.summary;
  await feed.fetchSummary();
  if (summaryLoadedOnce) detectFreshUpdates(previous, feed.summary);
  summaryLoadedOnce = true;
}

onMounted(async () => {
  await Promise.all([feed.fetchFeed(), refreshSummary()]);

  pollInterval = setInterval(refreshSummary, SUMMARY_POLL_MS);

  observer = new IntersectionObserver((entries: IntersectionObserverEntry[]) => {
    if (entries[0]?.isIntersecting) feed.fetchMore();
  });
  if (sentinel.value) observer.observe(sentinel.value);
});

onUnmounted(() => {
  if (pollInterval) clearInterval(pollInterval);
  observer?.disconnect();
});

function relativeTime(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60_000);
  if (minutes < 1) return t("feed.justNow");
  if (minutes < 60) return `${minutes}m ${t("feed.ago")}`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ${t("feed.ago")}`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ${t("feed.ago")}`;
  return new Date(iso).toLocaleDateString(locale.value, { month: "short", day: "numeric" });
}

function summaryFor(babyId: number): BabyActivitySummary | undefined {
  return feed.summary.find((entry) => entry.baby_id === babyId);
}

function entryKey(entry: FeedEntry): string {
  return `${entry.type}-${entry.id}`;
}
</script>

<template>
  <div class="feed-page">
    <h1 class="feed-heading">{{ t("feed.heading") }}</h1>

    <div class="stat-strip">
      <div v-for="baby in babies.babies" :key="baby.id" class="baby-stat-row">
        <span class="baby-dot" :style="{ '--baby-color': dimForTheme(baby.theme_color) }"></span>
        <span class="baby-stat-name">{{ baby.name }}</span>

        <div class="chips">
          <span
            v-for="metric in METRICS"
            :key="metric"
            class="chip"
            :class="[
              `chip-${metric}`,
              {
                glow: glowingChips.has(chipKey(baby.id, metric)),
                'long-gap': !!summaryFor(baby.id) && metricLongGap(summaryFor(baby.id)!, metric),
              },
            ]"
            :title="
              summaryFor(baby.id) && metricLongGap(summaryFor(baby.id)!, metric)
                ? t('feed.longGapHint')
                : undefined
            "
          >
            <span class="chip-icon">{{ metricIcon(metric) }}</span>
            <span class="chip-main">
              <template v-if="summaryFor(baby.id) && metricLastLoggedAt(summaryFor(baby.id)!, metric)">
                {{ relativeTime(metricLastLoggedAt(summaryFor(baby.id)!, metric)!) }}
              </template>
              <span v-else class="chip-none">{{ t("feed.noLogsYet") }}</span>

              <span v-if="summaryFor(baby.id) && metricAvgPerDay(summaryFor(baby.id)!, metric) > 0" class="chip-avg">
                {{ t("feed.avgPerDay", { avg: formatAvg(metricAvgPerDay(summaryFor(baby.id)!, metric)) }) }}
              </span>
            </span>
          </span>
        </div>
      </div>
    </div>

    <div v-if="displayEntries.length === 0 && !feed.loading" class="empty-state">
      {{ t("feed.empty") }}
    </div>

    <div class="feed-list">
      <div
        v-for="entry in displayEntries"
        :key="entryKey(entry)"
        class="feed-row"
        :class="{ 'feed-row-queued': entry._queued }"
      >
        <span class="feed-row-dot" :style="{ '--baby-color': dimForTheme(entry.baby_theme_color) }"></span>
        <span class="feed-row-icon">{{ metricIcon(entry.type) }}</span>
        <span class="feed-row-baby">{{ entry.baby_name }}</span>
        <span v-if="entry.type === 'bottle'" class="feed-row-amount">
          {{ t("bottleFeeding.amountSummary", { water: entry.water_ml, formula: entry.formula_g }) }}
        </span>
        <span class="feed-row-time">{{ relativeTime(entry.logged_at) }}</span>
      </div>
    </div>

    <div ref="sentinel" class="scroll-sentinel"></div>
    <p v-if="feed.loadingMore" class="loading-more">{{ t("feed.loadingMore") }}</p>
  </div>
</template>

<style scoped>
.feed-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: var(--space-3) var(--space-2) var(--space-4);
}

.feed-heading {
  font-size: 1.125rem;
  margin: 0 0 var(--space-2);
}

.stat-strip {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-2);
  margin-bottom: var(--space-3);
}

.baby-stat-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  padding: 8px 0;
}

.baby-stat-row + .baby-stat-row {
  border-top: 1px solid var(--color-border);
}

.baby-dot {
  width: 10px;
  height: 10px;
  flex-shrink: 0;
  border-radius: var(--radius-pill);
  background: var(--baby-color, var(--color-accent));
}

.baby-stat-name {
  font-weight: 600;
  margin-right: auto;
}

.chips {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border-radius: var(--radius-pill);
  padding: 4px 10px;
  font-size: 0.75rem;
  color: var(--color-ink-secondary);
  position: relative;
  box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--baby-color, var(--color-accent)) 20%, transparent);
}

.chip-diaper {
  background: color-mix(in srgb, var(--color-diaper) 16%, transparent);
}

.chip-bottle {
  background: color-mix(in srgb, var(--color-bottle) 16%, transparent);
}

.chip-breastfeeding {
  background: color-mix(in srgb, var(--color-breastfeeding) 16%, transparent);
}

.chip-none {
  opacity: 0.7;
}

.chip-main {
  display: inline-flex;
  flex-direction: column;
  line-height: 1.2;
}

.chip-avg {
  font-size: 0.6875rem;
  opacity: 0.7;
}

/* Ambient, not an alert: a slightly more saturated fill and a touch more
   ink, no color change, no motion — just enough to notice on a glance. */
.chip.long-gap {
  color: var(--color-ink);
}

.chip.long-gap.chip-diaper {
  background: color-mix(in srgb, var(--color-diaper) 30%, transparent);
}

.chip.long-gap.chip-bottle {
  background: color-mix(in srgb, var(--color-bottle) 30%, transparent);
}

.chip.long-gap.chip-breastfeeding {
  background: color-mix(in srgb, var(--color-breastfeeding) 30%, transparent);
}

.chip.glow::before {
  content: "";
  position: absolute;
  inset: -6px;
  border-radius: inherit;
  background: radial-gradient(
    circle,
    color-mix(in srgb, var(--baby-color, var(--color-accent)) 50%, transparent) 0%,
    transparent 70%
  );
  z-index: -1;
}

.empty-state {
  text-align: center;
  color: var(--color-ink-secondary);
  font-size: 0.875rem;
  padding: var(--space-4) 0;
}

.feed-list {
  display: flex;
  flex-direction: column;
}

.feed-row {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: 10px 0;
  border-bottom: 1px solid var(--color-border);
}

/* Ambient, not an alert — a still-syncing row gets a quiet dashed outline
   rather than a warning color, matching the long-gap chip's "noticeable on
   a glance" treatment from Step 9. */
.feed-row-queued {
  border: 1px dashed var(--color-ink-secondary);
  border-radius: var(--radius-card);
  padding: 10px var(--space-1);
}

.feed-row-dot {
  width: 8px;
  height: 8px;
  flex-shrink: 0;
  border-radius: var(--radius-pill);
  background: var(--baby-color, var(--color-accent));
}

.feed-row-icon {
  flex-shrink: 0;
}

.feed-row-baby {
  font-weight: 600;
  font-size: 0.875rem;
}

.feed-row-amount {
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
}

.feed-row-time {
  margin-left: auto;
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
  white-space: nowrap;
}

.scroll-sentinel {
  height: 1px;
}

.loading-more {
  text-align: center;
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
  padding: var(--space-2) 0;
}
</style>
