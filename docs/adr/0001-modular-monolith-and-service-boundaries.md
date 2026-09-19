# ADR 0001: Modular monolith and permitted service boundaries

- Status: Accepted
- Date: 2026-09-13
- Decision date: 2026-09-16
- Accountable owner: Architecture review group
- Deciders: Architecture review group and product owner
- Supersedes: None

## Context

The platform needs strong transactional coherence and a foundation that a small team and coding agents can extend without creating distributed ownership or policy gaps. Schools also need different combinations of business capabilities without creating tenant-specific releases, policy engines, or service topologies.

## Decision drivers

- One authoritative policy and transaction boundary.
- Low operational burden and explicit module ownership.
- Specialized runtimes only where capability or isolation requires them.
- One immutable product release with governed per-tenant module lifecycle.
- A clear separation between release availability, commercial entitlement, tenant activation, and actor authorization.

## Considered options

1. Phoenix/Ash/PostgreSQL modular monolith with a small kernel, bounded business modules, common release, tenant activation, and bounded supporting planes.
2. Per-domain microservices and independently deployed module releases from the start.
3. One unstructured application with no enforced module boundaries or lifecycle contract.
4. Customer-specific branches or dynamically loaded tenant code.

## Decision

Adopt a Phoenix/Ash/PostgreSQL modular monolith as the authoritative core. Its small mandatory kernel owns tenant and actor context, authorization, audit, typed configuration, module lifecycle, events, jobs, files, API conventions, localization, and shared experience contracts. Bounded business modules own their domain state and behaviour. Permit separate web delivery, scheduling, AI, analytics, and hardened utility runtimes only behind versioned contracts and without independent domain authority.

All approved module code ships in one immutable product release. Each tenant may activate an entitled subset, but release availability, entitlement, activation, and actor authorization are independent server-side gates. Activation never grants actor capabilities.

Activation and deactivation are named, auditable, idempotent actions. Dependencies are explicit and acyclic. Deactivation rejects new ordinary module work, drains or parks in-flight work under declared rules, retains protected data, and preserves required audit, outbox, retention, legal-hold, export, and recovery paths. It never drops shared tables or erases tenant data implicitly.

Tenant variation uses tenant-defined roles and access domains, typed configuration, governed profiles, localization, and approved integrations. Customer-specific branches, copied modules, arbitrary tenant code, and tenant-selected deployment units are prohibited.

## Consequences

### Positive

- Transactions, policy, audit, and migrations remain coherent.
- Modules can evolve without network boundaries.
- One release and one lifecycle contract reduce tenant-specific drift.
- Inactive modules remain governed without confusing activation with authorization.

### Negative

- Internal boundaries require architecture tests and disciplined ownership.
- Specialized workloads still need explicit contracts and operations.
- Common-release module code remains part of the security and dependency attack surface even when inactive.
- Safe deactivation, dependency evolution, retained-data access, and reactivation require explicit design and tests.

## Security, privacy, operability, and migration effects

One core reduces distributed authorization drift. Every supporting plane must propagate actor and tenant context, tolerate core unavailability, and avoid owning authoritative school state. Lifecycle gates apply consistently to HTTP, generated APIs, jobs, events, files, reports, search, analytics, webhooks, telemetry, and AI tools.

Module boundaries, deployment cells, and tenant database placements are orthogonal. A module is not promoted to a service or separate database merely because one tenant activates it.

## Validation evidence

See [service boundaries](../architecture/service-boundaries.md), [module activation and lifecycle](../architecture/module-activation-and-lifecycle.md), [module-lifecycle evidence](../phase-0/evidence/module-lifecycle.md), and the [Phase 0 architecture review record](../phase-0/review-record.md). The neutral synthetic lifecycle test proves independent gates, dependency handling, both concurrent deactivation lock orders, safe modeled job/event drain, retained-data access, and compatible reactivation. The 2026-09-16 review accepts the architecture contract while carrying real queue/outbox, idempotency, drain/replay, reconciliation, and operational ownership into the first production-module gate.

## Fallback and exit cost

Extract a capability only after measured isolation, scaling, lifecycle, or runtime needs justify it. Extraction requires an ADR, versioned contract, data-ownership plan, and rollback path. If the common-release lifecycle proves unmanageable, replace it through a superseding ADR rather than introducing tenant branches.

## Review triggers

- A capability cannot meet an accepted requirement inside the core.
- Team or deployment topology materially changes.
- Module activation, dependency, entitlement, drain, or retained-data semantics change.
- A tenant-specific variation cannot be expressed safely through governed data and profiles.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0015](0015-ai-gateway-tool-exposure-and-evaluation-policy.md)
- [ADR 0016](0016-scheduling-service-contract-and-publication-boundary.md)
