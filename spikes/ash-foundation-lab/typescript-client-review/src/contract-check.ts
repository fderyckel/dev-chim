import createClient from "openapi-fetch";

import type { paths } from "../generated/schema.d.ts";
import { createFoundationClient } from "./client.ts";

const foundationClient = createFoundationClient({ baseUrl: "https://phase0.invalid" });

foundationClient.submitForReview({
  causationId: "00000000-0000-0000-0000-000000000003",
  correlationId: "00000000-0000-0000-0000-000000000002",
  expectedVersion: 1,
  id: "00000000-0000-0000-0000-000000000001",
  idempotencyKey: "00000000-0000-0000-0000-000000000004",
});

// @ts-expect-error The thin client makes the caller-owned idempotency key mandatory.
foundationClient.submitForReview({
  causationId: "00000000-0000-0000-0000-000000000003",
  correlationId: "00000000-0000-0000-0000-000000000002",
  expectedVersion: 1,
  id: "00000000-0000-0000-0000-000000000001",
});

const generatedClient = createClient<paths>({ baseUrl: "https://phase0.invalid" });

// @ts-expect-error The generated contract exposes only the versioned action route.
generatedClient.PATCH("/foundation-records/{id}/submit-for-review", {});

generatedClient.PATCH("/api/v1/foundation-records/{id}/submit-for-review", {
  body: {
    data: {
      // @ts-expect-error The checked-in OpenAPI contract requires idempotency_key.
      attributes: {
        causation_id: "00000000-0000-0000-0000-000000000003",
        correlation_id: "00000000-0000-0000-0000-000000000002",
        expected_version: 1,
      },
      id: "00000000-0000-0000-0000-000000000001",
      type: "foundation-record",
    },
  },
  params: { path: { id: "00000000-0000-0000-0000-000000000001" } },
});
