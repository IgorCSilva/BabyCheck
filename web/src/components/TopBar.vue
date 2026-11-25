<script setup lang="ts">
import BabySwitcher from "@/components/BabySwitcher.vue";
import LanguageSwitcher from "@/components/LanguageSwitcher.vue";
</script>

<template>
  <header class="top-bar">
    <BabySwitcher />
    <LanguageSwitcher />
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
</style>
