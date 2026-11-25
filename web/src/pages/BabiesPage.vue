<script setup lang="ts">
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useBabiesStore, type Baby } from "@/stores/babies";
import { ApiError } from "@/lib/api";
import { translateApiError, translateFieldErrors } from "@/i18n";

const { t } = useI18n();

const SWATCHES = [
  "#F5A9B8", // soft pink
  "#9DC8E8", // soft blue
  "#F5D376", // soft yellow
  "#9FDFC0", // soft mint
  "#C3B2E0", // soft lavender
  "#F3B88C", // soft peach
  "#A8D8E8", // soft sky
  "#E8A6C4", // soft rose
];

const babies = useBabiesStore();

const editingId = ref<number | null>(null);
const name = ref("");
const themeColor = ref(SWATCHES[0]);
const customColor = ref(SWATCHES[0]);
const useCustomColor = ref(false);
const submitting = ref(false);
const errorMessage = ref("");
const fieldErrors = ref<Record<string, string[]>>({});

const isEditing = computed(() => editingId.value !== null);

function selectSwatch(color: string) {
  useCustomColor.value = false;
  themeColor.value = color;
}

function selectCustom(event: Event) {
  const color = (event.target as HTMLInputElement).value;
  customColor.value = color;
  useCustomColor.value = true;
  themeColor.value = color;
}

function startEdit(baby: Baby) {
  editingId.value = baby.id;
  name.value = baby.name;
  themeColor.value = baby.theme_color;
  useCustomColor.value = !SWATCHES.includes(baby.theme_color);
  if (useCustomColor.value) customColor.value = baby.theme_color;
  errorMessage.value = "";
  fieldErrors.value = {};
}

function cancelEdit() {
  editingId.value = null;
  name.value = "";
  themeColor.value = SWATCHES[0];
  useCustomColor.value = false;
  errorMessage.value = "";
  fieldErrors.value = {};
}

async function onSubmit() {
  submitting.value = true;
  errorMessage.value = "";
  fieldErrors.value = {};

  try {
    if (editingId.value !== null) {
      await babies.updateBaby(editingId.value, name.value, themeColor.value);
    } else {
      await babies.createBaby(name.value, themeColor.value);
    }
    cancelEdit();
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

async function onDelete(baby: Baby) {
  if (!window.confirm(t("babies.confirmDelete", { name: baby.name }))) return;

  await babies.deleteBaby(baby.id).catch(() => {});
  if (editingId.value === baby.id) cancelEdit();
}
</script>

<template>
  <div class="babies-page">
    <div class="babies-card">
      <h1 class="heading">{{ isEditing ? t("babies.editTitle") : t("babies.addTitle") }}</h1>

      <form @submit.prevent="onSubmit">
        <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

        <div class="field">
          <label for="baby-name">{{ t("babies.nameLabel") }}</label>
          <input id="baby-name" v-model="name" type="text" maxlength="60" required />
          <p v-if="fieldErrors.name" class="field-error">{{ fieldErrors.name.join(", ") }}</p>
        </div>

        <div class="field">
          <label>{{ t("babies.themeColorLabel") }}</label>
          <div class="swatch-grid">
            <button
              v-for="swatch in SWATCHES"
              :key="swatch"
              type="button"
              class="swatch"
              :class="{ selected: !useCustomColor && themeColor === swatch }"
              :style="{ background: swatch }"
              :aria-label="t('babies.useColor', { color: swatch })"
              @click="selectSwatch(swatch)"
            />
            <label class="swatch swatch-custom" :class="{ selected: useCustomColor }">
              <input type="color" :value="customColor" @input="selectCustom" />
              <span v-if="!useCustomColor" class="swatch-custom-label">{{ t("babies.custom") }}</span>
              <span v-else class="swatch-custom-swatch" :style="{ background: customColor }" />
            </label>
          </div>
          <p v-if="fieldErrors.theme_color" class="field-error">
            {{ fieldErrors.theme_color.join(", ") }}
          </p>
        </div>

        <button class="btn-primary" type="submit" :disabled="submitting">
          {{ submitting ? t("babies.saving") : isEditing ? t("babies.saveSubmit") : t("babies.addSubmit") }}
        </button>

        <button v-if="isEditing" class="helper-link" type="button" @click="cancelEdit">
          {{ t("babies.cancel") }}
        </button>
      </form>
    </div>

    <div v-if="babies.babies.length" class="babies-list">
      <div v-for="baby in babies.babies" :key="baby.id" class="baby-row">
        <span class="baby-row-avatar" :style="{ background: baby.theme_color }">
          {{ baby.name.charAt(0).toUpperCase() }}
        </span>
        <span class="baby-row-name">{{ baby.name }}</span>
        <button class="baby-row-action" type="button" @click="startEdit(baby)">
          {{ t("babies.edit") }}
        </button>
        <button class="baby-row-action baby-row-delete" type="button" @click="onDelete(baby)">
          {{ t("babies.delete") }}
        </button>
      </div>

      <router-link class="helper-link" to="/">{{ t("babies.backHome") }}</router-link>
    </div>
  </div>
</template>

<style scoped>
.babies-page {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-2);
}

.babies-card,
.babies-list {
  width: 100%;
  max-width: 420px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-4);
}

.babies-card h1 {
  margin: 0 0 var(--space-3);
  font-size: 1.25rem;
  text-align: center;
}

.swatch-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-1);
  margin-top: 6px;
}

.swatch {
  aspect-ratio: 1;
  border-radius: 999px;
  border: 2px solid transparent;
  cursor: pointer;
  padding: 0;
}

.swatch.selected {
  border-color: var(--color-ink);
}

.swatch-custom {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: 2px dashed var(--color-border);
  font-size: 0.7rem;
  color: var(--color-ink-secondary);
  overflow: hidden;
}

.swatch-custom.selected {
  border-style: solid;
  border-color: var(--color-ink);
}

.swatch-custom input[type="color"] {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.swatch-custom-swatch {
  position: absolute;
  inset: 0;
  border-radius: 999px;
}

.babies-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.baby-row {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--color-border);
}

.baby-row:last-of-type {
  border-bottom: none;
  padding-bottom: 0;
}

.baby-row-avatar {
  width: 36px;
  height: 36px;
  flex-shrink: 0;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: var(--font-heading);
  font-weight: 700;
  color: var(--color-ink);
}

.baby-row-name {
  flex: 1;
  font-weight: 600;
  overflow-wrap: anywhere;
}

.baby-row-action {
  border: none;
  background: none;
  color: var(--color-accent);
  font-size: 0.8125rem;
  cursor: pointer;
  padding: 6px 10px;
  border-radius: var(--radius-pill);
}

.baby-row-delete {
  color: var(--color-danger);
}
</style>
