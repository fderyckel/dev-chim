# Phase 0: architecture decisions and risk spikes

- Status: Complete
- Accountable approver: François — Project Owner
- Decision date: 2026-09-16
- Outcome: architecture decisions recorded; Ash conditionally accepted; production gates carried forward

## Deliverables

- Decided ADR set with Accepted, Conditionally Accepted, or Deferred outcomes.
- Ash Foundation Lab pressure-test, scorecard, and accountable adoption decision.
- Accepted Phase 0 security/privacy baseline and abuse cases.
- Approved numeric quality-attribute targets.
- Workload-driven tenant-placement profiles and a five-school planning envelope backed by synthetic evidence.
- A provider-neutral PostgreSQL availability, recovery, connection-budget, and consistency-aware read-routing contract backed by synthetic burst and failure evidence.
- An accepted module-lifecycle contract that separates release, entitlement, activation, and authorization.
- Reproducible local toolchain and one verification command.
- Review record with decisions, conditions, owners, dates, and review triggers.

## Completion snapshot

This page is the Phase 0 completion entry point. Follow the evidence and decision links for the exact proof and the production gates carried into later work.

| Area | Final Phase 0 outcome | Authoritative detail |
| --- | --- | --- |
| Repository and local verification | The candidate passes local verification and isolated clean-checkout bootstrap/check rehearsal. Ash 3.33.4 closes the recorded field-policy advisory across the Foundation Lab and bounded production core | [Clean-checkout rehearsal](evidence/clean-checkout-rehearsal.md), [development workflow](../development/testing.md), [security-patch review](evidence/ash-security-patch.md), and [Slice 1D evidence](../phase-1/evidence/database-admission.md) |
| Ash Foundation Lab | Ash is conditionally accepted as the default production-core framework. All 15 scenarios and tenant-movement/non-HTTP follow-up have evidence; eight bounded production gates have named ownership, verification, fallback, and review date | [Ash pressure-test and scorecard](evidence/ash-pressure-test.md), [bounded-condition disposition](evidence/ash-bounded-condition-disposition.md), [security patch](evidence/ash-security-patch.md), [annual-envelope migration measurement](evidence/retained-data-migration-measurement.md), [non-patch upgrade](evidence/ash-nonpatch-upgrade-exercise.md), [warning baseline](evidence/ash-dependency-warning-baseline.md), [scenario 15 evidence](evidence/resource-authoring-and-governed-metadata.md), [maintenance evidence](evidence/ash-test-and-maintenance-ergonomics.md), [routing evidence](evidence/trusted-routing.md), and [module-lifecycle evidence](evidence/module-lifecycle.md) |
| Architecture decisions | All 14 Phase 0-gated ADRs have accountable outcomes: six Accepted, five Conditionally Accepted, and three Deferred | [Decision register](decision-register.md) |
| Security and privacy | The threat model and abuse cases are accepted as the Phase 0 engineering baseline. Independent security/privacy review remains mandatory before real restricted data | [Threat model](../security/threat-model.md) and [review record](review-record.md) |
| Capacity, placement, and PostgreSQL recovery | Numeric targets, local pre-checkout admission, failover, and the exact 131.2-million-row local restore evidence are recorded. PostgreSQL remains provider-neutral; the earlier AWS example is withdrawn and deployment qualification moves to the infrastructure phase | [Target approval](evidence/quality-targets-approval.md), [combined measurement](evidence/capacity-and-recovery-measurement.md), [pre-checkout follow-up](evidence/precheckout-admission-measurement.md), [full-horizon restore](evidence/full-horizon-restore-measurement.md), [withdrawn AWS example](evidence/managed-postgresql-topology.md), [tenant-placement evidence](evidence/tenant-placement-capacity.md), and [PostgreSQL evidence](evidence/postgresql-availability-and-burst.md) |
| Module lifecycle | The four independent server-side gates, concurrency, drain, retained-data, mandatory-work, and reactivation contract are accepted. Real integrations remain production gates | [Module-lifecycle evidence](evidence/module-lifecycle.md) |
| Phase 0 exit | Complete: the named review, decisions, accountable Ash outcome, and exit verification are recorded | [Review record](review-record.md) |

Passing checks and accountable review now work together: the checks prove that the evidence and repository contracts remain internally consistent; the 2026-09-16 review supplies the human decisions the checks cannot make.

## Binding later gates

Phase 0 has no remaining exit blocker. The following are deliberately carried into the phase where they become real:

1. **Ash production gates.** Verify each of the eight [bounded conditions](evidence/ash-bounded-condition-disposition.md) before its dependent production capability ships. A failed gate uses the recorded fallback and fails closed.
2. **Deployment qualification.** Select the actual non-AWS hosting/deployment environment later, then qualify PostgreSQL availability, recovery, connection budgets, multi-node admission, tenant movement, residency, and operations against the accepted targets. Provider selection is not a Phase 0 decision.
3. **Independent review before real data or pilot.** François is the interim security/privacy and product/operations owner. Name an independent security/privacy reviewer before real restricted child data is used, and a school-side records owner before a pilot, no later than 2026-12-15.
4. **Deferred capability decisions.** Reopen report rendering, AI, scheduling, native clients, and other deferred choices only when their bounded capability enters scope and has measurable requirements.

The machine-readable exit command is `mise exec -- uv run python tools/check_phase0.py --exit-review`. It is expected to remain green; any unresolved ADR status, placeholder owner/date, stale evidence binding, or broken repository contract makes it fail.

Repository-governance follow-up: the GitHub remote and `main` default branch are configured, but GitHub reported no protection for `main` on 2026-09-15. The exit checker does not enforce that external setting, so it remains a separate governance task.

Phase 1 work still proceeds only in explicitly authorized bounded slices. Phase 0 completion accepts the foundation decisions; it does not authorize a school business module, web shell, scheduler, AI gateway, analytics plane, or production infrastructure by itself. See the [Phase 1 scope](../phase-1/README.md).

## Navigation

- [Decision register](decision-register.md)
- [Risk register](risk-register.md)
- [Review record](review-record.md)
- [Evidence index](evidence/README.md)
- [Tenant placement and workload capacity](../architecture/tenant-placement-and-capacity.md)
- [PostgreSQL availability, recovery, and read routing](../architecture/postgresql-availability-recovery-and-read-routing.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Implementation plan](../plans/phase-0-implementation-plan.md)

No production business module, user interface, scheduler, runtime AI service, analytics plane, or file/report service was added in Phase 0.
