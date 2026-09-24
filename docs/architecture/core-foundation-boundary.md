# Core foundation boundary

- Status: Slices 1A through 1F and the first Slice 1G safe-write increment implemented and test-verified under completed Phase 0 decisions
- Owner: Platform engineering
- Governing records: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), and [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- Review trigger: identity or placement integration, another authority mutation, public write invocation, or a retained Ash production gate

## Purpose

The production core begins with the narrow trust boundary that every later interface and module needs. It establishes a validated execution context from two distinct platform-owned inputs:

1. authenticated actor and tenant identity with an explicit assurance value; and
2. current tenant placement with a positive routing version and an opaque placement reference.

Request metadata adds a correlation identifier, purpose, and locale only after the two trusted inputs agree on the tenant. The boundary accepts neither a raw request map nor caller-selected database, repository, cell, queue, storage, cache, or projection coordinates.

## Ash boundary

`Chimwemwe.Platform` is the production Ash domain. It always runs authorization and requires an actor. Slice 1F replaces its deliberate empty baseline with six persistent authority resources: tenant membership, role, capability, actor-role assignment, role-capability grant, and role inclusion. The first Slice 1G increment adds closed authority-audit, outbox, and idempotency resources. All nine are tenant-owned and policy-protected. Only `Role.rename_role` has an action; it is private and capability-protected.

`Chimwemwe.Platform.Resource` is the code-owned base for future platform resources. It requires an explicit `:tenant_owned` or `:global_reference` ownership declaration and owns the Ash policy-authorizer configuration. `Chimwemwe.Platform.ResourceContract` audits every registered resource and the domain itself in the required test suite. A tenant-owned resource must use private, non-null `tenant_id` attribute multitenancy with no global fallback; a global-reference resource cannot silently carry tenant state; and create, update, and destroy actions cannot use their generic type name.

This structural audit does not prove a policy is correct, that a relationship has compound tenant constraints, or that a migration is safe. Those remain resource-specific review and negative-test obligations. The in-memory resources that test the guard compile only in the test environment and are not registered in the production domain.

`Chimwemwe.Platform.ResourceDescriptor` is the single outward model-derivation seam added in slice 1B. It accepts only resources that pass the structural audit and projects an explicit code allowlist into stable Chimwemwe references, portable public types and constraints, data classifications, named actions, and ownership-derived tenant scope. Its canonical encoding and content revision are deterministic. Ash module names, source names, policies, tenant keys, and executable behavior are deliberately absent, so the descriptor remains a bounded tool contract rather than a second model or an Ash-internal API.

The descriptor builder has no checked production artifact yet because the authority resources intentionally expose no public actions or fields. It does not validate, persist, render, or execute tenant metadata, and it creates no reporting dataset authority. Those are later boundaries with separate authorization, classification, compatibility, and lifecycle obligations.

Slice 1C adds a read-only invocation boundary. It revalidates `ExecutionContext` before model lookup, admits only resources in an actor-required and always-authorized domain, derives actor and tenant from that context, rejects platform-owned keys in action input, and invokes only public named Ash reads. Tenant-owned reads receive the authenticated tenant; global-reference reads intentionally receive no Ash tenant while retaining the real actor and policy evaluation. The caller cannot supply `authorize?`, domain, scope, repository, placement, or alternate actor/tenant options.

Generic and public write invocation remain deferred. The first resource-specific state-changing path now proves the required named action, policy, tenant constraints, concurrency, idempotency, transactional outbox, recovery, and negative-test contract without creating a reusable caller-selected writer.

## Pre-checkout admission boundary

Slice 1D adds a node-local concurrency boundary before any callback that may reach a database pool. It revalidates `ExecutionContext`, derives tenant and placement capacity keys from the trusted actor and placement, and atomically enforces explicit per-tenant and per-placement limits. Tenant saturation is a rate-limited result; placement saturation is a retryable-dependency result. Neither result contains tenant or placement identifiers, and retry guidance exists only when configured with a bounded interval.

Admission protects scarce database connections; it does not grant authority. An admitted callback must still enter an authorized named action with the same execution context. The boundary is deliberately not supervised or connected to Ecto in this slice because production placement resolution, pool ownership, settings, failover, and multi-node calibration remain unresolved. It is not a distributed quota, and stronger physical placement remains the fallback if selected-deployment evidence misses its target.

## Trusted persistence boundary

Slice 1E turns the earlier admission and routing contracts into one bounded PostgreSQL entry path. `Chimwemwe.Platform.PersistenceRuntime` supervises only explicitly configured `Chimwemwe.Repo` pools, an immutable `PlacementRegistry`, and `DatabaseAdmission`. `Persistence.with_writer/3` validates context before resolving the current route, derives the repository from startup-owned route state, acquires tenant and placement capacity, then installs that repository only for the synchronous callback. It restores the caller's prior dynamic repository on every exit path.

The runtime accepts route and pool configuration only at startup. The operation API has no repository, database, tenant, placement, routing, or raw Ecto option. Unknown tenants and stale or forged placement details return the same non-disclosing route failure. Missing runtime components fail closed as a retryable dependency. A spawned process inherits neither the dynamic repository nor permission to use it; asynchronous work must establish and validate its own context.

The repository module and migration baseline are production code. Slice 1F adds the authority graph tables, and the first Slice 1G increment adds the three closed write-evidence tables. No runtime is installed under `Chimwemwe.Application` until a later deployment slice provides trusted route data, credentials, and measured explicit limits. The registry remains an immutable integration seam rather than the durable placement and movement control plane required before production movement.

## Tenant-authority boundary

Slice 1F implements the authorization graph already selected by ADR 0003. Membership binds an authenticated actor UUID to one tenant. Roles, capabilities, assignments, grants, and inclusions are ordinary tenant-owned data; school job-title constants do not exist in code. Role identity is its UUID, so renaming a role does not change its authority.

Every authority edge has a non-null tenant key and a compound foreign key to the referenced `(id, tenant_id)` pair. PostgreSQL therefore rejects cross-tenant membership assignment, capability grant, and role composition through Ash, Ecto, SQL, or another future adapter. A tenant-scoped recursive trigger and transaction advisory lock reject direct, indirect, and racing graph cycles at the database boundary.

`Chimwemwe.Platform.Authority.authorize/3` revalidates execution context and enters `Persistence.with_writer/3` before reading current authority state. Its recursive query starts only from the current actor's membership, follows tenant-qualified assignments and inclusions, and matches one exact capability key. Callers cannot provide role identifiers, grants, graph fragments, repositories, or tenant selectors. Missing membership and missing capability return the same forbidden result.

`Chimwemwe.Platform.Policy.HasCapability` is the Ash policy adapter over that resolver. It fails closed outside the selected writer process. `Role.rename_role` requires the code-owned `platform.authority.roles.rename` capability, and `Authority.rename_role/3` is the only supported invocation boundary. It derives actor, tenant, writer, routing, correlation, and Ash options from validated context; locks tenant authority writes; rechecks capability on the writer; and requires expected version, idempotency key, and causation input.

The rename transaction updates one tenant-qualified role version and commits one immutable audit fact, one minimal outbox fact, and one completed idempotency result. Exact retries return the stored result, while changed input or actor receives a stable conflict. The audit, outbox, and idempotency resources expose no actions. Assignment, grant, composition, revoke, dispatch, retention, and operational replay remain deferred Slice 1G work.

The production dependencies are pinned to the exact Ash, AshPostgres, and PicoSAT releases exercised by the Phase 0 pressure-test. ADR 0002 conditionally accepts Ash and ADR 0019 accepts the code-defined authority boundary; their production gates remain binding. The disposable `AshFoundationLab` remains evidence and is not imported, copied, or exposed as a production API.

## Fail-closed contract

Core work can run through the context guard only after all identifiers and metadata validate and the authenticated tenant matches the routed tenant. Missing context, raw maps, malformed identifiers, non-positive routing versions, unsupported placement profiles, blank purpose, and tenant mismatch return typed, non-disclosing errors before the supplied operation executes.

The core validates context shape and source separation, resolves an immutable startup-owned route to a scoped Ecto repository, and authorizes code-known capability requirements from current tenant-owned data. It can rename one role through the bounded private action and store its audit/outbox/idempotency facts. It does not authenticate a user, provide a durable placement registry, expose a public interface, dispatch an event, or administer the authority graph.

## Explicit non-goals

- no school business resource or fixed role name;
- no authority assignment, grant, inclusion, revoke, generic CRUD, public write invocation, or production data;
- no descriptor consumer or checked production descriptor artifact, experience metadata, custom-field store, or alternate schema source;
- no Phoenix endpoint or public API;
- no production module, entitlement, or activation registry;
- no Oban worker or outbox dispatcher;
- no external service, web workspace, or production infrastructure; and
- no claim that Phase 0 completion authorizes any capability outside the explicitly approved slice.

See the [Phase 1 core-foundation plan](../plans/phase-1-core-foundation-plan.md), [slice 1C invocation evidence](../phase-1/evidence/action-invocation.md), [slice 1D admission evidence](../phase-1/evidence/database-admission.md), [slice 1E persistence evidence](../phase-1/evidence/trusted-persistence.md), [slice 1F authority evidence](../phase-1/evidence/tenant-authority.md), [Slice 1G role-rename evidence](../phase-1/evidence/authority-role-rename.md), [domain-model authoring boundary](domain-model-authoring-and-metadata.md), [trusted-routing evidence](../phase-0/evidence/trusted-routing.md), and [threat model](../security/threat-model.md).
