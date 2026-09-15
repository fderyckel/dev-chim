import { describe, expect, it, vi } from "vitest";

import { createFoundationClient, type SubmitForReviewInput } from "../src/client.ts";

const input: SubmitForReviewInput = {
  causationId: "00000000-0000-0000-0000-000000000003",
  correlationId: "00000000-0000-0000-0000-000000000002",
  expectedVersion: 7,
  id: "00000000-0000-0000-0000-000000000001",
  idempotencyKey: "00000000-0000-0000-0000-000000000004",
};

const successDocument = {
  data: {
    attributes: {
      audit_reference: "00000000-0000-0000-0000-000000000005",
      lock_version: 8,
      name: "Synthetic record",
      status: "in_review",
    },
    id: input.id,
    type: "foundation-record",
  },
};

function successfulResponse() {
  return new Response(JSON.stringify(successDocument), {
    headers: { "content-type": "application/vnd.api+json" },
    status: 200,
  });
}

function requireRequest(input: RequestInfo | URL | undefined): Request {
  if (!(input instanceof Request)) {
    throw new Error("expected openapi-fetch to pass a Request instance");
  }

  return input;
}

describe("generated Phase 0 client boundary", () => {
  it("calls only the versioned named action with the required concurrency envelope", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => successfulResponse());
    const client = createFoundationClient({ baseUrl: "https://phase0.invalid", fetch });

    const result = await client.submitForReview(input);

    expect(result.data).toEqual(successDocument);
    expect(fetch).toHaveBeenCalledTimes(1);

    const request = requireRequest(fetch.mock.calls[0]?.[0]);
    expect(request.method).toBe("PATCH");
    expect(new URL(request.url).pathname).toBe(
      `/api/v1/foundation-records/${input.id}/submit-for-review`,
    );

    const document = await request.clone().json();
    expect(document).toEqual({
      data: {
        attributes: {
          causation_id: input.causationId,
          correlation_id: input.correlationId,
          expected_version: input.expectedVersion,
          idempotency_key: input.idempotencyKey,
        },
        id: input.id,
        type: "foundation-record",
      },
    });
    expect(JSON.stringify(document)).not.toContain("tenant");
  });

  it("reuses an explicit key only when the caller repeats the operation", async () => {
    const bodies: unknown[] = [];
    const fetch = vi.fn<typeof globalThis.fetch>(async (request) => {
      request = requireRequest(request);
      bodies.push(await request.clone().json());
      return successfulResponse();
    });
    const client = createFoundationClient({ baseUrl: "https://phase0.invalid", fetch });

    await client.submitForReview(input);
    await client.submitForReview(input);

    expect(fetch).toHaveBeenCalledTimes(2);
    expect(bodies[0]).toEqual(bodies[1]);
  });

  it("does not hide transport failures behind an automatic write retry", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => {
      throw new TypeError("synthetic network failure");
    });
    const client = createFoundationClient({ baseUrl: "https://phase0.invalid", fetch });

    await expect(client.submitForReview(input)).rejects.toThrow("synthetic network failure");
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it.each([
    {
      code: "rate_limited",
      detail: "Request capacity is temporarily unavailable.",
      retryAfter: "5",
      status: 429,
      title: "RateLimited",
    },
    {
      code: "dependency_unavailable",
      detail: "A required dependency is temporarily unavailable.",
      retryAfter: "2",
      status: 503,
      title: "DependencyUnavailable",
    },
    {
      code: "internal_error",
      detail: "An internal error occurred.",
      retryAfter: undefined,
      status: 500,
      title: "InternalError",
    },
  ])("surfaces the $status error without an automatic write retry", async (failure) => {
    const retrySeconds = failure.retryAfter ? Number.parseInt(failure.retryAfter, 10) : undefined;
    const errorDocument = {
      errors: [
        {
          code: failure.code,
          detail: failure.detail,
          id: "00000000-0000-0000-0000-000000000006",
          meta: retrySeconds
            ? { api_version: "v1", retry_after_seconds: retrySeconds, retryable: true }
            : { api_version: "v1" },
          status: failure.status.toString(),
          title: failure.title,
        },
      ],
    };
    const headers: Record<string, string> = {
      "cache-control": "no-store",
      "content-type": "application/vnd.api+json",
    };

    if (failure.retryAfter) {
      headers["retry-after"] = failure.retryAfter;
    }

    const fetch = vi.fn<typeof globalThis.fetch>(async () =>
      new Response(JSON.stringify(errorDocument), {
        headers,
        status: failure.status,
      }),
    );
    const client = createFoundationClient({ baseUrl: "https://phase0.invalid", fetch });

    const result = await client.submitForReview(input);

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(result.error).toEqual(errorDocument);
    expect(result.response.status).toBe(failure.status);
    expect(result.response.headers.get("cache-control")).toBe("no-store");
    expect(result.response.headers.get("retry-after") ?? undefined).toBe(failure.retryAfter);
  });
});
