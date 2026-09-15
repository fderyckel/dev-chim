# Core foundation boundary

- Status: Provisional during the early Phase 1 slice
- Owner: Platform engineering
- Governing records: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md), and [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md)
- Review trigger: Phase 0 architecture outcome, identity or placement integration, or the first persistent resource

## Purpose

The production core begins with the narrow trust boundary that every later interface and module needs. It establishes a validated execution context from two distinct platform-owned inputs:

1. authenticated actor and tenant identity with an explicit assurance value; and
2. current tenant placement with a positive routing version and an opaque placement reference.

Request metadata adds a correlation identifier, purpose, and locale only after the two trusted inputs agree on the tenant. The boundary accepts neither a raw request map nor caller-selected database, repository, cell, queue, storage, cache, or projection coordinates.

## Ash boundary

`Chimwemwe.Platform` is the production Ash domain. It has `authorization { authorize :always }` and no resources in slice 1A. The empty list is deliberate: each later resource must arrive with a named capability, owner, tenant contract, policies, persistence constraints, module lifecycle, and negative tests.

The production dependency is pinned to the exact Ash release exercised by the Phase 0 pressure-test. This is a reversible working assumption, not an acceptance of ADR 0002. The disposable `AshFoundationLab` remains evidence and is not imported, copied, or exposed as a production API.

## Fail-closed contract

Core work can run through the context guard only after all identifiers and metadata validate and the authenticated tenant matches the routed tenant. Missing context, raw maps, malformed identifiers, invalid or stale routing versions, unsupported placement profiles, blank purpose, and tenant mismatch return typed, non-disclosing errors before the supplied operation executes.

This first slice validates context shape and source separation. It does not authenticate a user, resolve a live registry, select an Ecto repository, authorize a capability, persist a record, or emit an event. Those require later named slices and their database, threat, and recovery evidence.

## Explicit non-goals

- no school business resource or fixed role name;
- no PostgreSQL repository or migration;
- no Phoenix endpoint or public API;
- no production module, entitlement, or activation registry;
- no Oban worker or outbox dispatcher;
- no external service, web workspace, or production infrastructure; and
- no claim that Phase 0 has exited or its Proposed ADRs are accepted.

See the [Phase 1 core-foundation plan](../plans/phase-1-core-foundation-plan.md), [trusted-routing evidence](../phase-0/evidence/trusted-routing.md), and [threat model](../security/threat-model.md).
