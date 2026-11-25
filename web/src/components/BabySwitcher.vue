<script setup lang="ts">
import { useRouter } from "vue-router";
import { useI18n } from "vue-i18n";
import { useBabiesStore } from "@/stores/babies";

const babies = useBabiesStore();
const router = useRouter();
const { t } = useI18n();

function selectBaby(id: number) {
  babies.setActiveBaby(id);
}

function goToBabies() {
  router.push("/babies");
}
</script>

<template>
  <div class="baby-switcher">
    <button
      v-if="babies.babies.length === 0"
      class="add-first-baby-pill"
      type="button"
      @click="goToBabies"
    >
      {{ t("babies.addFirstBaby") }}
    </button>

    <template v-else>
      <button
        v-for="baby in babies.babies"
        :key="baby.id"
        type="button"
        class="baby-avatar"
        :class="{ active: baby.id === babies.activeBabyId }"
        :style="{ '--baby-color': baby.theme_color }"
        :title="baby.name"
        @click="selectBaby(baby.id)"
      >
        {{ baby.name.charAt(0).toUpperCase() }}
      </button>

      <button
        class="baby-avatar baby-avatar-add"
        type="button"
        :title="t('babies.addBabyTitle')"
        @click="goToBabies"
      >
        +
      </button>
    </template>
  </div>
</template>

<style scoped>
.baby-switcher {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  /* overflow-x: auto; */
}

.baby-avatar {
  width: 25px;
  height: 25px;
  flex-shrink: 0;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--baby-color, var(--color-accent));
  color: var(--color-ink);
  font-family: var(--font-heading);
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-left: 9px;
  opacity: 0.7;
  cursor: pointer;
  position: relative;
  transition: transform 0.15s ease;
}

.baby-avatar.active {
  transform: scale(1.4);
  opacity: 1;
}

.baby-avatar.active::before {
  content: "";
  position: absolute;
  inset: -10px;
  border-radius: inherit;
  background: radial-gradient(
    circle,
    color-mix(in srgb, var(--baby-color, var(--color-accent)) 45%, transparent) 0%,
    transparent 70%
  );
  z-index: -1;
}

.baby-avatar-add {
  background: var(--color-bg);
  border: 1px dashed var(--color-border);
  color: var(--color-ink-secondary);
  font-size: 1.25rem;
  font-weight: 400;
}

.add-first-baby-pill {
  border: 1px dashed var(--color-accent);
  background: none;
  color: var(--color-accent);
  border-radius: var(--radius-pill);
  padding: 10px 18px;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  white-space: nowrap;
}
</style>
