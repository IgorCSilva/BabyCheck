import { defineStore } from "pinia";
import { apiRequest } from "@/lib/api";

export interface FeedEntry {
  type: "diaper" | "bottle" | "breastfeeding";
  id: number;
  baby_id: number;
  baby_name: string;
  baby_theme_color: string;
  logged_at: string;
  peed: boolean | null;
  pooped: boolean | null;
  water_ml: number | null;
  formula_g: number | null;
}

export interface BabyActivitySummary {
  baby_id: number;
  baby_name: string;
  baby_theme_color: string;
  diaper_last_logged_at: string | null;
  bottle_last_logged_at: string | null;
  breastfeeding_last_logged_at: string | null;
  diaper_avg_per_day_7d: number;
  bottle_avg_per_day_7d: number;
  breastfeeding_avg_per_day_7d: number;
  diaper_long_gap: boolean;
  bottle_long_gap: boolean;
  breastfeeding_long_gap: boolean;
}

const PAGE_SIZE = 20;

interface FeedState {
  entries: FeedEntry[];
  summary: BabyActivitySummary[];
  loading: boolean;
  loadingMore: boolean;
  hasMore: boolean;
}

export const useFeedStore = defineStore("feed", {
  state: (): FeedState => ({
    entries: [],
    summary: [],
    loading: false,
    loadingMore: false,
    hasMore: true,
  }),

  actions: {
    async fetchFeed() {
      this.loading = true;
      try {
        this.entries = await apiRequest<FeedEntry[]>(`/api/feed?limit=${PAGE_SIZE}`, {
          method: "GET",
        });
        this.hasMore = this.entries.length === PAGE_SIZE;
      } finally {
        this.loading = false;
      }
    },

    // Cursor-based (the last visible entry's own `logged_at`) rather than
    // offset-based, so a log landing elsewhere while the user scrolls can
    // never shift which entries the next page picks up.
    async fetchMore() {
      if (this.loadingMore || !this.hasMore || this.entries.length === 0) return;

      this.loadingMore = true;
      try {
        const cursor = this.entries[this.entries.length - 1].logged_at;
        const params = new URLSearchParams({ limit: String(PAGE_SIZE), before: cursor });
        const next = await apiRequest<FeedEntry[]>(`/api/feed?${params.toString()}`, {
          method: "GET",
        });
        this.entries.push(...next);
        this.hasMore = next.length === PAGE_SIZE;
      } finally {
        this.loadingMore = false;
      }
    },

    async fetchSummary() {
      this.summary = await apiRequest<BabyActivitySummary[]>("/api/feed/summary", {
        method: "GET",
      });
    },

    reset() {
      this.entries = [];
      this.summary = [];
      this.loading = false;
      this.loadingMore = false;
      this.hasMore = true;
    },
  },
});
