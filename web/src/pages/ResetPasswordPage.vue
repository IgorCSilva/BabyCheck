<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useI18n } from "vue-i18n";
import { useAuthStore, ApiError } from "@/stores/auth";
import { translateApiError, translateFieldErrors } from "@/i18n";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const token = route.params.token as string;
const form = reactive({ password: "", passwordConfirmation: "" });
const submitting = ref(false);
const errorMessage = ref("");
const fieldErrors = ref<Record<string, string[]>>({});

async function onSubmit() {
  submitting.value = true;
  errorMessage.value = "";
  fieldErrors.value = {};

  try {
    await auth.resetPassword(token, form.password, form.passwordConfirmation);
    router.push("/");
  } catch (error) {
    if (error instanceof ApiError) {
      errorMessage.value = Object.keys(error.fieldErrors).length ? "" : translateApiError(error);
      fieldErrors.value = translateFieldErrors(error.fieldErrors);
    } else {
      errorMessage.value = t("auth.genericError");
    }
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <AuthCard :title="t('auth.resetPassword.title')">
    <form @submit.prevent="onSubmit">
      <p v-if="errorMessage" class="form-error">
        {{ errorMessage }}
        <router-link to="/forgot-password">{{ t("auth.resetPassword.requestNewLink") }}</router-link>
      </p>

      <div class="field">
        <label for="password">{{ t("auth.resetPassword.newPassword") }}</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          autocomplete="new-password"
          required
        />
        <p v-if="fieldErrors.password" class="field-error">{{ fieldErrors.password.join(", ") }}</p>
      </div>

      <div class="field">
        <label for="password_confirmation">{{ t("auth.resetPassword.confirmNewPassword") }}</label>
        <input
          id="password_confirmation"
          v-model="form.passwordConfirmation"
          type="password"
          autocomplete="new-password"
          required
        />
        <p v-if="fieldErrors.password_confirmation" class="field-error">
          {{ fieldErrors.password_confirmation.join(", ") }}
        </p>
      </div>

      <button class="btn-primary" type="submit" :disabled="submitting">
        {{ submitting ? t("auth.resetPassword.submitting") : t("auth.resetPassword.submit") }}
      </button>
    </form>
  </AuthCard>
</template>
