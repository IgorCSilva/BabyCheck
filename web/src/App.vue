<script setup lang="ts">
import { watch } from "vue";
import { useAuthStore } from "@/stores/auth";
import { useBabiesStore } from "@/stores/babies";
import TopBar from "@/components/TopBar.vue";

const auth = useAuthStore();
const babies = useBabiesStore();

// Centralized here rather than in every place that can trigger a
// logout, so a second account signing in on the same browser never
// inherits the previous account's baby list or active-baby selection.
watch(
  () => auth.isAuthenticated,
  (isAuthenticated) => {
    if (!isAuthenticated) babies.reset();
  },
);
</script>

<template>
  <template v-if="auth.ready">
    <TopBar v-if="auth.isAuthenticated" />
    <router-view />
  </template>
</template>
