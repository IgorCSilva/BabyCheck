import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { useBabiesStore } from "@/stores/babies";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      name: "home",
      component: () => import("@/pages/FeedPage.vue"),
      meta: { requiresAuth: true, requiresBaby: true },
    },
    {
      path: "/babies",
      name: "babies",
      component: () => import("@/pages/BabiesPage.vue"),
      meta: { requiresAuth: true },
    },
    {
      path: "/diapers",
      name: "diapers",
      component: () => import("@/pages/DiaperLogPage.vue"),
      meta: { requiresAuth: true, requiresBaby: true },
    },
    {
      path: "/bottle-feedings",
      name: "bottle-feedings",
      component: () => import("@/pages/BottleFeedingPage.vue"),
      meta: { requiresAuth: true, requiresBaby: true },
    },
    {
      path: "/breastfeeding",
      name: "breastfeeding",
      component: () => import("@/pages/BreastfeedingLogPage.vue"),
      meta: { requiresAuth: true, requiresBaby: true },
    },
    {
      path: "/charts",
      name: "charts",
      component: () => import("@/pages/ChartsPage.vue"),
      meta: { requiresAuth: true, requiresBaby: true },
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

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: "login", query: { redirect: to.fullPath } };
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    return { name: "home" };
  }

  if (to.meta.requiresAuth && auth.isAuthenticated) {
    const babies = useBabiesStore();
    await babies.ensureLoaded();

    if (to.meta.requiresBaby && to.name !== "babies" && babies.babies.length === 0) {
      return { name: "babies" };
    }
  }
});
