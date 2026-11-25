<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore, ApiError } from "@/stores/auth";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();

const form = reactive({ email: "", password: "", rememberMe: true });
const submitting = ref(false);
const errorMessage = ref("");

async function onSubmit() {
  submitting.value = true;
  errorMessage.value = "";

  try {
    await auth.login(form.email, form.password, form.rememberMe);
    const redirect = typeof route.query.redirect === "string" ? route.query.redirect : "/";
    router.push(redirect);
  } catch (error) {
    errorMessage.value = error instanceof ApiError ? error.message : "something went wrong";
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <AuthCard title="Welcome back">
    <form @submit.prevent="onSubmit">
      <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

      <div class="field">
        <label for="email">Email</label>
        <input id="email" v-model="form.email" type="email" autocomplete="email" required />
      </div>

      <div class="field">
        <label for="password">Password</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          autocomplete="current-password"
          required
        />
      </div>

      <label class="checkbox-row">
        <input v-model="form.rememberMe" type="checkbox" />
        Remember me
      </label>

      <button class="btn-primary" type="submit" :disabled="submitting">
        {{ submitting ? "Logging in…" : "Log in" }}
      </button>

      <router-link class="helper-link" to="/forgot-password">Forgot password?</router-link>
    </form>

    <p class="helper-text">
      New to BabyCheck? <router-link to="/signup">Create an account</router-link>
    </p>
  </AuthCard>
</template>
