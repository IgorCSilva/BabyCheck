<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { useI18n } from "vue-i18n";
import { useAuthStore, ApiError } from "@/stores/auth";
import { translateApiError, translateFieldErrors } from "@/i18n";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const form = reactive({ email: "", password: "", passwordConfirmation: "" });
const submitting = ref(false);
const errorMessage = ref("");
const fieldErrors = ref<Record<string, string[]>>({});

async function onSubmit() {
  submitting.value = true;
  errorMessage.value = "";
  fieldErrors.value = {};

  try {
    await auth.register(form.email, form.password, form.passwordConfirmation);
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
  <AuthCard :title="t('auth.signup.title')">
    <form @submit.prevent="onSubmit">
      <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

      <div class="field">
        <label for="email">{{ t("auth.signup.email") }}</label>
        <input id="email" v-model="form.email" type="email" autocomplete="email" required />
        <p v-if="fieldErrors.email" class="field-error">{{ fieldErrors.email.join(", ") }}</p>
      </div>

      <div class="field">
        <label for="password">{{ t("auth.signup.password") }}</label>
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
        <label for="password_confirmation">{{ t("auth.signup.confirmPassword") }}</label>
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
        {{ submitting ? t("auth.signup.submitting") : t("auth.signup.submit") }}
      </button>
    </form>

    <p class="helper-text">
      {{ t("auth.signup.haveAccount") }}
      <router-link to="/login">{{ t("auth.signup.logIn") }}</router-link>
    </p>
  </AuthCard>
</template>
