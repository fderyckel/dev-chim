# Core foundation boundary

- Status: Provisional; slices 1A through 1C verified
- Owner: Platform engineering
- Governing records: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md), and [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- Review trigger: Phase 0 architecture outcome, identity or placement integration, or the first persistent resource

## Purpose

The production core begins with the narrow trust boundary that every later interface and module needs. It establishes a validated execution context from two distinct platform-owned inputs:

1. authenticated actor and tenant identity with an explicit assurance value; and
2. current tenant placement with a positive routing version and an opaque placement reference.

Request metadata adds a correlation identifier, purpose, and locale only after the two trusted inputs agree on the tenant. The boundary accepts neither a raw request map nor caller-selected database, repository, cell, queue, storage, cache, or projection coordinates.

## Ash boundary

`Chimwemwe.Platform` is the production Ash domain. It always runs authorization, requires an actor, and remains resource-empty through slice 1C. The empty list is deliberate: each later resource must arrive with a named capability, owner, tenant contract, policies, persistence constraints, migration choreography, module lifecycle, and negative tests.

`Chimwemwe.Platform.Resource` is the code-owned base for future platform resources. It requires an explicit `:tenant_owned` or `:global_reference` ownership declaration and owns the Ash policy-authorizer configuration. `Chimwemwe.Platform.ResourceContract` audits every registered resource and the domain itself in the required test suite. A tenant-owned resource must use private, non-null `tenant_id` attribute multitenancy with no global fallback; a global-reference resource cannot silently carry tenant state; and create, update, and destroy actions cannot use their generic type name.

This structural audit does not prove a policy is correct, that a relationship has compound tenant constraints, or that a migration is safe. Those remain resource-specific review and negative-test obligations. The in-memory resources that test the guard compile only in the test environment and are not registered in the production domain.

`Chimwemwe.Platform.ResourceDescriptor` is the single outward model-derivation seam added in slice 1B. It accepts only resources that pass the structural audit and projects an explicit code allowlist into stable Chimwemwe references, portable public types and constraints, data classifications, named actions, and ownership-derived tenant scope. Its canonical encoding and content revision are deterministic. Ash module names, source names, policies, tenant keys, and executable behavior are deliberately absent, so the descriptor remains a bounded tool contract rather than a second model or an Ash-internal API.

The descriptor builder has no production resource or checked artifact yet. It does not validate, persist, render, or execute tenant metadata, and it creates no reporting dataset authority. Those are later boundaries with separate authorization, classification, compatibility, and lifecycle obligations.

Slice 1C adds a read-only invocation boundary. It revalidates `ExecutionContext` before model lookup, admits only resources in an actor-required and always-authorized domain, derives actor and tenant from that context, rejects platform-owned keys in action input, and invokes only public named Ash reads. Tenant-owned reads receive the authenticated tenant; global-reference reads intentionally receive no Ash tenant while retaining the real actor and policy evaluation. The caller cannot supply `authorize?`, domain, scope, repository, placement, or alternate actor/tenant options.

Write invocation is intentionally deferred. A state-changing path must arrive with the first persistent resource's named action, policy, tenant constraints, migration, concurrency, idempotency, transactional outbox, recovery, and negative tests.

The production dependencies are pinned to the exact Ash and PicoSAT releases exercised by the Phase 0 pressure-test. This is a reversible working assumption, not an acceptance of ADR 0002 or ADR 0019. The disposable `AshFoundationLab` remains evidence and is not imported, copied, or exposed as a production API.

## Fail-closed contract

Core work can run through the context guard only after all identifiers and metadata validate and the authenticated tenant matches the routed tenant. Missing context, raw maps, malformed identifiers, non-positive routing versions, unsupported placement profiles, blank purpose, and tenant mismatch return typed, non-disclosing errors before the supplied operation executes.

This first slice validates context shape and source separation. It does not authenticate a user, resolve a live registry, select an Ecto repository, authorize a capability, persist a record, or emit an event. Those require later named slices and their database, threat, and recovery evidence.

## Explicit non-goals

- no school business resource or fixed role name;
- no PostgreSQL repository, migration, or write invocation;
- no descriptor consumer or checked production descriptor artifact, experience metadata, custom-field store, or alternate schema source;
- no Phoenix endpoint or public API;
- no production module, entitlement, or activation registry;
- no Oban worker or outbox dispatcher;
- no external service, web workspace, or production infrastructure; and
- no claim that Phase 0 has exited or its Proposed ADRs are accepted.

See the [Phase 1 core-foundation plan](../plans/phase-1-core-foundation-plan.md), [slice 1C invocation evidence](../phase-1/evidence/action-invocation.md), [domain-model authoring boundary](domain-model-authoring-and-metadata.md), [trusted-routing evidence](../phase-0/evidence/trusted-routing.md), and [threat model](../security/threat-model.md).
