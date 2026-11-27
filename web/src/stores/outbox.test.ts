import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useOutboxStore } from "./outbox";
import { useBabiesStore } from "./babies";
import { useDiaperLogsStore } from "./diaperLogs";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("outbox store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("enqueue persists the entry and attempts to send it immediately", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );

    const outbox = useOutboxStore();
    const promise = outbox.enqueue({
      tempId: -1,
      metric: "diaper",
      baby_id: 1,
      payload: { logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
    });

    expect(outbox.entries).toHaveLength(1);

    const log = (await promise) as { id: number };
    expect(log.id).toBe(9);
    expect(outbox.entries).toHaveLength(0);

    const [, options] = fetchSpy.mock.calls[0];
    const body = JSON.parse((options as RequestInit).body as string);
    expect(body.client_request_id).toBe("-1");
  });

  it("flush only ever sends entries for babies the current account owns", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(201, { data: {} }));

    const outbox = useOutboxStore();
    outbox.entries = [
      { tempId: -1, metric: "diaper", baby_id: 1, payload: {} },
      { tempId: -2, metric: "diaper", baby_id: 999, payload: {} },
    ];

    await outbox.flush();

    const createCalls = fetchSpy.mock.calls.filter((call) => String(call[0]).includes("diaper_logs"));
    expect(createCalls).toHaveLength(1);
    expect(outbox.entries).toEqual([{ tempId: -2, metric: "diaper", baby_id: 999, payload: {} }]);
  });

  it("flush stops the pass (leaving everything queued) on a network failure", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];

    vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Failed to fetch"));

    const outbox = useOutboxStore();
    outbox.entries = [
      { tempId: -1, metric: "diaper", baby_id: 1, payload: {} },
      { tempId: -2, metric: "diaper", baby_id: 1, payload: {} },
    ];

    await outbox.flush();

    expect(outbox.entries).toHaveLength(2);
  });

  it("a successful flush splices the real record into the owning store", async () => {
    const babies = useBabiesStore();
    babies.babies = [{ id: 1, name: "Riley", theme_color: "#F5A9B8" }];
    const diaperLogs = useDiaperLogsStore();
    diaperLogs.logs = [
      { id: -7, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true, _queued: true },
    ];

    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(201, {
        data: { id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      }),
    );

    const outbox = useOutboxStore();
    outbox.entries = [
      {
        tempId: -7,
        metric: "diaper",
        baby_id: 1,
        payload: { logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true },
      },
    ];

    await outbox.flush();

    expect(diaperLogs.logs).toEqual([{ id: 9, baby_id: 1, logged_at: "2026-11-24T10:00:00Z", peed: true, pooped: true }]);
  });

  it("cancelIfQueued removes a not-yet-sent entry and reports success", () => {
    const outbox = useOutboxStore();
    outbox.entries = [{ tempId: -1, metric: "diaper", baby_id: 1, payload: {} }];

    expect(outbox.cancelIfQueued(-1)).toBe(true);
    expect(outbox.entries).toHaveLength(0);
    expect(outbox.cancelIfQueued(-1)).toBe(false);
  });

  it("entriesFor filters by metric and baby", () => {
    const outbox = useOutboxStore();
    outbox.entries = [
      { tempId: -1, metric: "diaper", baby_id: 1, payload: {} },
      { tempId: -2, metric: "bottle", baby_id: 1, payload: {} },
      { tempId: -3, metric: "diaper", baby_id: 2, payload: {} },
    ];

    expect(outbox.entriesFor("diaper", 1).map((entry) => entry.tempId)).toEqual([-1]);
  });
});
