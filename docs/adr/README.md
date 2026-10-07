# Architecture decision records

- Status: Active process
- Owner: Architecture review group

ADRs record decisions that shape stable platform boundaries. Every record starts Proposed. Only named deciders may accept it after reviewing linked evidence.

## Document responsibilities

Each ADR owns its decision, rationale, alternatives, conditions, and approval history. This index
summarizes those records. [Architecture guides](../architecture/README.md) explain how decisions
fit together and supply detailed implementation contracts; they link to the governing ADR for
decision status and rationale. Evidence records retain tests, measurements, and reviews, while
phase records and delivery plans track implementation progress and next steps.

Keep each contract and calculation in one authoritative location and link to it elsewhere.
Short summaries may aid readers, but must not become separately maintained decisions or statuses.

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
| [0018](0018-temporal-records-correction-audit-and-evidence-semantics.md) | Temporal records, correction, audit, and evidence semantics | Accepted | Platform engineering and domain records owners | [Decision review](../architecture/temporal-records-decision-review.md), [T1-C evidence](../phase-1/handover-evidence.md), and [Slice 2.0-C evidence](../phase-2/temporal-completion-and-recovery-evidence.md); neutral TR-01–TR-07 engineering and accountable residual-risk review are complete, while TR-08 remains a binding library restraint |
| [0019](0019-domain-model-authoring-and-governed-metadata.md) | Domain model authoring and governed metadata | Accepted | Platform engineering | [Authoring and metadata scenario](../phase-0/handover-evidence.md) |
| [0020](0020-human-interface-experience-and-client-platform-boundary.md) | Human-interface experience and client-platform boundary | Conditionally Accepted | Product experience and platform engineering | Journey research, prototypes, accessibility checks, and public-client contract tests |
| [0021](0021-academic-calendar-authority-and-template-adoption.md) | Academic calendar authority and explicit adoption | Conditionally Accepted | Product and platform engineering | Project Owner authorized bounded synthetic L1 on 2026-10-03; executable candidate validation/resolution tests pass; institutional/operator writer, persistence, representative review, migration, security, and connected experience evidence remain |
| [0022](0022-local-read-only-browser-core-bridge.md) | Local read-only browser-to-core bridge | Conditionally Accepted | Product experience and platform engineering | [UI-1A local interface, tenant-isolation, generated-client, and browser evidence](../phase-1/handover-evidence.md) passed; representative school-user terminology/usability review and the local-only sunset boundary remain conditions |
| [0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md) | Sensitive-collection enumeration and bulk-export boundary | Conditionally Accepted | Security architecture with platform and product engineering | Non-enumeration and separate-export policy accepted; page-limit, adversarial traversal, cumulative-exposure, export-authorization, OpenAPI, generated-client, and independent-review evidence remain per-candidate gates |
| [0024](0024-assurance-proportionality-and-module-evolution.md) | Assurance proportionality and module evolution | Proposed | Architecture review group | Representative module and external-boundary classification evidence required |
| [0025](0025-learning-institution-operating-system-and-institutional-structure.md) | Learning-institution operating system with separated corporate/legal and educational structure | Conditionally Accepted | Product, corporate/legal, and educational-structure domain ownership | [Decision evidence plan](../phase-2/institutional-structure-decision-evidence.md) records the bounded G6 decision; C25-01 permits only minimal synthetic 2.1-B entry, [ADR 0032](0032-c25-02-delegated-contract-acceptance.md) closes C25-02 by delegated review; ADR 0034 closes C25-03 for synthetic L1; ADR 0035 closes synthetic C25-04; C25-03-R and C25-05/C25-06 retain their gates |
| [0026](0026-module-aware-outbox-cursors-and-reconciliation.md) | Module-aware outbox cursors and reconciliation | Conditionally Accepted | Platform engineering | Slice 2.0-B cursor, drain, replay, telemetry, and recovery evidence |
| [0027](0027-production-identity-session-and-support-access.md) | Production identity, session, and support-access boundary | Superseded | Security architecture and platform engineering | Superseded by ADR 0029; provider-independent controls retained |
| [0028](0028-experience-design-system-and-governed-personalization.md) | Experience design system and governed personalization | Proposed | Product experience and client engineering | [DS-1 token evidence](../phase-1/handover-evidence.md), [DS-2 component evidence](../phase-1/handover-evidence.md), and [DS-3 technical evidence](../phase-1/handover-evidence.md) passed their focused checks; the repository-wide development-tool audit, representative-human DS-3 evidence, public-boundary security review, and later flow evidence remain |
| [0029](0029-provider-neutral-identity-federation-and-directory-connections.md) | Provider-neutral identity federation and directory connections | Accepted | Security architecture and platform engineering | [Decision evidence](../phase-2/identity-session-and-support-access-decision-evidence.md), [decision review](../phase-2/identity-session-and-support-access-decision-review.md), and [operating runbook](../operations/identity-session-and-support-access.md); each real connection and Slice 2.0-D implementation remain gated |
| [0030](0030-same-origin-public-session-and-named-action-boundary.md) | Same-origin public session and named-action boundary | Accepted | Platform and web engineering with product experience and security architecture | [Bounded D.3 implementation evidence](../phase-2/identity-session-and-support-access-implementation-evidence.md) covers the disabled-by-default synthetic adapter and checked session contract; 2.0-E browser and selected-deployment evidence remain required |
| [0031](0031-bounded-cross-jurisdiction-legal-structure-foundation.md) | Bounded cross-jurisdiction legal-structure foundation | Conditionally Accepted | Corporate/legal structure and platform engineering | Project Owner authorized synthetic L1 Slice 2.1-C1; ADR 0032 completes the C25-02 contract disposition; external adoption validation remains required before L2, real data, migration, or jurisdictional/accounting claims |
| [0032](0032-c25-02-delegated-contract-acceptance.md) | C25-02 delegated corporate/legal contract acceptance | Accepted | François — Project Owner; Codex as expressly delegated AI decider | [Completed corporate/finance review](../phase-2/c25-02-corporate-governance-finance-review.md): C25-02 closed with catalogue, thirteen answers, scenarios and migration findings; synthetic C1 scope and later adoption/release gates retained |
| [0033](0033-append-only-legal-structure-lifecycle-foundation.md) | Append-only legal-structure lifecycle foundation | Conditionally Accepted | Corporate/legal structure and platform engineering | Project Owner confirmed C25-02 approved while consultants review it and authorized synthetic Slice 2.1-C2a relationship ending and corporate-unit profile revision; structural moves and later release gates remain closed |
| [0034](0034-c25-03-delegated-educational-structure-acceptance.md) | C25-03 delegated educational-structure acceptance for synthetic L1 | Accepted | François — Project Owner; Codex as expressly delegated reviewer | [Five-context educational review](../phase-2/c25-03-educational-structure-review.md): C25-03 closed for synthetic L1; C25-03-R preserves external representative validation; ADR 0035 subsequently closes the synthetic operator decision |
| [0035](0035-c25-04-delegated-primary-operator-acceptance.md) | C25-04 delegated primary-operator acceptance for synthetic L1 | Accepted | François — Project Owner; Codex as expressly delegated reviewer | [Completed operator review](../phase-2/c25-04-primary-operator-review.md): seven rules accepted; compliance/governance owner, 14-day retrospective review and immediate revocation controls with human reconciliation within 72 hours; implementation and retained adoption/release gates remain |
| [0036](0036-minimal-people-participation-and-staff-account-association.md) | Minimal people, participation and staff-account association | Proposed | Product and platform engineering | Project Owner authorized the bounded private synthetic CF-4A increment; broader domain acceptance, representative review and real-data policy remain open |

| [0037](0037-class-register-enrolment-and-placement.md) | Class register, enrolment and dated placement | Proposed | Product and platform engineering | Project Owner authorized bounded private synthetic CF-4B; calendar integration and classroom checks recorded separately from connected adoption |

| [0038](0038-local-classroom-attendance-workflow.md) | Local session-bound classroom attendance | Proposed | Product and platform engineering | Project Owner authorized the bounded synthetic screen-to-writer increment; [workflow evidence](../phase-2/classroom-attendance-workflow-evidence.md) retains real-data and release gates |
| [0039](0039-public-calendar-evidence-for-cf-3-engineering-entry.md) | Public-calendar evidence for CF-3 engineering entry | Accepted | François — Project Owner and interim Security/Privacy Owner | Official public operational calendars admit a disabled local synthetic CF-3 candidate without inventing representative testimony; institution-side, real-data, identity, pilot, deployment, and production gates remain |
| [0040](0040-session-bound-classroom-preparation-workspace.md) | Session-bound classroom preparation workspace | Proposed | Product and platform engineering | Project Owner authorized the disabled local synthetic CF-4 preparation screen; implementation evidence must retain exact scope, atomic named actions, browser handoff and real-data gates |

Allowed decision statuses are Proposed, Accepted, Conditionally Accepted, Rejected, Superseded, and Deferred. `Template` is reserved for ADR 0000.
