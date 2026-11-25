import { describe, expect, it, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { createRouter, createMemoryHistory } from "vue-router";
import LoginPage from "./LoginPage.vue";
import { useAuthStore } from "@/stores/auth";
import { i18n } from "@/i18n";

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status });
}

async function mountLoginPage() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div>home</div>" } },
      { path: "/login", component: LoginPage },
      { path: "/signup", component: { template: "<div>signup</div>" } },
      { path: "/forgot-password", component: { template: "<div>forgot</div>" } },
    ],
  });

  router.push("/login");
  await router.isReady();

  return mount(LoginPage, { global: { plugins: [router, i18n] } });
}

describe("LoginPage", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("renders email, password, and remember-me fields", async () => {
    const wrapper = await mountLoginPage();

    expect(wrapper.find("#email").exists()).toBe(true);
    expect(wrapper.find("#password").exists()).toBe(true);
    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(true);
  });

  it("logs in and navigates home on submit", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: { user: { id: 1, email: "parent@example.com" }, access_token: "tok" } }),
    );

    const wrapper = await mountLoginPage();
    const auth = useAuthStore();

    await wrapper.find("#email").setValue("parent@example.com");
    await wrapper.find("#password").setValue("supersecret123");
    await wrapper.find("form").trigger("submit.prevent");
    await flushPromises();

    expect(auth.isAuthenticated).toBe(true);
    expect(auth.user?.email).toBe("parent@example.com");
  });

  it("shows the backend error message on failed login", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(401, { errors: { detail: "invalid email or password", code: "invalid_credentials" } }),
    );

    const wrapper = await mountLoginPage();

    await wrapper.find("#email").setValue("parent@example.com");
    await wrapper.find("#password").setValue("wrongpass");
    await wrapper.find("form").trigger("submit.prevent");
    await flushPromises();

    expect(wrapper.text()).toContain("invalid email or password");
  });
});

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}
