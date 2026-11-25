<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";
import {
  useBottleFeedingsStore,
  type BottleFeeding,
  DEFAULT_WATER_ML,
  DEFAULT_FORMULA_G,
} from "@/stores/bottleFeedings";

type Preset = "today" | "7d" | "30d" | "custom";

const babies = useBabiesStore();
const bottleFeedings = useBottleFeedingsStore();
const { t, locale } = useI18n();

const preset = ref<Preset>("today");
const customFrom = ref(toDateInputValue(new Date()));
const customTo = ref(toDateInputValue(new Date()));

const editingId = ref<number | null>(null);
const editLoggedAt = ref("");
const editWaterMl = ref(DEFAULT_WATER_ML);
const editFormulaG = ref(DEFAULT_FORMULA_G);

const toast = ref<{ tempId: number; promise: Promise<BottleFeeding> } | null>(null);
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
  await bottleFeedings.fetchFeedings(babies.activeBaby.id, activeRange.value);
}

onMounted(reload);
watch(() => babies.activeBabyId, reload);
watch(activeRange, reload);

function selectPreset(next: Preset) {
  preset.value = next;
}

const totalWaterMl = computed(() =>
  bottleFeedings.feedings.reduce((sum, feeding) => sum + feeding.water_ml, 0),
);
const totalFormulaG = computed(() =>
  bottleFeedings.feedings.reduce((sum, feeding) => sum + feeding.formula_g, 0),
);

function dayLabel(iso: string): string {
  const date = new Date(iso);
  const diffDays = Math.round(
    (startOfDay(new Date()).getTime() - startOfDay(date).getTime()) / 86_400_000,
  );
  if (diffDays === 0) return t("bottleFeeding.today");
  if (diffDays === 1) return t("bottleFeeding.yesterday");
  return date.toLocaleDateString(locale.value, { month: "short", day: "numeric" });
}

function timeLabel(iso: string): string {
  return new Date(iso).toLocaleTimeString(locale.value, { hour: "numeric", minute: "2-digit" });
}

const groupedFeedings = computed(() => {
  const groups: { label: string; feedings: BottleFeeding[] }[] = [];

  for (const feeding of bottleFeedings.feedings) {
    const label = dayLabel(feeding.logged_at);
    const lastGroup = groups[groups.length - 1];
    if (lastGroup && lastGroup.label === label) {
      lastGroup.feedings.push(feeding);
    } else {
      groups.push({ label, feedings: [feeding] });
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
  const entry = bottleFeedings.quickLog(babies.activeBaby.id);
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
    const feeding = await entry.promise;
    await bottleFeedings.deleteFeeding(feeding.id);
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

function startEdit(feeding: BottleFeeding) {
  editingId.value = feeding.id;
  editLoggedAt.value = toLocalInputValue(feeding.logged_at);
  editWaterMl.value = feeding.water_ml;
  editFormulaG.value = feeding.formula_g;
}

function cancelEdit() {
  editingId.value = null;
}

function stepWater(delta: number) {
  editWaterMl.value = Math.max(0, editWaterMl.value + delta);
}

function stepFormula(delta: number) {
  editFormulaG.value = Math.max(0, editFormulaG.value + delta);
}

async function saveEdit() {
  if (editingId.value === null) return;

  await bottleFeedings.updateFeeding(editingId.value, {
    logged_at: new Date(editLoggedAt.value).toISOString(),
    water_ml: editWaterMl.value,
    formula_g: editFormulaG.value,
  });
  cancelEdit();
}

async function onDelete(feeding: BottleFeeding) {
  if (!window.confirm(t("bottleFeeding.confirmDelete"))) return;
  await bottleFeedings.deleteFeeding(feeding.id).catch(() => {});
  if (editingId.value === feeding.id) cancelEdit();
}
</script>

<template>
  <div class="bottle-page">
    <div class="range-header">
      <p class="range-total heading">{{ bottleFeedings.feedings.length }}</p>
      <p class="range-total-label">{{ t("bottleFeeding.total") }}</p>

      <div class="range-stats">
        <span>{{ totalWaterMl }}ml {{ t("bottleFeeding.totalWater") }}</span>
        <span>{{ totalFormulaG }}g {{ t("bottleFeeding.totalFormula") }}</span>
      </div>

      <div class="preset-tabs">
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'today' }"
          @click="selectPreset('today')"
        >
          {{ t("bottleFeeding.today") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '7d' }"
          @click="selectPreset('7d')"
        >
          {{ t("bottleFeeding.sevenDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === '30d' }"
          @click="selectPreset('30d')"
        >
          {{ t("bottleFeeding.thirtyDays") }}
        </button>
        <button
          type="button"
          class="preset-tab"
          :class="{ active: preset === 'custom' }"
          @click="selectPreset('custom')"
        >
          {{ t("bottleFeeding.custom") }}
        </button>
      </div>

      <div v-if="preset === 'custom'" class="custom-range">
        <input v-model="customFrom" type="date" />
        <span>{{ t("bottleFeeding.to") }}</span>
        <input v-model="customTo" type="date" />
      </div>
    </div>

    <div v-if="groupedFeedings.length === 0" class="empty-state">
      {{ t("bottleFeeding.empty") }}
    </div>

    <div v-for="group in groupedFeedings" :key="group.label" class="day-group">
      <h2 class="day-header">{{ group.label }}</h2>

      <div
        v-for="feeding in group.feedings"
        :key="feeding.id"
        class="log-row"
        :class="{ pending: feeding.id < 0 }"
      >
        <template v-if="editingId === feeding.id">
          <form class="log-edit-form" @submit.prevent="saveEdit">
            <input v-model="editLoggedAt" type="datetime-local" required />
            <div class="stepper">
              <span class="stepper-label">{{ t("bottleFeeding.water") }}</span>
              <button type="button" class="stepper-btn" @click="stepWater(-5)">−</button>
              <span class="stepper-value">{{ editWaterMl }}</span>
              <button type="button" class="stepper-btn" @click="stepWater(5)">+</button>
            </div>
            <div class="stepper">
              <span class="stepper-label">{{ t("bottleFeeding.formula") }}</span>
              <button type="button" class="stepper-btn" @click="stepFormula(-1)">−</button>
              <span class="stepper-value">{{ editFormulaG }}</span>
              <button type="button" class="stepper-btn" @click="stepFormula(1)">+</button>
            </div>
            <div class="log-edit-actions">
              <button class="log-row-action" type="submit">{{ t("bottleFeeding.save") }}</button>
              <button class="log-row-action" type="button" @click="cancelEdit">
                {{ t("bottleFeeding.cancel") }}
              </button>
            </div>
          </form>
        </template>
        <template v-else>
          <span class="log-row-time">{{ timeLabel(feeding.logged_at) }}</span>
          <span class="log-row-flags">
            {{
              t("bottleFeeding.amountSummary", {
                water: feeding.water_ml,
                formula: feeding.formula_g,
              })
            }}
          </span>
          <button
            class="log-row-action"
            type="button"
            :disabled="feeding.id < 0"
            @click="startEdit(feeding)"
          >
            {{ t("bottleFeeding.edit") }}
          </button>
          <button
            class="log-row-action log-row-delete"
            type="button"
            :disabled="feeding.id < 0"
            @click="onDelete(feeding)"
          >
            {{ t("bottleFeeding.delete") }}
          </button>
        </template>
      </div>
    </div>

    <div v-if="toast" class="toast">
      {{ t("bottleFeeding.toastLogged") }}
      <button type="button" @click="onUndo">{{ t("bottleFeeding.undo") }}</button>
    </div>

    <router-link class="helper-link" to="/">{{ t("bottleFeeding.backHome") }}</router-link>

    <div class="quick-log-bar">
      <button
        class="quick-log-btn"
        :class="{ glow: glowing }"
        :style="{ '--baby-color': babies.activeBaby?.theme_color }"
        type="button"
        @click="onQuickLog"
      >
        {{ t("bottleFeeding.quickLog") }}
        <span class="quick-log-hint">
          {{ t("bottleFeeding.quickLogHint", { water: DEFAULT_WATER_ML, formula: DEFAULT_FORMULA_G }) }}
        </span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.bottle-page {
  flex: 1;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  /* Extra bottom padding keeps the last list row (and "Back home") clear of
     the fixed quick-log bar docked at the bottom of the viewport. */
  padding: var(--space-3) var(--space-2)
    calc(72px + var(--space-4) + env(safe-area-inset-bottom, 0px));
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

.range-stats {
  display: flex;
  justify-content: center;
  gap: var(--space-3);
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
  margin-bottom: var(--space-2);
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
  background: var(--color-bottle);
  border-color: var(--color-bottle);
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

/* Docked to the bottom edge, in the thumb-reachable zone on mobile, so
   logging never requires reaching up the screen. */
.quick-log-bar {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 5;
  display: flex;
  justify-content: center;
  padding: var(--space-2) var(--space-2) calc(var(--space-2) + env(safe-area-inset-bottom, 0px));
  background: linear-gradient(to top, var(--color-bg) 65%, transparent);
}

.quick-log-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  width: 100%;
  max-width: 480px;
  min-height: 56px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--color-bottle);
  color: #ffffff;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  position: relative;
}

.quick-log-hint {
  font-weight: 400;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.8);
}

.quick-log-btn.glow::before {
  content: "";
  position: absolute;
  inset: -14px;
  border-radius: inherit;
  background: radial-gradient(
    circle,
    color-mix(in srgb, var(--baby-color, var(--color-bottle)) 50%, transparent) 0%,
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

.stepper {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.8125rem;
}

.stepper-label {
  color: var(--color-ink-secondary);
}

.stepper-btn {
  border: 1px solid var(--color-border);
  background: var(--color-bg);
  border-radius: var(--radius-pill);
  width: 28px;
  height: 28px;
  font-size: 1rem;
  line-height: 1;
  cursor: pointer;
}

.stepper-value {
  min-width: 28px;
  text-align: center;
  font-weight: 600;
}

.log-edit-actions {
  display: flex;
  gap: 6px;
  margin-left: auto;
}

.toast {
  position: fixed;
  left: 50%;
  /* Sits above the fixed quick-log bar instead of being covered by it. */
  bottom: calc(72px + var(--space-3) * 2 + env(safe-area-inset-bottom, 0px));
  transform: translateX(-50%);
  z-index: 6;
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
  color: var(--color-bottle);
  font-weight: 700;
  cursor: pointer;
}
</style>
