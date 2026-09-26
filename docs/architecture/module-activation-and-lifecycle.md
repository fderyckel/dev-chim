# Module activation and lifecycle

- Status: Accepted architecture contract; Phase 1 Slices 1H-A and 1H-B implemented
- Owner: Architecture review group with platform and product engineering
- Governing record: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md)
- Review trigger: module contract, entitlement, activation, dependency, or deactivation semantics change

## Fit with the original design

The original modular-monolith decision already separates a small platform kernel, bounded business modules, and specialized supporting planes. Tenant activation makes that modularity operational without turning modules into microservices, deployments, customer branches, or independent policy engines.

The mandatory kernel owns tenant and actor context, authorization, audit, configuration, module lifecycle, events, jobs, files, API conventions, localization, and shared experience contracts. Business modules own their domain language and state. Specialized services remain replaceable clients of core contracts and never gain independent domain authority.

## Four independent gates

Every server-side entry point evaluates four separate questions:

1. Release availability: does the immutable product release contain a compatible module version?
2. Entitlement: does the tenant's current contract permit the capability?
3. Activation: has the tenant deliberately activated the module and satisfied its dependencies and configuration?
4. Authorization: may this actor perform this named action on these records and fields for this purpose now?

Passing one gate never implies another. Navigation and route hiding are user-experience consequences, not enforcement. A disabled or unentitled module cannot be made available by a client parameter, and activation never creates actor permissions.

## Common release and tenant variation

Approved module code ships in the common, immutable release. Tenant differences come from:

- tenant-defined hierarchical, nested, renameable, and composable roles and access domains;
- module activation;
- typed, effective-dated configuration;
- governed calendar, curriculum, evidence, documentation, and workflow profiles;
- localized terminology and translations; and
- approved integrations.

Tenant-specific branches, copied modules, dynamic tenant code, and arbitrary scripts inside the ERP process are prohibited. Code for an inactive module still belongs to the release attack surface and must pass dependency, static-analysis, migration, and security gates.

## Lifecycle contract

Activation and deactivation are named, auditable domain actions with optimistic concurrency, idempotency, and explicit outcomes. Before activation, the platform validates entitlement, module and platform version compatibility, dependency state, required typed configuration, migration readiness, and operational quotas.

Dependencies form a versioned acyclic graph. A dependency activates first. Deactivation is rejected while an active dependent requires the module unless an explicit, reviewed cascade plan exists.

Deactivation is a controlled drain, not a table drop or an immediate kill switch:

- reject new operational mutations and new scheduled work at the domain boundary;
- define whether each in-flight request finishes, cancels, or compensates;
- drain, cancel, or park queued work according to its idempotency and data-integrity contract;
- continue mandatory security, audit, retention, deletion, reconciliation, and outbox processing;
- stop module-specific event consumption only after its cursor and replay position are recorded safely;
- invalidate or retire routes, navigation, caches, search projections, webhooks, and analytical publications coherently; and
- retain protected data according to retention, correction, legal-hold, recovery, and contractual rules.

Retained data does not become ownerless. Explicit, authorized read, export, correction, retention, and reactivation actions remain available where policy or law requires them. Deactivation, entitlement expiry, and tenant offboarding are distinct workflows.

Reactivation validates compatibility, resumes from recorded cursors, rebuilds disposable projections, and reconciles state before opening ordinary actions. It must not assume that retained data matches the newest module version.

## Required module declaration

Every later module contract declares:

- stable module identifier, owner, version, and dependencies;
- activation prerequisites and typed configuration;
- entitlement keys without embedding commercial rules in authorization policies;
- server-side action, route, API, job, event-consumer, cache, file, search, report, analytics, and AI gates;
- data ownership, classification, retention, correction, export, offboarding, and reactivation behaviour;
- drain, cancellation, compensation, replay, and reconciliation rules;
- telemetry and audit events for every lifecycle transition; and
- positive, negative, concurrency, dependency, and recovery tests.

## Phase 1 Slice 1H-A boundary

Slice 1H-A implements the smallest persistent production-core proof of the four independent
gates. A trusted, immutable release manifest declares stable module keys, versions, owners, and
an acyclic dependency graph. Closed tenant-owned entitlement and activation resources persist
tenant state. They do not provide an entitlement-management surface.

`Chimwemwe.Platform.ModuleLifecycle.activate/4` is the only initial-activation boundary. It
validates trusted context before action input, derives the released version and dependencies from
the trusted manifest, requires `platform.modules.activate` on the authoritative writer, locks the
tenant-and-module lifecycle scope, verifies entitlement and active dependencies independently,
and invokes one private named Ash action. The transaction creates activation version 1 together
with one minimized audit fact, one transactional outbox fact, and one exact idempotency result.

`ModuleLifecycle.authorize/5` is the ordinary use gate. It independently requires that the module
is released, entitled, active at the released version, dependency-compatible, and permitted by
the requested code-owned actor capability. Activating a module therefore grants no actor
capability. Neither the client nor action input can select tenant, repository, release state,
entitlement, activation, dependencies, actor, or Ash authorization options.

At Slice 1H-A completion there was no commercial entitlement workflow, deactivation, drain,
reactivation, retained-data action, public interface, provisioning flow, or business module.
Slice 1H-B separately adds only the neutral drain and reactivation proof below.

## Phase 1 Slice 1H-B boundary

Slice 1H-B implements the remaining neutral lifecycle state contract. The persistent activation
aggregate remains the owner of its lifecycle state after deactivation and records consumer,
replay, and reconciled cursors; projection generation and readiness; reconciliation state; and
retained ownership. A closed tenant-qualified work resource models ordinary and mandatory work
states without becoming a scheduler or queue implementation.

Deactivation and ordinary mutations use the same tenant-and-module transaction lock. Deactivation
rejects an active dependent, closes ordinary authority, parks queued or running ordinary work,
retains mandatory work, records the replay boundary, and marks disposable projections stale in
one exact-versioned transaction with audit, outbox, and idempotency evidence. A mutation that
wins the lock commits before drain; a mutation that waits behind deactivation rechecks the gates
and fails inactive.

Mandatory audit, outbox, retention, legal-hold, and reconciliation work uses a separate private
action and capability and does not reopen ordinary authority. Compatible reactivation requires
current entitlement and dependencies plus an explicit release-owned `compatible_from` rule. It
requeues parked work from the recorded cursor, records reconciliation, increments projection
generation, and opens ordinary authority only when every authoritative and evidence write commits.

The slice proves this state contract with synthetic facts. It adds no real Oban/outbox adapter,
external consumer, cache/search/webhook/analytics integration, projection rebuilder, entitlement
expiry, offboarding, retained-data access or deletion workflow, public interface, provisioning
flow, or business module. See the
[Slice 1H-B evidence](../phase-1/evidence/module-lifecycle-drain-reactivation.md).

## Phase 0 boundary and evidence

Phase 0 recorded and pressure-tested the lifecycle contract only. It did not create a production
module registry, entitlement service, UI, or school business module. Slices 1H-A and 1H-B now
promote the trusted declaration, closed entitlement/activation/work state, initial activation,
ordinary gates, controlled drain, mandatory work, and compatible reactivation described above.

Before this decision is accepted, a neutral synthetic module must prove that:

- activation does not grant a capability;
- an authorized actor is still denied when entitlement or activation is absent;
- request parameters cannot bypass any gate;
- dependency activation and deactivation rules fail closed;
- concurrent deactivation and mutation have one deterministic outcome;
- jobs and events do not continue with ordinary module authority after deactivation;
- required audit, retention, and outbox work is not lost during drain; and
- no lifecycle transition drops or implicitly erases retained tenant data.
