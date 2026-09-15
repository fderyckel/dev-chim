# ADR 0014: Primary API and generated TypeScript client

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform and web engineering
- Deciders: Architecture review group
- Supersedes: None

## Context

Web, integrations, and tools need a typed interface that preserves named actions, actor/tenant policy, errors, pagination, idempotency, and compatibility.

## Decision drivers

- One authoritative action contract.
- Generated TypeScript types and client behaviour.
- Predictable evolution without a second policy engine.

## Considered options

1. Ash-generated JSON:API evaluated first.
2. Purpose-built REST/OpenAPI adapters over the same actions.
3. GraphQL as the primary interface.

## Decision

Propose testing Ash JSON:API first because it can derive from the candidate domain model. Accept it only if named actions, policy, errors, pagination, versioning, idempotency, and client generation meet the scorecard. Use a thin REST/OpenAPI adapter if it does not. Defer GraphQL until a concrete use case cannot be served safely and efficiently otherwise.

## Consequences

### Positive

- Generated contracts reduce duplicated schema logic.
- The interface cannot become an independent authorization layer.

### Negative

- Generated semantics may require careful compatibility rules or adapters.
- A client-generation pipeline must be owned and tested.

## Security, privacy, operability, and migration effects

Every request establishes actor, tenant, scope, assurance, purpose, and correlation context. Trusted placement is resolved from that authenticated tenant, never from a request-selected repository. Release availability, entitlement, module activation, and actor authorization are enforced server-side. Fields and query results remain policy-filtered. Errors must not reveal cross-tenant existence or placement.

## Validation evidence

The [generated JSON:API policy slice](../phase-0/evidence/ash-pressure-test.md#generated-jsonapi-policy-slice) proves explicit `/api/v1` list and named-transition routes without a generic update route, actor/capability and tenant policy preservation, stable core public errors, required optimistic request versions, tenant-safe keyset pagination, and a checked-in OpenAPI document with drift detection. The tested adapter did not enforce or document the resource's maximum page size, so a thin public gate and supported OpenAPI modifier are required.

The [idempotency and generated-client slice](../phase-0/evidence/ash-pressure-test.md#idempotency-and-generated-typescript-client-slice) proves a caller-supplied UUID key, tenant-and-action uniqueness, actor/aggregate/request binding, exact replay of the committed result, stable conflict on changed reuse, tenant isolation, two-connection serialization, and claim/state/outbox rollback as one transaction. Its isolated TypeScript harness generates immutable declarations from the checked-in OpenAPI artifact, rejects missing keys and unversioned routes at compile time, and tests the exact request envelope without automatic write retries or caller-selected tenant placement. The harness pins TypeScript 5.9 because `openapi-typescript` 7.13 declares a TypeScript 5.x peer range; production web tooling remains a Phase 1 decision.

The [stable public error taxonomy slice](../phase-0/evidence/ash-pressure-test.md#stable-public-error-taxonomy-slice) adds explicit `429`, `503`, and `500` contracts. Synthetic transient failures receive bounded `Retry-After` guidance, every server failure is non-cacheable, private reasons are removed from the response, and the client surfaces each response without an implicit write retry. The failure selector exists only in trusted server context and cannot be supplied in the JSON:API document.

Accountable acceptance of the bounded page-limit, error/header, idempotency, and client adapters still prevents this ADR from leaving Proposed.

## Fallback and exit cost

Use thin REST/OpenAPI adapters over explicit domain actions. Preserve action semantics and stable errors while replacing transport generation.

## Review triggers

- The generated interface cannot represent a required action safely.
- A consumer requires an incompatible versioning or query model.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
