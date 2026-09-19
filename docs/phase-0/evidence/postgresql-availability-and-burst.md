# PostgreSQL availability and synchronized-burst evidence

- Status: Provider-neutral PostgreSQL contract accepted; local gates passed after preserved raw fairness failure; deployment qualification required
- Owner: Platform engineering and operations
- Review date: 2026-12-15 or an earlier material topology, provider, region, or workload change
- Governing record: [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)

## What is established

The architecture distinguishes the PostgreSQL writer, same-region HA standby, optional read replica, recoverable WAL/backups, and optional cross-region disaster-recovery replica. Only the writer is authoritative for state changes, authorization and revocation, tenant placement, module gates, current job/outbox coordination, and immediate read-after-write confirmation.

The current arithmetic establishes the synthetic planning envelope:

| Scenario | Logical facts | Window | Logical fact rate |
| --- | ---: | ---: | ---: |
| 5,000-learner school, one period | 5,000 | 5 minutes | 16.7/second |
| All five schools, one period | 8,200 | 5 minutes | 27.3/second |
| 5,000-learner school, one period | 5,000 | 30 seconds | 166.7/second |
| All five schools, one period | 8,200 | 30 seconds | 273.3/second |

With an illustrative average batch of 25 learners, the all-school case is approximately 328 attendance-session transactions per period, or 10.9 transactions per second over 30 seconds. The actual batch distribution, transaction time, write amplification, concurrency, and retained footprint require measurement.

The [combined local measurement](capacity-and-recovery-measurement.md) now executes that exact 8,200-fact/328-session shape three times. It records 282,301-308,654 local facts/s, 0.637-0.884 ms batch p95, zero unauthorized partial commits, roughly fourfold lower WAL than 8,200 per-fact transactions, early rejection under exhausted connections, safe replica lag/outage, a bounded standby recovery conflict, interrupted-burst failover with zero sampled acknowledged-write loss and zero missing outbox facts, and an isolated 1,312,000-row PITR. These are local choreography and comparative measurements, not production service-tier capacity.

The raw pooled shape fails the accepted tenant-isolation gate: other-tenant p95 degradation was 119.298%-218.519% against a 20% maximum. The separately source-bound [fairness follow-up](tenant-fairness-backpressure-measurement.md) first proved the algorithm shape inside a transaction. The final [pre-checkout follow-up](precheckout-admission-measurement.md) passes three local PostgreSQL repetitions at -0.151%-0.257% degradation, rejects 602-603 tenant-1 attempts before the repository callback, rejects no tenants-2-5 attempt, and preserves all isolation/atomicity assertions. Pooled production placement remains gated by multi-node calibration and repeating the proof in the selected non-AWS deployment with mixed workload.

## Technical baseline and remaining governance inputs

| Input | Current status | Owner |
| --- | --- | --- |
| Writer service tier, region, zones, storage class, IOPS, and PostgreSQL settings | Provider deferred; qualify a PostgreSQL 18-compatible deployment. A 2-vCPU/8-GiB writer and 100-GiB storage remain starting estimates, not a provider selection or capacity claim | Platform engineering and operations |
| HA replication and commit-durability guarantee | A claimed zero committed-write RPO requires synchronous durable acknowledgement and a tested independent failure domain; exact topology is deployment-specific | Platform engineering and operations |
| Writer failover RPO/RTO and application reconnection target | Failover <= 120 s; application reconnect <= 60 s; missing outbox facts = 0 | Platform engineering and operations |
| Point-in-time restore RPO/RTO, retention, and drill interval | RPO <= 300 s; RTO <= 14,400 s; drill at least every 90 days; backup retention and legal retention require deployment and governance decisions | Platform engineering, records governance, and operations |
| Per-action consistency classification and replica staleness limit | Security and read-your-write routes remain writer-only; approved bounded-staleness routes <= 30 s; unsafe routes = 0 | Platform engineering and security |
| Application-node, Ecto, Oban, administration, and reserve connection budget | Two nodes x ten writer connections, zero readers, five job/outbox, 25 reserved, 50 budgeted of PostgreSQL maximum 100 | Platform engineering and operations |
| Session batch-size/concurrency and retry distribution | 25 facts per tenant-qualified session batch; 100 concurrent interactive-request planning load; retry uses the same idempotency key | Platform engineering and operations |
| Audit, history, outbox, index, WAL, and synchronous-projection amplification | Atomic state/audit/outbox; index/table <= 1.5; WAL/logical payload <= 4.0; synchronous non-authoritative projection work is excluded | Platform engineering and operations |
| Backpressure queue/wait budget and retry contract | Checkout p95 <= 25 ms and p99 <= 100 ms; tenant saturation is 429; placement/dependency saturation is 503; `Retry-After` only when bounded | Platform engineering and operations |
| Tenant fairness and noisy-neighbour threshold | Other-tenant p95 degradation <= 20%; node-local limits start at two per tenant and ten per placement | Platform engineering and operations |
| Lower-priority queue throttling and report degradation rules | Prioritize authoritative writes and outbox; delay or reject reports rather than create uncontrolled writer fallback; outbox p95 age <= 60 s and p99 <= 300 s | Platform engineering and operations |
| Cross-region recovery, residency, promotion, and failback requirement | No launch cross-region replica; residency/legal approval and explicit promotion, split-brain, reconciliation, and failback evidence are required before adding one | Security, records governance, and operations |

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
| Pooled candidate | 2 | 20 total | 0 | 5 | 25 | 50 | 100 | Node-local pre-checkout shape passes; multi-node selected-deployment run required |
| Dedicated-database candidate | 2 | 20 total | 0 | 5 | 25 | 50 | 100 | Conservative starting budget; selected-deployment isolated-versus-pooled comparison required |

If a pooler is proposed, add its mode, client and server limits, prepared-statement configuration, tenant/RLS context strategy, migration path, failure behaviour, and compatibility results. A pooler does not replace the end-to-end connection budget.

## Required benchmark and failure matrix

Use synthetic data only. Every run records the source revision, provider or hardware, topology, PostgreSQL version/settings, schema and indexes, data-age distribution, application-node count, pool configuration, exact command, repeated-run variance, raw evidence location, and limitations.

| Scenario | Required measurements | Required safety assertion | Result |
| --- | --- | --- | --- |
| Bounded attendance-session batches | facts/s, transactions/s, p50/p95/p99, pool wait, CPU, I/O, WAL, locks, error/retry rate | One authorized tenant/session scope; no unauthorized partial commit | LOCAL_PASS; selected-deployment/app-pool confirmation required |
| Intentionally unbatched comparison | Same measures and connection/commit amplification | Comparison only; unsafe shape is not a supported API | LOCAL_COMPLETE; about 5.5-6x elapsed and 4x WAL |
| Audit, history, index, and outbox amplification | Physical writes, WAL bytes, transaction duration, retained bytes | State, audit/history, and outbox remain atomic | LOCAL_PASS; production history shape required |
| Reports and operational summaries during burst | Writer and reader latency, lag, conflicts, queue age | Reports cannot starve authorization, writes, or outbox | PARTIAL; mixed reads pass locally, report/queue system absent |
| Noisy pooled tenant | Per-tenant latency, pool share, rejection, queue age | Other tenants remain within accepted targets | RAW_LOCAL_FAIL at 119.298%-218.519%; pre-checkout local candidate passes at -0.151%-0.257%; multi-node deployment proof required |
| Writer connection exhaustion | Checkout wait, early rejection, recovery time | Reject before transaction and retry idempotently | LOCAL_PASS at server and pre-checkout application boundaries; multi-node deployment confirmation required |
| Replica lag or outage | replay lag, routed/fallback load, delayed/rejected reports | Authorization, placement, module gates, and read-your-write never use stale state | LOCAL_PASS; selected-deployment lag/outage required if replicas are used |
| Long replica query and WAL conflict | replay delay, cancellations, storage/WAL retention | HA readiness and writer storage remain within target | LOCAL_PASS; query cancelled in 1,032.496 ms |
| HA failover during burst | lost/duplicate results, RPO/RTO, reconnect time, pool recovery | Idempotent retry; placement and authorization remain fail closed | LOCAL_PASS; same-host choreography only |
| Outbox continuity across failover | oldest event, duplicates, retries, missed events | No committed state lacks its outbox fact; consumers tolerate duplicates | LOCAL_PASS for stored facts; dispatcher/consumer evidence required |
| Point-in-time restore | latest restorable time, duration, integrity and reconciliation | Restore is isolated, authorized, complete, and tenant-correct | LOCAL_PASS at the exact 131,200,000-row horizon with zero logical mismatches; selected-deployment restore required |
| Placement and RLS/pool context after failover | cross-tenant probes and stale route/version cases | No default placement and no session-context leak | Local routing, movement, and failover cases pass separately; integrated deployment case required |

## Read-replica decision record

| Gate | Evidence | Decision |
| --- | --- | --- |
| Writer pressure remains materially read-driven after query/index/summary improvements | No production evidence demonstrates this trigger | No launch reader |
| Every candidate query has an approved consistency class and staleness limit | Central four-class contract exists; production query inventory does not | No launch reader |
| Lag, conflicts, cancellation, retained WAL, and failure are observable | Local mechanics pass; deployment observability is unproven | No launch reader |
| Security-sensitive and read-your-write paths remain on the writer | Contract and local negative cases require writer routing | Preserve writer-only baseline |
| Replica loss cannot cause an uncontrolled writer fallback surge | Degradation contract rejects/delays non-critical reads; live proof remains | No launch reader |
| Ecto pool, credentials, cost, recovery, and tenant movement remain acceptable | A reader is excluded from the accepted 50-connection baseline | Reconsider only after a measured trigger |

Do not approve a read replica merely from annual row count. If the gate fails, keep OLTP reads on the writer and use query improvements or governed asynchronous projections.

## Evidence conclusion

- Topology decision: ADR 0017 accepts a provider-neutral PostgreSQL contract. The earlier [AWS estimate is withdrawn](managed-postgresql-topology.md); actual hosting and topology selection move to deployment qualification.
- Read-replica decision: no launch reader; reconsider only after measured, sustained read pressure and all consistency gates pass.
- Pooler decision: no launch pooler; reconsider only if bounded direct pools miss the accepted connection or checkout targets and compatibility passes.
- Cross-region DR decision: deferred from launch pending approved residency/RPO/RTO need and a complete promotion/failback drill.
- Residual risks, owner, and expiry: selected-provider behaviour, multi-node fairness, deployment PITR, residency, and cost remain owned by platform engineering, security/records governance, and operations; review by 2026-12-15 or before provisioning.

See [database operations and read routing](../../architecture/postgresql-availability-recovery-and-read-routing.md), [tenant-placement capacity evidence](tenant-placement-capacity.md), [tenant-fairness measurement](tenant-fairness-backpressure-measurement.md), and [quality-attribute targets](../../architecture/quality-attribute-targets.md).
