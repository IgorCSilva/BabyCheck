import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import GrowthMeasurementsPage from "./GrowthMeasurementsPage.vue";
import { useBabiesStore } from "@/stores/babies";
import { i18n } from "@/i18n";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

function mountPage() {
  // The trend charts render via vue-chartjs/Chart.js, which needs a real
  // canvas 2D context happy-dom doesn't provide — stubbed out here the same
  // way every other test in this suite avoids touching Chart.js directly
  // (no ChartsPage.test.ts exists either, for the same reason).
  return mount(GrowthMeasurementsPage, {
    global: { plugins: [i18n], stubs: { Line: true } },
  });
}

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("GrowthMeasurementsPage", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("shows the empty state when there are no measurements", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(200, { data: [] }));

    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain("No growth measurements recorded yet.");
  });

  it("lists fetched measurements grouped by year", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [
          { id: 2, baby_id: 1, weight_kg: 5.1, height_cm: 58.0, measured_at: "2026-11-20" },
          { id: 1, baby_id: 1, weight_kg: 4.2, height_cm: 55.0, measured_at: "2025-11-01" },
        ],
      }),
    );

    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.findAll(".measurement-row")).toHaveLength(2);
    expect(wrapper.findAll(".year-header").map((el) => el.text())).toEqual(["2026", "2025"]);
  });

  it("submits a new measurement and resets the form", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((_url, init) => {
      if (init?.method === "POST") {
        return Promise.resolve(
          jsonResponse(201, {
            data: { id: 1, baby_id: 1, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" },
          }),
        );
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find("#growth-weight").setValue("4.2");
    await wrapper.find("#growth-height").setValue("55");
    await wrapper.find("#growth-date").setValue("2026-11-20");
    await wrapper.find("form").trigger("submit.prevent");
    await flushPromises();

    expect(wrapper.findAll(".measurement-row")).toHaveLength(1);
    expect((wrapper.find("#growth-weight").element as HTMLInputElement).value).toBe("");
  });

  it("shows a field error when the server rejects a measurement with neither value", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((_url, init) => {
      if (init?.method === "POST") {
        return Promise.resolve(
          jsonResponse(422, { errors: { weight_kg: ["weight or height must be present"] } }),
        );
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find("#growth-date").setValue("2026-11-20");
    await wrapper.find("form").trigger("submit.prevent");
    await flushPromises();

    expect(wrapper.text()).toContain("enter a weight or a height");
  });

  it("starts an edit, populating the form from the row", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [{ id: 1, baby_id: 1, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" }],
      }),
    );

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find(".measurement-row-action").trigger("click");

    expect((wrapper.find("#growth-weight").element as HTMLInputElement).value).toBe("4.2");
    expect((wrapper.find("#growth-height").element as HTMLInputElement).value).toBe("55");
    expect(wrapper.text()).toContain("Edit measurement");
  });

  it("deletes a measurement after confirmation", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((_url, init) => {
      if (init?.method === "DELETE") return Promise.resolve(jsonResponse(204, null));
      return Promise.resolve(
        jsonResponse(200, {
          data: [{ id: 1, baby_id: 1, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" }],
        }),
      );
    });
    window.confirm = vi.fn(() => true);

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find(".measurement-row-delete").trigger("click");
    await flushPromises();

    expect(wrapper.findAll(".measurement-row")).toHaveLength(0);
  });

  it("exports a PDF when the Export PDF button is clicked", async () => {
    const blob = new Blob(["%PDF-fake"], { type: "application/pdf" });
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/export")) {
        return Promise.resolve(
          new Response(blob, {
            status: 200,
            headers: {
              "content-disposition": 'attachment; filename="babycheck-riley-growth.pdf"',
            },
          }),
        );
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });
    vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:fake-url");
    vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find(".export-button").trigger("click");
    await flushPromises();

    const exportCall = fetchSpy.mock.calls.find((call) => String(call[0]).includes("/export"));
    expect(exportCall).toBeDefined();
    expect(String(exportCall?.[0])).toContain("/api/babies/1/growth_measurements/export?");
  });

  it("shows an error if the PDF export fails", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((url) => {
      if (String(url).includes("/export")) {
        return Promise.resolve(
          new Response(JSON.stringify({ errors: { detail: "not found" } }), { status: 404 }),
        );
      }
      return Promise.resolve(jsonResponse(200, { data: [] }));
    });

    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find(".export-button").trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("Couldn't export the PDF. Please try again.");
  });
});
