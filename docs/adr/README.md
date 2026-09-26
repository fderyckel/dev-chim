# Architecture decision records

- Status: Active process
- Owner: Architecture review group

ADRs record decisions that shape stable platform boundaries. Every record starts Proposed. Only named deciders may accept it after reviewing linked evidence.

## Process

1. Copy [ADR 0000](0000-template.md) and allocate the next reserved number from the source backlog.
2. Fill every section, including alternatives, negative consequences, validation, fallback, and review triggers.
3. Add the record to this index. Add it to the Phase 0 decision register only when it is governed by the completed Phase 0 review.
4. Gather evidence before acceptance.
5. Supersede an Accepted decision with a new ADR; do not rewrite its outcome.

## Index

| ADR | Title | Status | Owner | Evidence |
| --- | --- | --- | --- | --- |
| [0000](0000-template.md) | ADR template | Template | Architecture review group | Not applicable |
| [0001](0001-modular-monolith-and-service-boundaries.md) | Modular monolith and permitted service boundaries | Accepted | Architecture review group | Context, boundary, and module-lifecycle review |
| [0002](0002-ash-adoption-criteria-and-fallback.md) | Ash adoption criteria and fallback | Conditionally Accepted | Platform engineering | Ash pressure-test |
| [0003](0003-tenant-model-and-optional-postgresql-rls.md) | Tenant model, placement profiles, and optional PostgreSQL RLS | Conditionally Accepted | Security architecture | Threat model, routing, tenancy, capacity, movement, and recovery tests |
| [0005](0005-domain-action-and-state-transition-convention.md) | Domain action and state-transition convention | Accepted | Platform engineering | Named-action spike tests |
| [0007](0007-transactional-outbox-and-event-envelope.md) | Transactional outbox and event envelope | Accepted | Platform engineering | Atomic rollback test |
| [0009](0009-cache-taxonomy-invalidation-and-valkey-trigger.md) | Cache taxonomy, invalidation, and Valkey trigger | Accepted | Platform engineering | Classification and trigger review |
| [0010](0010-file-ownership-storage-pipeline-and-external-drives.md) | File ownership, storage pipeline, and external drives | Conditionally Accepted | Platform engineering and security | Threat model |
| [0012](0012-report-templates-gotenberg-and-campaign-model.md) | Report templates, Gotenberg, and campaign model | Deferred | Platform engineering and operations | Capacity scenario |
| [0014](0014-primary-api-and-generated-typescript-client.md) | Primary API and generated TypeScript client | Conditionally Accepted | Platform and web engineering | Generated API spike |
| [0015](0015-ai-gateway-tool-exposure-and-evaluation-policy.md) | AI gateway tool exposure and evaluation policy | Deferred | Security architecture | AI threat model |
| [0016](0016-scheduling-service-contract-and-publication-boundary.md) | Scheduling service contract and publication boundary | Deferred | Platform and scheduling engineering | Contract review |
| [0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md) | PostgreSQL availability, recovery, and consistency-aware read routing | Accepted | Platform engineering and operations | Availability, burst, lag, failover, connection, and restore evidence |
| [0018](0018-temporal-records-correction-audit-and-evidence-semantics.md) | Temporal records, correction, audit, and evidence semantics | Conditionally Accepted | Platform engineering and domain records owners | [Decision review](../architecture/temporal-records-decision-review.md) and [T1-C evidence](../phase-1/evidence/temporal-qualification-fact-and-reconciliation.md); TR-06, TR-07, final limits/review, and TR-08 restraint remain binding |
| [0019](0019-domain-model-authoring-and-governed-metadata.md) | Domain model authoring and governed metadata | Accepted | Platform engineering | [Authoring and metadata scenario](../phase-0/evidence/resource-authoring-and-governed-metadata.md) |
| [0020](0020-human-interface-experience-and-client-platform-boundary.md) | Human-interface experience and client-platform boundary | Conditionally Accepted | Product experience and platform engineering | Journey research, prototypes, accessibility checks, and public-client contract tests |
| [0021](0021-academic-calendar-authority-and-template-adoption.md) | Academic calendar authority and template adoption | Proposed | Product and platform engineering | [Synthetic scenario review](../architecture/academic-calendar-synthetic-scenario-review.md); stakeholder, migration, security, and interaction evidence required |
| [0022](0022-local-read-only-browser-core-bridge.md) | Local read-only browser-to-core bridge | Proposed | Product experience and platform engineering | [UI-1A local interface, tenant-isolation, generated-client, and browser evidence](../phase-1/evidence/local-browser-core-bridge.md); representative user review required |
| [0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md) | Sensitive-collection enumeration and bulk-export boundary | Proposed | Security architecture with platform and product engineering | Page-limit, adversarial traversal, cumulative-exposure, export-authorization, OpenAPI, and generated-client evidence required |
| [0024](0024-assurance-proportionality-and-module-evolution.md) | Assurance proportionality and module evolution | Proposed | Architecture review group | Representative module and external-boundary classification evidence required |
| [0025](0025-learning-institution-operating-system-and-institutional-structure.md) | Learning-institution operating system and recursive institutional structure | Proposed | Product and institutional-structure domain ownership | Cross-context structure, hierarchy-safety, authorization-separation, migration, and experience evidence required |

Allowed decision statuses are Proposed, Accepted, Conditionally Accepted, Rejected, Superseded, and Deferred. `Template` is reserved for ADR 0000.
