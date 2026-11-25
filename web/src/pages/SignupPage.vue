<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore, ApiError } from "@/stores/auth";
import AuthCard from "@/components/AuthCard.vue";

const auth = useAuthStore();
const router = useRouter();

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
      errorMessage.value = Object.keys(error.fieldErrors).length ? "" : error.message;
      fieldErrors.value = error.fieldErrors;
    } else {
      errorMessage.value = "something went wrong";
    }
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <AuthCard title="Create your account">
    <form @submit.prevent="onSubmit">
      <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

      <div class="field">
        <label for="email">Email</label>
        <input id="email" v-model="form.email" type="email" autocomplete="email" required />
        <p v-if="fieldErrors.email" class="field-error">{{ fieldErrors.email.join(", ") }}</p>
      </div>

      <div class="field">
        <label for="password">Password</label>
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
        <label for="password_confirmation">Confirm password</label>
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
        {{ submitting ? "Creating account…" : "Create account" }}
      </button>
    </form>

    <p class="helper-text">
      Already have an account? <router-link to="/login">Log in</router-link>
    </p>
  </AuthCard>
</template>
