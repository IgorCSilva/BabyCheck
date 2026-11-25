<script setup lang="ts">
import { ref } from "vue";
import { useI18n } from "vue-i18n";
import { useAuthStore } from "@/stores/auth";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const { t } = useI18n();

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
  <AuthCard :title="t('auth.forgotPassword.title')">
    <p v-if="submitted" class="form-success">
      {{ t("auth.forgotPassword.success") }}
    </p>

    <form v-else @submit.prevent="onSubmit">
      <div class="field">
        <label for="email">{{ t("auth.forgotPassword.email") }}</label>
        <input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>

      <button class="btn-primary" type="submit" :disabled="submitting">
        {{ submitting ? t("auth.forgotPassword.submitting") : t("auth.forgotPassword.submit") }}
      </button>
    </form>

    <p class="helper-text">
      <router-link to="/login">{{ t("auth.forgotPassword.backToLogin") }}</router-link>
    </p>
  </AuthCard>
</template>
