import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

function mockMatchMedia(initialMatches: boolean) {
  const listeners: Array<(event: { matches: boolean }) => void> = [];
  const mql = {
    matches: initialMatches,
    addEventListener: (_: string, callback: (event: { matches: boolean }) => void) => {
      listeners.push(callback);
    },
    removeEventListener: () => {},
  };
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue(mql) as unknown as typeof window.matchMedia,
  );
  return {
    setMatches(matches: boolean) {
      mql.matches = matches;
      listeners.forEach((callback) => callback({ matches }));
    },
  };
}

describe("theme", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.removeAttribute("data-theme");
    vi.resetModules();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("defaults to system mode, resolved from the OS preference", async () => {
    mockMatchMedia(true);
    const { themeMode, resolvedTheme } = await import("./theme");
    expect(themeMode.value).toBe("system");
    expect(resolvedTheme.value).toBe("dark");
    expect(document.documentElement.getAttribute("data-theme")).toBe("dark");
  });

  it("restores a previously stored manual mode instead of the OS preference", async () => {
    mockMatchMedia(true);
    localStorage.setItem("babycheck.theme", "light");
    const { themeMode, resolvedTheme } = await import("./theme");
    expect(themeMode.value).toBe("light");
    expect(resolvedTheme.value).toBe("light");
  });

  it("an unrecognized stored value falls back to system", async () => {
    mockMatchMedia(false);
    localStorage.setItem("babycheck.theme", "neon");
    const { themeMode } = await import("./theme");
    expect(themeMode.value).toBe("system");
  });

  it("setThemeMode persists the choice and updates the document attribute", async () => {
    mockMatchMedia(false);
    const { setThemeMode, resolvedTheme } = await import("./theme");
    setThemeMode("dark");
    expect(resolvedTheme.value).toBe("dark");
    expect(document.documentElement.getAttribute("data-theme")).toBe("dark");
    expect(localStorage.getItem("babycheck.theme")).toBe("dark");
  });

  it("in system mode, a live OS preference change updates the resolved theme", async () => {
    const { setMatches } = mockMatchMedia(false);
    const { resolvedTheme } = await import("./theme");
    expect(resolvedTheme.value).toBe("light");
    setMatches(true);
    expect(resolvedTheme.value).toBe("dark");
    expect(document.documentElement.getAttribute("data-theme")).toBe("dark");
  });

  it("a manual override is unaffected by OS preference changes", async () => {
    const { setMatches } = mockMatchMedia(false);
    const { setThemeMode, resolvedTheme } = await import("./theme");
    setThemeMode("light");
    setMatches(true);
    expect(resolvedTheme.value).toBe("light");
  });

  it("dimForTheme leaves colors untouched in light mode and dims them in dark mode", async () => {
    mockMatchMedia(false);
    const { setThemeMode, dimForTheme } = await import("./theme");
    expect(dimForTheme("#F5A9B8")).toBe("#F5A9B8");
    setThemeMode("dark");
    expect(dimForTheme("#F5A9B8")).toBe("color-mix(in srgb, #F5A9B8 55%, black)");
  });
});
