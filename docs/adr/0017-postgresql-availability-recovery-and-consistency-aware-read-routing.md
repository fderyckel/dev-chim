# ADR 0017: PostgreSQL availability, recovery, and consistency-aware read routing

- Status: Accepted
- Date: 2026-09-13
- Decision date: 2026-09-16
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

1. A qualified PostgreSQL writer deployment with fault-domain-aware HA where required, continuous WAL-backed or equivalent recovery, consistency-aware read routing, and evidence-triggered read or disaster-recovery replicas.
2. A writer and one asynchronous read replica treated interchangeably as HA, backup, and the destination for all reads.
3. A single PostgreSQL instance with periodic logical backups and no automatic failover.
4. Multi-writer PostgreSQL, sharding, or an event-streaming write path from the start.

## Decision

Adopt the provider-neutral PostgreSQL availability and recovery contract in option 1. Phase 0 defines and validates the contract; it does not select a hosting provider or provision production infrastructure. Deployment-environment qualification belongs to the later infrastructure phase and cannot silently weaken this ADR.

The deployment baseline is one authoritative PostgreSQL writer endpoint. Where the selected hosting model claims high availability, it must provide a separately failed-over standby or equivalent fault-domain separation with an explicit commit-durability guarantee, automatic or rehearsed failover behaviour, connection-endpoint contract, monitored replication state, and tested application reconnection. Continuous WAL archiving or equivalent incremental recovery, encrypted backups, retention, point-in-time recovery, and dated restore drills are separate mandatory controls. A standby or replica is not treated as a backup.

Do not deploy a general-purpose read replica by default. Add a separate asynchronous reader only when measured primary read CPU or I/O remains a limiting factor after query, index, summary, and report-workload improvements, and only for reads whose declared staleness budget permits it. Long reports must not share the HA standby when doing so can delay WAL replay or undermine failover readiness.

Every read path is classified and centrally routed:

1. **Primary-required:** authorization and revocation state, tenant and placement configuration, module gates, writes, corrections, locks, outbox and job coordination, and other security or transaction decisions.
2. **Read-your-write:** immediate confirmation and follow-up reads stay on the writer for the bounded interaction or until a proven replication position is visible.
3. **Bounded-staleness:** explicitly approved historical or operational projections may use a read-only replica while measured lag remains below their owner-approved limit.
4. **Analytical:** governed publications leave OLTP and are queried outside the transactional database.

Replica unavailability or excessive lag follows the owning capability's declared degradation policy. Security-sensitive reads return to the primary by design. Non-critical reports are delayed, queued, or rejected rather than creating an uncontrolled fallback surge against the writer. No replica result independently authorizes a state change.

Synchronized writes use named, idempotent domain actions with bounded batches. The future attendance unit is a tenant-qualified attendance session or classroom submission, not one transaction per learner and not one school-wide transaction. The action validates the complete tenant, actor, roster/version, permission, and state-transition scope before commit. Its transaction writes authoritative state, immutable change/audit facts, and the minimal outbox fact together. Notifications, summaries, integrations, exports, and analytical publication run after commit through separately governed Oban queues.

The implementation must measure the supported bulk strategies in the pinned Ash release rather than assuming a bulk call produces one SQL statement or one transaction. The selected action records its actual query and lock shape. If a measured requirement needs bounded Ecto or SQL, that implementation remains internal to the same named action and preserves authorization, tenant context, atomicity, idempotency, audit, outbox, database constraints, and negative tests.

The platform owns a connection budget per database placement:

```text
total_connections =
  application_nodes x writer_pool_per_node
  + application_nodes x reader_pool_per_node
  + job_and_outbox_pools
  + migration_administration_monitoring_and_replication_reserve
```

Application autoscaling, Ecto repositories, Oban instances, and tenant placements cannot be configured independently of this budget. Pool checkout wait, saturation, rejected work, and per-tenant fairness are first-class signals. Backpressure rejects retryable work before opening a transaction when safe capacity is unavailable; a retry reuses the same idempotency key. Deliberate caller or tenant throttling is a rate-limited condition and may map to HTTP 429. Pool, database, or required-dependency saturation is a retryable-dependency condition and normally maps to HTTP 503; it is not disguised as caller rate limiting. A `Retry-After` value is emitted only when a bounded interval is known.

Slice 1D implements only the node-local admission contract before a repository callback. It derives tenant and placement keys from validated platform context, uses explicit limits, classifies tenant and placement saturation separately, releases or reclaims permits on every termination path, and exposes no production default or distributed-capacity claim. Acceptance of this ADR does not choose a production database topology or authorize a repository, persistent resource, or write path.

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

The Phase 0 decision uses the [PostgreSQL availability and burst evidence](../phase-0/evidence/postgresql-availability-and-burst.md), the [combined local capacity/recovery measurement](../phase-0/evidence/capacity-and-recovery-measurement.md), the [pre-checkout admission follow-up](../phase-0/evidence/precheckout-admission-measurement.md), the [full-horizon restore](../phase-0/evidence/full-horizon-restore-measurement.md), the [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md), architect-approved [quality targets](../architecture/quality-attribute-targets.md), and the related threat-model treatments. The withdrawn [AWS example](../phase-0/evidence/managed-postgresql-topology.md) is historical evidence only and does not select a provider.

Deployment qualification must include synchronized session batches, unbatched comparison, audit/outbox amplification, report overlap, pool exhaustion, replica lag where applicable, stale authorization denial, failover during load where HA is claimed, application reconnection, outbox continuity, point-in-time restore, cross-tenant routing denial, and a noisy pooled tenant. Results must name the environment, PostgreSQL and hosting settings, connections, data shape, repeated-run variance, and limitations.

The local 2026-09-16 run exercises those PostgreSQL mechanics with real disposable primary, physical standby, WAL archive, and isolated restore processes. It passes the accepted local write, replica-safety, failover, outbox, and one-percent PITR gates but fails all three repetitions of the raw pooled noisy-tenant degradation target. The final pre-checkout candidate passes three local PostgreSQL reruns with -0.151%-0.257% other-tenant degradation while rejecting noisy-tenant work before its repository callback. The exact 131.2-million-row local restore passes in 9,835.776 ms with zero logical mismatches. [Slice 1D](../phase-1/evidence/database-admission.md) implements only that trusted node-local admission contract without repository wiring or capacity defaults. This closes the Phase 0 decision evidence. Multi-node calibration and qualification on the eventually selected hosting environment remain production-infrastructure gates, not Phase 0 exit gates.

## Fallback and exit cost

If the selected hosting model cannot provide automatic failover or fails the accepted latency, durability, or recovery targets, use a simpler statically operated topology only with an explicit residual-risk acceptance and tested restore plan. If read routing cannot be made safe, keep all OLTP reads on the writer and move heavy reporting to governed asynchronous projections. If transaction pooling is incompatible, retain bounded direct pools or session pooling and scale the database placement accordingly.

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
