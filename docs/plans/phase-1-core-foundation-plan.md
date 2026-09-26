# Phase 1 core-foundation implementation plan

- Status: Slices 1A through 1H-B, ADR 0018 T1-A/T1-B/T1-C, and local UI-1A implemented; T1-C complete-repository verification pending; Phase 0 decisions completed
- Owner: Platform engineering
- Decision posture: Ash conditionally accepted; applicable ADR outcomes and production gates are binding
- Review trigger: another authority mutation, a callable temporal action or read boundary, generic or public write invocation, a metadata consumer, a public interface, another app, or a school domain

## Inputs consumed

| Input | What the core slices carry forward | What remains unresolved |
| --- | --- | --- |
| [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md) | One production core with a small mandatory platform boundary | Real module-lifecycle integration before the first production module |
| [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md) | Exact pressure-tested Ash and policy-solver releases plus global authorization | Eight accepted production gates and their explicit fallbacks |
| [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md) | Mandatory tenant identity separated from trusted placement and routing version | Production registry, database routing, movement, recovery, and RLS |
| [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md) | No generic business mutation or CRUD surface; first private production named action | Additional resource actions and any public action/error contract |
| [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md) | The first write commits one minimal durable event fact with its state | Dispatcher, retry, operational replay, retention, and movement reconciliation |
| [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md) | One authoritative writer boundary, explicit pool budgets, admission before checkout, and no request-selected repository | Selected-deployment topology, failover, recovery, multi-node calibration, and production credentials |
| [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md) | Separate publication and correction intent, immutable operation results, explicit temporal reads, and evidence-layer separation | Retention/hold/erasure, reversal action, consumer reconciliation, migration provenance, backup/restore, and accountable Full Acceptance |
| [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md) | Code-owned base-resource convention, structural audit, and a small derived descriptor contract proven by disposable Phase 0 evidence | Descriptor consumers, governed metadata, persistence, and their closure gates |
| [Retained-data migration evidence](../phase-0/evidence/retained-data-migration-rehearsal.md) | Keep migration choreography explicit and resource-specific | Production-shaped measurements, mixed-release deployment, recovery proof, and an authorized persistent resource |
| [Trusted-routing evidence](../phase-0/evidence/trusted-routing.md) | Raw request placement is not accepted; missing or stale routing fails closed | Live registry and repository selection |
| [Pre-checkout admission evidence](../phase-0/evidence/precheckout-admission-measurement.md) | Acquire node-local tenant and placement capacity before any repository callback | Multi-node coordination, selected-deployment calibration, and live pool integration |
| [Threat model](../security/threat-model.md) | TM-01, TM-02, TM-09, and TM-11 shape context, authorization, and non-disclosure tests | Independent review before real restricted data and later interface-specific suites |

These are decided Phase 0 inputs. Conditional and production-readiness gates remain binding, and explicit slice authorization still limits the work below.

## Slice 1A implementation

1. Establish the root Elixir umbrella and one `chimwemwe_core` OTP app.
2. Pin the production core to Ash 3.33.11 and PicoSAT 0.2.3, including the coordinated Phase 0 security-patch reviews.
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

## ADR 0018 T1-A temporal qualification physical model

The authorized first increment of the neutral temporal proof is a closed physical-model
qualification inside the production core. It deliberately precedes any callable temporal action
or school domain.

1. Add one synthetic stable aggregate, immutable revision chain, immutable effective-segment
   set, and immutable append-only fact under a qualification-only namespace.
2. Keep every resource tenant-owned, actor-required through the platform domain, and closed to
   Ash actions. Add no generic temporal API, business vocabulary, public interface, descriptor,
   worker, dispatcher, or education module.
3. Let PostgreSQL assign `recorded_at`, preserve stable aggregate identity, prevent revision
   branches and backward current-pointer movement, and reject update or delete of revisions,
   effective segments, and facts through alternate write paths.
4. Enforce tenant-qualified aggregate, predecessor, current-pointer, segment, and reversal
   relationships. Include explicit synthetic scope identity where the later capability boundary
   must distinguish records inside one tenant.
5. Serialize segment insertion per tenant and revision and reject overlapping half-open Date
   intervals inside one revision while permitting historical successor revisions to cover the
   same effective dates.
6. Prove the physical exact/current/effective query shapes and append-only reversal shape with
   synthetic PostgreSQL tests, including cross-tenant, cross-scope, immutability, chain,
   interval, and caller-backdated timestamp negatives.
7. Generate and manually review the migration and resource snapshots, including circular
   selector ordering, compound indexes and foreign keys, trigger teardown order, apply,
   rollback, reapply, and drift.

T1-A does not complete TR-01 or any other ADR 0018 condition. Named publication/correction and
reversal actions, capability-protected history reads, operation/idempotency results, audit and
outbox atomicity, downstream reconciliation, retention/legal hold/erasure, baseline import,
backup/restore, and performance limits remain separately bounded T1 increments.

## ADR 0018 T1-B governed revision actions and reads

The authorized second increment keeps the T1-A qualification model neutral while adding only
the callable revision behavior required to evaluate TR-01 through TR-05. It does not add the
append-only reversal action, retention/erasure behavior, migration import, recovery rehearsal,
consumer implementation, public interface, or school domain.

1. Add separate private `Aggregate.publish_revision` and `Aggregate.correct_revision` actions.
   Publication creates revision 1 for a new caller-named aggregate; correction requires the exact
   current revision ID and creates one consecutive successor. There is no combined mode switch,
   generic mutation, or "correct latest" request.
2. Expose the actions only through a qualification-owned boundary that validates trusted context
   before action input and derives actor, tenant, placement, routing, correlation, repository,
   domain, authorization, and Ash options from that context.
3. Require distinct code-owned publish and correct capabilities, then re-authorize on the
   authoritative writer after taking a tenant-and-aggregate transaction lock.
4. Accept one bounded non-empty set of normalized half-open Date segments, a stable reason code,
   UUID idempotency and causation identifiers, and—only for correction—the expected current
   revision. Generate revision, operation, and segment identities inside the writer transaction.
5. Bind replay to tenant, action, actor, aggregate, and the canonical complete request. Exact and
   concurrent retries return the complete committed revision-and-segment result; changed input or
   actor conflicts; racing different corrections against one expected revision cannot branch.
6. Atomically create the aggregate when publishing, immutable revision and segments, monotonic
   current selector, minimized security audit evidence, one minimal outbox fact, and the completed
   idempotency result. Reuse the existing closed safe-write evidence resources only as neutral
   qualification scaffolding; do not promote a common temporal persistence abstraction.
7. Add named writer-routed `get_current`, `get_effective`, `get_revision`, and bounded
   `list_history` reads. Current/effective and exact/history use distinct code-owned capabilities;
   an unsupported recorded-time read validates and authorizes before returning an explicit typed
   failure rather than approximating from timestamps.
8. Prove success, exact replay, changed-request/actor conflict, stale and concurrent correction,
   missing capability/context, current-versus-history disclosure, cross-tenant non-disclosure,
   invalid/overlapping segments, full transaction rollback after outbox insertion, and exact,
   current, effective, history, and unsupported recorded-time behavior.
9. Keep all actions private. Add no generic/public write or read invoker, dispatcher, worker,
   browser connection, production runtime wiring, framework history dependency, reusable temporal
   library, business vocabulary, school module, or claim that TR-01 through TR-05 are complete.

T1-B may close executable portions of TR-01 through TR-05 only when its evidence is recorded.
TR-05 still requires consumer pin/follow/reconcile proof, while TR-06, TR-07, the reversal half of
TR-01, and accountable Full Acceptance remain later bounded work.

## ADR 0018 T1-C append-only correction and deliberate reconciliation

The authorized third increment completes only the append-only action branch and one neutral
deliberate-reconciliation consumer proof. It remains qualification-owned and synthetic. It adds
no retention, legal-hold, erasure, import, recovery, dispatcher, public interface, school domain,
or common temporal persistence library.

1. Add separate private `Fact.record_entry` and `Fact.reverse_and_replace` actions. Recording
   creates one writer-identified immutable entry. Correction targets one exact entry and creates
   one derived full reversal plus one replacement under one writer-owned operation identity.
   Neither action exposes generic insertion, deletion, adjustment, or caller-supplied recorded
   time, fact identity, reversal quantity, operation identity, repository, or authority options.
2. Require distinct code-owned record and reverse-and-replace capabilities. Revalidate trusted
   context and current capability on the authoritative writer, serialize by tenant and target
   scope or fact, and retain the database-enforced single-full-reversal and cross-scope guards.
3. Bind idempotency to tenant, action, actor, target scope or fact, and the canonical request.
   Exact and concurrent retries return the complete one- or two-fact result. Changed request or
   actor conflicts, while racing different corrections of the same entry permit exactly one
   reversal operation.
4. Atomically commit all created facts, minimized audit evidence, one minimal outbox fact, and the
   complete idempotency result. The outbox contains safe identifiers and counts, not quantities,
   and cannot grant consumer authority.
5. Add capability-protected exact fact, exact operation, and bounded scope-history reads. History
   access is distinct from action authority and every query is writer-routed and tenant-qualified.
6. Add one qualification-only append-only `ConsumerBasis` chain for deliberate reconciliation.
   `pin_revision` creates basis version one against the exact current source revision;
   `reconcile_revision` requires the exact current basis and exact current source revision, then
   appends one successor basis without rewriting the historical basis. Pin and reconciliation are
   separate private actions with separate code-owned capabilities, exact replay, audit, outbox,
   and stable concurrent conflict.
7. Enforce tenant-qualified source-revision and predecessor links, consecutive basis versions,
   writer-assigned recorded time, immutability, and one successor per basis through reviewed
   PostgreSQL constraints and triggers. An alternate writer cannot cross tenant/aggregate,
   reconcile to a stale source revision, branch the consumer chain, or mutate prior basis.
8. Prove success, exact and concurrent replay, changed-request/actor conflict, duplicate reversal,
   stale and racing reconciliation, missing capability/context, cross-tenant/cross-scope
   non-disclosure, event-without-authority denial, complete rollback after outbox insertion,
   exact operation/history reads, preserved pinned history, and corrected net quantity.
9. Generate and manually review the migration and snapshots, including compound tenant keys,
   self-reference ordering, rollback refusal after retained consumer basis, apply/rollback/reapply,
   and drift.
10. Add no automatic event dispatch or consumer mutation, follow-current durable decision,
    partial adjustment, reversal-of-reversal, retention/hold/erasure action, migration ledger,
    projection store, production runtime wiring, reusable temporal framework, business vocabulary,
    school module, UI, or public API.

T1-C may close the append-only branches of TR-01 through TR-05 and proves one deliberate
reconciliation mode. TR-06, TR-07, performance/recovery limits, accountable residual-risk review,
and the complete repository gate remain required before ADR 0018 Full Acceptance.

## Slice 1H-A independent module gates and activation

The authorized first module-lifecycle increment promotes only the release, entitlement,
activation, dependency, and actor-authorization contract already accepted by ADR 0001. It uses
one neutral declaration and synthetic tenant facts; it does not add a school module, commercial
entitlement service, deactivation drain, reactivation, or production runtime wiring.

1. Add an immutable Chimwemwe-owned release manifest whose declarations have stable module keys,
   versions, owners, and an acyclic dependency graph. Callers cannot supply a manifest through
   action input, and an invalid, duplicate, missing-dependency, or cyclic manifest fails closed.
2. Add closed tenant-owned `ModuleEntitlement` and `ModuleActivation` resources with non-null
   tenant keys, tenant-qualified uniqueness, and a compound entitlement relationship so an
   alternate writer cannot activate a module for another tenant or without its entitlement fact.
3. Add the private `ModuleActivation.activate_module` Ash action and expose it only through the
   Chimwemwe-owned `ModuleLifecycle.activate/4` boundary. Accept exactly module key, expected
   lifecycle version zero, idempotency key, and causation identifier; derive the released version,
   dependencies, actor, tenant, placement, routing, correlation, repository, and Ash options from
   trusted platform state.
4. Require the code-owned `platform.modules.activate` capability and recheck it on the selected
   authoritative writer while holding the tenant-and-module lifecycle lock. Verify release,
   entitlement, and every declared dependency independently before creating activation version 1.
5. Bind idempotency to tenant, action, actor, module key, released version, expected version, and
   causation identifier. Exact and concurrent retries return the committed activation; changed
   request or actor conflicts; a different key for an already active module is a stable conflict.
6. Atomically create the activation, one minimized audit fact, one versioned outbox fact, and the
   completed action-idempotency result. Activation grants no capability and neither evidence fact
   is release, entitlement, activation, placement, or authorization authority.
7. Add `ModuleLifecycle.authorize/5` as the ordinary server-side gate. It validates context before
   module lookup, uses the authoritative writer, and independently requires release availability,
   tenant entitlement, active compatible version, active dependencies, and the requested
   code-owned actor capability. It accepts no caller-selected gate state or repository options.
8. Prove each missing gate independently, successful activation followed by continued capability
   denial, the complete four-gate positive, missing/raw context, cross-tenant non-disclosure,
   dependency denial, alternate-write constraints, exact and changed replay, concurrent retry,
   tenant-isolated keys, and rollback after a post-outbox failure.
9. Generate and manually review the migration and resource snapshots, including tenant keys,
   module-key constraints, compound foreign keys, compatible table ordering, rollback order,
   apply/rollback/reapply, and drift.
10. Add no module deactivation, drain, queue or consumer state, retained-data action, reactivation,
    public or generic invocation, browser connection, provisioning resource, school vocabulary,
    business module, dispatcher, worker, or external service in this increment.

Slice 1H-A proves the independent gates and safe initial activation only. Slice 1H-B must still
prove deterministic deactivation versus ordinary work, drain/park behavior, mandatory work,
retained-data ownership, dependency-safe deactivation, compatible reactivation, replay, and
reconciliation before the production module-lifecycle gate is complete.

## Slice 1H-B controlled drain and reactivation

The separately authorized second lifecycle increment implements the remaining neutral lifecycle
state contract. It does not add a real queue, consumer, projection adapter, public lifecycle API,
entitlement workflow, or school module.

1. Expand the immutable release declaration with an optional normalized `compatible_from` set.
   Existing declarations default to their own version; reactivation may change version only when
   the installed version is explicitly compatible.
2. Keep `ModuleActivation` as the retained tenant-owned lifecycle aggregate. Expand it with
   non-negative consumer, replay, and reconciled cursors; positive projection generation;
   projection and reconciliation state; transition timestamps; and retained ownership fixed to
   `retained` by PostgreSQL.
3. Add closed tenant-owned `ModuleWorkItem` state with a compound tenant-qualified activation
   relationship. Model ordinary, audit, outbox, retention, legal-hold, and reconciliation work
   without adding a scheduler, dispatcher, consumer, or enqueueing API.
4. Add private named `deactivate_module`, `complete_mandatory_work`, and `reactivate_module`
   actions behind `ModuleLifecycle.deactivate/4`, `complete_mandatory_work/4`, and
   `reactivate/4`. Give deactivation, mandatory work, and reactivation distinct code-owned
   capabilities.
5. Add the internal mutation-side `authorize_current_transaction/4` gate. Require an existing
   writer transaction, take the same tenant-and-module transaction lock as lifecycle transitions,
   and re-evaluate release, entitlement, activation, dependencies, and actor capability before
   ordinary mutation proceeds.
6. Reject deactivation while a current-manifest dependent remains active. Serialize a racing
   dependent activation through the dependency activation row so either the dependency commits
   first and blocks deactivation or deactivation commits first and the dependency activation sees
   inactive state.
7. Deactivate atomically: require active state and exact lifecycle version, park queued or running
   ordinary work, preserve mandatory work, copy the consumer cursor to the replay boundary, mark
   projections stale, require reconciliation, close ordinary authority, and commit minimized
   audit, outbox, and exact idempotency evidence.
8. Permit only non-ordinary mandatory work completion while inactive. Keep its capability
   separate, retain the completed work item, advance the lifecycle version, and commit its state
   and evidence together without reopening ordinary authority.
9. Reactivate atomically only from inactive state with exact version, entitlement, compatible
   release, and active compatible dependencies. Requeue parked ordinary work from the replay
   boundary, record the reconciled cursor, increment projection generation, clear reconciliation
   state, and open ordinary authority only when every state and evidence write commits.
10. Prove both ordinary-mutation/deactivation lock orders, active-dependent rejection, queue and
    in-flight parking, mandatory audit/outbox/retention completion, retained ownership, exact
    replay, incompatible release denial, injected post-outbox rollback, cross-tenant database
    rejection, migration rollback refusal with retained 1H-B state, empty rollback/reapply, and
    generated migration/snapshot drift.

Slice 1H-B is a production-core state contract with synthetic facts. Real Oban/outbox adapters,
external consumers, cache or search invalidation, webhooks, analytical publications, projection
rebuilders, and placement-movement replay remain fail-closed production integration gates.

## Slice 1I-A governed presentation-definition contract

The authorized first governed-extension increment promotes the descriptor compatibility and
durable-definition boundary accepted by ADR 0019. It permits tenant-owned presentation choices
only; it does not add a renderer, metadata execution, custom fields, runtime schema mutation, a
workflow language, or a school business module.

1. Extend each code-owned module release declaration with an optional, versioned list of extension
   contract keys. Existing manifests default to no extension contracts, and malformed, duplicate,
   or unknown declarations fail closed.
2. Add a trusted immutable extension registry whose declarations bind one stable schema key and
   positive schema version to one released module, one contract-valid Ash resource, one explicit
   descriptor allowlist, and one supported presentation-definition kind. The registry derives the
   descriptor from code on construction and accepts no tenant, policy, repository, or executable
   input.
3. Implement only the first typed presentation schema: a bounded title, ordered unique allowlisted
   field references, bounded labels for those fields, and one allowlisted public read-action
   reference. Reject every extra, private, stale, authority-shaped, executable, or incompatible
   value. Derive the stored data classification from the highest referenced descriptor field.
4. Add a closed tenant-owned `ExtensionDefinition` aggregate with a compound tenant-qualified
   activation relationship, stable definition and schema keys, exact descriptor and module
   versions, validated JSON content, derived classification, positive lock version, and trusted
   actor attribution.
5. Add the private named `publish_definition` action behind a Chimwemwe-owned
   `GovernedExtension.publish_definition/5` boundary. Require exact input keys, validated context,
   a code-owned registry and manifest, the release-declared schema version, exact descriptor
   revision, module release/entitlement/activation/dependency gates, and the separate
   `platform.extensions.definitions.publish` capability.
6. Serialize publication with the module lifecycle lock and a tenant-definition lock. Expected
   version zero creates the caller-supplied stable definition UUID; a positive exact version
   revises the same aggregate. Stale versions, duplicate keys, cross-tenant IDs, inactive modules,
   and changed idempotency reuse fail without mutation.
7. Atomically commit the definition, minimized audit fact, minimal outbox fact, and completed
   exact-result idempotency claim. Neither evidence payload contains presentation labels or other
   definition content, and no stored definition grants read or mutation authority.
8. Prove strict validation, classification propagation, compatible create and revision, exact and
   concurrent replay, changed-request conflict, missing capability, every independent module gate,
   cross-tenant non-disclosure and database rejection, alternate-write constraints, post-outbox
   rollback, retained-state rollback refusal, empty rollback/reapply, and generated
   migration/snapshot drift.

Slice 1I-A creates no public API, browser connection, report dataset, renderer, generic metadata
executor, arbitrary SQL or code path, custom-field store, schema compiler, visual builder, client
authorization rule, provisioning surface, or education vocabulary. A later 1I increment requires
separate authorization before a real module or interface consumes the stored definition.

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
- The generic `ActionInvocation` boundary exports no write function; only the resource-specific `Authority.rename_role/3` and `Authority.assign_role/3` boundaries are added.
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
- All registered persistent platform resources are tenant-owned, contract-valid, and registered in the always-authorized actor-required domain. Module entitlement and modeled work state are action-closed, and module activation exposes only its private governed lifecycle actions.
- Direct and transitive capability grants resolve on the current writer and remain valid after a role rename.
- Missing membership, missing grant, malformed capability, raw or mismatched context, stale routing, and unavailable runtime fail closed without disclosing graph contents.
- Compound tenant foreign keys reject cross-tenant assignment, grant, and inclusion through alternate SQL writes.
- PostgreSQL rejects direct and indirect role cycles, and the surviving graph remains unchanged.
- Role rename requires the code-known capability, validated tenant context, positive expected version, idempotency key, and causation identifier.
- A successful rename increments the role version once and atomically records one audit fact, one minimal outbox fact, and one completed idempotency result.
- Exact and concurrent retries return the same committed result without duplicate facts; changed input or actor returns an idempotency conflict, and the same key is isolated between tenants.
- Unauthorized, stale-version, duplicate-name, cross-tenant, malformed-input, and raw-context requests fail with stable non-disclosing errors and leave no facts.
- A database failure after outbox insertion rolls back role state, audit, outbox, and idempotency together, after which the same request can succeed.
- Role assignment requires the code-known capability, validated tenant context, existing tenant-qualified membership and role, an idempotency key, and a causation identifier.
- A successful assignment creates one version-1 edge and atomically records one creation audit fact, one minimal outbox fact, and one action-neutral completed idempotency result.
- Exact and concurrent assignment retries return the same result without duplicate edges or facts; changed input or actor conflicts, a different key for the same edge conflicts, and the same key remains tenant-isolated.
- Unauthorized, cross-tenant, malformed-input, and raw-context assignment requests fail with stable non-disclosing errors and leave no action facts.
- Alternate SQL cannot create a cross-tenant assignment or a non-positive assignment version.
- A database failure after assignment outbox insertion rolls back the edge, audit, outbox, and idempotency together, after which the same request succeeds.
- Temporal publication and correction require distinct code-known capabilities, validated tenant context, bounded normalized segments, stable reason, idempotency and causation identifiers, and the exact expected current revision for correction.
- Publication and correction generate immutable operation, revision, and segment identities on the writer; writer time, the current selector, audit, outbox, and exact completed result commit or roll back together.
- Exact and concurrent temporal retries return the same complete result without duplicate state or evidence; changed request or actor conflicts, tenant keys remain isolated, and racing different corrections against one expected revision cannot branch.
- Missing capability/context, cross-tenant references, history-disclosure attempts, unknown input, invalid/overlapping intervals, and alternate physical writes fail closed without surviving action evidence.
- Named current/effective reads require current-read capability, exact/history reads require history capability, history is bounded with explicit truncation, and recorded-time reads fail explicitly after authorization.
- T1-B adds no reversal action, retention/hold/erasure action, consumer, import, recovery, public interface, UI connection, common temporal library, or school module, and does not mark TR-01 through TR-07 complete.
- The trusted release manifest rejects duplicate, missing-dependency, cyclic, malformed-key, and malformed-version declarations and cannot arrive through action input.
- Module release, tenant entitlement, compatible activation, active dependencies, and actor capability are required independently; activation grants no capability.
- Initial activation requires trusted context, the code-owned management capability, entitlement, dependency compatibility, lifecycle version zero, idempotency, and causation, while accepting no caller-selected tenant, placement, repository, release, gate, actor, or Ash option.
- Exact and concurrent activation retries return one committed result; changed input or actor conflicts, the same key is tenant-isolated, and a different key cannot duplicate an active module.
- Activation, minimized audit, transactional outbox, and completed idempotency evidence commit or roll back together; post-outbox failure leaves no facts and the same request can retry safely.
- Compound tenant foreign keys and database checks reject cross-tenant entitlements, malformed keys or versions, inactive state, and non-positive lifecycle versions through alternate writes.
- Slice 1H-A adds no entitlement-management API, deactivation, drain, queue or consumer lifecycle, retained-data action, reactivation, public invocation, browser connection, provisioning resource, or school module.
- Deactivation rejects an active dependent and atomically closes ordinary authority, parks queued or running ordinary work, records the replay cursor, marks the projection stale, requires reconciliation, and retains tenant state.
- Ordinary mutations and deactivation take the same lifecycle transaction lock; both forced lock orders have one deterministic winner and the waiting path re-evaluates current lifecycle state.
- Audit, outbox, retention, legal-hold, and reconciliation work cannot be parked as ordinary work and may complete while inactive only through the separate mandatory-work capability.
- Reactivation requires the exact inactive version, current entitlement, an explicitly compatible release, and active compatible dependencies; it records the reconciled cursor, requeues parked work, increments projection generation, and opens authority atomically.
- Deactivation, mandatory-work completion, and reactivation bind exact idempotent replay to tenant, action, actor, aggregate, canonical request, and causation, with audit and outbox facts in the same transaction.
- PostgreSQL rejects cross-tenant work references, unknown work or lifecycle states, parked mandatory work, negative cursors, inconsistent activation state, non-positive projection versions, and implicit release of retained ownership.
- Slice 1H-B adds no entitlement-management or offboarding workflow, retained-data read/export/correction/deletion action, real queue/consumer/projection adapter, public invocation, browser connection, provisioning surface, or school module.
- A module release declares governed extension contracts by stable key and positive schema version; existing declarations remain compatible and default to none.
- A trusted extension registry derives exact descriptors only from contract-valid resources and explicit code-owned allowlists, and rejects duplicate, malformed, unsupported, or non-tenant-owned declarations.
- Presentation content accepts only a bounded title, ordered allowlisted fields, labels for those fields, and one allowlisted public read action; private, stale, executable, authority-shaped, extra, and incompatible content fails closed.
- Stored definition classification is derived from the highest referenced field and cannot be selected or lowered by the caller.
- Definition publication requires validated tenant context, the release-declared extension contract, an active compatible module with active dependencies and entitlement, and the separate code-known publication capability.
- Create and revision use exact optimistic versioning and exact idempotent replay; changed request or actor, stale version, duplicate key, inactive module, missing capability, and cross-tenant references leave no definition or evidence residue.
- Definition state, minimized audit, minimal outbox, and completed idempotency evidence commit or roll back together, and retained definition content is absent from audit and outbox payloads.
- Compound tenant constraints reject cross-tenant activation references, while database checks reject malformed keys, invalid descriptor revisions, unknown classifications, non-positive versions, and non-object content.
- Slice 1I-A adds no renderer, execution path, custom fields, runtime schema or workflow language, generic metadata mutation, public interface, browser connection, provisioning surface, or school module.
- The reviewed migration applies, rolls back, reapplies, and passes generated migration and snapshot drift checks.
- Complete repository acceptance still requires `make check` and the Phase 0 exit review to pass;
  the current run stops on stale UI-1A dependency/security and clean-checkout evidence.

## Rollback and next gate

Slice 1A can be removed by deleting the root umbrella files, `apps/chimwemwe_core`, and its Phase 1 documentation and validator allowance while retaining all Phase 0 evidence. The execution-context, explicit-ownership, and named-action concepts survive an Ash fallback because they depend on platform trust semantics rather than an Ash resource.

Slice 1E can be rolled back by removing the repository runtime, AshPostgres dependency, migration baseline, and its tests while retaining the framework-neutral context and admission contracts from 1A-1D. Slice 1F can be rolled back before retained production data by removing its closed resources, resolver, migration/snapshots, and tests. Slice 1G-A and 1G-B can likewise be rolled back only while their role changes, assignments, and evidence tables contain no retained data. Once authority rows or action facts exist outside synthetic development, rollback must use forward repair or an approved recovery point rather than dropping or rewinding authority state.

Slice 1H-A can roll back only while entitlement, activation, and associated audit, outbox, and idempotency facts are absent. The migration enforces that boundary. Once any such fact is retained, lifecycle removal requires forward repair or an approved recovery point; dropping the tables is prohibited.

Slice 1H-B can roll back to the 1H-A schema only while no modeled work or 1H-B transition evidence
exists and every activation still has its pristine active cursor, projection, reconciliation, and
lifecycle state. The migration enforces that boundary. Once 1H-B state is retained, use forward
repair or an approved recovery point; deactivation is never permission to drop module data.

Slice 1I-A can roll back only while no governed definition exists and no publication audit,
outbox, or idempotency fact is retained. Once a definition has been published, descriptor or
schema evolution uses compatible forward migration and explicit revision; dropping definitions
or silently rewriting their pinned contract is prohibited.

The role-rename, role-assignment, temporal-qualification, and module-lifecycle increments prove
bounded resource-specific contracts. They do not authorize membership or role creation,
capability grant, composition, revoke, public write invocation, outbox dispatch, entitlement
expiry, offboarding, retained-data deletion, provisioning, a real queue/consumer/projection
adapter, or a school module. The next module-lifecycle work is real-adapter and operational
qualification inside a separately authorized production-readiness boundary. The Phase 0
descriptor artifact, report registry, and governed experience-metadata implementation remain
disposable evidence and are not production APIs. Slice 1I-A may promote only its newly reviewed
registry, validator, and durable definition boundary; it does not promote the spike report
executor or renderer. Do not add a school business module until an explicit module slice is
authorized.
