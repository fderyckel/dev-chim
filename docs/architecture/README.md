# Architecture index

- Status: Proposed during Phase 0
- Owner: Architecture review group

The platform is a security-first modular monolith around Phoenix, Ash under evaluation, and PostgreSQL. Human interfaces, integrations, jobs, and AI call the same named domain actions and authorization boundary.

- [System context](system-context.md)
- [Core foundation boundary](core-foundation-boundary.md)
- [Domain model authoring and metadata](domain-model-authoring-and-metadata.md)
- [Temporal records, correction, and evidence](temporal-records-correction-and-evidence.md)
- [Temporal records decision review](temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)
- [Academic calendar authority](academic-calendar-authority.md)
- [Service boundaries](service-boundaries.md)
- [Tenant placement and workload capacity](tenant-placement-and-capacity.md)
- [PostgreSQL availability, recovery, and read routing](postgresql-availability-recovery-and-read-routing.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Quality-attribute targets](quality-attribute-targets.md)
- [Deferred choices](deferred-choices.md)
- [Assurance proportionality and module evolution](../adr/0024-assurance-proportionality-and-module-evolution.md)
- [Architecture decisions](../adr/README.md)
- [Threat model](../security/threat-model.md)

An architectural statement remains Proposed until its ADR is accepted. The source roadmap guides Phase 0 but does not replace evidence or review.
