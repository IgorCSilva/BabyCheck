<script setup lang="ts">
import BabySwitcher from "@/components/BabySwitcher.vue";
</script>

<template>
  <header class="top-bar">
    <BabySwitcher />
  </header>
</template>

<style scoped>
.top-bar {
  display: flex;
  align-items: center;
  padding: var(--space-2) var(--space-3);
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
}
</style>
