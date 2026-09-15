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
- A PostgreSQL availability, recovery, connection-budget, and consistency-aware read-routing contract backed by synthetic burst and failure evidence.
- A module lifecycle contract that separates release, entitlement, activation, and authorization.
- Reproducible local toolchain and one verification command.
- Review record with decisions, conditions, owners, and expiry dates.

## Progress snapshot

This page is the Phase 0 progress entry point. Follow the evidence and decision links for the exact proof and remaining acceptance questions.

| Area | Current state | Authoritative detail |
| --- | --- | --- |
| Repository and local verification | Current working-tree `make check` passes | [Development workflow](../development/testing.md) |
| Ash Foundation Lab | Scenarios 1-14 now have evidence; role composition has cycle-safe administration plus field/relationship policy proof, and the generated interface has versioned routes, the complete proposed public error taxonomy, bounded keyset pagination, transactional action idempotency, checked-in OpenAPI/types drift detection, and a tested thin TypeScript client. Placement movement and the wider adoption scorecard remain incomplete | [Ash pressure-test and scorecard](evidence/ash-pressure-test.md), [routing evidence](evidence/trusted-routing.md), and [module-lifecycle evidence](evidence/module-lifecycle.md) |
| Architecture decisions | Required ADRs are drafted and remain Proposed | [Decision register](decision-register.md) |
| Security and privacy | Threats, classifications, and abuse cases are drafted; accountable review remains required | [Threat-model review](evidence/threat-model-review.md) |
| Capacity, placement, and PostgreSQL recovery | Contracts and synthetic planning envelopes exist; measured evidence and owner approvals remain required | [Tenant-placement evidence](evidence/tenant-placement-capacity.md) and [PostgreSQL evidence](evidence/postgresql-availability-and-burst.md) |
| Module lifecycle | Focused gate, dependency, concurrency, drain, retained-data, mandatory-work, and reactivation evidence passes; accountable review remains required | [Module-lifecycle evidence](evidence/module-lifecycle.md) |
| Phase 0 exit | Not ready: the architecture review is not scheduled and no required ADR has an accepted exit status | [Review record](review-record.md) |

Passing local checks proves the repository and implemented slices are internally consistent. It does not accept Ash, approve the architecture, or authorize Phase 1.

By explicit user direction on 2026-09-14, one provisional Phase 1 core-foundation slice may proceed before this exit gate. The exception is limited to `apps/chimwemwe_core`, uses Ash as a reversible working assumption, and does not change any Phase 0 decision status. See the [Phase 1 scope](../phase-1/README.md).

## Navigation

- [Decision register](decision-register.md)
- [Risk register](risk-register.md)
- [Review record](review-record.md)
- [Evidence index](evidence/README.md)
- [Tenant placement and workload capacity](../architecture/tenant-placement-and-capacity.md)
- [PostgreSQL availability, recovery, and read routing](../architecture/postgresql-availability-recovery-and-read-routing.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Implementation plan](../plans/phase-0-implementation-plan.md)

No production business module, user interface, scheduler, runtime AI service, analytics plane, or file/report service belongs in this phase.
