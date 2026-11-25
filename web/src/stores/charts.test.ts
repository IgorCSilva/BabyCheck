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

  it("reset clears the chart data", () => {
    const charts = useChartsStore();
    charts.data = {
      diaper: [{ date: "2026-11-20", count: 2 }],
      bottle: [],
      breastfeeding: [],
    };

    charts.reset();

    expect(charts.data).toEqual({ diaper: [], bottle: [], breastfeeding: [] });
  });
});
