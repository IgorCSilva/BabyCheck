<script setup lang="ts">
import { useRouter } from "vue-router";
import BabySwitcher from "@/components/BabySwitcher.vue";

const router = useRouter();
</script>

<template>
  <header class="top-bar">
    <BabySwitcher />
    <button class="manage-babies-link" type="button" @click="router.push('/babies')">
      Manage babies
    </button>
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
  position: sticky;
  top: 0;
  z-index: 10;
}

.manage-babies-link {
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

.manage-babies-link:hover {
  background: var(--color-bg);
}
</style>
