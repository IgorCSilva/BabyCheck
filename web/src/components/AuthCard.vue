<script setup lang="ts">
defineProps<{ title: string }>();
</script>

<template>
  <div class="auth-screen">
    <div class="auth-card">
      <h1 class="heading">{{ title }}</h1>
      <slot />
    </div>
  </div>
</template>

<style scoped>
.auth-screen {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-2);
}

.auth-card {
  width: 100%;
  max-width: 360px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-4);
}

.auth-card h1 {
  margin: 0 0 var(--space-3);
  font-size: 1.5rem;
  text-align: center;
}
</style>
