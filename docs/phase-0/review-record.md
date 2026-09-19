# Phase 0 architecture review record

- Status: Completed
- Review date: 2026-09-16
- Accountable approver: François — Project Owner
- Next condition review: 2026-12-15, or earlier at the first affected production gate

## Participants

- Architecture: François — Project Owner and Architecture Owner
- Platform engineering and Ash: François — interim Platform Owner
- Security/privacy: François — interim owner; an independent reviewer must be named before real restricted child or school data is used
- Product/operations: François — interim owner; a school-side records/governance owner must be named before a production pilot

This is an early-stage owner review, not an independent security certification. The lack of separate people is recorded explicitly rather than represented as review independence.

## Evidence reviewed

- ADR index and decision register.
- Ash pressure-test scorecard and commands.
- Versioned generated-interface routes, the complete public error taxonomy and retry headers, keyset pagination, transactional idempotency, and checked-in OpenAPI/TypeScript client drift evidence.
- Tenant-defined authorization graph, cycle, field-policy, and relationship-policy evidence.
- Threat model, abuse cases, and residual risks.
- The [accepted numeric quality targets](evidence/quality-targets-approval.md).
- Tenant-placement capacity profile, five-school planning hypothesis, routing/movement tests, and recovery evidence.
- PostgreSQL availability, consistency routing, connection budget, synchronized-burst, failover, replica-lag, point-in-time-restore evidence, and the [combined local result](evidence/capacity-and-recovery-measurement.md), including its preserved failed raw noisy-tenant gate.
- The passing [pre-checkout admission](evidence/precheckout-admission-measurement.md) and [full-horizon restore](evidence/full-horizon-restore-measurement.md). The former AWS topology is retained only as a [withdrawn historical example](evidence/managed-postgresql-topology.md); provider selection and deployment qualification are outside Phase 0.
- Module lifecycle, dependency, deactivation-drain, retained-data, and reactivation evidence.
- Retained-data expand/contract, lock-budget, mixed-version, tenant-batch, validation, irreversible-cleanup, and three-run annual-envelope measurement evidence.
- Patch and non-patch dependency upgrades, test and maintenance ergonomics, seeded and isolated runs, the dependency-warning zero-delta baseline, the owned-boundary manifest, and the [bounded-condition disposition](evidence/ash-bounded-condition-disposition.md).
- Resource-authoring, descriptor evolution, governed view/report metadata, and forbidden-reference evidence.
- The passing [clean-checkout bootstrap and `make check` rehearsal](evidence/clean-checkout-rehearsal.md).

## Decisions

| ADR | Outcome | Review rationale |
| --- | --- | --- |
| 0001 | Accepted | Use a modular monolith as the authoritative core; later services remain bounded and non-authoritative. |
| 0002 | Conditionally Accepted | Use Ash as the default core framework subject to the eight fail-closed production gates below. |
| 0003 | Conditionally Accepted | Accept logical tenancy and trusted routing; defer physical placement and optional RLS activation to production evidence. |
| 0005 | Accepted | Named actions, stable errors, concurrency, idempotency, and transaction semantics are foundational contracts. |
| 0007 | Accepted | State and minimal durable side-effect facts use a transactional outbox. |
| 0009 | Accepted | Use explicit tenant/version-aware cache classes; do not add Valkey without measured need. |
| 0010 | Conditionally Accepted | Accept file ownership, quarantine, and namespace rules; defer storage provider and external connectors. |
| 0012 | Deferred | Retain campaign requirements but choose a renderer only in the report phase. |
| 0014 | Conditionally Accepted | Use JSON:API/OpenAPI and generated TypeScript with bounded, owned edge adapters. |
| 0015 | Deferred | No AI gateway, provider, tool, or data-class selection is made in Phase 0. |
| 0016 | Deferred | Choose a solver only after a deterministic scheduling fixture exists. |
| 0017 | Accepted | Use a provider-neutral PostgreSQL writer, recovery, connection-budget, and consistency contract; hosting qualification is later infrastructure work. |
| 0019 | Accepted | Code-defined domain authority with derived, allowlisted, non-authorizing metadata is the stable boundary. |
| 0020 | Conditionally Accepted | Use responsive browser-first TypeScript/React; native Expo remains evidence-triggered. |

Deferred means a deliberate decision not to select or build the capability now. It is not missing Phase 0 work.

## Ash outcome

Ash is **Conditionally Accepted** as the default framework for the authoritative application core. The project will not maintain Ash and Phoenix/Ecto as competing production architectures. Explicit Phoenix/Ecto or SQL implementations remain permitted only inside inventoried adapters that preserve trusted context, Ash authorization, tenant constraints, named actions, transaction semantics, audit/outbox, and stable errors.

A failed condition blocks the affected capability. If the exceptions become pervasive or weaken a mandatory platform invariant, ADR 0002 must be superseded and the affected capability must use the explicit Phoenix/Ecto domain-service fallback.

## Conditions, owners, and expiry

The exact verification and fallback contract is recorded in the [bounded-condition disposition](evidence/ash-bounded-condition-disposition.md). All eight conditions are accepted with the following accountable assignment:

| Condition | Accountable person | Deadline | Expiry/review |
| --- | --- | --- | --- |
| Transaction-backed non-atomic action | François — Platform Owner | Before the first production state transition uses it | 2026-12-15 or the production gate, whichever is earlier |
| Dynamic-repository SQL | François — Platform Owner | Before an adapter is promoted to production | 2026-12-15 or the production gate, whichever is earlier |
| Page-limit edge adapter | François — Platform Owner | Before a generated public list route ships | 2026-12-15 or the production gate, whichever is earlier |
| Failure-header edge adapter | François — Platform Owner | Before the public error contract ships | 2026-12-15 or the production gate, whichever is earlier |
| OpenAPI contract modifier | François — Platform Owner | Before a production client is generated | 2026-12-15 or the production gate, whichever is earlier |
| Retained-data migration choreography | François — Platform Owner | Before a retained-data contraction | 2026-12-15 or the production gate, whichever is earlier |
| Resource descriptor and metadata validator | François — Platform Owner | Before a production metadata consumer or store | 2026-12-15 or the production gate, whichever is earlier |
| Tenant movement and non-HTTP routing | François — Platform Owner | Before a durable registry, movement operation, or non-HTTP adapter | 2026-12-15 or the production gate, whichever is earlier |

If a condition reaches its review date without passing, it is not silently renewed: the dependent capability remains blocked until the condition is verified, amended by a new review, or replaced by its recorded fallback.

## Security and module-lifecycle outcome

The threat model is accepted as the Phase 0 engineering baseline, not as production certification. No unresolved high or critical risk is accepted into production merely because its later test is planned. Real restricted data remains prohibited until a named independent security/privacy reviewer completes the relevant challenge and the capability-specific negative tests pass.

The module-lifecycle contract is accepted. Release availability, entitlement, tenant activation, dependencies, and actor authorization remain separate gates. Production module activation additionally requires idempotency, real queue/outbox drain and replay, reconciliation, and a named operational owner. Cascade deactivation is not approved.

## Provider and infrastructure decision

AWS is not selected and its earlier technical estimate is withdrawn. Phase 0 accepts a provider-neutral PostgreSQL contract. Self-managed, European cloud, VM, bare-metal, managed PostgreSQL, or another deployment may be evaluated later. The selected deployment must pass the accepted capacity, fairness, backup, restore, failover where claimed, residency, and recovery gates before carrying production data.

## Phase 1 authorization

Phase 0 is complete, and the repository exit check confirms this record and the decided ADR statuses. Phase 1 foundation work may proceed incrementally under the accepted ADRs and explicit slice authorization. This review does not automatically authorize a school business module, public deployment, real school data, external service, or production infrastructure.
