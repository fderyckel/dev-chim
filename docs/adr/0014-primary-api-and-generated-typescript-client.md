# ADR 0014: Primary API and generated TypeScript client

- Status: Conditionally Accepted
- Date: 2026-09-13
- Decision date: 2026-09-16
- Accountable owner: Platform and web engineering
- Deciders: Architecture review group
- Supersedes: None

## Context

Browser, native-mobile, integration, and tool clients need a typed interface that preserves named actions, actor/tenant policy, errors, pagination, idempotency, and compatibility. The public action contract must support excellent device-specific experiences without turning a generated transport or a TypeScript client into an independent policy engine.

## Decision drivers

- One authoritative action contract.
- Generated TypeScript types and client behaviour.
- Predictable evolution without a second policy engine.
- A client boundary that serves tailored browser and phone experiences without leaking Ash internals.

## Considered options

1. Ash-generated JSON:API evaluated first.
2. Purpose-built REST/OpenAPI adapters over the same actions.
3. GraphQL as the primary interface.

## Decision

Conditionally adopt Ash JSON:API with a checked OpenAPI contract and generated TypeScript client because named actions, policy, errors, pagination, versioning, idempotency, and client generation meet the Phase 0 scorecard. Retain the bounded page-limit, failure-header, and OpenAPI modifiers as explicit owned edge adapters. Use a thin REST/OpenAPI adapter if a generated boundary cannot preserve the contract. Defer GraphQL until a concrete use case cannot be served safely and efficiently otherwise.

ADR 0020 owns the proposed client-experience direction. Its browser and native clients consume the same versioned public contract, but their layouts, navigation, components, and device interactions remain product decisions. Generated declarations and request helpers may remove duplicated wire-format knowledge; they do not generate a generic school interface or make authorization decisions.

## Plain-English summary

### What this means

The product will expose a carefully defined, versioned way for approved browser, mobile, and
integration clients to ask for information or start approved actions. The same core rules decide
what is allowed everywhere; a screen or generated client helper cannot make its own permission
decisions.

### What was agreed

- Ash JSON:API is conditionally the first public-interface approach, supported by a checked
  machine-readable contract and generated TypeScript client helpers.
- The public interface must preserve named actions, permissions, tenant separation, stable errors,
  safe pagination, compatibility, and duplicate-request protection.
- Small owned adapters are required where the generated interface needs additional protections,
  including the agreed page-limit and failure-response rules.
- A thin REST/OpenAPI interface is the fallback if the generated boundary cannot preserve those
  protections.
- GraphQL is not selected; it remains deferred until a real use case proves the existing approach
  cannot serve it safely and efficiently.

### Context

Browser, phone, integration, and tool clients need a dependable common language with the product.
Without one, each client could interpret data, errors, and permissions differently. At the same
time, a common technical contract must not force all devices into the same user experience or let
a client bypass the product's central security rules.

### Examples

- A future browser screen and phone screen could present an approved action differently for their
  users while relying on the same server-side permission and error rules.
- If a connection drops after an approved request is sent, the client can use the agreed
  duplicate-request protection to find out whether the original action completed, rather than
  creating a second change.
- An integration cannot select another school's database or decide that a staff member is allowed
  to act; the server establishes that trusted context and applies the rules.

## Consequences

### Positive

- Generated contracts reduce duplicated schema logic.
- The interface cannot become an independent authorization layer.
- Browser and native clients can share action, error, and compatibility semantics without being forced into the same user interface.

### Negative

- Generated semantics may require careful compatibility rules or adapters.
- A client-generation pipeline must be owned and tested.
- Supporting multiple client surfaces requires explicit version, accessibility, degraded-network, and release ownership.

## Security, privacy, operability, and migration effects

Every request establishes actor, tenant, scope, assurance, purpose, and correlation context. Trusted placement is resolved from that authenticated tenant, never from a request-selected repository. Release availability, entitlement, module activation, and actor authorization are enforced server-side. Fields and query results remain policy-filtered. Errors must not reveal cross-tenant existence or placement.

## Validation evidence

The [generated JSON:API policy slice](../phase-0/handover-evidence.md) proves explicit `/api/v1` list and named-transition routes without a generic update route, actor/capability and tenant policy preservation, stable core public errors, required optimistic request versions, tenant-safe keyset pagination, and a checked-in OpenAPI document with drift detection. The tested adapter did not enforce or document the resource's maximum page size, so a thin public gate and supported OpenAPI modifier are required.

The [idempotency and generated-client slice](../phase-0/handover-evidence.md) proves a caller-supplied UUID key, tenant-and-action uniqueness, actor/aggregate/request binding, exact replay of the committed result, stable conflict on changed reuse, tenant isolation, two-connection serialization, and claim/state/outbox rollback as one transaction. Its isolated TypeScript harness generates immutable declarations from the checked-in OpenAPI artifact, rejects missing keys and unversioned routes at compile time, and tests the exact request envelope without automatic write retries or caller-selected tenant placement. The harness pins TypeScript 5.9 because `openapi-typescript` 7.13 declares a TypeScript 5.x peer range; production web tooling remains a Phase 1 decision.

The [stable public error taxonomy slice](../phase-0/handover-evidence.md) adds explicit `429`, `503`, and `500` contracts. Synthetic transient failures receive bounded `Retry-After` guidance, every server failure is non-cacheable, private reasons are removed from the response, and the client surfaces each response without an implicit write retry. The failure selector exists only in trusted server context and cannot be supplied in the JSON:API document.

The accountable review accepts the bounded page-limit, error/header, idempotency, and client adapters as production conditions. A failed adapter gate blocks the affected public route and triggers the thin explicit-interface fallback.

## Fallback and exit cost

Use thin REST/OpenAPI adapters over explicit domain actions. Preserve action semantics and stable errors while replacing transport generation.

## Review triggers

- The generated interface cannot represent a required action safely.
- A consumer requires an incompatible versioning or query model.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
