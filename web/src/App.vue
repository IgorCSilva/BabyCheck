<script setup lang="ts">
import { useAuthStore } from "@/stores/auth";

const auth = useAuthStore();
</script>

<template>
  <router-view v-if="auth.ready" />
</template>
