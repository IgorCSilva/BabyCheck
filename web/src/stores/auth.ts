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

    async refresh() {
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
