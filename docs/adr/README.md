# Architecture decision records

- Status: Active process
- Owner: Architecture review group

ADRs record decisions that shape stable platform boundaries. Every record starts Proposed. Only named deciders may accept it after reviewing linked evidence.

## Process

1. Copy [ADR 0000](0000-template.md) and allocate the next reserved number from the source backlog.
2. Fill every section, including alternatives, negative consequences, validation, fallback, and review triggers.
3. Add the record to this index and the Phase 0 decision register.
4. Gather evidence before acceptance.
5. Supersede an Accepted decision with a new ADR; do not rewrite its outcome.

## Index

| ADR | Title | Status | Owner | Evidence |
| --- | --- | --- | --- | --- |
| [0000](0000-template.md) | ADR template | Template | Architecture review group | Not applicable |
| [0001](0001-modular-monolith-and-service-boundaries.md) | Modular monolith and permitted service boundaries | Proposed | Architecture review group | Context and boundary review |
| [0002](0002-ash-adoption-criteria-and-fallback.md) | Ash adoption criteria and fallback | Proposed | Platform engineering | Ash pressure-test |
| [0003](0003-tenant-model-and-optional-postgresql-rls.md) | Tenant model and optional PostgreSQL RLS | Proposed | Security architecture | Threat model and tenancy tests |
| [0005](0005-domain-action-and-state-transition-convention.md) | Domain action and state-transition convention | Proposed | Platform engineering | Named-action spike tests |
| [0007](0007-transactional-outbox-and-event-envelope.md) | Transactional outbox and event envelope | Proposed | Platform engineering | Atomic rollback test |
| [0009](0009-cache-taxonomy-invalidation-and-valkey-trigger.md) | Cache taxonomy, invalidation, and Valkey trigger | Proposed | Platform engineering | Classification and trigger review |
| [0010](0010-file-ownership-storage-pipeline-and-external-drives.md) | File ownership, storage pipeline, and external drives | Proposed | Platform engineering and security | Threat model |
| [0012](0012-report-templates-gotenberg-and-campaign-model.md) | Report templates, Gotenberg, and campaign model | Proposed | Platform engineering and operations | Capacity scenario |
| [0014](0014-primary-api-and-generated-typescript-client.md) | Primary API and generated TypeScript client | Proposed | Platform and web engineering | Generated API spike |
| [0015](0015-ai-gateway-tool-exposure-and-evaluation-policy.md) | AI gateway tool exposure and evaluation policy | Proposed | Security architecture | AI threat model |
| [0016](0016-scheduling-service-contract-and-publication-boundary.md) | Scheduling service contract and publication boundary | Proposed | Platform and scheduling engineering | Contract review |

Allowed decision statuses are Proposed, Accepted, Conditionally Accepted, Rejected, Superseded, and Deferred. `Template` is reserved for ADR 0000.

