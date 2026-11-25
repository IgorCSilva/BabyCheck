<script setup lang="ts">
import { useRouter } from "vue-router";
import { useI18n } from "vue-i18n";
import { useAuthStore } from "@/stores/auth";
import BabySwitcher from "@/components/BabySwitcher.vue";
import LanguageSwitcher from "@/components/LanguageSwitcher.vue";

const auth = useAuthStore();
const router = useRouter();
const { t } = useI18n();

// The session is cleared either way (see auth.logout's `finally`), but
// Vue Router only re-runs its guards on an actual navigation attempt, not
// reactively on store state — so without this push, clearing the session
// alone would leave the user stranded on this now-unauthenticated page.
async function onLogout() {
  await auth.logout().catch(() => {});
  router.push("/login");
}
</script>

<template>
  <header class="top-bar">
    <BabySwitcher />
    <div class="top-bar-end">
      <LanguageSwitcher />
      <button class="logout-link" type="button" @click="onLogout">{{ t("nav.logout") }}</button>
    </div>
  </header>
</template>

<style scoped>
.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-3);
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
}

.top-bar-end {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  flex-shrink: 0;
}

.logout-link {
  border: none;
  background: none;
  color: var(--color-ink-secondary);
  font-size: 0.75rem;
  cursor: pointer;
  padding: 6px 4px;
  white-space: nowrap;
}
</style>
