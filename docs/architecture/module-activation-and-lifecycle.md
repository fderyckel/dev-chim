# Module activation and lifecycle

- Status: Accepted architecture contract; Phase 1 Slice 1H-A initial activation implemented
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

This slice adds no commercial entitlement workflow, deactivation, drain, reactivation, retained
data action, public interface, provisioning flow, or business module. Those remain explicitly
separate work, beginning with the bounded Slice 1H-B lifecycle proof.

## Phase 0 boundary and evidence

Phase 0 recorded and pressure-tested the lifecycle contract only. It did not create a production module registry, entitlement service, UI, or school business module. Slice 1H-A now promotes only the trusted declaration, closed entitlement/activation state, initial activation, and ordinary gate described above.

Before this decision is accepted, a neutral synthetic module must prove that:

- activation does not grant a capability;
- an authorized actor is still denied when entitlement or activation is absent;
- request parameters cannot bypass any gate;
- dependency activation and deactivation rules fail closed;
- concurrent deactivation and mutation have one deterministic outcome;
- jobs and events do not continue with ordinary module authority after deactivation;
- required audit, retention, and outbox work is not lost during drain; and
- no lifecycle transition drops or implicitly erases retained tenant data.
