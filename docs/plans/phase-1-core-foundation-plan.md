# Phase 1 core-foundation implementation plan

- Status: Slices 1A through 1F and Slice 1G-A implemented and test-verified; Slice 1G-B tenant-safe role assignment authorized and in progress; Phase 0 decisions completed
- Owner: Platform engineering
- Decision posture: Ash conditionally accepted; applicable ADR outcomes and production gates are binding
- Review trigger: another authority mutation, generic or public write invocation, a metadata consumer, a public interface, another app, or a school domain

## Inputs consumed

| Input | What the core slices carry forward | What remains unresolved |
| --- | --- | --- |
| [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md) | One production core with a small mandatory platform boundary | Real module-lifecycle integration before the first production module |
| [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md) | Exact pressure-tested Ash and policy-solver releases plus global authorization | Eight accepted production gates and their explicit fallbacks |
| [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md) | Mandatory tenant identity separated from trusted placement and routing version | Production registry, database routing, movement, recovery, and RLS |
| [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md) | No generic business mutation or CRUD surface; first private production named action | Additional resource actions and any public action/error contract |
| [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md) | The first write commits one minimal durable event fact with its state | Dispatcher, retry, operational replay, retention, and movement reconciliation |
| [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md) | One authoritative writer boundary, explicit pool budgets, admission before checkout, and no request-selected repository | Selected-deployment topology, failover, recovery, multi-node calibration, and production credentials |
| [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md) | Code-owned base-resource convention, structural audit, and a small derived descriptor contract proven by disposable Phase 0 evidence | Descriptor consumers, governed metadata, persistence, and their closure gates |
| [Retained-data migration evidence](../phase-0/evidence/retained-data-migration-rehearsal.md) | Keep migration choreography explicit and resource-specific | Production-shaped measurements, mixed-release deployment, recovery proof, and an authorized persistent resource |
| [Trusted-routing evidence](../phase-0/evidence/trusted-routing.md) | Raw request placement is not accepted; missing or stale routing fails closed | Live registry and repository selection |
| [Pre-checkout admission evidence](../phase-0/evidence/precheckout-admission-measurement.md) | Acquire node-local tenant and placement capacity before any repository callback | Multi-node coordination, selected-deployment calibration, and live pool integration |
| [Threat model](../security/threat-model.md) | TM-01, TM-02, TM-09, and TM-11 shape context, authorization, and non-disclosure tests | Independent review before real restricted data and later interface-specific suites |

These are decided Phase 0 inputs. Conditional and production-readiness gates remain binding, and explicit slice authorization still limits the work below.

## Slice 1A implementation

1. Establish the root Elixir umbrella and one `chimwemwe_core` OTP app.
2. Pin the production core to Ash 3.33.4 and PicoSAT 0.2.3, including the coordinated Phase 0 security-patch review.
3. Define the empty production Ash domain with authorization forced to `:always` and actor presence required.
4. Define trusted actor, trusted placement, and execution-context types without role constants or request-selected infrastructure.
5. Validate the complete context before invoking core work and return typed errors without echoing identifiers.
6. Add positive, missing-context, malformed-input, non-positive-routing, and tenant-mismatch tests.
7. Extend bootstrap, format, lint, test, documentation, dependency-audit, type-analysis, and full-check entrypoints to cover the production core.
8. Preserve the Phase 0 exit validator and explicitly allow only this documented app while the start exception is active.
9. Add a code-owned Ash base resource with an explicit tenant-owned or global-reference declaration and fixed policy authorizer.
10. Audit domain authorization, actor presence, domain registration, resource policies, tenant shape, global-reference separation, and named state-changing actions.
11. Exercise the authoring contract with test-only, synthetic, in-memory resources while keeping the production domain resource-empty.

## Slice 1B implementation

1. Add a production-core descriptor builder whose only inputs are a contract-controlled Ash resource and an explicit code-owned allowlist.
2. Require the resource to pass `Chimwemwe.Platform.ResourceContract` before deriving anything.
3. Validate positive schema and model versions, stable Chimwemwe references, unique source and public references, supported types, and the full platform classification vocabulary.
4. Derive ownership and tenant-scope characteristics from the resource base contract; do not accept caller-supplied tenancy characteristics.
5. Derive only explicitly allowlisted public attributes, public named actions, and public action arguments. Do not serialize Ash modules, source names, policies, tenant keys, or executable behavior.
6. Sort fields and actions by stable reference and canonicalize object keys before calculating a SHA-256 content revision or encoding an artifact.
7. Exercise the boundary with neutral, in-memory test resources, including private-field, private-action, unsupported-type, malformed-reference, duplicate-reference, invalid-resource, and deterministic-evolution cases.
8. Keep the production domain resource-empty and add no generated descriptor artifact until an authorized production resource exists.

Slice 1B deliberately does not promote the Phase 0 report-dataset registry or governed-metadata executor. Those need their own action, authorization, persistence, compatibility, classification, and lifecycle boundary.

## Slice 1C implementation

1. Add a read-only invocation boundary between the validated production execution context and Ash.
2. Validate context before resource or action lookup so unauthenticated input cannot probe the model surface.
3. Require the requested resource to be registered in an always-authorized, actor-required domain and to satisfy the production resource contract.
4. Accept only a public named read action and a plain map of action input; expose no Ash option passthrough.
5. Derive the actor and tenant exclusively from trusted context. Omit tenant scope only for a resource explicitly declared as global reference data.
6. Reject reserved context and authority keys in action input before Ash executes.
7. Propagate only correlation ID, purpose, locale, and routing version in a namespaced Ash context; do not expose placement coordinates.
8. Exercise real policy denial, tenant filtering, global-reference behavior, invalid context, private or wrong-type actions, invalid resources, and reserved-input denial with neutral in-memory resources.
9. Add no mutation API, production resource, persistence, migration, interface, worker, or external service.

## Slice 1D implementation

1. Add a node-local pre-checkout admission boundary that accepts only a validated production execution context and a zero-argument callback.
2. Derive tenant and placement capacity keys from trusted actor and placement objects; accept no caller-supplied tenant, placement, repository, or database coordinate.
3. Require explicit positive per-tenant and per-placement limits. Keep the Phase 0 two-and-ten values as measured candidates, not code defaults.
4. Acquire both limits atomically in one admission process before invoking the callback that may check out a database connection.
5. Reject tenant saturation as `:rate_limited` and placement saturation as `:retryable_dependency`; return no tenant or placement identifier.
6. Emit retry guidance only when an explicit bounded interval is configured.
7. Release every permit after normal completion or failure and reclaim permits when an admitted caller dies.
8. Expose only aggregate, identifier-free operational counters for this provisional boundary.
9. Do not register the process in the application supervisor or connect it to Ecto until live placement resolution, pool ownership, settings, and failover behaviour have their own slice.
10. Add no persistence, production resource, write action, public interface, distributed quota, or production infrastructure.

## Slice 1E implementation

1. Add the Chimwemwe-owned AshPostgres repository using the exact Phase 0 dependency baseline, PostgreSQL 18 minimum, and no production default connection.
2. Start repository processes only inside an explicitly configured persistence runtime; use no implicit or default pool.
3. Load an immutable tenant-to-placement-to-repository mapping at runtime startup, reject incomplete, duplicate, or unknown repository references, and expose no mutation API.
4. Revalidate `ExecutionContext` before runtime or route lookup, then compare the complete current placement including tenant, profile, opaque reference, and routing version.
5. Return one non-disclosing route failure for unknown, stale, or forged placement state and a retryable dependency failure for an unavailable runtime component.
6. Accept no repository, database, placement, routing, actor, tenant, or Ash options in the operation API.
7. Acquire the existing explicit tenant and placement admission permit before installing the dynamic repository or invoking the callback that may check out a connection.
8. Keep repository selection synchronous and process-local, restore the prior repository on every exit path, and prove spawned work has no inherited selection.
9. Add an empty generated-migration and resource-snapshot drift check plus the review contract for expand/backfill/validate/contract choreography before the first retained resource.
10. Exercise pooled and dedicated route selection against synthetic PostgreSQL, including positive query, raw/missing/mismatched context, unknown tenant, stale route, forged placement, admission rejection, unavailable runtime, and cleanup cases.
11. Keep `Chimwemwe.Platform` resource-empty. Add no table, production migration, write action, durable movement registry, production route configuration, or capacity default.

## Slice 1F implementation

1. Add six persistent tenant-owned Ash resources for tenant membership, role, capability, actor-role assignment, role-capability grant, and role inclusion inside the existing platform domain.
2. Keep every tenant key private and non-null, with no global fallback, and give every referenced resource a tenant-qualified unique `(id, tenant_id)` index.
3. Enforce compound tenant-qualified foreign keys for membership assignments, role grants, and both sides of role inclusion so alternate write paths cannot create cross-tenant authority edges.
4. Identify roles by immutable UUID rather than name. Keep role names renameable tenant data and reserve a positive lock version for the governed mutation slice.
5. Constrain capability keys to stable dotted identifiers. A stored key grants no behavior unless platform code explicitly requires the same key at a named action boundary.
6. Enforce direct and indirect role-cycle rejection in PostgreSQL with a tenant-qualified advisory lock and recursive trigger so the invariant covers every future adapter.
7. Add `Authority.authorize/3`, accepting only a persistence runtime, validated context, and code-known capability key. Resolve direct and transitive grants on the authoritative writer with no caller-selected role, grant, tenant, placement, or repository.
8. Add a fail-closed Ash policy check that can use the current writer selection; outside that boundary, database unavailability denies rather than granting authority.
9. Expose no Ash actions and no graph mutation API. Keep assignment, grant, inclusion, rename, revoke, audit, outbox, and idempotency behavior in Slice 1G.
10. Generate resource snapshots, review and correct migration dependency ordering, then prove migration apply, rollback, reapply, and drift against synthetic PostgreSQL.
11. Test direct and composed grants, rename independence, missing membership/grant denial, invalid capability input, untrusted and stale context, unavailable runtime, compound cross-tenant rejection, cycle rejection, closed resources, and absence of mutation functions.

## Slice 1G first safe-write vertical slice

The first Slice 1G increment is deliberately one resource-specific action rather than a
generic write invoker or a complete authority-administration API. It renames a tenant-defined
role without changing that role's identity, assignments, grants, or inclusions.

1. Add the private Ash action `Role.rename_role` and expose it only through the
   Chimwemwe-owned `Authority.rename_role/3` boundary. The caller supplies ordinary action
   input, while actor, tenant, placement, routing, correlation, and Ash options remain derived
   from validated platform context.
2. Require the code-owned `platform.authority.roles.rename` capability against current writer
   state. A stored capability with the same key grants nothing unless this action requires it.
3. Require a positive expected role version, a UUID idempotency key, and a UUID causation
   identifier. Lock the tenant-qualified role and increment its positive version exactly once.
4. Bind an idempotency key to tenant, action, actor, role, and a canonical request hash. An
   exact retry returns the committed result; changed input or actor returns one stable
   idempotency conflict. The same key remains independent in another tenant.
5. Commit the role update, one immutable authority-audit fact, one minimal versioned outbox
   fact, and the completed idempotency result in the same writer transaction. The outbox fact
   carries no role label and is not placement authority.
6. Keep audit, outbox, and idempotency resources closed to direct actions. Do not add a public
   write invoker, dispatcher, worker, interface, role assignment, capability grant, role
   inclusion, revoke path, provisioning resource, or school module in this increment.
7. Prove success, exact replay, concurrent retry serialization, stale-version conflict,
   changed-request conflict, missing-capability denial, cross-tenant non-disclosure, malformed
   input/context rejection, tenant-isolated idempotency, and rollback after a post-outbox
   database failure.
8. Generate and review the migration and resource snapshots, including tenant keys, indexes,
   completion constraints, rollback order, migration apply/rollback/reapply, and drift.

This increment proves the write contract but does not complete Slice 1G. Assignment, grant,
composition, rename reversal, revocation, retention, dispatch, and operational replay remain
separately authorized follow-up work.

## Slice 1G-B tenant-safe role assignment

The next Slice 1G increment adds one authority-graph mutation: assigning an existing tenant
membership to an existing tenant-defined role. It reuses the proven safe-write contract without
opening a generic authority-administration surface.

1. Add the private Ash action `ActorRoleAssignment.assign_role` and expose it only through the
   Chimwemwe-owned `Authority.assign_role/3` boundary. Accept exactly `membership_id`, `role_id`,
   `idempotency_key`, and `causation_id`; derive actor, tenant, placement, routing, correlation,
   repository, and Ash options from validated context.
2. Require the code-owned `platform.authority.assignments.create` capability and recheck it on
   the selected authoritative writer while holding the tenant authority-write lock.
3. Resolve and lock both referenced records by `(id, tenant_id)`. A missing or cross-tenant
   membership or role returns the same non-disclosing not-found result, and compound database
   constraints remain the final alternate-write defence.
4. Create one immutable assignment UUID at lock version 1. A second action with a different
   idempotency key for the same membership-role pair is a stable conflict; exact retries return
   the original committed assignment result.
5. Extend the existing action-idempotency manifest compatibly with an action-neutral JSON result
   payload while retaining the role-rename result columns for mixed-version compatibility. Do
   not drop or reinterpret existing role-rename claims in this increment.
6. Commit the assignment, one immutable authority-audit fact using aggregate version `0 -> 1`,
   one minimal versioned outbox fact, and the completed idempotency result in the same writer
   transaction. Neither fact carries a role label or grants authority independently.
7. Prove success and immediate writer-side authorization, exact and concurrent replay,
   changed-request and changed-actor conflict, duplicate-assignment conflict, missing-capability
   denial, cross-tenant non-disclosure, malformed input/context rejection, tenant-isolated
   idempotency, alternate-write constraint protection, and rollback after a post-outbox failure.
8. Generate and manually review the migration and resource snapshots for the assignment version,
   action-neutral result payload, compatibility constraint, audit creation-version rule, tenant
   keys, indexes, foreign keys, rollback order, apply/rollback/reapply, and drift.
9. Add no membership, role, capability, grant, inclusion, revoke, dispatcher, worker, public
   write invoker, browser connection, provisioning resource, or school module in this increment.

Slice 1G-B does not complete the authority administration surface. Capability grants, role
composition, revocation, membership lifecycle, retention, dispatch, and operational replay
remain separately authorized follow-up work.

## Acceptance checks

- `Ash.Domain.Info.authorize(Chimwemwe.Platform)` returns `:always`.
- `Ash.Domain.Info.require_actor?(Chimwemwe.Platform)` returns `true`.
- A complete context from matching trusted sources reaches the supplied operation.
- Missing context and a raw map fail before the operation runs.
- A non-positive routing version fails before the operation runs.
- Authenticated and routed tenant mismatch returns a non-disclosing typed error.
- A valid tenant-owned resource and a valid global-reference resource pass the structural audit.
- Missing base ownership, policy authorizer, policies, tenant attribute, or correct domain registration fails the audit.
- Nullable or public tenant keys, tenant resources with global fallback, and generic state-changing action names fail the audit.
- No school role, business module, HTTP route, worker, or external service is added.
- The production core never imports `AshFoundationLab`.
- Descriptor derivation rejects a resource that fails the production resource contract.
- Tenant scope is derived from resource ownership and cannot be supplied in the descriptor allowlist.
- Private or unallowlisted fields and actions, unsupported types or classifications, generic mutations, malformed or duplicate stable references, and invalid versions fail closed.
- Equivalent allowlists derive the same ordered descriptor, encoding, and revision; a model-version or public-surface change changes the revision.
- The descriptor contains no Ash module or source names, tenant key, policy implementation, persistence detail, or executable behavior.
- A valid trusted context can invoke a public named read and sees only its tenant's records.
- A denied actor remains forbidden and a global-reference read remains actor-authorized without tenant multitenancy.
- Raw, missing, malformed, mismatched, or non-positive-routing context fails before resource or action discovery.
- Unregistered or structurally invalid resources and private, missing, or non-read actions fail with one non-disclosing invocation error.
- Reserved authority or context keys and non-map input fail before the Ash action runs.
- The generic `ActionInvocation` boundary exports no write function; only the resource-specific `Authority.rename_role/3` boundary is added.
- Missing, raw, malformed, invalid-routing, or tenant-mismatched context is rejected before admission state or the supplied callback is reached.
- Tenant and placement limits are enforced independently, and another tenant or placement can proceed when its own capacity remains.
- Tenant and placement saturation have distinct stable classifications and do not disclose identifiers.
- Admitted callbacks release capacity after return, exception, throw, exit, or caller death.
- Retry guidance is absent by default and present only when configured explicitly.
- An unavailable admission process fails closed as a retryable dependency before the callback runs.
- Operational statistics contain counts only, not tenant or placement identifiers.
- No production repository callback is wired into the application supervision tree.
- The configured persistence runtime owns all repository processes and exposes no caller-selected repository option.
- A current pooled or dedicated route selects the expected repository and reaches PostgreSQL only after admission.
- Raw, mismatched, unknown, stale, and forged context fails before the database callback runs.
- The prior dynamic repository is restored after return or failure, and spawned work inherits no repository selection.
- Missing runtime components fail closed with a non-disclosing retryable-dependency result.
- Repository, placement, per-tenant, and per-placement configuration is explicit; there is no production database or capacity default.
- All nine persistent platform resources are tenant-owned, contract-valid, and registered in the always-authorized actor-required domain. Only `Role.rename_role` exposes an action, and it is private.
- Direct and transitive capability grants resolve on the current writer and remain valid after a role rename.
- Missing membership, missing grant, malformed capability, raw or mismatched context, stale routing, and unavailable runtime fail closed without disclosing graph contents.
- Compound tenant foreign keys reject cross-tenant assignment, grant, and inclusion through alternate SQL writes.
- PostgreSQL rejects direct and indirect role cycles, and the surviving graph remains unchanged.
- Role rename requires the code-known capability, validated tenant context, positive expected version, idempotency key, and causation identifier.
- A successful rename increments the role version once and atomically records one audit fact, one minimal outbox fact, and one completed idempotency result.
- Exact and concurrent retries return the same committed result without duplicate facts; changed input or actor returns an idempotency conflict, and the same key is isolated between tenants.
- Unauthorized, stale-version, duplicate-name, cross-tenant, malformed-input, and raw-context requests fail with stable non-disclosing errors and leave no facts.
- A database failure after outbox insertion rolls back role state, audit, outbox, and idempotency together, after which the same request can succeed.
- The reviewed migration applies, rolls back, reapplies, and passes generated migration and snapshot drift checks.
- `make check` and the Phase 0 exit review pass.

## Rollback and next gate

Slice 1A can be removed by deleting the root umbrella files, `apps/chimwemwe_core`, and its Phase 1 documentation and validator allowance while retaining all Phase 0 evidence. The execution-context, explicit-ownership, and named-action concepts survive an Ash fallback because they depend on platform trust semantics rather than an Ash resource.

Slice 1E can be rolled back by removing the repository runtime, AshPostgres dependency, migration baseline, and its tests while retaining the framework-neutral context and admission contracts from 1A-1D. Slice 1F can be rolled back before retained production data by removing its closed resources, resolver, migration/snapshots, and tests. The first Slice 1G increment can likewise be rolled back only while its role changes and evidence tables contain no retained data. Once authority rows or action facts exist outside synthetic development, rollback must use forward repair or an approved recovery point rather than dropping or rewinding authority state.

The role-rename increment proves the first safe-write contract; it does not authorize assignment, grant, composition, revoke, public write invocation, outbox dispatch, retention deletion, provisioning, or another module. Those require the next explicitly bounded plan and corresponding recovery and negative evidence. The Phase 0 descriptor artifact, report registry, and governed experience-metadata implementation remain disposable evidence and are not production APIs. Do not add a school business module until an explicit module slice is authorized.
