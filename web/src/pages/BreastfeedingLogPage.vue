<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";
import { useBreastfeedingLogsStore, type BreastfeedingLog } from "@/stores/breastfeedingLogs";

type Preset = "today" | "7d" | "30d" | "custom";

const babies = useBabiesStore();
const breastfeedingLogs = useBreastfeedingLogsStore();
const { t, locale } = useI18n();

const preset = ref<Preset>("today");
const customFrom = ref(toDateInputValue(new Date()));
const customTo = ref(toDateInputValue(new Date()));

const editingId = ref<number | null>(null);
const editLoggedAt = ref("");

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
  const babyId = babies.activeBaby.id;
  // Swallowed: a GET that fails while offline shouldn't blank the page —
  // just keep whatever was already loaded, then layer in anything still
  // queued below (so a reload that happens while still offline doesn't
  // make an already-safely-queued log look lost).
  await breastfeedingLogs.fetchLogs(babyId, activeRange.value).catch(() => {});
  breastfeedingLogs.restoreQueued(babyId);
}

onMounted(reload);
watch(() => babies.activeBabyId, reload);
watch(activeRange, reload);

function selectPreset(next: Preset) {
  preset.value = next;
}

function dayLabel(iso: string): string {
  const date = new Date(iso);
  const diffDays = Math.round(
    (startOfDay(new Date()).getTime() - startOfDay(date).getTime()) / 86_400_000,
  );
  if (diffDays === 0) return t("breastfeedingLog.today");
  if (diffDays === 1) return t("breastfeedingLog.yesterday");
  return date.toLocaleDateString(locale.value, { month: "short", day: "numeric" });
}

function timeLabel(iso: string): string {
  return new Date(iso).toLocaleTimeString(locale.value, { hour: "numeric", minute: "2-digit" });
}

const groupedLogs = computed(() => {
  const groups: { label: string; logs: BreastfeedingLog[] }[] = [];

  for (const log of breastfeedingLogs.logs) {
    const label = dayLabel(log.logged_at);
    const lastGroup = groups[groups.length - 1];
    if (lastGroup && lastGroup.label === label) {
      lastGroup.logs.push(log);
    } else {
      groups.push({ label, logs: [log] });
    }
  }

  return groups;
});

function toLocalInputValue(iso: string): string {
  const date = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(
    date.getHours(),
  )}:${pad(date.getMinutes())}`;
}

function startEdit(log: BreastfeedingLog) {
  editingId.value = log.id;
  editLoggedAt.value = toLocalInputValue(log.logged_at);
}

function cancelEdit() {
  editingId.value = null;
}

async function saveEdit() {
  if (editingId.value === null) return;

  await breastfeedingLogs.updateLog(editingId.value, {
    logged_at: new Date(editLoggedAt.value).toISOString(),
  });
  cancelEdit();
}

async function onDelete(log: BreastfeedingLog) {
  if (!window.confirm(t("breastfeedingLog.confirmDelete"))) return;
  await breastfeedingLogs.deleteLog(log.id).catch(() => {});
  if (editingId.value === log.id) cancelEdit();
}
</script>

<template>
  <div class="breastfeeding-page">
    <div class="range-header">
      <p class="range-total heading">{{ breastfeedingLogs.logs.length }}</p>
      <p class="range-total-label">{{ t("breastfeedingLog.total") }}</p>

      <div class="preset-tabs">
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'today' }"
          @click="selectPreset('today')"
        >
          {{ t("breastfeedingLog.today") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '7d' }"
          @click="selectPreset('7d')"
        >
          {{ t("breastfeedingLog.sevenDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '30d' }"
          @click="selectPreset('30d')"
        >
          {{ t("breastfeedingLog.thirtyDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'custom' }"
          @click="selectPreset('custom')"
        >
          {{ t("breastfeedingLog.custom") }}
        </button>
      </div>

      <div v-if="preset === 'custom'" class="custom-range">
        <input v-model="customFrom" type="date" />
        <span>{{ t("breastfeedingLog.to") }}</span>
        <input v-model="customTo" type="date" />
      </div>
    </div>

    <div v-if="groupedLogs.length === 0" class="empty-state">
      {{ t("breastfeedingLog.empty") }}
    </div>

    <div v-for="group in groupedLogs" :key="group.label" class="day-group">
      <h2 class="day-header">{{ group.label }}</h2>

      <div
        v-for="log in group.logs"
        :key="log.id"
        class="log-row"
        :class="{ pending: log.id < 0 && !log._queued, 'pending-offline': log._queued }"
      >
        <template v-if="editingId === log.id">
          <form class="log-edit-form" @submit.prevent="saveEdit">
            <input v-model="editLoggedAt" type="datetime-local" required />
            <div class="log-edit-actions">
              <button class="log-row-action" type="submit">
                {{ t("breastfeedingLog.save") }}
              </button>
              <button class="log-row-action" type="button" @click="cancelEdit">
                {{ t("breastfeedingLog.cancel") }}
              </button>
            </div>
          </form>
        </template>
        <template v-else>
          <span class="log-row-time">{{ timeLabel(log.logged_at) }}</span>
          <span class="log-row-flags"></span>
          <button
            class="log-row-action"
            type="button"
            :disabled="log.id < 0"
            @click="startEdit(log)"
          >
            {{ t("breastfeedingLog.edit") }}
          </button>
          <button
            class="log-row-action log-row-delete"
            type="button"
            :disabled="log.id < 0"
            @click="onDelete(log)"
          >
            {{ t("breastfeedingLog.delete") }}
          </button>
        </template>
      </div>
    </div>

    <router-link class="helper-link" to="/">{{ t("breastfeedingLog.backHome") }}</router-link>
  </div>
</template>

<style scoped>
.breastfeeding-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  /* Extra bottom padding keeps the last list row (and "Back home") clear of
     the global quick-log bar docked at the bottom of the viewport. */
  padding: var(--space-3) var(--space-2)
    calc(56px + var(--space-4) + env(safe-area-inset-bottom, 0px));
}

.range-header {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-3);
  text-align: center;
  margin-bottom: var(--space-3);
}

.range-total {
  font-size: 2.5rem;
  margin: 0;
  line-height: 1;
}

.range-total-label {
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
  margin: 2px 0 var(--space-2);
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
  background: var(--color-breastfeeding);
  border-color: var(--color-breastfeeding);
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

.empty-state {
  text-align: center;
  color: var(--color-ink-secondary);
  font-size: 0.875rem;
  padding: var(--space-3) 0;
}

.day-group {
  margin-bottom: var(--space-2);
}

.day-header {
  font-size: 0.8125rem;
  color: var(--color-ink-secondary);
  font-family: var(--font-body);
  font-weight: 600;
  margin: 0 0 6px;
}

.log-row {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: 10px 0;
  border-bottom: 1px solid var(--color-border);
}

.log-row.pending {
  opacity: 0.6;
}

/* Ambient, not an alert — a dashed outline for an entry still waiting on
   connectivity to sync, distinct from the brief in-flight opacity dip
   above, which usually resolves in well under a second. */
.log-row.pending-offline {
  border: 1px dashed var(--color-ink-secondary);
  border-radius: 8px;
  padding-left: 8px;
  padding-right: 8px;
}

.log-row-time {
  font-weight: 600;
  min-width: 72px;
}

.log-row-flags {
  flex: 1;
  display: flex;
  gap: 8px;
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
}

.log-row-action {
  border: none;
  background: none;
  color: var(--color-accent);
  font-size: 0.8125rem;
  cursor: pointer;
  padding: 6px 10px;
  border-radius: var(--radius-pill);
}

.log-row-action:disabled {
  opacity: 0.4;
  cursor: default;
}

.log-row-delete {
  color: var(--color-danger);
}

.log-edit-form {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-1);
  width: 100%;
}

.log-edit-form input[type="datetime-local"] {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 6px 8px;
}

.log-edit-actions {
  display: flex;
  gap: 6px;
  margin-left: auto;
}
</style>
