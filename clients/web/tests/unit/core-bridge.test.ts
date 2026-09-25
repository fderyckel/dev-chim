import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { getAssignmentOptions } from "../../src/server/core-bridge";

const validToken = "unit-local-token-" + "a".repeat(32);
const endpoint = "http://127.0.0.1:4001";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

function enableBridge() {
  vi.stubEnv("CHIMWEMWE_UI1_LOCAL", "true");
  vi.stubEnv("CHIMWEMWE_UI1_API_URL", endpoint);
  vi.stubEnv("CHIMWEMWE_UI1_BRIDGE_TOKEN", validToken);
}

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "x-request-id": "local-ref" },
  });
}

describe("the server-only UI-1A bridge adapter", () => {
  it("stays disabled without the exact guard and valid loopback configuration", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(getAssignmentOptions()).resolves.toEqual({ state: "disabled" });

    vi.stubEnv("CHIMWEMWE_UI1_LOCAL", "true");
    vi.stubEnv("CHIMWEMWE_UI1_API_URL", "https://example.com");
    vi.stubEnv("CHIMWEMWE_UI1_BRIDGE_TOKEN", validToken);

    await expect(getAssignmentOptions()).resolves.toEqual({ state: "disabled" });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("uses a no-store authorized server request and accepts the checked shape", async () => {
    enableBridge();
    const fetchMock = vi.fn(async (request: Request) => {
      expect(request.url).toBe(`${endpoint}/api/v1/authority/assignment-options`);
      expect(request.headers.get("authorization")).toBe(`Bearer ${validToken}`);
      expect(request.cache).toBe("no-store");

      return jsonResponse(
        {
          data: {
            connection: "local_core",
            contract_version: 1,
            memberships: [{ id: "membership-id", label: "Synthetic membership 01" }],
            roles: [{ id: "role-id", label: "Library review" }],
          },
        },
        200,
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(getAssignmentOptions()).resolves.toEqual({
      state: "ready",
      data: {
        connection: "local_core",
        contract_version: 1,
        memberships: [{ id: "membership-id", label: "Synthetic membership 01" }],
        roles: [{ id: "role-id", label: "Library review" }],
      },
    });
  });

  it.each([
    [401, "denied"],
    [403, "denied"],
    [503, "retryable"],
  ] as const)("maps HTTP %s to the non-disclosing %s state", async (status, state) => {
    enableBridge();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => jsonResponse({ errors: [] }, status)),
    );

    await expect(getAssignmentOptions()).resolves.toEqual({ state });
  });

  it("rejects an unrecognized contract shape", async () => {
    enableBridge();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        jsonResponse(
          {
            data: {
              connection: "local_core",
              contract_version: 2,
              memberships: [],
              roles: [],
            },
          },
          200,
        ),
      ),
    );

    await expect(getAssignmentOptions()).resolves.toEqual({
      state: "unexpected",
      reference: "local-ref",
    });
  });

  it("returns unavailable without leaking transport details", async () => {
    enableBridge();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => Promise.reject(new Error("secret detail"))),
    );

    await expect(getAssignmentOptions()).resolves.toEqual({ state: "unavailable" });
  });
});
