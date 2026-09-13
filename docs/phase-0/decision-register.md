# Phase 0 decision register

- Status: In progress
- Owner: Architecture review group

| ADR | Status | Evidence | Blocking question |
| --- | --- | --- | --- |
| [0001](../adr/0001-modular-monolith-and-service-boundaries.md) | Proposed | System context, boundary review, and [module-lifecycle evidence](evidence/module-lifecycle.md) | Are module dependencies, drain, retained-data access, and reactivation semantics complete and narrow enough? |
| [0002](../adr/0002-ash-adoption-criteria-and-fallback.md) | Proposed | [Ash pressure-test](evidence/ash-pressure-test.md) | Does every mandatory scorecard category pass? |
| [0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md) | Proposed | [Tenant-placement capacity evidence](evidence/tenant-placement-capacity.md), threat model, tenancy/routing tests, movement, backup, and restore drills | Which profile passes each tenant's peak, recovery, residency, cost, and isolation targets, and is RLS required as a backstop? |
| [0005](../adr/0005-domain-action-and-state-transition-convention.md) | Proposed | Named-action tests | Does the convention preserve intent through generated interfaces? |
| [0007](../adr/0007-transactional-outbox-and-event-envelope.md) | Proposed | Atomic rollback test | Is the envelope sufficient without leaking sensitive payloads? |
| [0009](../adr/0009-cache-taxonomy-invalidation-and-valkey-trigger.md) | Proposed | Threat model | What measured condition triggers shared Valkey? |
| [0010](../adr/0010-file-ownership-storage-pipeline-and-external-drives.md) | Proposed | Threat model | Which ownership modes are acceptable for external drives? |
| [0012](../adr/0012-report-templates-gotenberg-and-campaign-model.md) | Proposed | Quality target | What campaign size and deadline must the renderer meet? |
| [0014](../adr/0014-primary-api-and-generated-typescript-client.md) | Proposed | Generated-interface spike | Does JSON:API meet action and client requirements? |
| [0015](../adr/0015-ai-gateway-tool-exposure-and-evaluation-policy.md) | Proposed | Threat model | Which initial data classes and tools are allowed? |
| [0016](../adr/0016-scheduling-service-contract-and-publication-boundary.md) | Proposed | Contract review | Are the solver snapshot and explanation contracts sufficient? |

Phase 0 is not complete while a required record remains Proposed or lacks linked evidence and an accountable review outcome.
