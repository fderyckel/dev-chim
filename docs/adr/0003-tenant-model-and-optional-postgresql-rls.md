# ADR 0003: Tenant model, placement profiles, and optional PostgreSQL RLS

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Security architecture
- Deciders: Architecture review group and privacy owner
- Supersedes: None

## Context

Child and school data must not cross tenant boundaries through requests, jobs, events, caches, files, search, realtime, exports, telemetry, or AI tools. The original logical tenant model must also support pooled databases, dedicated databases, and dedicated deployment cells without fragmenting the product or allowing request-selected routing.

Attendance illustrates why placement cannot be inferred from student count. Under the current synthetic assumption, the five-school example produces 13.12 million baseline attendance facts per year and 131.2 million over ten years before corrections, history, audit, indexes, outbox records, projections, analytics, WAL, and backups. Those counts are planning inputs; synchronized period-start writes, report overlap, retention, recovery, and isolation requirements determine the actual pressure.

## Decision drivers

- Fail-closed tenant propagation.
- Relationship-aware, tenant-defined authorization.
- Database constraints that prevent accidental cross-tenant links.
- One logical tenant contract across pooled and dedicated placements.
- Placement based on per-domain workload and isolation evidence, not student count.
- Trusted, versioned routing with safe tenant movement and no default fallback.

## Considered options

1. Attribute-based logical tenancy and mandatory tenant keys across evidence-driven pooled, dedicated-database, and dedicated-cell profiles, with RLS evaluated as a backstop.
2. One pooled database for every tenant regardless of workload, recovery, or isolation needs.
3. One database or complete stack per tenant regardless of evidence.
4. Schema per tenant as the strategic default.

## Decision

Propose attribute-based logical tenancy in every placement. Every tenant-owned row has a non-null tenant key, compound constraints prevent cross-tenant relationships, and the selected database rejects tenants not assigned to that placement. Ash policies remain the business authorization layer.

Support three physical placement profiles without changing the application model:

1. pooled database: several tenants use tenant-keyed tables and shared database resources;
2. dedicated database: one tenant receives separate credentials, database resources, backup, and restore scope within the common release; and
3. dedicated cell: application workers, database, storage, cache, queues, and supporting resources are separated.

Schema-per-tenant is not the strategic default. It remains an evidence-driven exception because migration fan-out, administration, movement, and restore complexity remain while the database failure domain is still shared.

A platform-owned control-plane registry resolves authenticated tenant identity to cell, database placement, storage namespace, queue namespace, and routing version. It stores routing metadata, not ordinary school records. Request parameters cannot select a database, schema, cell, queue, or storage namespace. Unknown, stale, conflicting, or unavailable placement state fails closed with no default-database fallback.

Placement decisions use projected record volume, burst write concentration, write amplification, retention, report and integration workloads, connection-pool pressure, recovery objectives, residency, contractual isolation, accepted breach blast radius, and operating cost. Student count alone is prohibited as a placement threshold.

For the current five-school scenario, one common release and one regional cell are a candidate starting position. The 5,000-student school is a dedicated-database candidate; the four 800-student schools are pooled-database candidates only if governance accepts the blast radius and combined peak tests pass. Neither candidate is approved by this ADR without the linked benchmark, recovery, and security evidence.

Decide RLS only after the pressure-test and threat analysis prove connection, job, migration, backup, support, and pool-context safety. If adopted, use non-owner application credentials, default-deny policies, `FORCE ROW LEVEL SECURITY` where appropriate, and tests for `BYPASSRLS`, table-owner, referential-integrity, `TRUNCATE`, and `REFERENCES` paths. RLS remains defence in depth, not business authorization.

Roles, scopes, and capabilities are tenant-defined hierarchical data. School job-title constants are prohibited as the production authorization model.

## Consequences

### Positive

- One operating model supports efficient transactions and migrations.
- Tenants can move to stronger containment without losing logical tenant controls or taking a separate code line.
- Placement can follow measured domain pressure and recovery needs.
- Optional RLS remains available as defence in depth.

### Negative

- Every path must propagate tenant context correctly.
- RLS, if adopted, complicates pooling, maintenance, support, and migrations.
- Trusted routing becomes a critical control plane and availability dependency.
- Dedicated databases and cells increase migration, job, backup, restore, observability, and cost fan-out.
- Dynamic repository selection is process-local, so spawned tasks and jobs require explicit propagation and cleanup.

## Security, privacy, operability, and migration effects

Missing tenant or placement context fails closed. Support access requires explicit tenant selection, strong assurance, reason, expiry, and enhanced audit. Global reference data must be clearly separate from tenant-owned data.

Database, queue, storage, cache, search, analytics, telemetry, and AI placement must follow the same trusted routing version. Placement changes are named, audited operations with quiescence or controlled dual-routing, reconciliation, rollback, and restore proof. Application, migration, backup, analytics, and support use separate least-privilege identities.

Range partitioning for append-heavy resources is decided per resource after benchmark and retention evidence. A proposal must account for PostgreSQL's requirement that partitioned-table unique and primary keys include all partition-key columns, plus migration locks, pruning, foreign keys, archival, and stable domain identifiers.

## Validation evidence

See the [tenant placement and workload capacity model](../architecture/tenant-placement-and-capacity.md), [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md), [trusted pooled/dedicated routing evidence](../phase-0/evidence/trusted-routing.md), [threat model](../security/threat-model.md), and Ash tenancy tests.

The focused routing slice passes pooled and dedicated selection, cross-placement denial, explicit spawned-task and job propagation, stale and missing routing, untrusted request input, repository-type validation, and process cleanup. Its follow-up passes capability-gated movement between two real disposable databases with source authority during copy, quiescence, code-owned tenant-snapshot reconciliation, versioned cutover, rollback, and stale-envelope rejection across event, file, cache, search, realtime, export, analytics, telemetry, AI-tool, and integration classes. Acceptance still requires synchronized workload bursts, concurrent permission revocation, pool exhaustion, production control-plane and real-adapter integration, backup, restore, and accountable review. Attendance calculations alone are not acceptance evidence.

## Fallback and exit cost

Begin with the simplest profile that passes the accepted legal, security, capacity, and recovery requirements. Move a tenant between approved profiles through the versioned movement contract when evidence changes. If dynamic placement cannot be made safe, use statically configured cells or databases while preserving the same tenant-keyed application model.

Adopt RLS as a backstop if application-only controls cannot meet the accepted threat model. If RLS cannot be operated safely, retain application policy and stronger physical placement while recording the residual risk.

## Review triggers

- A cross-tenant control weakness or independent security finding.
- Connection-pool, support, or job architecture changes.
- A domain's burst, retention, reporting, integration, or recovery profile materially changes.
- A tenant placement or movement drill fails its target.
- Residency, contractual isolation, or accepted breach blast radius changes.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0009](0009-cache-taxonomy-invalidation-and-valkey-trigger.md)
- [ADR 0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [Data classification](../security/data-classification.md)
