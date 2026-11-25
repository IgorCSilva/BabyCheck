import { defineStore } from "pinia";
import { apiRequest } from "@/lib/api";

export interface Baby {
  id: number;
  name: string;
  theme_color: string;
}

const ACTIVE_BABY_STORAGE_KEY = "babycheck.activeBabyId";

function readStoredActiveBabyId(): number | null {
  const stored = localStorage.getItem(ACTIVE_BABY_STORAGE_KEY);
  return stored ? Number(stored) : null;
}

interface BabiesState {
  babies: Baby[];
  loaded: boolean;
  activeBabyId: number | null;
}

export const useBabiesStore = defineStore("babies", {
  state: (): BabiesState => ({
    babies: [],
    loaded: false,
    activeBabyId: readStoredActiveBabyId(),
  }),

  getters: {
    activeBaby: (state): Baby | null =>
      state.babies.find((baby) => baby.id === state.activeBabyId) ?? null,
  },

  actions: {
    // Called from the router guard before entering any authenticated
    // route — fetches once per session and is skipped on every
    // subsequent navigation.
    async ensureLoaded() {
      if (!this.loaded) await this.fetchBabies();
    },

    async fetchBabies() {
      this.babies = await apiRequest<Baby[]>("/api/babies", { method: "GET" });
      this.loaded = true;
      this.reconcileActiveBaby();
    },

    async createBaby(name: string, themeColor: string) {
      const baby = await apiRequest<Baby>("/api/babies", {
        method: "POST",
        body: { name, theme_color: themeColor },
      });
      this.babies.push(baby);
      this.reconcileActiveBaby();
      return baby;
    },

    async updateBaby(id: number, name: string, themeColor: string) {
      const baby = await apiRequest<Baby>(`/api/babies/${id}`, {
        method: "PUT",
        body: { name, theme_color: themeColor },
      });
      const index = this.babies.findIndex((existing) => existing.id === id);
      if (index !== -1) this.babies[index] = baby;
      return baby;
    },

    async deleteBaby(id: number) {
      await apiRequest<void>(`/api/babies/${id}`, { method: "DELETE" });
      this.babies = this.babies.filter((baby) => baby.id !== id);
      this.reconcileActiveBaby();
    },

    setActiveBaby(id: number) {
      this.activeBabyId = id;
      localStorage.setItem(ACTIVE_BABY_STORAGE_KEY, String(id));
    },

    // Keeps the active baby pointed at something real: falls back to the
    // first baby if the stored id no longer exists (deleted, or from a
    // different account on this browser), and clears it once there are
    // no babies left at all.
    reconcileActiveBaby() {
      if (this.babies.length === 0) {
        this.activeBabyId = null;
        localStorage.removeItem(ACTIVE_BABY_STORAGE_KEY);
        return;
      }

      if (!this.babies.some((baby) => baby.id === this.activeBabyId)) {
        this.setActiveBaby(this.babies[0].id);
      }
    },

    reset() {
      this.babies = [];
      this.loaded = false;
      this.activeBabyId = null;
      localStorage.removeItem(ACTIVE_BABY_STORAGE_KEY);
    },
  },
});
