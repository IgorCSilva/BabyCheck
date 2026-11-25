import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import FeedPage from "./FeedPage.vue";
import { useBabiesStore } from "@/stores/babies";
import { i18n } from "@/i18n";

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status });
}

function baseSummary(overrides: Record<string, unknown> = {}) {
  return {
    baby_id: 1,
    baby_name: "Riley",
    baby_theme_color: "#F5A9B8",
    diaper_last_logged_at: "2026-11-24T10:00:00Z",
    bottle_last_logged_at: null,
    breastfeeding_last_logged_at: null,
    diaper_avg_per_day_7d: 0,
    bottle_avg_per_day_7d: 0,
    breastfeeding_avg_per_day_7d: 0,
    diaper_long_gap: false,
    bottle_long_gap: false,
    breastfeeding_long_gap: false,
    ...overrides,
  };
}

function mountFeedPage() {
  return mount(FeedPage, { global: { plugins: [i18n] } });
}

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("FeedPage insight chips", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("shows the rolling 7-day average next to a metric that has one", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/summary")) {
        return Promise.resolve(jsonResponse(200, { data: [baseSummary({ diaper_avg_per_day_7d: 3.2 })] }));
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountFeedPage();
    await flushPromises();
    await flushPromises();

    const diaperChip = wrapper.find(".chip-diaper");
    expect(diaperChip.find(".chip-avg").text()).toContain("3.2");
  });

  it("hides the average for a metric that has never been logged", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/summary")) {
        return Promise.resolve(jsonResponse(200, { data: [baseSummary()] }));
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountFeedPage();
    await flushPromises();
    await flushPromises();

    const bottleChip = wrapper.find(".chip-bottle");
    expect(bottleChip.find(".chip-avg").exists()).toBe(false);
  });

  it("marks a metric's chip long-gap, quietly, without any logs-never-happened styling", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/summary")) {
        return Promise.resolve(
          jsonResponse(200, { data: [baseSummary({ diaper_avg_per_day_7d: 1.2, diaper_long_gap: true })] }),
        );
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountFeedPage();
    await flushPromises();
    await flushPromises();

    const diaperChip = wrapper.find(".chip-diaper");
    expect(diaperChip.classes()).toContain("long-gap");
    expect(diaperChip.attributes("title")).toBe(i18n.global.t("feed.longGapHint"));
  });

  it("does not flag long-gap on a metric the summary reports as on-schedule", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/summary")) {
        return Promise.resolve(jsonResponse(200, { data: [baseSummary({ diaper_avg_per_day_7d: 1.2 })] }));
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountFeedPage();
    await flushPromises();
    await flushPromises();

    const diaperChip = wrapper.find(".chip-diaper");
    expect(diaperChip.classes()).not.toContain("long-gap");
    expect(diaperChip.attributes("title")).toBeUndefined();
  });
});
