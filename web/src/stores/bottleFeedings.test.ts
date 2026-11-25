import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useBottleFeedingsStore } from "./bottleFeedings";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("bottleFeedings store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchFeedings loads the range-filtered list", async () => {
    const bottleFeedings = useBottleFeedingsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [
          { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", water_ml: 30, formula_g: 10 },
        ],
      }),
    );

    await bottleFeedings.fetchFeedings(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    expect(bottleFeedings.feedings).toHaveLength(1);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/bottle_feedings?");
    expect(url).toContain("from=");
    expect(url).toContain("to=");
  });

  it("quickLog inserts a placeholder with default amounts, then swaps in the real record", async () => {
    const bottleFeedings = useBottleFeedingsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 5, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", water_ml: 30, formula_g: 10 },
      }),
    );

    const { tempId, promise } = bottleFeedings.quickLog(1);

    expect(bottleFeedings.feedings).toHaveLength(1);
    expect(bottleFeedings.feedings[0].id).toBe(tempId);
    expect(bottleFeedings.feedings[0].water_ml).toBe(30);
    expect(bottleFeedings.feedings[0].formula_g).toBe(10);
    expect(tempId).toBeLessThan(0);

    const real = await promise;

    expect(real.id).toBe(5);
    expect(bottleFeedings.feedings).toHaveLength(1);
    expect(bottleFeedings.feedings[0].id).toBe(5);
  });

  it("quickLog rolls back the placeholder if the request fails", async () => {
    const bottleFeedings = useBottleFeedingsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(422, { errors: { detail: "bad request" } }),
    );

    const { promise } = bottleFeedings.quickLog(1);
    await expect(promise).rejects.toThrow();

    expect(bottleFeedings.feedings).toHaveLength(0);
  });

  it("updateFeeding replaces the entry and keeps the list sorted by logged_at desc", async () => {
    const bottleFeedings = useBottleFeedingsStore();
    bottleFeedings.feedings = [
      { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", water_ml: 30, formula_g: 10 },
      { id: 2, baby_id: 1, logged_at: "2026-11-19T08:00:00Z", water_ml: 30, formula_g: 10 },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: { id: 2, baby_id: 1, logged_at: "2026-11-21T08:00:00Z", water_ml: 45, formula_g: 15 },
      }),
    );

    await bottleFeedings.updateFeeding(2, {
      logged_at: "2026-11-21T08:00:00Z",
      water_ml: 45,
      formula_g: 15,
    });

    expect(bottleFeedings.feedings.map((feeding) => feeding.id)).toEqual([2, 1]);
    expect(bottleFeedings.feedings[0].water_ml).toBe(45);
  });

  it("deleteFeeding removes the entry", async () => {
    const bottleFeedings = useBottleFeedingsStore();
    bottleFeedings.feedings = [
      { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", water_ml: 30, formula_g: 10 },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await bottleFeedings.deleteFeeding(1);

    expect(bottleFeedings.feedings).toEqual([]);
  });

  it("reset clears the feedings", () => {
    const bottleFeedings = useBottleFeedingsStore();
    bottleFeedings.feedings = [
      { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", water_ml: 30, formula_g: 10 },
    ];

    bottleFeedings.reset();

    expect(bottleFeedings.feedings).toEqual([]);
  });
});
