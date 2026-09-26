# Core foundation boundary

- Status: Slices 1A through 1J-B and ADR 0018 T1-A/T1-B/T1-C bounded increments implemented under completed Phase 0 decisions; wider operational readiness remains open
- Owner: Platform engineering
- Governing records: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md), and [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- Review trigger: identity or placement integration, another authority mutation, public write invocation, or a retained Ash production gate

## Purpose

The production core begins with the narrow trust boundary that every later interface and module needs. It establishes a validated execution context from two distinct platform-owned inputs:

1. authenticated actor and tenant identity with an explicit assurance value; and
2. current tenant placement with a positive routing version and an opaque placement reference.

Request metadata adds a correlation identifier, purpose, and locale only after the two trusted inputs agree on the tenant. The boundary accepts neither a raw request map nor caller-selected database, repository, cell, queue, storage, cache, or projection coordinates.

## Ash boundary

`Chimwemwe.Platform` is the production Ash domain. It always runs authorization and requires an actor. Slice 1F replaces its deliberate empty baseline with six persistent authority resources: tenant membership, role, capability, actor-role assignment, role-capability grant, and role inclusion. Slice 1G-A adds closed authority-audit, outbox, and idempotency resources. ADR 0018 T1-A adds four temporal-qualification resources and T1-C adds the closed operation identity plus consumer-basis chain. Slice 1H-A adds closed module-entitlement and module-activation resources, Slice 1H-B adds closed modeled module-work state, Slice 1I-A adds the closed governed extension-definition aggregate, Slice 1J-A adds closed outbox-delivery state, and Slice 1J-B adds the closed durable consumer receipt. Every registered resource is tenant-owned and policy-protected. Temporal, module-lifecycle, and extension-publication actions are private and capability-protected behind their trusted resource-specific boundaries; delivery and receipt have no Ash actions and are reachable only through internal capability boundaries.

`Chimwemwe.Platform.Resource` is the code-owned base for future platform resources. It requires an explicit `:tenant_owned` or `:global_reference` ownership declaration and owns the Ash policy-authorizer configuration. `Chimwemwe.Platform.ResourceContract` audits every registered resource and the domain itself in the required test suite. A tenant-owned resource must use private, non-null `tenant_id` attribute multitenancy with no global fallback; a global-reference resource cannot silently carry tenant state; and create, update, and destroy actions cannot use their generic type name.

This structural audit does not prove a policy is correct, that a relationship has compound tenant constraints, or that a migration is safe. Those remain resource-specific review and negative-test obligations. The in-memory resources that test the guard compile only in the test environment and are not registered in the production domain.

`Chimwemwe.Platform.ResourceDescriptor` is the single outward model-derivation seam added in slice 1B. It accepts only resources that pass the structural audit and projects an explicit code allowlist into stable Chimwemwe references, portable public types and constraints, data classifications, named actions, and ownership-derived tenant scope. Its canonical encoding and content revision are deterministic. Ash module names, source names, policies, tenant keys, and executable behavior are deliberately absent, so the descriptor remains a bounded tool contract rather than a second model or an Ash-internal API.

The descriptor builder has no checked production artifact yet. Slice 1I-A uses it only inside a
trusted immutable registry to derive and pin one typed presentation-definition contract from an
explicit allowlist. It does not render or execute metadata and creates no reporting dataset
authority.

`Chimwemwe.Platform.GovernedExtension` is the only definition-publication entry point. It accepts
a code-owned release manifest and registry, validates exact schema and descriptor compatibility,
then rechecks module release, entitlement, activation, dependency, and actor-capability gates on
the authoritative writer. The retained tenant-owned definition can arrange only allowlisted
fields, labels, title, and one public read action. Its classification is derived from referenced
fields; stored content cannot grant authority. Publication uses exact optimistic versioning and
idempotent replay and commits minimized audit and outbox evidence atomically. No renderer or real
module/interface consumer exists.

Slice 1I-B adds exact internal definition resolution to that same boundary. It requires a separate
read capability before tenant-qualified lookup and rechecks all module gates under the lifecycle
lock. The resolver accepts one definition UUID, re-derives its schema/resource/descriptor contract,
revalidates normalized content and classification, and permits only the exact current module
version or an explicitly compatible predecessor. Its immutable view excludes platform and evidence
identifiers. It cannot enumerate definitions, invoke the referenced action, fetch domain records,
or render metadata.

Slice 1C adds a read-only invocation boundary. It revalidates `ExecutionContext` before model lookup, admits only resources in an actor-required and always-authorized domain, derives actor and tenant from that context, rejects platform-owned keys in action input, and invokes only public named Ash reads. Tenant-owned reads receive the authenticated tenant; global-reference reads intentionally receive no Ash tenant while retaining the real actor and policy evaluation. The caller cannot supply `authorize?`, domain, scope, repository, placement, or alternate actor/tenant options.

Generic and public write invocation remain deferred. The first resource-specific state-changing path now proves the required named action, policy, tenant constraints, concurrency, idempotency, transactional outbox, recovery, and negative-test contract without creating a reusable caller-selected writer.

## Pre-checkout admission boundary

Slice 1D adds a node-local concurrency boundary before any callback that may reach a database pool. It revalidates `ExecutionContext`, derives tenant and placement capacity keys from the trusted actor and placement, and atomically enforces explicit per-tenant and per-placement limits. Tenant saturation is a rate-limited result; placement saturation is a retryable-dependency result. Neither result contains tenant or placement identifiers, and retry guidance exists only when configured with a bounded interval.

Admission protects scarce database connections; it does not grant authority. An admitted callback must still enter an authorized named action with the same execution context. The boundary is deliberately not supervised or connected to Ecto in this slice because production placement resolution, pool ownership, settings, failover, and multi-node calibration remain unresolved. It is not a distributed quota, and stronger physical placement remains the fallback if selected-deployment evidence misses its target.

## Trusted persistence boundary

Slice 1E turns the earlier admission and routing contracts into one bounded PostgreSQL entry path. `Chimwemwe.Platform.PersistenceRuntime` supervises only explicitly configured `Chimwemwe.Repo` pools, an immutable `PlacementRegistry`, and `DatabaseAdmission`. `Persistence.with_writer/3` validates context before resolving the current route, derives the repository from startup-owned route state, acquires tenant and placement capacity, then installs that repository only for the synchronous callback. It restores the caller's prior dynamic repository on every exit path.

The runtime accepts route and pool configuration only at startup. The operation API has no repository, database, tenant, placement, routing, or raw Ecto option. Unknown tenants and stale or forged placement details return the same non-disclosing route failure. Missing runtime components fail closed as a retryable dependency. A spawned process inherits neither the dynamic repository nor permission to use it; asynchronous work must establish and validate its own context.

The repository module and migration baseline are production code. Slice 1F adds the authority graph tables, Slice 1G-A adds the three closed write-evidence tables, ADR 0018 T1-A adds the synthetic temporal-qualification tables, Slice 1H-A adds tenant-qualified entitlement and activation tables, Slice 1H-B expands the activation aggregate plus closed tenant-qualified modeled work, Slice 1I-A adds tenant-qualified governed extension definitions, and Slice 1J-A adds tenant-qualified delivery leases with retained-state rollback refusal. Slice 1J-B adds tenant-qualified consumer receipts, handler/event contract pins, replay-cycle state, and retained-evidence rollback refusal. T1-B changes no table. T1-C adds fact-operation and consumer-basis tables, same-scope operation guards, a tenant-qualified consumer chain, and retained-state rollback refusal. Slice 1I-A reuses the closed safe-write evidence tables and refuses schema rollback once definition or publication evidence is retained. No runtime is installed under `Chimwemwe.Application` until a later deployment slice provides trusted route data, credentials, and measured explicit limits. The placement registry remains an immutable integration seam rather than the durable movement control plane required before production movement.

## Tenant-authority boundary

Slice 1F implements the authorization graph already selected by ADR 0003. Membership binds an authenticated actor UUID to one tenant. Roles, capabilities, assignments, grants, and inclusions are ordinary tenant-owned data; school job-title constants do not exist in code. Role identity is its UUID, so renaming a role does not change its authority.

Every authority edge has a non-null tenant key and a compound foreign key to the referenced `(id, tenant_id)` pair. PostgreSQL therefore rejects cross-tenant membership assignment, capability grant, and role composition through Ash, Ecto, SQL, or another future adapter. A tenant-scoped recursive trigger and transaction advisory lock reject direct, indirect, and racing graph cycles at the database boundary.

`Chimwemwe.Platform.Authority.authorize/3` revalidates execution context and enters `Persistence.with_writer/3` before reading current authority state. Its recursive query starts only from the current actor's membership, follows tenant-qualified assignments and inclusions, and matches one exact capability key. Callers cannot provide role identifiers, grants, graph fragments, repositories, or tenant selectors. Missing membership and missing capability return the same forbidden result.

`Chimwemwe.Platform.Policy.HasCapability` is the Ash policy adapter over that resolver. It fails closed outside the selected writer process. `Role.rename_role` requires the code-owned `platform.authority.roles.rename` capability, and `ActorRoleAssignment.assign_role` requires `platform.authority.assignments.create`. Their corresponding `Authority` functions are the only supported invocation boundaries. They derive actor, tenant, writer, routing, correlation, and Ash options from validated context, lock tenant authority writes, and recheck capability on the writer.

The rename transaction updates one tenant-qualified role version. The assignment transaction locks one existing membership and role, creates one tenant-qualified assignment at version 1, and changes effective authority immediately on the writer. Each transaction commits one immutable audit fact, one minimal outbox fact, and one completed idempotency result. Exact retries return the stored result, while changed input or actor receives a stable conflict. The audit, outbox, and idempotency resources expose no actions. Membership/role creation, grants, composition, revoke, external consumer execution, retention, and replay ranges/cursors remain deferred.

The production dependencies are pinned to the exact Ash, AshPostgres, and PicoSAT releases exercised by the Phase 0 pressure-test. ADR 0002 conditionally accepts Ash and ADR 0019 accepts the code-defined authority boundary; their production gates remain binding. The disposable `AshFoundationLab` remains evidence and is not imported, copied, or exposed as a production API.

## Neutral temporal qualification boundary

`Chimwemwe.Platform.TemporalQualification` is the only supported T1-B/T1-C entry point. It validates
trusted context before input, derives tenant and writer placement, and exposes separate private
publication and exact-target correction actions. The actions use distinct capability keys, lock
the tenant-and-aggregate write scope, re-authorize from current writer state, and atomically
create the immutable revision and segments, advance the current selector, write minimized audit
and outbox evidence, and complete an exact replay result.

T1-C adds separate private record and reverse-and-replace fact actions plus exact operation and
bounded scope-history reads. One neutral consumer-basis chain remains pinned after source
correction until a separately authorized reconcile action appends a successor against the exact
current source revision. The event identifier is causation evidence only and grants no authority.
Fact and consumer transactions retain the same atomic state/audit/outbox/idempotency contract.

Named reads stay on the writer. Current/effective authority does not grant exact/history access,
and unsupported recorded-time reads return a typed failure only after history authorization. The
boundary is qualification-only: it is not a public invocation framework, temporal library, school
schema, retention implementation, or production sizing result.

## Module lifecycle boundary

Slice 1H-A keeps code-owned release availability, tenant entitlement, tenant activation, active
dependencies, and actor authorization as separate decisions. `ModuleLifecycle.activate/4`
validates trusted context and an immutable release manifest, requires the tenant-defined
`platform.modules.activate` capability on the writer, and creates only the initial active version
through a private action. Entitlement rows remain closed facts with no mutation API.

The transaction serializes by tenant and module, binds exact replay to tenant, action, actor,
module declaration, expected version, and causation, then commits activation, audit, outbox, and
idempotency evidence together. `ModuleLifecycle.authorize/5` evaluates all gates again for an
ordinary code-owned capability. It accepts no caller-selected gate, role, tenant, repository, or
Ash options.

Slice 1H-B adds private deactivation, mandatory-work, and compatible-reactivation actions.
Deactivation and the internal mutation-side gate share one tenant-and-module transaction lock.
Deactivation rejects active dependents, closes ordinary authority, parks modeled ordinary work,
records the consumer replay cursor, and marks projections stale without deleting retained state.
Mandatory audit, outbox, retention, legal-hold, and reconciliation work stays available through a
separate capability. Reactivation requires explicit release compatibility and active dependencies,
requeues parked work, records reconciliation, advances projection generation, and reopens ordinary
authority only in the same transaction as audit, outbox, and exact idempotency evidence.

## Internal outbox delivery boundary

Slice 1J-A adds a code-owned `ConsumerRegistry` whose exact event/schema subscription, batch
size, lease duration, attempt limit, and retry delay cannot be supplied by request or event data.
`Outbox.claim/4`, `acknowledge/6`, and `fail/7` revalidate context, select the authoritative writer,
and require `platform.outbox.dispatch`; `Outbox.status/4` separately requires
`platform.outbox.observe`.

Claims are tenant-qualified, current-route, internal-classification, bounded, deterministically
ordered, and protected by PostgreSQL row locks and skip-locked competition. The closed delivery
resource has a compound tenant-qualified event reference. Acknowledgement and failure accept only
the exact active token according to database time, while exact same-outcome replay is idempotent.
Retry and dead-letter transitions derive from the code declaration. Operational status contains
counts and the oldest pending timestamp only; it carries no event, tenant, actor, payload, audit,
lease, repository, or placement identifier.

This boundary performs no consumer work and has no scheduler, worker, external publisher, replay
administrator, HTTP route, application-supervisor wiring, or production placement default. It is
the first 1J increment, not deployment, recovery, movement, capacity, or independent-review
qualification.

Slice 1J-B adds a code-owned `Consumer` behaviour, a closed receipt tied by compound constraints to
the exact tenant event and delivery, and `Outbox.consume/5`. Consumption rereads the authoritative
event under the exact active delivery lease and current route, runs the handler only inside the
writer transaction, and commits its database effect with the receipt. Redelivery after receipt
commit skips handler execution, while a handler revision or event-contract mismatch fails closed.

An explicitly configured caller may supervise `Outbox.Dispatcher`; no instance is in the
application tree and it has no route, repository, or capacity default. Exact dead-letter replay is
separate from dispatch authority. It is serialized, version-checked, capability-protected, audited,
and exactly idempotent, and it cannot edit payload, choose a handler, or select tenant or placement.
External effects, replay ranges/cursors, module drain integration, retention, deployment, recovery,
and independent review remain open.

## Fail-closed contract

Core work can run through the context guard only after all identifiers and metadata validate and the authenticated tenant matches the routed tenant. Missing context, raw maps, malformed identifiers, non-positive routing versions, unsupported placement profiles, blank purpose, and tenant mismatch return typed, non-disclosing errors before the supplied operation executes.

The core validates context shape and source separation, resolves an immutable startup-owned route to a scoped Ecto repository, and authorizes code-known capability requirements from current tenant-owned data. It can rename one role, assign one existing membership to one existing role, qualify neutral revision publication/correction, append a neutral reversal/replacement operation, deliberately reconcile one neutral consumer, activate, drain, perform mandatory work for, and compatibly reactivate one entitled released module, publish one typed compatible presentation definition, resolve one exact compatible definition, lease and database-locally consume internal outbox events, and exactly replay one dead letter through bounded private boundaries while storing write audit/outbox/idempotency facts. It can also serve capability-separated neutral temporal reads and independently gate ordinary module use. It does not authenticate a user, provide a durable placement registry, expose a public interface, enumerate definitions, render or execute the stored action reference, execute an external event consumer, provide a general authority-administration or entitlement-management surface, or authorize a school domain.

## Explicit non-goals

- no school business resource or fixed role name;
- no membership/role creation, capability grant, role inclusion, revoke, generic CRUD, public write invocation, or production data;
- no checked public descriptor artifact, module/interface renderer, stored-action executor, domain-record metadata consumer, custom-field store, or alternate schema source;
- no Phoenix endpoint or public API;
- no entitlement-management or offboarding API, retained-data read/export/correction/deletion action, real queue/consumer/projection adapter, or school business module;
- no temporal retention, hold, erasure, import, backup/restore, or migration action and no reusable temporal persistence library;
- no Oban/background worker, external or filesystem consumer, external publisher, replay range or cursor controller, or production dispatcher child;
- no external service, web workspace, or production infrastructure; and
- no claim that Phase 0 completion authorizes any capability outside the explicitly approved slice.

See the [Phase 1 core-foundation plan](../plans/phase-1-core-foundation-plan.md), [slice 1C invocation evidence](../phase-1/evidence/action-invocation.md), [slice 1D admission evidence](../phase-1/evidence/database-admission.md), [slice 1E persistence evidence](../phase-1/evidence/trusted-persistence.md), [slice 1F authority evidence](../phase-1/evidence/tenant-authority.md), [Slice 1G-A role-rename evidence](../phase-1/evidence/authority-role-rename.md), [Slice 1G-B role-assignment evidence](../phase-1/evidence/authority-role-assignment.md), [ADR 0018 T1-A evidence](../phase-1/evidence/temporal-qualification-physical-model.md), [ADR 0018 T1-B evidence](../phase-1/evidence/temporal-qualification-revision-boundary.md), [ADR 0018 T1-C evidence](../phase-1/evidence/temporal-qualification-fact-and-reconciliation.md), [Slice 1H-A module-lifecycle evidence](../phase-1/evidence/module-lifecycle-initial-activation.md), [Slice 1H-B drain/reactivation evidence](../phase-1/evidence/module-lifecycle-drain-reactivation.md), [Slice 1I-A governed-extension evidence](../phase-1/evidence/governed-extension-definitions.md), [Slice 1I-B resolution evidence](../phase-1/evidence/governed-extension-resolution.md), [Slice 1J-A outbox evidence](../phase-1/evidence/outbox-delivery-lease.md), [Slice 1J-B consumption and replay evidence](../phase-1/evidence/outbox-supervised-consumption-and-replay.md), [domain-model authoring boundary](domain-model-authoring-and-metadata.md), [trusted-routing evidence](../phase-0/evidence/trusted-routing.md), and [threat model](../security/threat-model.md).
