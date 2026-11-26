import { useAuthStore } from "@/stores/auth";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

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

// Shared by every authenticated store beyond auth itself (babies now,
// the per-metric logs in later steps) so each one doesn't reimplement
// the same bearer-token/credentials/error-shape plumbing.
//
// The access token is short-lived (15 minutes) and nothing proactively
// renews it, so a 401 here is the expected, routine way a stale token gets
// noticed — retried once against a fresh token from auth.refresh() (itself
// deduped against concurrent callers) before giving up. `retried` guards
// against looping if the refresh cookie itself is gone (genuinely logged
// out), in which case the original 401 is what the caller should see, not
// whatever error refresh() raised trying to recover from it.
export async function apiRequest<T>(
  path: string,
  options: { method: string; body?: Record<string, unknown> },
  retried = false,
): Promise<T> {
  const auth = useAuthStore();

  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(auth.accessToken ? { Authorization: `Bearer ${auth.accessToken}` } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (response.status === 401 && !retried) {
    try {
      await auth.refresh();
      return apiRequest<T>(path, options, true);
    } catch {
      // Refresh failed too — fall through and surface the original 401.
    }
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const payload = (await response.json()) as ApiErrorBody & { data?: T };

  if (!response.ok) {
    const { detail, code, ...fieldErrors } = payload.errors ?? {};
    throw new ApiError(
      (detail as string) || "something went wrong",
      code as string | undefined,
      fieldErrors as Record<string, string[]>,
    );
  }

  return payload.data as T;
}
