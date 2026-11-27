<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useOutboxStore } from "@/stores/outbox";

const outbox = useOutboxStore();
const { t } = useI18n();
</script>

<template>
  <div v-if="!outbox.online" class="offline-banner" role="status">
    {{ t("app.offlineBanner") }}
  </div>
</template>

<style scoped>
/* Calm, not alarming — the app's own cream background a shade deeper, no
   red/yellow warning hue, per the roadmap's "thin, calm cream banner" note. */
.offline-banner {
  background: var(--color-bg);
  border-bottom: 1px solid var(--color-border);
  color: var(--color-ink-secondary);
  text-align: center;
  font-size: 0.8125rem;
  padding: 6px var(--space-2);
}
</style>
