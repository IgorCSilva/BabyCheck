import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useGrowthMeasurementsStore } from "./growthMeasurements";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("growthMeasurements store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchMeasurements loads the list for the given baby", async () => {
    const store = useGrowthMeasurementsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [{ id: 1, baby_id: 7, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" }],
      }),
    );

    await store.fetchMeasurements(7);

    expect(store.measurements).toHaveLength(1);
    expect(store.measurements[0].weight_kg).toBe(4.2);
  });

  it("createMeasurement adds the new entry, newest first", async () => {
    const store = useGrowthMeasurementsStore();
    store.measurements = [
      { id: 1, baby_id: 7, weight_kg: 4.0, height_cm: 54.0, measured_at: "2026-11-01" },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 2, baby_id: 7, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" },
      }),
    );

    await store.createMeasurement(7, {
      weight_kg: 4.2,
      height_cm: 55.0,
      measured_at: "2026-11-20",
    });

    expect(store.measurements.map((entry) => entry.id)).toEqual([2, 1]);
  });

  it("updateMeasurement replaces the entry in place", async () => {
    const store = useGrowthMeasurementsStore();
    store.measurements = [
      { id: 1, baby_id: 7, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: { id: 1, baby_id: 7, weight_kg: 5.1, height_cm: 58.0, measured_at: "2026-11-21" },
      }),
    );

    const updated = await store.updateMeasurement(1, {
      weight_kg: 5.1,
      height_cm: 58.0,
      measured_at: "2026-11-21",
    });

    expect(updated.weight_kg).toBe(5.1);
    expect(store.measurements).toEqual([
      { id: 1, baby_id: 7, weight_kg: 5.1, height_cm: 58.0, measured_at: "2026-11-21" },
    ]);
  });

  it("deleteMeasurement removes the entry", async () => {
    const store = useGrowthMeasurementsStore();
    store.measurements = [
      { id: 1, baby_id: 7, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await store.deleteMeasurement(1);

    expect(store.measurements).toEqual([]);
  });

  it("exportPdf downloads the PDF using the server-provided filename", async () => {
    const store = useGrowthMeasurementsStore();
    const blob = new Blob(["%PDF-fake"], { type: "application/pdf" });
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(blob, {
        status: 200,
        headers: { "content-disposition": 'attachment; filename="babycheck-riley-growth.pdf"' },
      }),
    );
    const createObjectURLSpy = vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:fake-url");
    const revokeObjectURLSpy = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});

    const originalCreateElement = document.createElement.bind(document);
    let createdLink: HTMLAnchorElement | undefined;
    vi.spyOn(document, "createElement").mockImplementation((tag: string) => {
      const el = originalCreateElement(tag);
      if (tag === "a") createdLink = el as HTMLAnchorElement;
      return el;
    });

    await store.exportPdf(1);

    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/growth_measurements/export?");
    expect(createObjectURLSpy).toHaveBeenCalled();
    expect(createdLink?.download).toBe("babycheck-riley-growth.pdf");
    expect(clickSpy).toHaveBeenCalled();
    expect(revokeObjectURLSpy).toHaveBeenCalledWith("blob:fake-url");
  });

  it("exportPdf falls back to a default filename when the server sends none", async () => {
    const store = useGrowthMeasurementsStore();
    const blob = new Blob(["%PDF-fake"], { type: "application/pdf" });
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(blob, { status: 200 }));
    vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:fake-url");
    vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});

    const originalCreateElement = document.createElement.bind(document);
    let createdLink: HTMLAnchorElement | undefined;
    vi.spyOn(document, "createElement").mockImplementation((tag: string) => {
      const el = originalCreateElement(tag);
      if (tag === "a") createdLink = el as HTMLAnchorElement;
      return el;
    });

    await store.exportPdf(1);

    expect(createdLink?.download).toBe("babycheck-growth.pdf");
  });

  it("exportPdf rejects when the server returns an error", async () => {
    const store = useGrowthMeasurementsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ errors: { detail: "not found" } }), { status: 404 }),
    );

    await expect(store.exportPdf(1)).rejects.toThrow("not found");
  });

  it("reset clears the list", () => {
    const store = useGrowthMeasurementsStore();
    store.measurements = [
      { id: 1, baby_id: 7, weight_kg: 4.2, height_cm: 55.0, measured_at: "2026-11-20" },
    ];

    store.reset();

    expect(store.measurements).toEqual([]);
    expect(store.loading).toBe(false);
  });
});
