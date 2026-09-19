# PostgreSQL availability, recovery, and read routing

- Status: Proposed during Phase 0
- Owner: Platform engineering and operations
- Governing record: [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- Review trigger: material workload, consistency, recovery, placement, provider, or connection-topology change

## Architectural position

PostgreSQL remains the single authoritative write and transaction boundary. High availability, read scaling, point-in-time recovery, and regional disaster recovery are different capabilities and must not be represented by one generic "replica" checkbox.

The initial production hypothesis is:

```text
clients
   |
Phoenix/Ash application nodes
   |
trusted placement and consistency router
   |
writer endpoint --> PostgreSQL primary --> same-region HA standby
                         |
                         +--> WAL archive and recoverable backups
                         |
                         +--> optional asynchronous read replica
                         |
                         +--> transactional outbox --> governed Oban queues
                                                        |
                                                        +--> projections, reports,
                                                             notifications and analytics
```

The Phase 0 repository defines this contract and its evidence requirements. Production infrastructure, production applications, and school business modules remain outside Phase 0.

## Topology responsibilities

| Component | Primary purpose | Application use | Required proof |
| --- | --- | --- | --- |
| Writer/primary | Authoritative state, policy-sensitive reads, locks, audit, and outbox | Reads and writes | Commit latency, capacity, constraints, pool budget, and degradation |
| HA standby | Same-region failover after instance or zone failure | Provider-dependent; not a default report target | Durability, replication health, failover, reconnection, and outbox continuity |
| Read replica | Offload approved stale-tolerant reads | Read-only and lag-gated | Read benefit, maximum lag, conflict behaviour, and safe degradation |
| WAL archive and backups | Point-in-time and dated recovery | No query traffic | Retention, encryption, restore integrity, achieved RPO, and achieved RTO |
| Cross-region replica | Regional disaster recovery | Only through an approved promotion/runbook | Residency, non-zero-lag risk, promotion, endpoint switch, failback, and reconciliation |

A provider may combine some physical resources, but every responsibility and acceptance target remains explicit. Long reports must not compromise the standby that protects writer availability.

## Consistency and routing contract

| Class | Examples | Route | Degradation rule |
| --- | --- | --- | --- |
| Primary-required | Authorization and revocation; tenant placement; module gates; job/outbox locks; current configuration | Writer | Fail closed or return a retryable error; never use stale replica state to authorize |
| Read-your-write | Attendance confirmation; correction confirmation; newly changed configuration | Writer for the bounded interaction, or a reader only after a proven replay position | Preserve monotonic user experience; do not report a committed write as missing |
| Bounded-staleness | Approved historical dashboards, operational summaries, and exports | Read-only replica while lag is within the declared limit | Delay, queue, reject, or use an explicitly capacity-safe fallback |
| Analytical | Long-horizon analysis and institutional reporting | Governed publication outside OLTP | Serve the last approved publication with its as-of time or report unavailability |

Routing is a platform-owned capability. A request, module, report template, job, or AI tool cannot choose a database hostname or downgrade its consistency class. Every route preserves authenticated actor, tenant, placement, routing version, data classification, and correlation context.

Read-after-write and replica-lag tests must use real separate connections. Ecto repositories open separate pools, and process-local dynamic repository selection must be re-established and restored across tasks and jobs.

## Attendance burst model

The current synthetic population is 5,000 learners in one school and 800 learners in each of four schools. One synchronized period therefore produces 8,200 baseline attendance facts.

| Peak window | 5,000-learner school | All five schools |
| --- | ---: | ---: |
| Five minutes | 16.7 facts/second | 27.3 facts/second |
| One minute | 83.3 facts/second | 136.7 facts/second |
| Thirty seconds | 166.7 facts/second | 273.3 facts/second |

These are logical facts, not physical writes or transactions. If a synthetic average classroom has 25 learners, all five schools create about 328 attendance-session transactions per period, or about 10.9 session transactions per second in a 30-second window. This is an illustrative batching hypothesis, not a target or benchmark.

Physical pressure is modelled as:

```text
peak_fact_rate = facts_due_in_peak_window / peak_window_seconds
peak_transaction_rate = session_batches / peak_window_seconds
physical_write_rate = peak_fact_rate x measured_write_amplification
connection_demand = concurrent_actions x connections_held_per_action
```

Write amplification includes current state, immutable changes, security audit, outbox, indexes, WAL, corrections, retries, and any synchronous projection. The benchmark must measure it; architecture prose cannot assume a multiplier.

## Bounded write path

The later attendance capability must follow these constraints:

1. Submit one tenant-qualified attendance session or classroom batch, not one request per learner.
2. Include a stable session identifier, roster/version or equivalent concurrency evidence, and an idempotency key.
3. Validate the real actor, tenant, permission, roster, allowed state transition, and every affected learner before commit.
4. Use one explicit transaction boundary for the session. No unauthorized row may partially commit.
5. Write authoritative state, immutable change/audit evidence, and the minimal outbox fact in the same primary transaction.
6. Return success only after the authoritative commit.
7. Run summaries, notifications, integrations, exports, and analytical publication after commit through governed consumers.
8. Retry transient failures with bounded exponential backoff and the same idempotency key.

The benchmark compares this path with an intentionally unbatched shape to quantify the avoided request, commit, and connection amplification. The comparison is evidence only and does not make unsafe unbatched behaviour a supported API.

### Bulk implementation evidence

Batching is a domain contract, not a promise that a framework call becomes one SQL statement. For an Ash implementation, benchmark the supported `Ash.bulk_create/4` or `Ash.bulk_update/4` path in the pinned release and record the selected strategy, transaction shape, generated SQL, query count, lock behaviour, memory use, error semantics, and repeated-run variance. Error-collection options do not permit unauthorized or unexpectedly partial writes.

Choose the smallest implementation that meets the accepted target while preserving whole-session validation and commit semantics. If the supported Ash path cannot meet a measured requirement, a bounded Ecto or SQL implementation may sit behind the same named action. It must keep trusted actor and tenant context, authorization, idempotency, audit, outbox, constraints, and the registered maintenance and negative-test obligations; it does not become a caller-visible persistence API.

## Backpressure and asynchronous work

The system preserves the primary rather than allowing an unbounded queue of open transactions:

- bound request payload and batch size;
- cap concurrent work per application node and database placement;
- measure pool checkout wait and reject retryable work before the transaction when the accepted queue budget is exhausted;
- enforce tenant fairness so one pooled school cannot consume all connections or workers;
- isolate critical outbox dispatch from notifications, integrations, reports/exports, and analytical publication;
- pause or reduce lower-priority consumers during a declared operational burst; and
- never acknowledge an attendance write merely because an in-memory or non-authoritative queue accepted it.

Queue names and exact concurrency are later implementation choices, but the service classes and starvation rules are platform contracts. The transactional outbox remains the bridge between committed state and at-least-once consumers.

Overload is classified before an interface maps it to a transport response. A deliberate caller- or tenant-fairness limit is `rate_limited` and may map to HTTP 429. Database, pool, or required-dependency saturation is `retryable_dependency` and normally maps to HTTP 503. `Retry-After` is supplied only when the owning control can state a bounded retry interval, and write retries reuse the same idempotency key. A generic database checkout failure is not relabelled as caller rate limiting.

The [Phase 0 fairness follow-up](../phase-0/evidence/tenant-fairness-backpressure-measurement.md) demonstrates that a two-slot-per-tenant candidate can protect the other tenants in the local synthetic workload while preserving atomicity and outbox facts. Its advisory-lock proxy rejects only after database checkout and transaction start, so it is not the production control described above. The [pre-checkout follow-up](../phase-0/evidence/precheckout-admission-measurement.md) closes that local seam. Production readiness still requires the same comparison through the actual pool, multiple application nodes, and selected deployment environment.

## Connection budget

Every candidate placement records:

```text
total_connections =
  application_nodes x writer_pool_per_node
  + application_nodes x reader_pool_per_node
  + Oban_and_outbox_pools_per_placement
  + migration_administration_monitoring_and_replication_reserve
```

The budget must remain below the provider and PostgreSQL limit with failover and maintenance headroom. Increasing Ecto `pool_size`, application replicas, database placements, read repositories, or Oban instances consumes the same budget. More connections are not automatically more throughput; pool wait, query duration, lock time, CPU, memory, and storage latency decide the useful concurrency.

Use DBConnection's bounded checkout queue as overload protection and expose its wait and rejection behaviour as service indicators. PgBouncer or a managed pooler is introduced only when measurements show direct pools cannot meet the budget. Before transaction pooling, prove compatibility with prepared statements, migrations, advisory locks/listeners, and tenant/RLS context. Persistent session state cannot be a tenant security boundary.

## Read-replica adoption gate

A read replica is justified only when all of the following are recorded:

- primary pressure is materially read-driven after query, index, summary, and campaign-shaping work;
- the selected query classes have an owner-approved maximum staleness;
- replica lag, WAL replay, standby conflicts, and query cancellation are monitored;
- authorization, placement, module gates, job locks, and immediate read-after-write remain on the writer;
- replica failure and lag have bounded degradation without a writer fallback storm;
- its Ecto pool and credentials fit the per-placement connection and least-privilege budgets; and
- the benefit exceeds its cost, WAL retention, operational, recovery, and movement effects.

If those conditions do not hold, improve the primary workload or publish a governed asynchronous projection instead.

## Availability and recovery contract

Operations must define and later prove:

- commit durability and accepted data-loss window for each write class;
- failover detection, promotion, writer-endpoint update, application reconnection, and failback;
- behaviour of in-flight and retried idempotent actions during failover;
- continued tenant placement enforcement after topology change;
- outbox continuity and duplicate-tolerant consumption;
- backup and WAL retention, encryption, deletion protection, and access controls;
- point-in-time restore into an isolated environment, integrity verification, and reconciliation;
- regional recovery only when the approved RPO/RTO and residency require it; and
- a drill cadence with dated evidence and accountable owners.

High availability does not recover an accidentally deleted or corrupted fact after that change replicates. Restore capability is accepted only after a dated restore drill meets its target.

## Observability and capacity signals

| Layer | Required indicators |
| --- | --- |
| Domain action | facts/second, session transactions/second, p50/p95/p99 latency, validation/authorization errors, retries, duplicates, and unauthorized partial commits |
| Connection boundary | pool size, checkout wait, timeouts/rejections, active/idle connections, and per-node/per-placement allocation |
| PostgreSQL writer | CPU, memory, storage latency/IOPS, commits, locks/deadlocks, WAL rate, checkpoints, buffer behaviour, autovacuum lag, bloat, table/index growth, and slow queries |
| Replica/standby | byte and time lag, receive/flush/replay positions, conflicts/cancellations, retained WAL, replay throughput, and readiness |
| Asynchronous work | oldest outbox item, dispatch and queue age, retry/dead-letter counts, throughput, and tenant fairness |
| Recovery | latest restorable time, backup age, restore-test date, achieved RPO/RTO, integrity result, and unresolved reconciliation |

Telemetry uses safe tenant and placement identifiers without restricted payloads or credentials.

## Evidence and failure scenarios

The Phase 0 evidence templates require later controlled tests for:

1. synchronized classroom/session batches for the large school and all five schools;
2. retries, corrections, duplicates, and permission revocation racing a submission;
3. report overlap, outbox dispatch, and one noisy pooled tenant;
4. writer connection exhaustion and application backpressure;
5. a lagging or unavailable read replica and a prohibited stale authorization read;
6. long replica queries conflicting with WAL replay;
7. HA failover during a write burst, application reconnection, and idempotent retry;
8. outbox continuity and duplicate-safe consumers across failover;
9. point-in-time restore at planning-horizon volume; and
10. placement routing, RLS/pool context, and credential isolation after failover or restore.

Tests use synthetic data and record exact hardware or service tier, PostgreSQL/provider settings, topology, connections, schema/index shape, retained data distribution, commands, repeated-run variance, raw evidence, and limitations.

## Decision triggers

| Choice | Trigger required before adoption |
| --- | --- |
| Read replica | Measured read-driven writer pressure and approved staleness/failure behaviour |
| PgBouncer or managed pooler | Measured connection-budget or checkout-wait pressure plus compatibility proof |
| Attendance partitioning | Measured pruning, retention, maintenance, index, and migration benefit |
| Dedicated tenant database | Recovery, isolation, noisy-neighbour, movement, contractual, or sustained workload evidence |
| Dedicated cell | Residency, SLA, high-risk integration, or sustained whole-cell capacity evidence |
| Cross-region DR replica | Approved regional RPO/RTO, residency, promotion, failback, and reconciliation plan |
| Broker, sharding, or multi-writer store | Evidence that bounded PostgreSQL writes, placement, indexing, and projections cannot meet accepted targets |

## External technical evidence

- [PostgreSQL standby and streaming replication](https://www.postgresql.org/docs/current/warm-standby.html) distinguishes asynchronous and synchronous replication and documents durability, latency, WAL, and monitoring effects.
- [PostgreSQL hot standby](https://www.postgresql.org/docs/current/hot-standby.html) documents replay conflicts, query cancellation, lag, and I/O contention.
- [PostgreSQL point-in-time recovery](https://www.postgresql.org/docs/current/continuous-archiving.html) documents base backups, WAL archiving, timelines, and recovery targets.
- [PostgreSQL replication statistics](https://www.postgresql.org/docs/current/monitoring-stats.html) defines write, flush, replay, and conflict indicators.
- [Ecto replicas and dynamic repositories](https://ecto.hexdocs.pm/replicas-and-dynamic-repositories.html) documents read-only repositories, separate pools, transaction visibility, and process-local routing.
- [DBConnection queue configuration](https://db-connection.hexdocs.pm/DBConnection.html#module-queue-config) documents bounded checkout waits and overload shedding.
- [Ash bulk actions](https://ash-project.github.io/ash/Ash.html#bulk_create/4-options) documents `:all`, `:batch`, and no-transaction execution choices.
- [Ash policy behaviour for bulk creates](https://ash.hexdocs.pm/policies.html#bulk-creates) documents transaction requirements for filter-mode authorization.
- [Oban queues](https://oban.hexdocs.pm/Oban.Queues.html) documents independently controlled queue concurrency.
- [PgBouncer configuration](https://www.pgbouncer.org/config.html) documents pool modes, connection limits, session-state constraints, and prepared-statement handling.
- [Google Cloud SQL disaster recovery](https://docs.cloud.google.com/sql/docs/postgres/intro-to-cloud-sql-disaster-recovery) is one managed-service example that distinguishes regional HA from cross-region DR and its non-zero RPO risk.
