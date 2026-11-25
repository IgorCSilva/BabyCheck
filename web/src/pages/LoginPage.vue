<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useI18n } from "vue-i18n";
import { useAuthStore, ApiError } from "@/stores/auth";
import { translateApiError } from "@/i18n";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();
const { t } = useI18n();

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
    errorMessage.value = error instanceof ApiError ? translateApiError(error) : t("auth.genericError");
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <AuthCard :title="t('auth.login.title')">
    <form @submit.prevent="onSubmit">
      <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

      <div class="field">
        <label for="email">{{ t("auth.login.email") }}</label>
        <input id="email" v-model="form.email" type="email" autocomplete="email" required />
      </div>

      <div class="field">
        <label for="password">{{ t("auth.login.password") }}</label>
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
        {{ t("auth.login.rememberMe") }}
      </label>

      <button class="btn-primary" type="submit" :disabled="submitting">
        {{ submitting ? t("auth.login.submitting") : t("auth.login.submit") }}
      </button>

      <router-link class="helper-link" to="/forgot-password">
        {{ t("auth.login.forgotPassword") }}
      </router-link>
    </form>

    <p class="helper-text">
      {{ t("auth.login.noAccount") }}
      <router-link to="/signup">{{ t("auth.login.createAccount") }}</router-link>
    </p>
  </AuthCard>
</template>
