import { defineStore } from "pinia";

export interface SessionUser {
  id: number;
  email: string;
}

interface ApiErrorBody {
  errors?: {
    detail?: string;
    code?: string;
    [field: string]: unknown;
  };
}

export class ApiError extends Error {
  code?: string;
  fieldErrors: Record<string, string[]>;

  constructor(message: string, code: string | undefined, fieldErrors: Record<string, string[]>) {
    super(message);
    this.code = code;
    this.fieldErrors = fieldErrors;
  }
}

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

// Dedupes concurrent refresh() callers (apiRequest's 401 retry can fire from
// several in-flight requests at once, since the 15-minute access token
// expires for all of them together) so they share a single
// /api/auth/refresh call instead of racing. The backend rotates the refresh
// token on each call, so a second concurrent call would read the
// now-stale, already-rotated-out cookie, fail, and wrongly clear the
// session the first call just re-established.
let refreshPromise: Promise<void> | null = null;

interface AuthState {
  user: SessionUser | null;
  accessToken: string | null;
  ready: boolean;
}

export const useAuthStore = defineStore("auth", {
  state: (): AuthState => ({
    user: null,
    accessToken: null,
    ready: false,
  }),

  getters: {
    isAuthenticated: (state) => state.user !== null && state.accessToken !== null,
  },

  actions: {
    // Called once on app boot: tries to resume a session from the
    // HttpOnly refresh cookie, so a page reload doesn't bounce an
    // already-logged-in visitor to the login screen.
    async initialize() {
      try {
        await this.refresh();
      } catch {
        this.clearSession();
      } finally {
        this.ready = true;
      }
    },

    async register(email: string, password: string, passwordConfirmation: string) {
      const { user, access_token } = await this.request("/api/auth/register", {
        method: "POST",
        body: { email, password, password_confirmation: passwordConfirmation },
      });
      this.setSession(user, access_token);
    },

    async login(email: string, password: string, rememberMe: boolean) {
      const { user, access_token } = await this.request("/api/auth/login", {
        method: "POST",
        body: { email, password, remember_me: rememberMe },
      });
      this.setSession(user, access_token);
    },

    // Exchanges the HttpOnly refresh cookie for a fresh access token.
    // Delegates to performRefresh() through the module-level dedup guard
    // above, so overlapping callers share one in-flight request.
    async refresh() {
      if (!refreshPromise) {
        refreshPromise = this.performRefresh().finally(() => {
          refreshPromise = null;
        });
      }
      return refreshPromise;
    },

    async performRefresh() {
      const { user, access_token } = await this.request("/api/auth/refresh", { method: "POST" });
      this.setSession(user, access_token);
    },

    async logout() {
      try {
        await this.request("/api/auth/logout", { method: "DELETE" });
      } finally {
        this.clearSession();
      }
    },

    async requestPasswordReset(email: string) {
      await this.request("/api/auth/password_resets", { method: "POST", body: { email } });
    },

    async resetPassword(token: string, password: string, passwordConfirmation: string) {
      const { user, access_token } = await this.request(`/api/auth/password_resets/${token}`, {
        method: "PUT",
        body: { password, password_confirmation: passwordConfirmation },
      });
      this.setSession(user, access_token);
    },

    setSession(user: SessionUser, accessToken: string) {
      this.user = user;
      this.accessToken = accessToken;
    },

    clearSession() {
      this.user = null;
      this.accessToken = null;
    },

    async request(
      path: string,
      options: { method: string; body?: Record<string, unknown> },
    ): Promise<{ user: SessionUser; access_token: string }> {
      const response = await fetch(`${API_BASE_URL}${path}`, {
        method: options.method,
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
          ...(this.accessToken ? { Authorization: `Bearer ${this.accessToken}` } : {}),
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
      });

      if (response.status === 204) {
        return { user: this.user as SessionUser, access_token: this.accessToken as string };
      }

      const payload = (await response.json()) as ApiErrorBody & {
        data?: { user: SessionUser; access_token: string };
      };

      if (!response.ok) {
        const { detail, code, ...fieldErrors } = payload.errors ?? {};
        throw new ApiError(
          (detail as string) || "something went wrong",
          code as string | undefined,
          fieldErrors as Record<string, string[]>,
        );
      }

      return payload.data as { user: SessionUser; access_token: string };
    },
  },
});
