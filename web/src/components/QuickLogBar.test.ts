import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { mount, flushPromises } from "@vue/test-utils";
import { createI18n } from "vue-i18n";
import en from "@/i18n/en";
import type { MessageSchema } from "@/i18n/en";
import QuickLogBar from "./QuickLogBar.vue";
import { useBabiesStore } from "@/stores/babies";
import { useDiaperLogsStore } from "@/stores/diaperLogs";
import { useBottleFeedingsStore } from "@/stores/bottleFeedings";
import { useBreastfeedingLogsStore } from "@/stores/breastfeedingLogs";
import { useFeedStore } from "@/stores/feed";
import { useChartsStore } from "@/stores/charts";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

function mountBar() {
  const i18n = createI18n<[MessageSchema], "en", false>({
    legacy: false,
    locale: "en",
    messages: { en },
  });
  return mount(QuickLogBar, { global: { plugins: [i18n] } });
}

describe("QuickLogBar", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("renders nothing when there is no active baby", () => {
    const wrapper = mountBar();
    expect(wrapper.findAll(".quick-log-btn")).toHaveLength(0);
  });

  it("renders one fixed-accent button per metric for the active baby", () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    const wrapper = mountBar();
    const buttons = wrapper.findAll(".quick-log-btn");
    expect(buttons).toHaveLength(3);
    expect(wrapper.find(".quick-log-btn-diaper").exists()).toBe(true);
    expect(wrapper.find(".quick-log-btn-bottle").exists()).toBe(true);
    expect(wrapper.find(".quick-log-btn-breastfeeding").exists()).toBe(true);
  });

  it("tapping the diaper button logs optimistically for the active baby and shows a toast", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );

    const wrapper = mountBar();
    await wrapper.find(".quick-log-btn-diaper").trigger("click");

    const diaperLogs = useDiaperLogsStore();
    expect(diaperLogs.logs).toHaveLength(1);
    expect(wrapper.text()).toContain(en.diaperLog.toastLogged);

    await flushPromises();
    expect(diaperLogs.logs[0].id).toBe(9);
  });

  it("tapping the bottle button logs via the bottle-feedings store, not diaper or breastfeeding", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 4, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", water_ml: 30, formula_g: 10 },
      }),
    );

    const wrapper = mountBar();
    await wrapper.find(".quick-log-btn-bottle").trigger("click");

    const bottleFeedings = useBottleFeedingsStore();
    const diaperLogs = useDiaperLogsStore();
    const breastfeedingLogs = useBreastfeedingLogsStore();
    expect(bottleFeedings.feedings).toHaveLength(1);
    expect(diaperLogs.logs).toHaveLength(0);
    expect(breastfeedingLogs.logs).toHaveLength(0);
  });

  it("a successful quick log refreshes the feed and a previously-loaded charts range", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    const feed = useFeedStore();
    const charts = useChartsStore();
    // Simulate the Charts page already having been visited once, the way it
    // would be if the user tapped the bar while that page is open.
    charts.lastBabyId = 1;
    charts.lastRange = { from: new Date("2026-11-20"), to: new Date("2026-11-24") };

    const fetchFeedSpy = vi.spyOn(feed, "fetchFeed").mockResolvedValue();
    const fetchSummarySpy = vi.spyOn(feed, "fetchSummary").mockResolvedValue();
    const chartsRefreshSpy = vi.spyOn(charts, "refresh").mockResolvedValue();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );

    const wrapper = mountBar();
    await wrapper.find(".quick-log-btn-diaper").trigger("click");
    await flushPromises();

    expect(fetchFeedSpy).toHaveBeenCalledTimes(1);
    expect(fetchSummarySpy).toHaveBeenCalledTimes(1);
    expect(chartsRefreshSpy).toHaveBeenCalledTimes(1);
  });

  it("does not refresh the feed/charts while the create request is still pending", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    const feed = useFeedStore();
    const fetchFeedSpy = vi.spyOn(feed, "fetchFeed").mockResolvedValue();

    let resolveFetch: (value: Response) => void = () => {};
    vi.spyOn(globalThis, "fetch").mockReturnValue(
      new Promise((resolve) => {
        resolveFetch = resolve;
      }) as Promise<Response>,
    );

    const wrapper = mountBar();
    await wrapper.find(".quick-log-btn-diaper").trigger("click");
    expect(fetchFeedSpy).not.toHaveBeenCalled();

    resolveFetch(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );
    await flushPromises();
    expect(fetchFeedSpy).toHaveBeenCalledTimes(1);
  });

  it("undo removes the entry after it resolves", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z" },
      }),
    );

    const wrapper = mountBar();
    await wrapper.find(".quick-log-btn-breastfeeding").trigger("click");
    await flushPromises();

    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));
    await wrapper.find(".quick-log-toast button").trigger("click");
    await flushPromises();

    const breastfeedingLogs = useBreastfeedingLogsStore();
    expect(breastfeedingLogs.logs).toHaveLength(0);
  });
});
