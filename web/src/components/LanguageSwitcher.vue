<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { setLocale, type Locale } from "@/i18n";

const { t, locale } = useI18n();

function choose(next: Locale) {
  setLocale(next);
}
</script>

<template>
  <div class="language-switcher" role="group" :aria-label="t('language.label')">
    <button
      type="button"
      class="language-option"
      :class="{ active: locale === 'en' }"
      @click="choose('en')"
    >
      {{ t("language.en") }}
    </button>
    <button
      type="button"
      class="language-option"
      :class="{ active: locale === 'pt-BR' }"
      @click="choose('pt-BR')"
    >
      {{ t("language.ptBR") }}
    </button>
  </div>
</template>

<style scoped>
.language-switcher {
  display: flex;
  align-items: center;
  flex-shrink: 0;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  padding: 2px;
  gap: 2px;
}

.language-option {
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

.language-option.active {
  background: var(--color-accent);
  color: var(--color-accent-contrast);
}
</style>
