# PostgreSQL availability and synchronized-burst evidence

- Status: Evidence required
- Owner: Platform engineering and operations
- Review date: DATE_REQUIRED
- Governing record: [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)

## What is established

The architecture distinguishes the PostgreSQL writer, same-region HA standby, optional read replica, recoverable WAL/backups, and optional cross-region disaster-recovery replica. Only the writer is authoritative for state changes, authorization and revocation, tenant placement, module gates, current job/outbox coordination, and immediate read-after-write confirmation.

The current arithmetic establishes a synthetic planning envelope, not measured capacity:

| Scenario | Logical facts | Window | Logical fact rate |
| --- | ---: | ---: | ---: |
| 5,000-learner school, one period | 5,000 | 5 minutes | 16.7/second |
| All five schools, one period | 8,200 | 5 minutes | 27.3/second |
| 5,000-learner school, one period | 5,000 | 30 seconds | 166.7/second |
| All five schools, one period | 8,200 | 30 seconds | 273.3/second |

With an illustrative average batch of 25 learners, the all-school case is approximately 328 attendance-session transactions per period, or 10.9 transactions per second over 30 seconds. The actual batch distribution, transaction time, write amplification, concurrency, and retained footprint require measurement.

## Inputs requiring accountable approval

| Input | Current status | Owner |
| --- | --- | --- |
| Writer service tier, region, zones, storage class, IOPS, and PostgreSQL settings | TARGET_REQUIRED | OWNER_REQUIRED |
| HA replication and commit-durability guarantee | TARGET_REQUIRED | OWNER_REQUIRED |
| Writer failover RPO/RTO and application reconnection target | TARGET_REQUIRED | OWNER_REQUIRED |
| Point-in-time restore RPO/RTO, retention, and drill interval | TARGET_REQUIRED | OWNER_REQUIRED |
| Per-action consistency classification and replica staleness limit | TARGET_REQUIRED | OWNER_REQUIRED |
| Application-node, Ecto, Oban, administration, and reserve connection budget | TARGET_REQUIRED | OWNER_REQUIRED |
| Session batch-size/concurrency and retry distribution | TARGET_REQUIRED | OWNER_REQUIRED |
| Audit, history, outbox, index, WAL, and synchronous-projection amplification | TARGET_REQUIRED | OWNER_REQUIRED |
| Backpressure queue/wait budget and retry contract | TARGET_REQUIRED | OWNER_REQUIRED |
| Tenant fairness and noisy-neighbour threshold | TARGET_REQUIRED | OWNER_REQUIRED |
| Lower-priority queue throttling and report degradation rules | TARGET_REQUIRED | OWNER_REQUIRED |
| Cross-region recovery, residency, promotion, and failback requirement | TARGET_REQUIRED | OWNER_REQUIRED |

## Connection-budget record

Record the accepted maximum for each candidate database placement:

```text
total_connections =
  application_nodes x writer_pool_per_node
  + application_nodes x reader_pool_per_node
  + Oban_and_outbox_pools_per_placement
  + migration_administration_monitoring_and_replication_reserve
```

| Placement | Application nodes | Writer pools | Reader pools | Job/outbox pools | Reserved connections | Total | Maximum | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Pooled candidate | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | NOT_RUN |
| Dedicated-database candidate | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | TARGET_REQUIRED | NOT_RUN |

If a pooler is proposed, add its mode, client and server limits, prepared-statement configuration, tenant/RLS context strategy, migration path, failure behaviour, and compatibility results. A pooler does not replace the end-to-end connection budget.

## Required benchmark and failure matrix

Use synthetic data only. Every run records the source revision, provider or hardware, topology, PostgreSQL version/settings, schema and indexes, data-age distribution, application-node count, pool configuration, exact command, repeated-run variance, raw evidence location, and limitations.

| Scenario | Required measurements | Required safety assertion | Result |
| --- | --- | --- | --- |
| Bounded attendance-session batches | facts/s, transactions/s, p50/p95/p99, pool wait, CPU, I/O, WAL, locks, error/retry rate | One authorized tenant/session scope; no unauthorized partial commit | NOT_RUN |
| Intentionally unbatched comparison | Same measures and connection/commit amplification | Comparison only; unsafe shape is not a supported API | NOT_RUN |
| Audit, history, index, and outbox amplification | Physical writes, WAL bytes, transaction duration, retained bytes | State, audit/history, and outbox remain atomic | NOT_RUN |
| Reports and operational summaries during burst | Writer and reader latency, lag, conflicts, queue age | Reports cannot starve authorization, writes, or outbox | NOT_RUN |
| Noisy pooled tenant | Per-tenant latency, pool share, rejection, queue age | Other tenants remain within accepted targets | NOT_RUN |
| Writer connection exhaustion | Checkout wait, early rejection, recovery time | Reject before transaction and retry idempotently | NOT_RUN |
| Replica lag or outage | replay lag, routed/fallback load, delayed/rejected reports | Authorization, placement, module gates, and read-your-write never use stale state | NOT_RUN |
| Long replica query and WAL conflict | replay delay, cancellations, storage/WAL retention | HA readiness and writer storage remain within target | NOT_RUN |
| HA failover during burst | lost/duplicate results, RPO/RTO, reconnect time, pool recovery | Idempotent retry; placement and authorization remain fail closed | NOT_RUN |
| Outbox continuity across failover | oldest event, duplicates, retries, missed events | No committed state lacks its outbox fact; consumers tolerate duplicates | NOT_RUN |
| Point-in-time restore | latest restorable time, duration, integrity and reconciliation | Restore is isolated, authorized, complete, and tenant-correct | NOT_RUN |
| Placement and RLS/pool context after failover | cross-tenant probes and stale route/version cases | No default placement and no session-context leak | NOT_RUN |

## Read-replica decision record

| Gate | Evidence | Decision |
| --- | --- | --- |
| Writer pressure remains materially read-driven after query/index/summary improvements | EVIDENCE_REQUIRED | DECISION_REQUIRED |
| Every candidate query has an approved consistency class and staleness limit | EVIDENCE_REQUIRED | DECISION_REQUIRED |
| Lag, conflicts, cancellation, retained WAL, and failure are observable | EVIDENCE_REQUIRED | DECISION_REQUIRED |
| Security-sensitive and read-your-write paths remain on the writer | EVIDENCE_REQUIRED | DECISION_REQUIRED |
| Replica loss cannot cause an uncontrolled writer fallback surge | EVIDENCE_REQUIRED | DECISION_REQUIRED |
| Ecto pool, credentials, cost, recovery, and tenant movement remain acceptable | EVIDENCE_REQUIRED | DECISION_REQUIRED |

Do not approve a read replica merely from annual row count. If the gate fails, keep OLTP reads on the writer and use query improvements or governed asynchronous projections.

## Evidence conclusion

- Topology decision: DECISION_REQUIRED
- Read-replica decision: DECISION_REQUIRED
- Pooler decision: DECISION_REQUIRED
- Cross-region DR decision: DECISION_REQUIRED
- Residual risks, owner, and expiry: OWNER_REQUIRED

See [database operations and read routing](../../architecture/postgresql-availability-recovery-and-read-routing.md), [tenant-placement capacity evidence](tenant-placement-capacity.md), and [quality-attribute targets](../../architecture/quality-attribute-targets.md).
