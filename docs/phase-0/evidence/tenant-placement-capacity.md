# Tenant-placement capacity evidence

- Status: Evidence required
- Owner: Platform engineering and operations
- Review date: DATE_REQUIRED

## What is established

The synthetic five-school arithmetic is internally consistent under the stated assumption of eight attendance opportunities on each of 200 days:

- 5,000 students produce 8,000,000 baseline attendance facts per year;
- each 800-student school produces 1,280,000;
- four 800-student schools produce 5,120,000;
- all five produce 13,120,000 per year and 131,200,000 over ten years.

This establishes a planning input only. It does not establish actual peak throughput, physical storage, database cost, recovery time, or a final placement.

## Inputs requiring accountable approval

| Input | Current status | Owner |
| --- | --- | --- |
| Attendance days and opportunities by school and calendar | Hypothesis: 200 days and 8 opportunities | OWNER_REQUIRED |
| Peak submission window and concurrent classes | TARGET_REQUIRED | OWNER_REQUIRED |
| Batch-size and retry distribution | TARGET_REQUIRED | OWNER_REQUIRED |
| Correction and late-change rate | TARGET_REQUIRED | OWNER_REQUIRED |
| Audit, outbox, index, WAL, and projection amplification | TARGET_REQUIRED | OWNER_REQUIRED |
| Active OLTP retention, archive, legal hold, and analytical retention | TARGET_REQUIRED | OWNER_REQUIRED |
| Mixed report and integration workload during period starts | TARGET_REQUIRED | OWNER_REQUIRED |
| RPO, RTO, residency, accepted breach blast radius, and isolation terms | TARGET_REQUIRED | OWNER_REQUIRED |

## Benchmark protocol

Use synthetic data only. Record the source revision, PostgreSQL version and settings, hardware or container limits, connection-pool size, table and index design, data age distribution, exact commands, measurement tool, repeated-run variance, and raw result location.

At minimum, exercise:

1. synchronized period-start submissions for the 5,000-student school;
2. combined synchronized submissions for the four 800-student schools;
3. concurrent late corrections and idempotent retries;
4. authorization revocation racing a bulk submission;
5. operational summary reads and outbox dispatch during the write burst;
6. representative report and integration reads during the write burst;
7. connection-pool exhaustion and one noisy tenant;
8. index growth, WAL, autovacuum, projection lag, and retained-footprint measurements;
9. backup and restore at the planning-horizon volume; and
10. stale, conflicting, unavailable, and malicious placement-routing inputs.

The bulk action must prove that all rows are within one validated tenant and authorization scope before commit. An unauthorized row cannot produce a partial unauthorized submission.

## Placement decision record

| Tenant profile | Candidate placement | Required evidence | Decision |
| --- | --- | --- | --- |
| 5,000-student school | Dedicated database in a shared regional cell | Isolated and pooled benchmark comparison; recovery and contractual isolation review | DECISION_REQUIRED |
| Four 800-student schools | Pooled database in a shared regional cell | Combined peak, reports, pool pressure, legal governance, and breach-blast-radius acceptance | DECISION_REQUIRED |
| Any school | Dedicated cell | Residency, SLA, integration risk, sustained capacity, or contractual evidence | DECISION_REQUIRED |

The final record must name the deciders, date, accepted targets, evidence links, residual risks, review trigger, and rollback or movement plan. Student count alone cannot close the decision.

See [tenant placement and workload capacity](../../architecture/tenant-placement-and-capacity.md) and [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md).
