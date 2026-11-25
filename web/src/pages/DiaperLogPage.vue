<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";
import { useDiaperLogsStore, type DiaperLog } from "@/stores/diaperLogs";

type Preset = "today" | "7d" | "30d" | "custom";

const babies = useBabiesStore();
const diaperLogs = useDiaperLogsStore();
const { t, locale } = useI18n();

const preset = ref<Preset>("today");
const customFrom = ref(toDateInputValue(new Date()));
const customTo = ref(toDateInputValue(new Date()));

const editingId = ref<number | null>(null);
const editLoggedAt = ref("");
const editPeed = ref(true);
const editPooped = ref(true);

const toast = ref<{ tempId: number; promise: Promise<DiaperLog> } | null>(null);
let toastTimeout: ReturnType<typeof setTimeout> | null = null;

const glowing = ref(false);
let glowTimeout: ReturnType<typeof setTimeout> | null = null;

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
  await diaperLogs.fetchLogs(babies.activeBaby.id, activeRange.value);
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
  if (diffDays === 0) return t("diaperLog.today");
  if (diffDays === 1) return t("diaperLog.yesterday");
  return date.toLocaleDateString(locale.value, { month: "short", day: "numeric" });
}

function timeLabel(iso: string): string {
  return new Date(iso).toLocaleTimeString(locale.value, { hour: "numeric", minute: "2-digit" });
}

const groupedLogs = computed(() => {
  const groups: { label: string; logs: DiaperLog[] }[] = [];

  for (const log of diaperLogs.logs) {
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

function pulseGlow() {
  glowing.value = false;
  requestAnimationFrame(() => {
    glowing.value = true;
    if (glowTimeout) clearTimeout(glowTimeout);
    glowTimeout = setTimeout(() => (glowing.value = false), 700);
  });
}

async function onQuickLog() {
  if (!babies.activeBaby) return;

  pulseGlow();
  const entry = diaperLogs.quickLog(babies.activeBaby.id);
  toast.value = entry;
  if (toastTimeout) clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => {
    if (toast.value?.tempId === entry.tempId) toast.value = null;
  }, 5000);

  entry.promise.catch(() => {});
}

async function onUndo() {
  const entry = toast.value;
  if (!entry) return;
  toast.value = null;
  if (toastTimeout) clearTimeout(toastTimeout);

  try {
    const log = await entry.promise;
    await diaperLogs.deleteLog(log.id);
  } catch {
    // The create itself failed — the optimistic row was already rolled back.
  }
}

function toLocalInputValue(iso: string): string {
  const date = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(
    date.getHours(),
  )}:${pad(date.getMinutes())}`;
}

function startEdit(log: DiaperLog) {
  editingId.value = log.id;
  editLoggedAt.value = toLocalInputValue(log.logged_at);
  editPeed.value = log.peed;
  editPooped.value = log.pooped;
}

function cancelEdit() {
  editingId.value = null;
}

async function saveEdit() {
  if (editingId.value === null) return;

  await diaperLogs.updateLog(editingId.value, {
    logged_at: new Date(editLoggedAt.value).toISOString(),
    peed: editPeed.value,
    pooped: editPooped.value,
  });
  cancelEdit();
}

async function onDelete(log: DiaperLog) {
  if (!window.confirm(t("diaperLog.confirmDelete"))) return;
  await diaperLogs.deleteLog(log.id).catch(() => {});
  if (editingId.value === log.id) cancelEdit();
}
</script>

<template>
  <div class="diaper-page">
    <div class="range-header">
      <p class="range-total heading">{{ diaperLogs.logs.length }}</p>
      <p class="range-total-label">{{ t("diaperLog.total") }}</p>

      <div class="preset-tabs">
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'today' }"
          @click="selectPreset('today')"
        >
          {{ t("diaperLog.today") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '7d' }"
          @click="selectPreset('7d')"
        >
          {{ t("diaperLog.sevenDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '30d' }"
          @click="selectPreset('30d')"
        >
          {{ t("diaperLog.thirtyDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'custom' }"
          @click="selectPreset('custom')"
        >
          {{ t("diaperLog.custom") }}
        </button>
      </div>

      <div v-if="preset === 'custom'" class="custom-range">
        <input v-model="customFrom" type="date" />
        <span>{{ t("diaperLog.to") }}</span>
        <input v-model="customTo" type="date" />
      </div>
    </div>

    <button
      class="quick-log-btn"
      :class="{ glow: glowing }"
      :style="{ '--baby-color': babies.activeBaby?.theme_color }"
      type="button"
      @click="onQuickLog"
    >
      {{ t("diaperLog.quickLog") }}
    </button>

    <div v-if="groupedLogs.length === 0" class="empty-state">{{ t("diaperLog.empty") }}</div>

    <div v-for="group in groupedLogs" :key="group.label" class="day-group">
      <h2 class="day-header">{{ group.label }}</h2>

      <div v-for="log in group.logs" :key="log.id" class="log-row" :class="{ pending: log.id < 0 }">
        <template v-if="editingId === log.id">
          <form class="log-edit-form" @submit.prevent="saveEdit">
            <input v-model="editLoggedAt" type="datetime-local" required />
            <label><input v-model="editPeed" type="checkbox" /> {{ t("diaperLog.peed") }}</label>
            <label><input v-model="editPooped" type="checkbox" /> {{ t("diaperLog.pooped") }}</label>
            <div class="log-edit-actions">
              <button class="log-row-action" type="submit">{{ t("diaperLog.save") }}</button>
              <button class="log-row-action" type="button" @click="cancelEdit">
                {{ t("diaperLog.cancel") }}
              </button>
            </div>
          </form>
        </template>
        <template v-else>
          <span class="log-row-time">{{ timeLabel(log.logged_at) }}</span>
          <span class="log-row-flags">
            <span v-if="log.peed">{{ t("diaperLog.peed") }}</span>
            <span v-if="log.pooped">{{ t("diaperLog.pooped") }}</span>
          </span>
          <button class="log-row-action" type="button" :disabled="log.id < 0" @click="startEdit(log)">
            {{ t("diaperLog.edit") }}
          </button>
          <button
            class="log-row-action log-row-delete"
            type="button"
            :disabled="log.id < 0"
            @click="onDelete(log)"
          >
            {{ t("diaperLog.delete") }}
          </button>
        </template>
      </div>
    </div>

    <div v-if="toast" class="toast">
      {{ t("diaperLog.toastLogged") }}
      <button type="button" @click="onUndo">{{ t("diaperLog.undo") }}</button>
    </div>

    <router-link class="helper-link" to="/">{{ t("diaperLog.backHome") }}</router-link>
  </div>
</template>

<style scoped>
.diaper-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: var(--space-3) var(--space-2) calc(var(--space-4) * 2);
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
  background: var(--color-diaper);
  border-color: var(--color-diaper);
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

.quick-log-btn {
  display: block;
  width: 100%;
  min-height: 56px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--color-diaper);
  color: #ffffff;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
  margin-bottom: var(--space-3);
  position: relative;
}

.quick-log-btn.glow::before {
  content: "";
  position: absolute;
  inset: -14px;
  border-radius: inherit;
  background: radial-gradient(
    circle,
    color-mix(in srgb, var(--baby-color, var(--color-diaper)) 50%, transparent) 0%,
    transparent 70%
  );
  z-index: -1;
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

.log-edit-form label {
  font-size: 0.8125rem;
  display: flex;
  align-items: center;
  gap: 4px;
}

.log-edit-actions {
  display: flex;
  gap: 6px;
  margin-left: auto;
}

.toast {
  position: fixed;
  left: 50%;
  bottom: var(--space-3);
  transform: translateX(-50%);
  background: var(--color-ink);
  color: #ffffff;
  border-radius: var(--radius-pill);
  padding: 10px 18px;
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 0.875rem;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
}

.toast button {
  border: none;
  background: none;
  color: var(--color-diaper);
  font-weight: 700;
  cursor: pointer;
}
</style>
