import { beforeEach, describe, expect, it, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { apiRequest, ApiError } from "./api";
import { useAuthStore } from "@/stores/auth";

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status });
}

describe("apiRequest", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it("retries once after a 401 by refreshing the access token first", async () => {
    const auth = useAuthStore();
    auth.setSession({ id: 1, email: "a@example.com" }, "stale-token");

    const fetchSpy = vi.spyOn(globalThis, "fetch");
    fetchSpy
      .mockResolvedValueOnce(jsonResponse(401, { errors: { detail: "expired", code: "invalid_token" } }))
      .mockResolvedValueOnce(
        jsonResponse(200, {
          data: { user: { id: 1, email: "a@example.com" }, access_token: "fresh-token" },
        }),
      )
      .mockResolvedValueOnce(jsonResponse(200, { data: { id: 5, name: "Riley" } }));

    const result = await apiRequest("/api/babies/1", { method: "GET" });

    expect(result).toEqual({ id: 5, name: "Riley" });
    expect(auth.accessToken).toBe("fresh-token");
    expect(fetchSpy).toHaveBeenCalledTimes(3);

    const retriedHeaders = fetchSpy.mock.calls[2][1]?.headers as Record<string, string>;
    expect(retriedHeaders.Authorization).toBe("Bearer fresh-token");
  });

  it("does not attempt a refresh for non-401 errors", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(422, { errors: { name: ["can't be blank"] } }));

    await expect(apiRequest("/api/babies", { method: "POST", body: {} })).rejects.toBeInstanceOf(ApiError);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("surfaces the original 401 without looping when the retried request 401s again", async () => {
    const auth = useAuthStore();
    auth.setSession({ id: 1, email: "a@example.com" }, "stale-token");

    const fetchSpy = vi.spyOn(globalThis, "fetch");
    fetchSpy
      .mockResolvedValueOnce(jsonResponse(401, { errors: { detail: "expired", code: "invalid_token" } }))
      .mockResolvedValueOnce(
        jsonResponse(200, {
          data: { user: { id: 1, email: "a@example.com" }, access_token: "fresh-token" },
        }),
      )
      .mockResolvedValueOnce(jsonResponse(401, { errors: { detail: "still invalid", code: "invalid_token" } }));

    await expect(apiRequest("/api/babies/1", { method: "GET" })).rejects.toMatchObject({
      message: "still invalid",
    });
    expect(fetchSpy).toHaveBeenCalledTimes(3);
  });

  it("surfaces the original 401 when the refresh cookie itself is invalid, without a second retry", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    fetchSpy
      .mockResolvedValueOnce(jsonResponse(401, { errors: { detail: "expired", code: "invalid_token" } }))
      .mockResolvedValueOnce(
        jsonResponse(401, { errors: { detail: "invalid or expired session", code: "invalid_session" } }),
      );

    await expect(apiRequest("/api/babies/1", { method: "GET" })).rejects.toMatchObject({
      message: "expired",
    });
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });
});
