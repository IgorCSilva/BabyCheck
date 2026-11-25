import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useFeedStore } from "./feed";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

function entry(overrides: Record<string, unknown> = {}) {
  return {
    type: "diaper",
    id: 1,
    baby_id: 1,
    baby_name: "Riley",
    baby_theme_color: "#F5A9B8",
    logged_at: "2026-11-20T08:00:00Z",
    peed: true,
    pooped: false,
    water_ml: null,
    formula_g: null,
    ...overrides,
  };
}

describe("feed store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("fetchFeed loads entries and flags hasMore when a full page comes back", async () => {
    const feed = useFeedStore();
    const page = Array.from({ length: 20 }, (_, i) => entry({ id: i + 1 }));
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(200, { data: page }));

    await feed.fetchFeed();

    expect(feed.entries).toHaveLength(20);
    expect(feed.hasMore).toBe(true);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("/api/feed?limit=20");
  });

  it("fetchFeed sets hasMore false when fewer than a full page comes back", async () => {
    const feed = useFeedStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: [entry()] }),
    );

    await feed.fetchFeed();

    expect(feed.entries).toHaveLength(1);
    expect(feed.hasMore).toBe(false);
  });

  it("fetchMore appends the next page using the last entry's logged_at as the cursor", async () => {
    const feed = useFeedStore();
    feed.entries = [entry({ id: 1, logged_at: "2026-11-20T08:00:00Z" })];
    feed.hasMore = true;

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: [entry({ id: 2, logged_at: "2026-11-19T08:00:00Z" })] }),
    );

    await feed.fetchMore();

    expect(feed.entries).toHaveLength(2);
    expect(feed.entries[1].id).toBe(2);
    const url = fetchSpy.mock.calls[0][0] as string;
    expect(url).toContain("before=2026-11-20T08%3A00%3A00Z");
  });

  it("fetchMore does nothing when hasMore is false", async () => {
    const feed = useFeedStore();
    feed.entries = [entry()];
    feed.hasMore = false;
    const fetchSpy = vi.spyOn(globalThis, "fetch");

    await feed.fetchMore();

    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("fetchSummary loads the per-baby summary", async () => {
    const feed = useFeedStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, {
        data: [
          {
            baby_id: 1,
            baby_name: "Riley",
            baby_theme_color: "#F5A9B8",
            diaper_last_logged_at: "2026-11-20T08:00:00Z",
            bottle_last_logged_at: null,
            breastfeeding_last_logged_at: null,
          },
        ],
      }),
    );

    await feed.fetchSummary();

    expect(feed.summary).toHaveLength(1);
    expect(feed.summary[0].baby_id).toBe(1);
  });

  it("reset clears entries, summary, and pagination state", () => {
    const feed = useFeedStore();
    feed.entries = [entry()];
    feed.summary = [
      {
        baby_id: 1,
        baby_name: "Riley",
        baby_theme_color: "#F5A9B8",
        diaper_last_logged_at: null,
        bottle_last_logged_at: null,
        breastfeeding_last_logged_at: null,
      },
    ];
    feed.hasMore = false;

    feed.reset();

    expect(feed.entries).toEqual([]);
    expect(feed.summary).toEqual([]);
    expect(feed.hasMore).toBe(true);
  });
});
