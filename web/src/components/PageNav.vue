<script setup lang="ts">
import { useRouter } from "vue-router";
import { useI18n } from "vue-i18n";

const router = useRouter();
const { t } = useI18n();
</script>

<template>
  <nav class="page-nav">
    <button class="page-nav-link" type="button" @click="router.push('/')">
      {{ t("nav.feed") }}
    </button>
    <button class="page-nav-link" type="button" @click="router.push('/diapers')">
      {{ t("nav.diaperLog") }}
    </button>
    <button class="page-nav-link" type="button" @click="router.push('/bottle-feedings')">
      {{ t("nav.bottleFeeding") }}
    </button>
    <button class="page-nav-link" type="button" @click="router.push('/breastfeeding')">
      {{ t("nav.breastfeeding") }}
    </button>
    <button class="page-nav-link" type="button" @click="router.push('/charts')">
      {{ t("nav.charts") }}
    </button>
    <button class="page-nav-link" type="button" @click="router.push('/babies')">
      {{ t("nav.manageBabies") }}
    </button>
  </nav>
</template>

<style scoped>
.page-nav {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: 6px var(--space-3) var(--space-1);
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  overflow-x: auto;
}

.page-nav-link {
  flex-shrink: 0;
  border: none;
  background: none;
  color: var(--color-ink-secondary);
  font-size: 0.8125rem;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: var(--radius-pill);
  white-space: nowrap;
}

.page-nav-link:hover {
  background: var(--color-bg);
}
</style>
