import { ref } from "vue";

export type ThemeMode = "light" | "dark" | "system";
export type ResolvedTheme = "light" | "dark";

const STORAGE_KEY = "babycheck.theme";
const MODES: ThemeMode[] = ["light", "dark", "system"];

function readStoredMode(): ThemeMode {
  const stored = localStorage.getItem(STORAGE_KEY);
  return stored && (MODES as string[]).includes(stored) ? (stored as ThemeMode) : "system";
}

function prefersDark(): boolean {
  return typeof window !== "undefined" && typeof window.matchMedia === "function"
    ? window.matchMedia("(prefers-color-scheme: dark)").matches
    : false;
}

function resolve(mode: ThemeMode): ResolvedTheme {
  return mode === "system" ? (prefersDark() ? "dark" : "light") : mode;
}

export const themeMode = ref<ThemeMode>(readStoredMode());
export const resolvedTheme = ref<ResolvedTheme>(resolve(themeMode.value));

function applyResolvedTheme() {
  resolvedTheme.value = resolve(themeMode.value);
  if (typeof document !== "undefined") {
    document.documentElement.setAttribute("data-theme", resolvedTheme.value);
  }
}

applyResolvedTheme();

if (typeof window !== "undefined" && typeof window.matchMedia === "function") {
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if (themeMode.value === "system") applyResolvedTheme();
  });
}

export function setThemeMode(mode: ThemeMode) {
  themeMode.value = mode;
  localStorage.setItem(STORAGE_KEY, mode);
  applyResolvedTheme();
}

// A baby's theme color is picked for how it looks on the light cream
// background, so on a near-black dark background it's rendered through this
// dimmed/desaturated variant instead — keeps the Nightlight Glow motif
// readable without flashing a bright pastel in a dark room.
export function dimForTheme(color: string): string {
  return resolvedTheme.value === "dark" ? `color-mix(in srgb, ${color} 55%, black)` : color;
}
