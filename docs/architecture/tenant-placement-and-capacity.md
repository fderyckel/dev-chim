# Tenant placement and workload capacity

- Status: Proposed during Phase 0
- Owner: Architecture review group with platform engineering and operations
- Governing record: [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md)
- Review trigger: material workload, residency, recovery, isolation, or placement change

## Fit with the original design

The original design remains intact: PostgreSQL is authoritative, every tenant-owned record and work item carries a non-null tenant key, Ash policies enforce business authorization, and every interface fails closed without trusted actor and tenant context. Physical placement is an additional containment and capacity decision; it does not create a second tenant model or a tenant-specific product branch.

One product release may serve several deployment cells and database placements. Module boundaries, deployment cells, and database placements are independent concerns.

## Critical synthesis

The reviewed architecture messages improve the original design, with four qualifications:

1. The attendance arithmetic is a sound baseline estimate under its assumptions, but it is not a benchmark or storage estimate.
2. Student count is an inadequate placement rule. Domain workload, burst shape, retention, reports, integrations, recovery, residency, and accepted breach blast radius drive placement.
3. Eight million annual attendance facts make the 5,000-student school a strong dedicated-database candidate, not an automatic dedicated-database decision. PostgreSQL table size alone does not establish the need.
4. One regional cell is a plausible starting hypothesis only if residency, availability, recovery, correlated-failure, and peak-load evidence support it.

The words "small", "modest", and "large" are prohibited as capacity conclusions unless accompanied by the data shape, time window, environment, measurement, and owner-approved target.

## Attendance planning model

The current synthetic planning case assumes one attendance fact for each scheduled attendance opportunity:

| Population | Calculation | Baseline facts per year |
| --- | --- | ---: |
| One 5,000-student school | `5,000 x 8 periods x 200 days` | 8,000,000 |
| One 800-student school | `800 x 8 periods x 200 days` | 1,280,000 |
| Four 800-student schools | `4 x 1,280,000` | 5,120,000 |
| All five schools | `8,000,000 + 5,120,000` | 13,120,000 |
| Ten-year baseline | `10 x 13,120,000` | 131,200,000 |

These figures exclude corrections, domain history, security audit, attendance sessions, outbox events, indexes, read models, analytical copies, WAL, replicas, backups, bloat, and temporary maintenance space. They also assume 200 attendance days and eight opportunities every day for every enrolled student. Evidence must replace those assumptions with distributions for the schools being planned.

Average annual volume hides synchronized period-start bursts. A benchmark profile must define at least:

```text
base_facts_per_day = enrolled_students x attendance_opportunities_per_day
peak_facts_per_second = facts_due_in_peak_window x write_amplification / peak_window_seconds
retained_oltp_bytes = facts x row_and_index_bytes x retention_and_bloat_factors
```

The profile also records concurrent submissions, batch-size distribution, correction rate, idempotent retries, audit and outbox amplification, report overlap, projection lag, connection count, autovacuum behaviour, backup growth, and restore duration. Results without these inputs cannot justify a placement decision.

For orientation only, one period creates 5,000 logical facts for the large school and 8,200 across all five schools. A 30-second window is approximately 166.7 and 273.3 logical facts per second respectively. With an illustrative average batch of 25 learners, the all-school case becomes about 328 tenant-qualified attendance-session transactions per period, or 10.9 transactions per second in 30 seconds. These figures do not include physical write amplification and are not performance targets.

The infrastructure implication is to preserve one authoritative writer and reduce avoidable transaction and connection amplification through bounded session batches. A read replica cannot absorb writes. High availability, stale-tolerant read scaling, point-in-time recovery, and regional disaster recovery remain separate decisions governed by [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md) and [database operations and read routing](postgresql-availability-recovery-and-read-routing.md).

## Placement profiles

| Profile | Isolation and capacity boundary | Appropriate when | Limitation |
| --- | --- | --- | --- |
| Pooled database | Several tenants use tenant-keyed tables and shared database resources | Governance accepts the breach blast radius and combined peak tests pass | Largest shared data and resource failure domain |
| Dedicated database | One tenant has separate credentials, database resources, backup and restore scope while using the common release | Recovery, contractual isolation, movement, workload, or noisy-neighbour evidence justifies it | Application and other cell resources can remain shared |
| Dedicated cell | Application workers, database, queues, storage, cache, and supporting resources are separated | Residency, high-risk integration, SLA, sustained capacity, or contract requires it | Highest operating and release-management cost |
| Schema per tenant | Tenant-specific PostgreSQL schemas inside a shared database | A measured namespace or operational requirement outweighs migration fan-out | Not the strategic default and not equivalent to a dedicated database |

Containers and virtual machines are useful operating boundaries, but do not replace database credentials, network policy, storage and queue namespaces, backup scope, trusted routing, and authorization.

All profiles retain the same logical contract:

- non-null `tenant_id` on tenant-owned rows and work;
- tenant-qualified identities, unique constraints, foreign keys, indexes, events, jobs, cache keys, object paths, projections, exports, telemetry, and AI tools;
- a database-level constraint or referential design that rejects a tenant not assigned to that placement;
- business authorization at the domain boundary; and
- separate least-privilege identities for application, migration, backup, analytics, and time-bounded support work.

## Five-school planning position

The current planning position is deliberately conditional:

- use one immutable product release;
- evaluate one regional cell as the baseline topology;
- benchmark the 5,000-student school as a dedicated-database candidate;
- pool the four 800-student schools only if legal governance and the accepted breach blast radius allow it and their combined burst, reporting, recovery, and connection-pool tests pass;
- keep separate databases on shared automated PostgreSQL infrastructure available when stronger containment is required; and
- require explicit evidence before assigning any school to a dedicated cell.

There is no student-count threshold that automatically selects a profile. Attendance, audit, messaging, assessment attempts, integration events, and other append-heavy workloads may drive placement more strongly than registered-user count.

## Trusted placement routing

A small control-plane registry maps an authenticated tenant identity to a deployment cell, database placement, storage namespace, queue namespace, and monotonically changing routing version. It contains routing metadata, not ordinary school records.

The routing contract must:

- derive tenant identity from authenticated platform context, never a request-selected database, host, schema, or queue;
- expose routing only through one platform-owned data-access boundary;
- fail closed on unknown, stale, conflicting, or unavailable placement state, with no default-database fallback;
- bind database, queue, storage, cache, search, analytics, and telemetry placement to the same versioned decision;
- restore process-local repository selection after each bounded operation and re-establish it in every spawned task or job;
- use separate credentials scoped to the selected placement;
- audit placement changes and administrative reads without logging credentials; and
- support versioned, reversible movement with quiescence or controlled dual-routing, reconciliation, rollback, and restore proof.

Dynamic repositories establish technical feasibility, not routing safety. The Foundation Lab must test task and job boundaries, stale routing versions, placement changes, pool exhaustion, and deliberate attempts to choose another tenant's placement.

## Future attendance design constraints

Attendance is a later business module; Phase 0 creates no attendance schema or API. Its workload nevertheless supplies a useful foundation stress profile. The later module contract must evaluate:

- a stable, tenant-qualified attendance-session identifier instead of repeatedly deriving identity from mutable timetable relationships;
- a named, idempotent bulk action whose entire authorization scope is validated before any attendance fact commits;
- explicit correction actions and current operational state kept distinct from immutable domain history and security audit;
- rebuildable daily, course, and learner summaries for operational reads;
- governed historical analytics published outside OLTP;
- retention and archival that bound active indexes while respecting correction, legal-hold, and recovery obligations; and
- concurrency tests for synchronized starts, retries, late corrections, duplicate batches, and permission revocation during submission.

Partial business-validation outcomes may be supported only through an explicit action contract. A batch must never partially commit rows the actor is not authorized to submit.

Range partitioning by date or academic period remains evidence-driven. PostgreSQL notes that partitioning benefits depend on table size and workload, and a partitioned table's unique or primary key must include every partition-key column. A partition proposal must therefore prove pruning and retention benefits, migration and lock behaviour, and the effect on tenant-qualified identities, foreign keys, and stable attendance-session identifiers before adoption.

## Evidence required before acceptance

- Owner-approved per-domain launch and planning-horizon profiles.
- Synthetic synchronized-burst tests with named hardware, PostgreSQL settings, data shape, and pass thresholds.
- Mixed workload tests covering attendance writes, corrections, operational summaries, reports, outbox dispatch, and permission revocation.
- Pool saturation, lock, WAL, autovacuum, index-growth, backup, restore, and projection-lag measurements.
- Cross-placement negative tests for HTTP, tasks, jobs, events, files, caches, search, exports, telemetry, support, and AI tools.
- A placement-movement rehearsal with version conflict, rollback, and reconciliation evidence.
- A five-school decision signed by architecture, security/privacy, and operations owners; the arithmetic alone is insufficient.
- Availability evidence that distinguishes writer failover, replica lag, point-in-time restore, and regional recovery, with an explicit connection budget and read-consistency classification.

The evidence template is [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md).

## External technical evidence

- [Ash multitenancy](https://ash-project.github.io/ash/multitenancy.html) documents attribute tenancy, required tenant context, and tenant-aware identities.
- [AshPostgres schema-based multitenancy](https://ash-postgres.hexdocs.pm/schema-based-multitenancy.html) documents separate tenant migrations and migration fan-out.
- [Ecto dynamic repositories](https://ecto.hexdocs.pm/replicas-and-dynamic-repositories.html) are process-local and require disciplined selection and restoration.
- [Oban isolation](https://oban.hexdocs.pm/isolation.html) requires a separate Oban instance for each dynamic repository instance.
- [PostgreSQL row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) documents default-deny policy behaviour, bypass roles, owner behaviour, and operations outside RLS coverage.
- [PostgreSQL table partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html) documents workload-dependent benefits, maintenance trade-offs, and uniqueness limitations.
