import createClient from "openapi-fetch";

import type { paths } from "../generated/schema.d.ts";

export interface FoundationClientOptions {
  readonly baseUrl: string;
  readonly fetch?: typeof globalThis.fetch;
}

export interface SubmitForReviewInput {
  readonly causationId: string;
  readonly correlationId: string;
  readonly expectedVersion: number;
  readonly id: string;
  readonly idempotencyKey: string;
}

export interface ListFoundationRecordsInput {
  readonly after?: string;
  readonly limit?: 1 | 2 | 3;
}

export function createFoundationClient({ baseUrl, fetch }: FoundationClientOptions) {
  const client = createClient<paths>({ baseUrl, fetch });

  return {
    listFoundationRecords(input: ListFoundationRecordsInput = {}) {
      return client.GET("/api/v1/foundation-records", {
        params: {
          query: {
            page: {
              after: input.after,
              limit: input.limit,
            },
          },
        },
      });
    },

    submitForReview(input: SubmitForReviewInput) {
      return client.PATCH("/api/v1/foundation-records/{id}/submit-for-review", {
        body: {
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
        },
        params: {
          path: { id: input.id },
        },
      });
    },
  };
}
