# Phase 0 TypeScript client review

This directory is a disposable contract harness for ADR 0014. It is not the Phase 1 web workspace and does not select the production frontend toolchain.

The checked-in OpenAPI document is the only generation input. `openapi-typescript` produces immutable TypeScript declarations, `openapi-fetch` provides the typed transport, and a deliberately thin wrapper exposes the bounded list query and named `submitForReview` action. The wrapper does not accept tenant placement, generate idempotency keys, or automatically retry writes.

## Verify

From this directory:

```sh
mise exec -- npm ci
mise exec -- npm run generate:check
mise exec -- npm run typecheck
mise exec -- npm test
```

`npm run generate` intentionally updates [`generated/schema.d.ts`](generated/schema.d.ts) after an approved OpenAPI change. The repository-wide `make check` only verifies that the generated file is current.

The compile-time contract checks prove that the versioned route and caller-supplied idempotency key are required. Runtime tests prove the request path and body, explicit same-key retry behaviour, omission of tenant input, and the absence of hidden automatic write retries for transport, rate-limit, dependency, and internal failures. Transient retry guidance is surfaced to the caller; the thin client never acts on it automatically.
