<script setup lang="ts">
import { useAuthStore } from "@/stores/auth";
import { useRouter } from "vue-router";

const auth = useAuthStore();
const router = useRouter();

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
  <div class="home">
    <div class="home-card">
      <h1 class="heading glow">Welcome, {{ auth.user?.email }}</h1>
      <p class="helper-text">
        Bottle and breastfeeding logging are coming in the next steps — diaper changes are
        ready now.
      </p>
      <router-link class="btn-primary" to="/diapers">Go to diaper log</router-link>
      <button class="helper-link" type="button" @click="onLogout">Log out</button>
    </div>
  </div>
</template>

<style scoped>
.home {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-2);
}

.home-card {
  width: 100%;
  max-width: 420px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-4);
  text-align: center;
}

.home-card h1 {
  font-size: 1.5rem;
  margin: 0 0 var(--space-2);
  overflow-wrap: anywhere;
}

.home-card .btn-primary {
  margin-top: var(--space-3);
}
</style>
