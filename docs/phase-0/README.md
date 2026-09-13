# Phase 0: architecture decisions and risk spikes

- Status: In progress
- Owner: Architecture review group
- Exit gate: architecture decisions accepted and Ash accepted, conditionally accepted, or replaced before Phase 1 production boundaries depend on it

## Deliverables

- Proposed and reviewed ADR set.
- Ash Foundation Lab pressure-test and scorecard.
- Security/privacy threat model and abuse cases.
- Approved numeric quality-attribute targets.
- Workload-driven tenant-placement profiles and a five-school capacity decision backed by synthetic evidence.
- A module lifecycle contract that separates release, entitlement, activation, and authorization.
- Reproducible local toolchain and one verification command.
- Review record with decisions, conditions, owners, and expiry dates.

## Current evidence boundary

The local toolchain and environment smoke tests pass. They demonstrate that contributors can install locked dependencies and run repository, static-analysis, and PostgreSQL-backed tests. They do not yet prove the full Ash adoption scorecard or complete the Phase 0 architecture exit gate.

## Navigation

- [Decision register](decision-register.md)
- [Risk register](risk-register.md)
- [Review record](review-record.md)
- [Evidence index](evidence/README.md)
- [Tenant placement and workload capacity](../architecture/tenant-placement-and-capacity.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Implementation plan](../plans/phase-0-implementation-plan.md)

No production business module, user interface, scheduler, runtime AI service, analytics plane, or file/report service belongs in this phase.
