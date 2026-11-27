import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useChartsStore } from "./charts";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("charts store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchCharts loads the range-filtered daily counts for all three metrics", async () => {
    const charts = useChartsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: {
          diaper: [{ date: "2026-11-20", count: 2 }],
          bottle: [{ date: "2026-11-20", count: 0 }],
          breastfeeding: [{ date: "2026-11-20", count: 1 }],
        },
      }),
    );

    await charts.fetchCharts(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    expect(charts.data.diaper).toEqual([{ date: "2026-11-20", count: 2 }]);
    expect(charts.data.bottle).toEqual([{ date: "2026-11-20", count: 0 }]);
    expect(charts.data.breastfeeding).toEqual([{ date: "2026-11-20", count: 1 }]);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/charts?");
    expect(url).toContain("from=");
    expect(url).toContain("to=");
  });

  it("loading is true while the request is in flight and false once it resolves", async () => {
    const charts = useChartsStore();
    let resolveFetch: (value: Response) => void = () => {};
    vi.spyOn(globalThis, "fetch").mockReturnValue(
      new Promise((resolve) => {
        resolveFetch = resolve;
      }) as Promise<Response>,
    );

    const promise = charts.fetchCharts(1, { from: new Date(), to: new Date() });
    expect(charts.loading).toBe(true);

    resolveFetch(jsonResponse(200, { data: { diaper: [], bottle: [], breastfeeding: [] } }));
    await promise;

    expect(charts.loading).toBe(false);
  });

  it("refresh re-fetches using the most recently requested baby and range", async () => {
    const charts = useChartsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: {
          diaper: [{ date: "2026-11-20", count: 1 }],
          bottle: [],
          breastfeeding: [],
        },
      }),
    );

    await charts.fetchCharts(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    fetchSpy.mockResolvedValue(
      jsonResponse(200, {
        data: {
          diaper: [{ date: "2026-11-20", count: 2 }],
          bottle: [],
          breastfeeding: [],
        },
      }),
    );

    await charts.refresh();

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    const secondUrl = fetchSpy.mock.calls[1][0] as string;
    expect(secondUrl).toContain("/api/babies/1/charts?");
    expect(charts.data.diaper).toEqual([{ date: "2026-11-20", count: 2 }]);
  });

  it("refresh is a no-op before any chart has ever been fetched", async () => {
    const charts = useChartsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch");

    await charts.refresh();

    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("exportSummary downloads the PDF using the server-provided filename", async () => {
    const charts = useChartsStore();
    const blob = new Blob(["%PDF-fake"], { type: "application/pdf" });
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(blob, {
        status: 200,
        headers: { "content-disposition": 'attachment; filename="babycheck-riley-summary.pdf"' },
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

    await charts.exportSummary(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/export?");
    expect(createObjectURLSpy).toHaveBeenCalled();
    expect(createdLink?.download).toBe("babycheck-riley-summary.pdf");
    expect(clickSpy).toHaveBeenCalled();
    expect(revokeObjectURLSpy).toHaveBeenCalledWith("blob:fake-url");
  });

  it("exportSummary falls back to a default filename when the server sends none", async () => {
    const charts = useChartsStore();
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

    await charts.exportSummary(1, { from: new Date(), to: new Date() });

    expect(createdLink?.download).toBe("babycheck-summary.pdf");
  });

  it("exportSummary rejects when the server returns an error", async () => {
    const charts = useChartsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ errors: { detail: "not found" } }), { status: 404 }),
    );

    await expect(charts.exportSummary(1, { from: new Date(), to: new Date() })).rejects.toThrow(
      "not found",
    );
  });

  it("reset clears the chart data and forgets the last-requested range", () => {
    const charts = useChartsStore();
    charts.data = {
      diaper: [{ date: "2026-11-20", count: 2 }],
      bottle: [],
      breastfeeding: [],
    };
    charts.lastBabyId = 1;
    charts.lastRange = { from: new Date(), to: new Date() };

    charts.reset();

    expect(charts.data).toEqual({ diaper: [], bottle: [], breastfeeding: [] });
    expect(charts.lastBabyId).toBeNull();
    expect(charts.lastRange).toBeNull();
  });
});
