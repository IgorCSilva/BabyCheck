<script setup lang="ts">
import { ref } from "vue";
import { useAuthStore } from "@/stores/auth";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();

const email = ref("");
const submitting = ref(false);
const submitted = ref(false);

async function onSubmit() {
  submitting.value = true;

  try {
    await auth.requestPasswordReset(email.value);
  } finally {
    // Always show the same confirmation, whether or not the email is
    // registered — the backend responds identically either way so this
    // screen can't be used to check who has an account.
    submitted.value = true;
    submitting.value = false;
  }
}
</script>

<template>
  <AuthCard title="Reset your password">
    <p v-if="submitted" class="form-success">
      If an account exists for that email, we've sent instructions to reset your password.
    </p>

    <form v-else @submit.prevent="onSubmit">
      <div class="field">
        <label for="email">Email</label>
        <input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>

      <button class="btn-primary" type="submit" :disabled="submitting">
        {{ submitting ? "Sending…" : "Send reset link" }}
      </button>
    </form>

    <p class="helper-text">
      <router-link to="/login">Back to log in</router-link>
    </p>
  </AuthCard>
</template>
