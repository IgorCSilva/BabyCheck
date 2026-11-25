import { createApp } from "vue";
import { createPinia } from "pinia";
import App from "./App.vue";
import { router } from "./router";
import { useAuthStore } from "./stores/auth";
import "./styles/base.css";

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);

// Installing the router triggers its own initial-navigation guard check
// immediately (synchronously, as part of `app.use(router)`) — so it must
// happen *after* initialize() resolves, not before. Doing this in the other
// order was the original bug: the guard would see `isAuthenticated: false`
// (initialize() hadn't run yet) and redirect to /login, and nothing
// re-navigated back once the session actually resumed a moment later.
useAuthStore()
  .initialize()
  .finally(() => {
    app.use(router);
    app.mount("#app");
  });
