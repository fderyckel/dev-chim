# Architecture index

- Status: Maintained architecture guide; decision status belongs to the governing ADR
- Owner: Architecture review group

Start with the [system context and service boundaries](system-context.md) to see how the platform
fits together. The [ADR index](../adr/README.md) identifies the governing decisions and their
statuses; these guides explain their detailed contracts without granting implementation authority.

## Contracts and shared references

- [Core foundation boundary](core-foundation-boundary.md)
- [Domain model authoring and metadata workflow](../development/code-conventions.md#domain-model-authoring)
- [Governed model and workflow views](governed-model-views.md)
- [Temporal records, correction, and evidence](temporal-records-correction-and-evidence.md)
- [Academic calendar authority](academic-calendar-authority.md)
- [Tenant placement and workload capacity](tenant-placement-and-capacity.md)
- [PostgreSQL availability, recovery, and read routing](postgresql-availability-recovery-and-read-routing.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Quality-attribute targets](quality-attribute-targets.md)
- [Deferred choices](deferred-choices.md)
- [Threat model](../security/threat-model.md)

## Related decisions and review evidence

- [Learning-institution operating system with separated corporate/legal and educational structure](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Assurance proportionality and module evolution](../adr/0024-assurance-proportionality-and-module-evolution.md)
- [Experience design system and governed personalization](../adr/0028-experience-design-system-and-governed-personalization.md)
- [Identity, session, and support-access decision review](../phase-2/identity-session-and-support-access-decision-review.md)
- [Institutional-structure scenario and vocabulary review](../phase-2/institutional-structure-scenario-review.md)
- [Institutional-structure security, migration, and temporal review](../phase-2/institutional-structure-security-migration-review.md)
- [Institutional-structure experience evidence](../phase-2/institutional-structure-experience-evidence.md)
- [Temporal records decision review](temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)

For implementation progress and remaining delivery gates, read the [current Phase 2 records](../phase-2/README.md).
Completed work is summarized in the [Phase 0](../phase-0/handover-evidence.md) and
[Phase 1](../phase-1/handover-evidence.md) handovers.
