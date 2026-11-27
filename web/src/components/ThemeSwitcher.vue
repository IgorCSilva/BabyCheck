<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { themeMode, setThemeMode, type ThemeMode } from "@/theme";

const { t } = useI18n();

function choose(mode: ThemeMode) {
  setThemeMode(mode);
}
</script>

<template>
  <div class="theme-switcher" role="group" :aria-label="t('theme.label')">
    <button
      type="button"
      class="theme-option"
      :class="{ active: themeMode === 'light' }"
      @click="choose('light')"
    >
      {{ t("theme.light") }}
    </button>
    <button
      type="button"
      class="theme-option"
      :class="{ active: themeMode === 'dark' }"
      @click="choose('dark')"
    >
      {{ t("theme.dark") }}
    </button>
    <button
      type="button"
      class="theme-option"
      :class="{ active: themeMode === 'system' }"
      @click="choose('system')"
    >
      {{ t("theme.system") }}
    </button>
  </div>
</template>

<style scoped>
.theme-switcher {
  display: flex;
  align-items: center;
  flex-shrink: 0;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  padding: 2px;
  gap: 2px;
}

.theme-option {
  border: none;
  background: none;
  color: var(--color-ink-secondary);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  padding: 5px 10px;
  border-radius: var(--radius-pill);
  line-height: 1;
}

.theme-option.active {
  background: var(--color-accent);
  color: var(--color-accent-contrast);
}
</style>
