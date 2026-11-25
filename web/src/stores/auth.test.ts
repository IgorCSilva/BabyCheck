import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useAuthStore, ApiError } from "./auth";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("auth store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("starts unauthenticated", () => {
    const auth = useAuthStore();
    expect(auth.isAuthenticated).toBe(false);
  });

  it("login sets the session on success", async () => {
    const auth = useAuthStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: { user: { id: 1, email: "a@example.com" }, access_token: "tok" } }),
    );

    await auth.login("a@example.com", "supersecret123", true);

    expect(auth.isAuthenticated).toBe(true);
    expect(auth.user?.email).toBe("a@example.com");
    expect(auth.accessToken).toBe("tok");
  });

  it("login throws an ApiError with the backend's message on failure", async () => {
    const auth = useAuthStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(401, { errors: { detail: "invalid email or password", code: "invalid_credentials" } }),
    );

    await expect(auth.login("a@example.com", "wrong", true)).rejects.toMatchObject({
      message: "invalid email or password",
      code: "invalid_credentials",
    });
    expect(auth.isAuthenticated).toBe(false);
  });

  it("register surfaces field-level validation errors", async () => {
    const auth = useAuthStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(422, { errors: { email: ["has already been taken"] } }),
    );

    const error = await auth.register("a@example.com", "supersecret123", "supersecret123").catch((e) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).fieldErrors.email).toEqual(["has already been taken"]);
  });

  it("logout clears the session even if the request fails", async () => {
    const auth = useAuthStore();
    auth.setSession({ id: 1, email: "a@example.com" }, "tok");
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("network down"));

    await expect(auth.logout()).rejects.toThrow("network down");
    expect(auth.isAuthenticated).toBe(false);
  });

  it("initialize resumes a session when the refresh cookie is valid", async () => {
    const auth = useAuthStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(200, { data: { user: { id: 1, email: "a@example.com" }, access_token: "tok" } }),
    );

    await auth.initialize();

    expect(auth.ready).toBe(true);
    expect(auth.isAuthenticated).toBe(true);
  });

  it("initialize ends up unauthenticated when there's no valid session", async () => {
    const auth = useAuthStore();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse(401, { errors: { detail: "invalid or expired session", code: "invalid_session" } }),
    );

    await auth.initialize();

    expect(auth.ready).toBe(true);
    expect(auth.isAuthenticated).toBe(false);
  });
});
