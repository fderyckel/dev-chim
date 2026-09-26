# Phase 1: core foundation

- Status: Slices 1A through 1I-B, ADR 0018 T1-A/T1-B/T1-C, and local UI-1A implemented; Slice 1I-B focused, production-core, and complete repository verification passing; local synthetic UI-0 implemented; representative human review and the remaining ADR-specific gates are pending
- Owner: Platform engineering
- Start basis: explicit user direction on 2026-09-14, followed by the completed Phase 0 review on 2026-09-16
- Entry basis: Ash is conditionally accepted; implementation proceeds only in explicitly authorized bounded slices and must satisfy the retained production gates

## Why this can start narrowly

Phase 0 has direct evidence for named actions, tenant and capability denial, tenant-defined role composition, global authorization requirements, optimistic concurrency, transactional rollback and idempotency, generated-interface policy preservation, trusted placement input, module-gate separation, telemetry redaction, migration generation, and patch plus non-patch interface-framework upgrades. Ash 3.33.11 closes the recorded field-policy and bulk-private-argument advisories with focused regressions, and complete verification passes for the current combined candidate.

Phase 0 now has a three-run annual-envelope retained-data migration measurement, an accepted disposition for all eight Ash bounded conditions, architect-approved numeric technical targets, a provider-neutral PostgreSQL contract, a combined local capacity/recovery run, exact full-horizon local restore, and clean-checkout rehearsal. The raw local run preserves the pooled noisy-tenant failure; the pre-checkout application-boundary candidate passes three local reruns. The accountable review accepts Ash conditionally and carries deployment, production identity, durable routing/movement, real adapter, and independent security verification into the phases where those capabilities become real. Those gates still prevent broad production scaffolding or a school business module without explicit authorization.

## Slice 1A boundary

Slice 1A creates one production Elixir umbrella app, `apps/chimwemwe_core`, containing:

- a globally authorized, actor-required, but resource-empty `Chimwemwe.Platform` Ash domain;
- separate opaque types for trusted actor identity and trusted tenant placement;
- a validated execution context that requires actor, tenant, current routing version, correlation, purpose, and locale;
- typed, non-disclosing failures for missing, malformed, invalid, or mismatched context; and
- negative tests proving core work is not invoked for raw, missing, non-positive-routing, or cross-tenant context;
- a code-owned Ash base resource that requires explicit tenant-owned or global-reference ownership and installs the policy authorizer; and
- an automated domain audit that rejects missing policies, wrong-domain registration, unsafe tenant shape, and generic state-changing action names.

The slice does not reuse code from the disposable Ash spike. It pins the exact pressure-tested Ash and PicoSAT releases so the production assumption and policy-verification dependency are visible and replaceable. Synthetic in-memory resources exercise the authoring guard only in tests; the production domain remains empty.

## Slice 1B boundary

Slice 1B promotes one stable seam from the completed Phase 0 authoring scenario: a Chimwemwe-owned, versioned resource descriptor derived from an explicitly allowlisted Ash resource surface. The descriptor builder:

- accepts only resources that already satisfy the production resource contract;
- derives tenant scope from code-owned resource ownership rather than caller input;
- exposes only explicitly allowlisted public attributes, public named actions, public action arguments, stable references, supported portable types and constraints, and an accountable data classification;
- excludes Ash module names, source attribute and action names, policies, tenant keys, private fields, executable behavior, and infrastructure details; and
- sorts its public surface and canonicalizes object keys so the content revision and encoded artifact are deterministic.

The slice is exercised only with neutral, test-only resources. It adds no production resource and no descriptor artifact because the production domain is still empty. Report datasets, definition persistence, tenant customization, metadata validation or execution, rendering, and custom fields remain outside the production core.

## Slice 1C boundary

Slice 1C adds one trusted invocation path from `Chimwemwe.Platform.ExecutionContext` to a public named Ash read action. It:

- validates the opaque execution context before inspecting the requested resource or action;
- accepts only resources registered in an actor-required, always-authorized Ash domain and passing the production resource contract;
- derives actor and tenant scope exclusively from the trusted context, omitting tenant scope only for explicitly global-reference resources;
- reserves actor, tenant, placement, routing, correlation, purpose, locale, domain, scope, repository, and authorization input keys so action input cannot replace platform context;
- propagates a minimal namespaced correlation, purpose, locale, and routing-version context into Ash; and
- invokes only a public action whose Ash type is `:read`, with no caller-supplied Ash options.

Neutral in-memory tenant-owned and global-reference resources exercise real Ash policy and tenancy behavior in tests. Mutation invocation is deliberately absent: production writes still require the first resource's persistence, migration, idempotency, outbox, concurrency, and recovery contract.

## Slice 1D boundary

Slice 1D promotes only the contract proven by the new Phase 0 pre-checkout admission evidence. A node-local `Chimwemwe.Platform.DatabaseAdmission` boundary:

- validates `ExecutionContext` before inspecting tenant or placement capacity;
- derives tenant and placement capacity keys from trusted context rather than caller input;
- requires explicit positive per-tenant and per-placement limits instead of embedding the current candidate values as production defaults;
- acquires both permits before invoking the callback that may reach Ecto or Postgrex;
- classifies tenant saturation as rate limited and placement saturation as a retryable dependency without disclosing identifiers;
- supplies retry guidance only when an explicit bounded interval is configured; and
- releases permits after normal return, exception, throw, exit, or caller termination.

The boundary is not yet attached to a repository or application supervisor because no production placement registry, repository, or accepted capacity settings exist. It is node-local rather than a distributed quota and it does not replace Ash authorization, idempotency, database constraints, or stronger tenant placement.

## Slice 1E boundary

Slice 1E implements the trusted persistence spine governed by ADRs 0003 and 0017 without adding a production resource. It adds:

- a Chimwemwe-owned AshPostgres repository with no production default database or fallback pool;
- an immutable runtime placement registry populated only from startup-owned configuration;
- exact comparison of the validated actor tenant and complete current placement, including the routing version, before repository selection;
- explicitly configured pooled or dedicated repository processes supervised with the registry and admission control;
- one synchronous `Persistence.with_writer/3` boundary that accepts no repository, database, placement, or Ash options from the caller;
- node-local tenant and placement admission before the operation can check out a connection;
- scoped Ecto dynamic-repository selection with restoration after success, exception, throw, or exit; and
- a checked empty migration/snapshot baseline plus an operator-owned migration discipline for the first retained resource.

Missing, raw, mismatched, unknown, stale, or forged context fails before the database callback. An unavailable registry, runtime, or repository fails closed as a retryable dependency. Spawned work does not inherit repository selection and must re-enter the same boundary with its own trusted context.

The runtime is not installed in the application supervisor because production route data, credentials, pool budgets, and a selected deployment do not exist yet. Tests start it with synthetic routes and the local synthetic PostgreSQL database. The in-memory registry is an integration seam, not the durable movement control plane. No table, migration, production Ash resource, state-changing action, or production capacity default is added.

## Slice 1F boundary

Slice 1F implements the tenant-authority foundation required by ADR 0003 and threat TM-02. It adds six tenant-owned, persistent Ash resources for memberships, roles, capabilities, actor-role assignments, role-capability grants, and role inclusion. Every row has a private, non-null tenant key. Every graph edge uses a compound tenant-qualified foreign key, so a relationship cannot join records from different tenants even through an alternate SQL path.

Roles are identified by immutable UUIDs and may be renamed without changing grants. Role inclusion is recursive and composable. A PostgreSQL trigger takes a tenant-qualified transaction advisory lock and rejects direct, indirect, and racing cycles for every write path. Capability keys are constrained stable identifiers; creating a matching record grants nothing unless code explicitly requires that key at a named action boundary.

`Authority.authorize/3` accepts only the persistence runtime, validated execution context, and one code-known capability key. It re-enters the Slice 1E writer boundary and resolves direct and transitive grants from current PostgreSQL state. It accepts no role, grant, tenant, repository, or placement selector. Missing membership or grant returns the same non-disclosing forbidden result, and malformed, stale, cross-tenant, or unavailable context fails closed.

At Slice 1F completion all six resources exposed no Ash actions. Test fixtures used direct SQL only to prove the data constraints and resolver; that was not a production administration path. The first Slice 1G increment below replaces only that role-rename deferral. Assignment, grant, inclusion, and revoke remain closed.

## Slice 1G-A first safe-write boundary

The first bounded Slice 1G increment implements one private named action,
`Role.rename_role`, behind `Authority.rename_role/3`. It deliberately changes only a
role label: the role UUID, assignments, grants, inclusions, and effective authority remain
unchanged.

The boundary:

- validates trusted context before action input and accepts no actor, tenant, placement,
  repository, domain, authorization, or Ash option from action input;
- requires the code-owned `platform.authority.roles.rename` capability from current writer
  state and rechecks it under the tenant authority-write lock;
- requires a positive expected version, UUID idempotency key, and UUID causation identifier;
- binds idempotency to tenant, action, actor, role, and canonical request, returning the exact
  committed result for a retry and a stable conflict for changed input or actor;
- commits the role version change, one immutable authority-audit fact, one minimal outbox
  fact, and the completed idempotency result in the same writer transaction; and
- keeps audit, outbox, and idempotency resources closed to direct actions.

The implementation is a bounded SQL action behind Ash policy and the trusted persistence
boundary, as permitted by ADRs 0002 and 0017. The outbox payload contains the role reference
and resulting version, not the tenant-defined role label. There is no public write invoker,
HTTP route, dispatcher, worker, production runtime wiring, assignment/grant/composition API,
or provisioning resource. This increment proves the safe-write contract; it does not complete
all of Slice 1G.

## Slice 1G-B tenant-safe role assignment

Slice 1G-B adds one more private named action,
`ActorRoleAssignment.assign_role`, behind `Authority.assign_role/3`. The action connects one
existing tenant membership to one existing tenant-defined role; it cannot create either record
or accept an actor, tenant, placement, repository, or Ash option from request input.

The boundary requires the code-owned `platform.authority.assignments.create` capability and
rechecks it on the authoritative writer while holding the tenant authority-write lock. It locks
the membership and role through tenant-qualified predicates, returns the same not-found result
for absent and cross-tenant references, and relies on compound foreign keys as the final defence
for alternate write paths.

The assignment is an immutable UUID aggregate at version 1. Its transaction creates the
assignment, an audit fact recording aggregate version `0 -> 1`, a minimal outbox fact without a
role label, and a completed idempotency result. Exact and concurrent retries return the original
assignment and evidence references. Changed input or actor conflicts, while the same key remains
independent between tenants. A different idempotency key for an existing membership-role pair is
a stable conflict rather than a silent no-op.

The idempotency manifest adds a JSON result payload as a compatible expansion. Existing
role-rename rows and code continue using the retained name/version result columns; the migration
does not drop or reinterpret them. Capability grants, role composition, revocation, membership
lifecycle, dispatch, retention, public APIs, and browser integration remain outside this slice.

## ADR 0018 T1-A temporal qualification boundary

T1-A adds four closed, tenant-owned resources for one neutral synthetic temporal proof: stable
aggregate identity, immutable revisions, immutable effective segments, and immutable append-only
facts. They remain inside the existing platform domain, expose no Ash actions, and are not a
shared temporal library or a school-domain schema.

PostgreSQL assigns recorded time, preserves tenant-and-aggregate revision chains, constrains the
current selector to its own aggregate, rejects backward selector movement, serializes overlapping
segment races, permits the same dates in historical successor revisions, and rejects direct
revision, segment, fact, or aggregate-identity rewrites. Fact reversals remain append-only and
tenant-and-scope qualified.

Focused tests exercise the physical exact/current/effective query shapes and negative database
paths only. Publication/correction and reversal actions, capability-protected history reads,
idempotency, audit/outbox atomicity, retention/legal hold/erasure, import provenance,
backup/restore, projection convergence, and performance limits remain open. Consequently T1-A
does not complete TR-01 or any other ADR 0018 condition. See the
[physical-model evidence](evidence/temporal-qualification-physical-model.md).

## ADR 0018 T1-B governed revision boundary

T1-B opens only the revisioned half of the neutral proof. `Aggregate.publish_revision` and
`Aggregate.correct_revision` are separate private actions reached through
`TemporalQualification.publish_revision/3` and `correct_revision/3`. Publication creates a new
aggregate and revision 1; correction requires the exact selected revision and creates one
consecutive immutable successor. Both actions require distinct tenant-defined capabilities,
recheck authority on the writer under an aggregate lock, bind exact replay to actor and canonical
request, and commit revision state, minimized audit evidence, a transactional outbox fact, and the
completed result together.

The same boundary provides writer-routed `get_current`, `get_effective`, `get_revision`, and
bounded `list_history` reads. Current/effective access is separate from exact/history access.
Recorded-time queries are explicitly unsupported and fail only after trusted context and history
capability checks. Inputs are limited to 32 normalized half-open Date segments and history to 100
revisions; those are qualification bounds, not production sizing claims.

T1-B adds no append-only fact action, retention/legal-hold/erasure action, consumer, migration
import, recovery rehearsal, dispatcher, public API, UI connection, common temporal library, or
school module. TR-01 through TR-07 therefore remain open as whole gates even though the revision
branches of their action, authorization, concurrency, read, and atomic-evidence checks now have
executable proof. See the [T1-B evidence](evidence/temporal-qualification-revision-boundary.md).

## ADR 0018 T1-C append-only fact and reconciliation boundary

T1-C adds separate private actions to record one immutable fact entry and to reverse and replace
one exact entry under a single immutable operation. Exact retries return the one- or two-fact
result; changed request or actor conflicts; tenant-and-target serialization plus PostgreSQL
constraints prevent duplicate or branching correction. Exact fact, exact operation, and bounded
scope-history reads require a distinct history capability. Minimal outbox payloads exclude fact
quantities and effective dates.

One neutral `ConsumerBasis` chain proves deliberate reconciliation. Pinning records one exact
current source revision. A later source correction does not silently change that basis.
Reconciliation requires both the exact current consumer basis and the exact current source
revision, appends a consecutive successor, and preserves the original basis. Pin, reconcile, and
history use separate capabilities; an outbox event is causation evidence and never authority.

The reviewed migration orders the self-reference after its compound destination index, restores
the prior fact guard on empty rollback, refuses rollback once T1-C state is retained, and passes
apply/rollback/reapply plus drift checks. T1-C still adds no retention, hold, erasure, import,
backup/restore, performance qualification, dispatcher, public API, reusable temporal library, or
school module. ADR 0018 therefore remains Conditionally Accepted. See the
[T1-C evidence](evidence/temporal-qualification-fact-and-reconciliation.md).

## Slice 1H-A independent module gates and initial activation

Slice 1H-A promotes only the neutral lifecycle contract accepted in ADR 0001. A trusted immutable
release manifest declares stable module keys, versions, owners, and an acyclic dependency graph.
Two closed tenant-owned resources store entitlement and active version facts. Entitlement remains
a fact with no mutation or commercial-contract API.

`ModuleLifecycle.activate/4` validates trusted context before exact action input, derives release
and dependency state from the manifest, requires `platform.modules.activate` on the authoritative
writer, and invokes one private named initial-activation action. Tenant-and-module serialization,
exact replay, and one writer transaction bind the activation to minimized audit evidence, a
transactional outbox fact, and the completed idempotency result. A database failure after outbox
insertion rolls back every fact and permits a safe retry.

`ModuleLifecycle.authorize/5` independently requires release availability, tenant entitlement, an
active compatible version, active compatible dependencies, and the requested code-owned actor
capability. Activation therefore grants no actor authority. Cross-tenant edges, malformed module
keys and versions, raw or missing context, caller-selected gate state, public mutation, and generic
CRUD remain fail closed.

This slice adds no deactivation, drain, queue or consumer lifecycle, retained-data action,
reactivation, entitlement management, provisioning, browser connection, or school module. See the
[Slice 1H-A evidence](evidence/module-lifecycle-initial-activation.md).

## Slice 1H-B controlled drain and compatible reactivation

Slice 1H-B completes the neutral lifecycle state contract without adding a queue runtime or a
business module. `ModuleActivation` remains the retained aggregate after deactivation and now
records consumer, replay, and reconciled cursors; projection generation and readiness;
reconciliation state; lifecycle timestamps; and retained ownership. A closed tenant-qualified
`ModuleWorkItem` resource models ordinary and mandatory work state only.

`ModuleLifecycle.deactivate/4` rejects active dependents, takes the same lifecycle transaction
lock required by ordinary mutations, closes ordinary authority, parks queued or running ordinary
work, records the replay boundary, and marks disposable projections stale in one exact-versioned,
idempotent transaction. Both forced mutation/deactivation lock orders have deterministic outcomes:
the first transaction completes and the waiting transaction re-evaluates current lifecycle state.

Audit, outbox, retention, legal-hold, and reconciliation work remains available through the
separate private `complete_mandatory_work` action and capability while ordinary authority is
closed. `ModuleLifecycle.reactivate/4` requires explicit release compatibility, entitlement, and
active compatible dependencies; requeues parked work, records reconciliation from the saved
cursor, advances projection generation, and reopens ordinary authority only when state, audit,
outbox, and idempotency evidence commit together.

This slice implements a queue-neutral transactional contract. It adds no Oban worker, dispatcher,
external consumer, projection adapter, cache/search/webhook/analytics integration, entitlement or
offboarding workflow, retained-data read/export/correction/deletion action, public mutation,
browser connection, provisioning surface, or school module. See the
[Slice 1H-B evidence](evidence/module-lifecycle-drain-reactivation.md).

## Slice 1I-A governed presentation definitions

Slice 1I-A implements the first durable governed-extension boundary accepted by ADR 0019 without
creating a renderer or a second domain model. Code-owned module releases may declare versioned
extension contracts. A trusted immutable registry binds each supported schema to one released
module and a descriptor derived from a contract-valid tenant-owned resource and explicit
allowlists.

The only supported schema is a bounded presentation definition containing a title, ordered
allowlisted fields, labels for those fields, and one allowlisted public read action. Validation
rejects extra, private, stale, executable, authority-shaped, or incompatible content and derives
the retained classification from the most sensitive referenced field.

`GovernedExtension.publish_definition/5` is the sole publication boundary. It revalidates trusted
context, the release and registry contract, all independent module gates, and the separate
publication capability on the authoritative writer. Exact optimistic versioning, definition and
lifecycle locks, exact replay, and one transaction bind tenant-owned definition state to minimized
audit, outbox, and idempotency evidence. The evidence omits labels and definition content.

This slice adds no public API, browser connection, real module consumer, report dataset, renderer,
metadata execution, custom fields, runtime schema or workflow language, visual builder,
provisioning surface, or education vocabulary. See the
[Slice 1I-A evidence](evidence/governed-extension-definitions.md).

## Slice 1I-B exact definition resolution

Slice 1I-B closes the Phase 1 governed-extension contract with one internal consumer boundary.
`GovernedExtension.resolve_definition/5` accepts one caller-known definition UUID and returns an
immutable compatible definition view. It exposes no enumeration, search, filtering, history, or
bulk-read surface.

The resolver requires the separate `platform.extensions.definitions.read` capability before
definition lookup, then rechecks that capability together with release, entitlement, active
version, and dependency gates under the module lifecycle lock. Missing and cross-tenant IDs return
the same not-found result. Publication authority does not imply read authority.

Resolution derives the module and resource contract from the current trusted registry, not stored
or caller-selected authority. It requires the retained schema version, resource reference,
descriptor revision, normalized content, and derived classification to match current code. The
published module version must equal the active release or be explicitly listed in its
`compatible_from` contract. The returned view reports `exact` or `compatible` and excludes tenant,
actor, activation, entitlement, placement, repository, authority, audit, outbox, and idempotency
identifiers.

This slice does not execute the stored read action, fetch domain records, render a component, expose
an Ash/public/HTTP/browser read, add a checked public descriptor artifact, or create report, export,
cache, search, custom-field, runtime-schema, provisioning, or education-domain authority. See the
[Slice 1I-B evidence](evidence/governed-extension-resolution.md).

## UI-0 local browser boundary

UI-0 implements only the local experience-validation slice authorized on 2026-09-24. It adds a separate Next.js, React, and TypeScript workspace under `clients/web` with:

- a responsive Home shell and UI-preview route;
- deterministic, visibly labelled synthetic fixture data behind a read-only view-data port;
- no core, API, database, authentication, browser-storage, or external-service connection;
- an explicit `CHIMWEMWE_UI0_SYNTHETIC=true` guard for development, testing, and production compilation;
- a semantic CSS contract with fixed cascade layers, owned design tokens, and enforced `l-`, `c-`, `u-`, `is-`, and `has-` class names;
- written ready, loading, empty, denied, rate-limited, retryable, conflict, and unexpected-error states; and
- unit, accessibility, keyboard, reflow, wide, medium, and narrow real-browser checks.

The workspace is local evidence for ADR 0020, not the public client described by ADR 0014. Navigation and hidden or disabled controls grant no authority. The synthetic adapter cannot become a production API shim, and the production core remains unchanged. Representative school-user testing and a real authorized workflow remain later gates.

## UI-1A local read-only core bridge

UI-1A implements the separately authorized local qualification governed by proposed ADR 0022.
It adds one loopback Phoenix endpoint inside the existing core and one server-rendered Next.js
route at `/authority/assignments`. A fresh local token resolves only on the server to fixed
synthetic trusted actor and placement values. Browser input cannot select the actor, tenant,
capability, repository, placement, routing version, or Ash options.

The endpoint exposes only `GET /api/v1/authority/assignment-options`. Both underlying named Ash
reads require `platform.authority.assignments.create` and execute through the authoritative
writer boundary. The minimal DTO contains opaque membership and role option IDs and labels but
no tenant, actor, capability, repository, placement, or routing identifiers. A second synthetic
tenant is seeded so tests can prove non-disclosure.

The Next.js adapter is server-only, rejects non-loopback configuration and unexpected contract
versions, uses a checked OpenAPI artifact and generated TypeScript declarations, and does not
cache. The screen provides accessible selectors and an explicitly disabled save control. There
is no POST route, mutation client, server action, browser persistence, real identity, public
deployment, or school module. Representative human testing remains necessary before terminology
or workflow is considered validated.

## Continuing guardrails

- Phase 0 ADR outcomes and conditional gates are binding; an Accepted ADR is changed only by supersession.
- `make check` proves repository consistency; it does not by itself approve a new production capability.
- Only `apps/chimwemwe_core` is allowed during slices 1A through the current Slice 1I-B increment. A second production app or service needs explicit later-slice authorization.
- `clients/web` is allowed for UI-0 and only UI-1A's guarded, loopback, read-only core connection;
  it has no authority to become a production client, expose a write, or add real identity.
- The core contains no production data or secrets and introduces no generic or public write invocation, metadata renderer or execution engine, or public interface.
- If a retained Ash gate fails and its explicit adapter fallback cannot preserve the platform invariants, ADR 0002 must be superseded before the affected business capability depends on it; the execution-context contract remains framework-neutral.

See the [implementation plan](../plans/phase-1-core-foundation-plan.md), [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md), [UI-1A plan](../plans/local-browser-core-bridge-plan.md), [core boundary](../architecture/core-foundation-boundary.md), [domain-model authoring boundary](../architecture/domain-model-authoring-and-metadata.md), [slice 1A evidence](evidence/core-foundation.md), [slice 1B evidence](evidence/resource-descriptor.md), [slice 1C evidence](evidence/action-invocation.md), [slice 1D evidence](evidence/database-admission.md), [slice 1E evidence](evidence/trusted-persistence.md), [slice 1F evidence](evidence/tenant-authority.md), [Slice 1G-A role-rename evidence](evidence/authority-role-rename.md), [Slice 1G-B role-assignment evidence](evidence/authority-role-assignment.md), [ADR 0018 T1-A evidence](evidence/temporal-qualification-physical-model.md), [ADR 0018 T1-B evidence](evidence/temporal-qualification-revision-boundary.md), [ADR 0018 T1-C evidence](evidence/temporal-qualification-fact-and-reconciliation.md), [Slice 1H-A evidence](evidence/module-lifecycle-initial-activation.md), [Slice 1H-B evidence](evidence/module-lifecycle-drain-reactivation.md), [Slice 1I-A evidence](evidence/governed-extension-definitions.md), [Slice 1I-B evidence](evidence/governed-extension-resolution.md), [UI-0 evidence](evidence/local-browser-experience.md), [UI-1A evidence](evidence/local-browser-core-bridge.md), [migration discipline](../development/migrations.md), [Phase 0 status](../phase-0/README.md), and [review record](../phase-0/review-record.md).
