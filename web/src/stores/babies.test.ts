import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useBabiesStore } from "./babies";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("babies store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    localStorage.clear();
  });

  it("fetchBabies loads the list and picks an active baby", async () => {
    const babies = useBabiesStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }] }),
    );

    await babies.fetchBabies();

    expect(babies.babies).toHaveLength(1);
    expect(babies.activeBabyId).toBe(1);
    expect(babies.activeBaby?.name).toBe("Riley");
  });

  it("ensureLoaded only fetches once", async () => {
    const babies = useBabiesStore();
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(200, { data: [] }));

    await babies.ensureLoaded();
    await babies.ensureLoaded();

    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("createBaby appends to the list and activates the first baby added", async () => {
    const babies = useBabiesStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, { data: { id: 2, name: "Sam", theme_color: "#9DC8E8" } }),
    );

    await babies.createBaby("Sam", "#9DC8E8");

    expect(babies.babies).toEqual([{ id: 2, name: "Sam", theme_color: "#9DC8E8" }]);
    expect(babies.activeBabyId).toBe(2);
  });

  it("deleteBaby removes it and reassigns the active baby", async () => {
    const babies = useBabiesStore();
    babies.babies = [
      { id: 1, name: "Riley", theme_color: "#F5A9B8" },
      { id: 2, name: "Sam", theme_color: "#9DC8E8" },
    ];
    babies.setActiveBaby(1);
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await babies.deleteBaby(1);

    expect(babies.babies).toEqual([{ id: 2, name: "Sam", theme_color: "#9DC8E8" }]);
    expect(babies.activeBabyId).toBe(2);
  });

  it("deleteBaby clears the active baby once none remain", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await babies.deleteBaby(1);

    expect(babies.babies).toEqual([]);
    expect(babies.activeBabyId).toBe(null);
  });

  it("reset clears babies and the active selection", () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    babies.setActiveBaby(1);

    babies.reset();

    expect(babies.babies).toEqual([]);
    expect(babies.loaded).toBe(false);
    expect(babies.activeBabyId).toBe(null);
  });
});
