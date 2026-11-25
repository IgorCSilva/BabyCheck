<script setup lang="ts">
import { watch } from "vue";
import { useAuthStore } from "@/stores/auth";
import { useBabiesStore } from "@/stores/babies";
import { useDiaperLogsStore } from "@/stores/diaperLogs";
import TopBar from "@/components/TopBar.vue";
import PageNav from "@/components/PageNav.vue";

const auth = useAuthStore();
const babies = useBabiesStore();
const diaperLogs = useDiaperLogsStore();

// Centralized here rather than in every place that can trigger a
// logout, so a second account signing in on the same browser never
// inherits the previous account's baby list, active-baby selection, or logs.
watch(
  () => auth.isAuthenticated,
  (isAuthenticated) => {
    if (!isAuthenticated) {
      babies.reset();
      diaperLogs.reset();
    }
  },
);
</script>

<template>
  <div v-if="auth.ready" class="app-shell">
    <div v-if="auth.isAuthenticated" class="app-header">
      <TopBar />
      <PageNav />
    </div>
    <main class="app-main">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
/* A flex column, not stacked min-height:100vh blocks: the header's real
   rendered height is subtracted from the available space automatically,
   so pages never end up taller than the viewport (and scrollable) just
   because they also assume a full 100vh for their own centering. */
.app-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  position: sticky;
  top: 0;
  z-index: 10;
}

.app-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
</style>
