import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: "autoUpdate",
      // The stack is exercised via `npm run dev` (docker compose), not a
      // production build — without this, the service worker/manifest never
      // actually register outside `vite build`, and installability/offline
      // couldn't be tested against the running dev stack at all.
      devOptions: { enabled: true },
      includeAssets: ["icons/favicon.png", "icons/apple-touch-icon.png"],
      manifest: {
        name: "BabyCheck",
        short_name: "BabyCheck",
        description: "Track diaper changes, bottle-feedings, and breastfeeding, one tap at a time.",
        theme_color: "#7FB7BE",
        background_color: "#FFF9F4",
        display: "standalone",
        start_url: "/",
        icons: [
          { src: "icons/icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "icons/icon-512.png", sizes: "512x512", type: "image/png" },
          {
            src: "icons/icon-512-maskable.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        // Precaches the app shell (built JS/CSS/HTML/icons) only — no
        // runtime caching rules for `/api/*`. This step makes the app
        // itself loadable offline and the quick-log write path resilient
        // via the IndexedDB outbox, not a general offline data cache.
        globPatterns: ["**/*.{js,css,html,ico,png,svg}"],
      },
    }),
  ],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    host: true,
    port: 3000,
  },
  test: {
    environment: "happy-dom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
  },
});
