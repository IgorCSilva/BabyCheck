import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useBreastfeedingLogsStore } from "./breastfeedingLogs";
import { useOutboxStore } from "./outbox";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("breastfeedingLogs store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchLogs loads the range-filtered list", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z" }],
      }),
    );

    await breastfeedingLogs.fetchLogs(1, {
      from: new Date("2026-11-20T00:00:00Z"),
      to: new Date("2026-11-20T23:59:59Z"),
    });

    expect(breastfeedingLogs.logs).toHaveLength(1);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/babies/1/breastfeeding_logs?");
    expect(url).toContain("from=");
    expect(url).toContain("to=");
  });

  it("quickLog inserts a placeholder immediately, then swaps in the real record", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 5, baby_id: 1, logged_at: "2026-11-24T10:00:00Z" },
      }),
    );

    const { tempId, promise } = breastfeedingLogs.quickLog(1);

    expect(breastfeedingLogs.logs).toHaveLength(1);
    expect(breastfeedingLogs.logs[0].id).toBe(tempId);
    expect(tempId).toBeLessThan(0);

    const real = await promise;

    expect(real.id).toBe(5);
    expect(breastfeedingLogs.logs).toHaveLength(1);
    expect(breastfeedingLogs.logs[0].id).toBe(5);
  });

  it("quickLog rolls back the placeholder if the request fails", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(422, { errors: { detail: "bad request" } }),
    );

    const { promise } = breastfeedingLogs.quickLog(1);
    await expect(promise).rejects.toThrow();

    expect(breastfeedingLogs.logs).toHaveLength(0);
  });

  it("quickLog falls back to the offline outbox on a network failure instead of rolling back", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Failed to fetch"));

    const { tempId } = breastfeedingLogs.quickLog(1);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(breastfeedingLogs.logs).toHaveLength(1);
    const row = breastfeedingLogs.logs.find((log) => log.id === tempId);
    expect(row?._queued).toBe(true);

    const outbox = useOutboxStore();
    expect(outbox.entriesFor("breastfeeding", 1).map((entry) => entry.tempId)).toContain(tempId);
  });

  it("restoreQueued re-inserts a still-queued outbox entry after a reload", () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    const outbox = useOutboxStore();
    outbox.entries = [
      { tempId: -123, metric: "breastfeeding", baby_id: 1, payload: { logged_at: "2026-11-24T10:00:00Z" } },
    ];

    breastfeedingLogs.restoreQueued(1);

    expect(breastfeedingLogs.logs).toHaveLength(1);
    expect(breastfeedingLogs.logs[0]).toMatchObject({ id: -123, baby_id: 1, _queued: true });
  });

  it("tryDiscard cancels a still-queued entry without ever hitting the network", () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    breastfeedingLogs.logs = [
      { id: -123, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", _queued: true },
    ];
    const outbox = useOutboxStore();
    outbox.entries = [{ tempId: -123, metric: "breastfeeding", baby_id: 1, payload: {} }];

    expect(breastfeedingLogs.tryDiscard(-123)).toBe(true);
    expect(breastfeedingLogs.logs).toHaveLength(0);
    expect(outbox.entries).toHaveLength(0);
  });

  it("updateLog replaces the entry and keeps the list sorted by logged_at desc", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    breastfeedingLogs.logs = [
      { id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z" },
      { id: 2, baby_id: 1, logged_at: "2026-11-19T08:00:00Z" },
    ];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: { id: 2, baby_id: 1, logged_at: "2026-11-21T08:00:00Z" } }),
    );

    await breastfeedingLogs.updateLog(2, { logged_at: "2026-11-21T08:00:00Z" });

    expect(breastfeedingLogs.logs.map((log) => log.id)).toEqual([2, 1]);
  });

  it("deleteLog removes the entry", async () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    breastfeedingLogs.logs = [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z" }];
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(204, null));

    await breastfeedingLogs.deleteLog(1);

    expect(breastfeedingLogs.logs).toEqual([]);
  });

  it("reset clears the logs", () => {
    const breastfeedingLogs = useBreastfeedingLogsStore();
    breastfeedingLogs.logs = [{ id: 1, baby_id: 1, logged_at: "2026-11-20T08:00:00Z" }];

    breastfeedingLogs.reset();

    expect(breastfeedingLogs.logs).toEqual([]);
  });
});
