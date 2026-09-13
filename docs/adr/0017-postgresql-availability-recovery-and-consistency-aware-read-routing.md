# ADR 0017: PostgreSQL availability, recovery, and consistency-aware read routing

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering and operations
- Deciders: Architecture review group, operations owner, and security/privacy owner
- Supersedes: None

## Context

PostgreSQL is the authoritative store for school state, audit facts, and the transactional outbox. The platform must distinguish database high availability, read scaling, backup recovery, and regional disaster recovery because each has different consistency, failure, cost, and operational properties.

Attendance is a useful stress profile. Under the current synthetic assumptions, all five schools may submit 8,200 attendance facts near the start of one period. If those facts arrive within 30 seconds, the logical rate is about 273 facts per second. That does not by itself require a distributed write architecture, but per-learner requests, connection fan-out, synchronous side effects, excessive indexes, report overlap, and unmeasured audit or outbox amplification can turn it into an avoidable overload.

An asynchronous read replica cannot increase PostgreSQL write capacity and may lag behind committed permissions, tenant configuration, attendance, or placement changes. A replica therefore cannot be introduced as an undifferentiated destination for application reads.

## Decision drivers

- Durable, authoritative state changes with explicit RPO and RTO.
- Predictable synchronized-write behaviour without weakening authorization or atomicity.
- Read-your-write behaviour for user confirmation and security-sensitive state.
- Bounded connection use across application nodes, repositories, jobs, and placements.
- Safe degradation during replica lag, failover, recovery, or reporting overload.
- Measured triggers for read replicas, connection poolers, partitioning, and stronger placement.

## Considered options

1. A managed PostgreSQL writer with a same-region, zone-redundant HA standby, continuous WAL-backed recovery, consistency-aware read routing, and evidence-triggered read or disaster-recovery replicas.
2. A writer and one asynchronous read replica treated interchangeably as HA, backup, and the destination for all reads.
3. A single PostgreSQL instance with periodic logical backups and no automatic failover.
4. Multi-writer PostgreSQL, sharding, or an event-streaming write path from the start.

## Decision

Propose option 1 as the production topology hypothesis for Phase 1 planning. Phase 0 defines and validates the contract; it does not provision production infrastructure.

The baseline topology is one managed PostgreSQL writer endpoint plus a same-region standby in another availability zone where the selected provider and region support it. The HA configuration must have an explicit commit-durability guarantee, automatic failover behaviour, connection-endpoint contract, monitored replication state, and tested application reconnection. Continuous WAL archiving, encrypted backups, retention, point-in-time recovery, and dated restore drills are separate mandatory controls. A standby or replica is not treated as a backup.

Do not deploy a general-purpose read replica by default. Add a separate asynchronous reader only when measured primary read CPU or I/O remains a limiting factor after query, index, summary, and report-workload improvements, and only for reads whose declared staleness budget permits it. Long reports must not share the HA standby when doing so can delay WAL replay or undermine failover readiness.

Every read path is classified and centrally routed:

1. **Primary-required:** authorization and revocation state, tenant and placement configuration, module gates, writes, corrections, locks, outbox and job coordination, and other security or transaction decisions.
2. **Read-your-write:** immediate confirmation and follow-up reads stay on the writer for the bounded interaction or until a proven replication position is visible.
3. **Bounded-staleness:** explicitly approved historical or operational projections may use a read-only replica while measured lag remains below their owner-approved limit.
4. **Analytical:** governed publications leave OLTP and are queried outside the transactional database.

Replica unavailability or excessive lag follows the owning capability's declared degradation policy. Security-sensitive reads return to the primary by design. Non-critical reports are delayed, queued, or rejected rather than creating an uncontrolled fallback surge against the writer. No replica result independently authorizes a state change.

Synchronized writes use named, idempotent domain actions with bounded batches. The future attendance unit is a tenant-qualified attendance session or classroom submission, not one transaction per learner and not one school-wide transaction. The action validates the complete tenant, actor, roster/version, permission, and state-transition scope before commit. Its transaction writes authoritative state, immutable change/audit facts, and the minimal outbox fact together. Notifications, summaries, integrations, exports, and analytical publication run after commit through separately governed Oban queues.

The platform owns a connection budget per database placement:

```text
total_connections =
  application_nodes x writer_pool_per_node
  + application_nodes x reader_pool_per_node
  + job_and_outbox_pools
  + migration_administration_monitoring_and_replication_reserve
```

Application autoscaling, Ecto repositories, Oban instances, and tenant placements cannot be configured independently of this budget. Pool checkout wait, saturation, rejected work, and per-tenant fairness are first-class signals. Backpressure rejects retryable work before opening a transaction when safe capacity is unavailable; a retry reuses the same idempotency key.

PgBouncer or a managed transaction pooler remains evidence-triggered. Adopt it only when direct Ecto/Oban pools cannot stay within the accepted connection budget. Transaction pooling requires a compatibility test for prepared statements, migrations, advisory locks, listener behaviour, and any tenant or RLS context. Tenant and authorization safety must never depend on persistent session state crossing transaction-pooled connections.

Cross-region replication remains a disaster-recovery option, not the launch default. It requires approved regional RPO/RTO, residency, promotion, endpoint switch, split-brain prevention, reconciliation, failback, and restore evidence.

## Consequences

### Positive

- Availability, read scaling, backup recovery, and regional recovery have distinct, testable contracts.
- The authoritative write and authorization path remains simple and transactionally coherent.
- Classroom/session batching reduces request, commit, and connection amplification during synchronized bursts.
- Read replicas and poolers are added only when measurements justify their cost and consistency risk.

### Negative

- Some reports may be delayed rather than automatically falling back to the writer.
- Synchronous or provider-managed HA can add commit latency and requires capacity headroom.
- Central read routing, lag monitoring, reconnection, and failure drills add platform work.
- Dedicated databases multiply pools, backup scopes, Oban instances, monitoring, and operational fan-out.

## Security, privacy, operability, and migration effects

The real actor, authenticated tenant, placement, and routing version remain mandatory on primary and replica reads. Request input cannot select a repository or weaken the consistency class. Separate least-privilege credentials cover application writes, read-only replicas, migrations, backups, analytics, replication, and time-bounded support.

Permission revocation, module activation, tenant movement, and other security-sensitive state are never decided from an asynchronous replica. If PostgreSQL RLS is adopted, pool compatibility must prove that tenant context is established transaction-locally, fails closed, and cannot leak to another checkout.

Backups, WAL archives, replica credentials, metrics, and recovery artifacts follow the data-classification and residency rules. Failover cannot bypass placement membership constraints or default an unknown tenant to another database. Schema changes use expand-and-contract techniques; heavy indexes, rewrites, failovers, and recovery drills are scheduled outside declared school peak windows unless the exercise explicitly tests peak behaviour.

## Validation evidence

Acceptance requires the [PostgreSQL availability and burst evidence](../phase-0/evidence/postgresql-availability-and-burst.md), the [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md), owner-approved [quality targets](../architecture/quality-attribute-targets.md), and the related threat-model treatments.

Evidence must include synchronized session batches, unbatched comparison, audit/outbox amplification, report overlap, pool exhaustion, replica lag, stale authorization denial, HA failover during load, application reconnection, outbox continuity, point-in-time restore, cross-tenant routing denial, and a noisy pooled tenant. Results must name the environment, PostgreSQL and provider settings, connections, data shape, repeated-run variance, and limitations.

## Fallback and exit cost

If managed automatic failover is unavailable or fails the accepted latency, durability, or recovery targets, use a simpler statically operated topology only with an explicit residual-risk acceptance and tested restore plan. If read routing cannot be made safe, keep all OLTP reads on the writer and move heavy reporting to governed asynchronous projections. If transaction pooling is incompatible, retain bounded direct pools or session pooling and scale the database placement accordingly.

Multi-writer, sharding, a broker-first ingestion path, or another database requires a new ADR with evidence that writer sizing, batching, indexing, workload isolation, and placement cannot meet the accepted targets.

## Review triggers

- The writer approaches an accepted CPU, I/O, WAL, storage, latency, or connection threshold.
- Replica lag, standby conflicts, failover, restore, or reconnection misses its target.
- A stale read affects authorization, tenant placement, module state, or user confirmation.
- Application-node, database-placement, Oban, RLS, or pooler topology changes.
- Regional RPO/RTO, residency, or provider capabilities change.
- A domain proposes partitioning, sharding, multi-writer storage, or queued acceptance before the authoritative commit.

## Related records

- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0009](0009-cache-taxonomy-invalidation-and-valkey-trigger.md)
- [Database operations and read routing](../architecture/postgresql-availability-recovery-and-read-routing.md)
- [Threat model](../security/threat-model.md)
