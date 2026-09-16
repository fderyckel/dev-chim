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
| Ash Foundation Lab | All 15 planned scenarios and the mandatory tenant-movement/non-HTTP follow-up have focused evidence. The scorecard's mandatory criteria have direct Phase 0 proof, and the complete locked dependency-warning surface now has a machine-normalized zero-delta gate. Test and maintenance ergonomics pass with bounded remediation through seeded/isolated runs and a checked ownership manifest for eight custom boundaries. The non-patch upgrade, production-shaped migration measurement, bounded-condition disposition, and accountable adoption decision remain open | [Ash pressure-test and scorecard](evidence/ash-pressure-test.md), [warning baseline](evidence/ash-dependency-warning-baseline.md), [scenario 15 evidence](evidence/resource-authoring-and-governed-metadata.md), [maintenance evidence](evidence/ash-test-and-maintenance-ergonomics.md), [authoring boundary](../architecture/domain-model-authoring-and-metadata.md), [migration rehearsal](evidence/retained-data-migration-rehearsal.md), [routing evidence](evidence/trusted-routing.md), and [module-lifecycle evidence](evidence/module-lifecycle.md) |
| Architecture decisions | Required ADRs are drafted and remain Proposed | [Decision register](decision-register.md) |
| Security and privacy | Threats, classifications, and abuse cases are drafted; accountable review remains required | [Threat-model review](evidence/threat-model-review.md) |
| Capacity, placement, and PostgreSQL recovery | Contracts and synthetic planning envelopes exist; measured evidence and owner approvals remain required | [Tenant-placement evidence](evidence/tenant-placement-capacity.md) and [PostgreSQL evidence](evidence/postgresql-availability-and-burst.md) |
| Module lifecycle | Focused gate, dependency, concurrency, drain, retained-data, mandatory-work, and reactivation evidence passes; accountable review remains required | [Module-lifecycle evidence](evidence/module-lifecycle.md) |
| Phase 0 exit | Not ready: the architecture review is not scheduled and no required ADR has an accepted exit status | [Review record](review-record.md) |

Passing local checks proves the repository and implemented slices are internally consistent. It does not accept Ash, approve the architecture, or authorize Phase 1.

## Remaining exit gates

Phase 0 closes only when all of these gates are complete:

1. **Dispose of the remaining Ash bounded conditions.** The mandatory pressure-test criteria and dependency-warning normalization now have direct evidence. Complete, reject, or record production-shaped migration measurement, a non-patch upgrade, and every owned adapter limitation as bounded conditions with accountable owners, deadlines, expiry, and verification methods before Phase 2; then make the accountable Ash adoption or fallback decision.
2. **Approve numeric targets and run the capacity/recovery evidence.** Replace every target and owner placeholder, approve the five-school workload inputs, run the synchronized-burst, pool-exhaustion, replica-lag, failover, outbox-continuity, restore, and movement cases, then decide placement, read-replica, pooler, partitioning, and cross-region recovery from those results.
3. **Complete accountable security and lifecycle review.** Review the threat model and abuse cases, accept or mitigate residual high/critical risks, and record the module-lifecycle decision with named owners and expiry dates for conditions.
4. **Rehearse the final gate from a clean checkout.** Run `make check` with a disposable database on a clean checkout and record the machine or CI-host result. The current working-tree check is green but is not this rehearsal.
5. **Hold the architecture review and decide every required ADR.** Name participants and accountable approvers, set the date, choose the Ash outcome and fallback/conditions, move all 13 required ADRs out of Proposed, and prepare the accepted Phase 1 input list.

The machine-readable exit check is `mise exec -- uv run python tools/check_phase0.py --exit-review`. It intentionally remains red while accountable fields, measurements, decisions, or ADR outcomes are unresolved.

Repository-governance follow-up: the GitHub remote and `main` default branch are configured, but GitHub reported no protection for `main` on 2026-09-15. The current exit checker does not enforce that external setting, so it must be reviewed separately.

By explicit user directions on 2026-09-14 and 2026-09-15, provisional Phase 1 core-foundation slices 1A through 1C may proceed before this exit gate. The exception is limited to `apps/chimwemwe_core`, uses Ash as a reversible working assumption, and does not change any Phase 0 decision status. See the [Phase 1 scope](../phase-1/README.md).

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
