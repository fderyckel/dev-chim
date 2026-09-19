# Tenant-placement capacity evidence

- Status: Technical planning profiles accepted; production placement remains evidence-driven
- Owner: Platform engineering and operations
- Review date: 2026-12-15 or an earlier material workload, provider, residency, or isolation change

## What is established

The synthetic five-school arithmetic is internally consistent under the stated assumption of eight attendance opportunities on each of 200 days:

- 5,000 students produce 8,000,000 baseline attendance facts per year;
- each 800-student school produces 1,280,000;
- four 800-student schools produce 5,120,000;
- all five produce 13,120,000 per year and 131,200,000 over ten years.

This establishes a planning input only. It does not establish actual peak throughput, physical storage, database cost, recovery time, or a final placement.

The [trusted-routing pressure test](trusted-routing.md) proves authenticated pooled and dedicated database selection, cross-placement denial, stale and missing routing failure, and explicit task/job propagation. The [combined local measurement](capacity-and-recovery-measurement.md) adds three repeated 8,200-fact bursts, per-fact comparison, mixed reads, noisy tenancy, connection exhaustion, physical-standby lag/outage/conflict, failover, outbox continuity, and one-percent planning-horizon PITR. The [fairness follow-up](tenant-fairness-backpressure-measurement.md) then binds itself to that raw failure and evaluates a two-slot-per-tenant admission candidate.

The bounded session shape cleared the accepted write target locally, but the raw pooled shape exceeded the 20% other-tenant p95-degradation limit by 119.298%-218.519%. The final pre-checkout candidate reduced the repeated degradation range to -0.151%-0.257%, rejected 602-603 noisy-tenant attempts per run before repository access, rejected no tenants-2-5 attempt, and preserved all atomicity and isolation assertions. The exact 131.2-million-row local restore also passes. This is a viable node-local application admission shape, not pooled-placement acceptance: multi-node coordination, selected-deployment capacity/failover/restore, contractual isolation, and final placement remain open.

## Technical estimates and governance boundaries

| Input | Current status | Owner |
| --- | --- | --- |
| Attendance days and opportunities by school and calendar | Technical sizing hypothesis: 200 days and 8 opportunities; product/calendar validation required | Product and operations |
| Peak submission window and concurrent classes | 30-second synchronized window; 328 session batches for 8,200 facts; 100 concurrent interactive-request planning load | Product, platform engineering, and operations |
| Batch-size and retry distribution | 25 facts per tenant-qualified session batch; retries retain the idempotency key; <= 0.1% final error target | Platform engineering and operations |
| Correction and late-change rate | Provisional 5% sizing allowance over the following 24 hours; validate from school workflow discovery before production sizing | Product and operations |
| Audit, outbox, index, WAL, and projection amplification | Atomic state/audit/outbox; index/table <= 1.5 and WAL/logical payload <= 4.0; projections asynchronous | Platform engineering and operations |
| Active OLTP retention, archive, legal hold, and analytical retention | Size two active years and a ten-year/131.2-million-fact recovery horizon; this does not authorize legal retention, archival, or deletion | Records governance and operations |
| Mixed report and integration workload during period starts | Protect writer and outbox; queue or reject lower-priority work; reference report campaign is 100 ten-page reports in <= 15 minutes outside an uncontrolled writer surge | Product, platform engineering, and operations |
| RPO, RTO, residency, accepted breach blast radius, and isolation terms | Database committed-write RPO 0 bytes, failover <= 120 s, PITR RPO <= 300 s and RTO <= 4 h; residency and breach blast radius require governance acceptance | Security, records governance, and operations |
| Writer/HA topology, connection budget, read-consistency classes, and replica-lag limits | Provider-neutral PostgreSQL contract; planning budget of 50 of 100 connections; writer-only security/read-your-write; bounded staleness <= 30 s; actual topology requires deployment qualification | Platform engineering, security, and operations |

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
10. stale, conflicting, unavailable, and malicious placement-routing inputs;
11. HA failover during a synchronized burst with idempotent retry and outbox continuity; and
12. replica lag or outage without stale authorization, missing read-your-write results, or an uncontrolled writer fallback surge.

The bulk action must prove that all rows are within one validated tenant and authorization scope before commit. An unauthorized row cannot produce a partial unauthorized submission.

## Placement decision record

| Tenant profile | Candidate placement | Required evidence | Decision |
| --- | --- | --- | --- |
| 5,000-student school | Dedicated database in a shared regional cell | Local write/recovery choreography passes; selected-deployment isolated-versus-pooled comparison and contractual isolation review remain | Accepted planning profile; production selection pending |
| Four 800-student schools | Pooled database in a shared regional cell | Raw shape fails; pre-checkout local candidate passes; multi-node deployment mixed-load rerun, reports, legal governance, and breach-blast-radius acceptance remain | Accepted planning profile; production selection pending |
| Any school | Dedicated cell | Residency, SLA, integration risk, sustained capacity, or contractual evidence | Evidence-triggered exception, not launch default |

The production placement record must name the deciders, date, accepted targets, deployment evidence, residual risks, review trigger, and rollback or movement plan. Student count alone cannot close that later decision.

See [tenant placement and workload capacity](../../architecture/tenant-placement-and-capacity.md), [PostgreSQL availability and burst evidence](postgresql-availability-and-burst.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), and [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md).
