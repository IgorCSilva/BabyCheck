import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/auth";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      name: "home",
      component: () => import("@/pages/HomePage.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/login",
      name: "login",
      component: () => import("@/pages/LoginPage.vue"),
      meta: { guestOnly: true },
    },
    {
      path: "/signup",
      name: "signup",
      component: () => import("@/pages/SignupPage.vue"),
      meta: { guestOnly: true },
    },
    {
      path: "/forgot-password",
      name: "forgot-password",
      component: () => import("@/pages/ForgotPasswordPage.vue"),
      meta: { guestOnly: true },
    },
    {
      // Deliberately no `guestOnly` here, unlike the other auth pages: a
      // reset link must work no matter who (if anyone) is currently logged
      // in on this browser — completing it always issues a fresh session
      // for whichever account the token belongs to, overwriting any
      // existing one. Gating it would silently swallow valid reset links
      // for anyone with an active session (e.g. right after Test 4).
      path: "/reset-password/:token",
      name: "reset-password",
      component: () => import("@/pages/ResetPasswordPage.vue"),
    },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: "login", query: { redirect: to.fullPath } };
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    return { name: "home" };
  }
});
