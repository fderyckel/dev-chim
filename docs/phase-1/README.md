# Phase 1: core foundation

- Status: Slices 1A through 1F and the first Slice 1G safe-write increment implemented and test-verified; local synthetic UI-0 implemented; representative human review pending
- Owner: Platform engineering
- Start basis: explicit user direction on 2026-09-14, followed by the completed Phase 0 review on 2026-09-16
- Entry basis: Ash is conditionally accepted; implementation proceeds only in explicitly authorized bounded slices and must satisfy the retained production gates

## Why this can start narrowly

Phase 0 has direct evidence for named actions, tenant and capability denial, tenant-defined role composition, global authorization requirements, optimistic concurrency, transactional rollback and idempotency, generated-interface policy preservation, trusted placement input, module-gate separation, telemetry redaction, migration generation, and patch plus non-patch interface-framework upgrades. Ash 3.33.4 now closes the field-policy advisory with a focused forbidden-calculation filter regression, and the current complete verification contract passes.

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

## Slice 1G first safe-write boundary

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

## Continuing guardrails

- Phase 0 ADR outcomes and conditional gates are binding; an Accepted ADR is changed only by supersession.
- `make check` proves repository consistency; it does not by itself approve a new production capability.
- Only `apps/chimwemwe_core` is allowed during slices 1A through the current Slice 1G increment. A second production app or service needs explicit later-slice authorization.
- `clients/web` is allowed only for UI-0's guarded synthetic experience; it has no authority to become a production client or connect to the core.
- The core contains no production data or secrets and introduces no generic or public write invocation, experience-metadata engine, or public interface.
- If a retained Ash gate fails and its explicit adapter fallback cannot preserve the platform invariants, ADR 0002 must be superseded before the affected business capability depends on it; the execution-context contract remains framework-neutral.

See the [implementation plan](../plans/phase-1-core-foundation-plan.md), [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md), [core boundary](../architecture/core-foundation-boundary.md), [domain-model authoring boundary](../architecture/domain-model-authoring-and-metadata.md), [slice 1A evidence](evidence/core-foundation.md), [slice 1B evidence](evidence/resource-descriptor.md), [slice 1C evidence](evidence/action-invocation.md), [slice 1D evidence](evidence/database-admission.md), [slice 1E evidence](evidence/trusted-persistence.md), [slice 1F evidence](evidence/tenant-authority.md), [Slice 1G role-rename evidence](evidence/authority-role-rename.md), [UI-0 evidence](evidence/local-browser-experience.md), [migration discipline](../development/migrations.md), [Phase 0 status](../phase-0/README.md), and [review record](../phase-0/review-record.md).
