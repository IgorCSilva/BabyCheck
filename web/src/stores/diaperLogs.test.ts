import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useDiaperLogsStore } from "./diaperLogs";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("diaperLogs store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchLogs loads the range-filtered list", async () => {
    const diaperLogs = useDiaperLogsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", peed: true, pooped: true }],
      }),
    );

    await diaperLogs.fetchLogs(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    expect(diaperLogs.logs).toHaveLength(1);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/diaper_logs?");
    expect(url).toContain("from=");
    expect(url).toContain("to=");
  });

  it("quickLog inserts a placeholder immediately, then swaps in the real record", async () => {
    const diaperLogs = useDiaperLogsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 5, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );

    const { tempId, promise } = diaperLogs.quickLog(1);

    expect(diaperLogs.logs).toHaveLength(1);
    expect(diaperLogs.logs[0].id).toBe(tempId);
    expect(tempId).toBeLessThan(0);

    const real = await promise;

    expect(real.id).toBe(5);
    expect(diaperLogs.logs).toHaveLength(1);
    expect(diaperLogs.logs[0].id).toBe(5);
  });

  it("quickLog rolls back the placeholder if the request fails", async () => {
    const diaperLogs = useDiaperLogsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(422, { errors: { detail: "bad request" } }),
    );

    const { promise } = diaperLogs.quickLog(1);
    await expect(promise).rejects.toThrow();

    expect(diaperLogs.logs).toHaveLength(0);
  });

  it("updateLog replaces the entry and keeps the list sorted by logged_at desc", async () => {
    const diaperLogs = useDiaperLogsStore();
    diaperLogs.logs = [
      { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", peed: true, pooped: true },
      { id: 2, baby_id: 1, logged_at: "2026-11-19T08:00:00Z", peed: true, pooped: true },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: { id: 2, baby_id: 1, logged_at: "2026-11-21T08:00:00Z", peed: false, pooped: true },
      }),
    );

    await diaperLogs.updateLog(2, { logged_at: "2026-11-21T08:00:00Z", peed: false, pooped: true });

    expect(diaperLogs.logs.map((log) => log.id)).toEqual([2, 1]);
    expect(diaperLogs.logs[0].peed).toBe(false);
  });

  it("deleteLog removes the entry", async () => {
    const diaperLogs = useDiaperLogsStore();
    diaperLogs.logs = [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", peed: true, pooped: true }];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await diaperLogs.deleteLog(1);

    expect(diaperLogs.logs).toEqual([]);
  });

  it("reset clears the logs", () => {
    const diaperLogs = useDiaperLogsStore();
    diaperLogs.logs = [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z", peed: true, pooped: true }];

    diaperLogs.reset();

    expect(diaperLogs.logs).toEqual([]);
  });
});
