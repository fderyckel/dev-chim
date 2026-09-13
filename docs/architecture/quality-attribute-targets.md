# Quality-attribute targets

- Status: Proposed - business approval required before Phase 0 exit
- Owner: Platform engineering coordinates; accountable business and operations owners must be named
- Review trigger: architecture review, material scale change, or production-region decision

Final targets are not invented in code. The architecture review must replace each `OWNER_REQUIRED` and `TARGET_REQUIRED` marker with an accountable name and numeric target before running `tools/check_phase0.py --exit-review`.

| Area | SLI | Numeric target | Load and environment | Owner |
| --- | --- | --- | --- | --- |
| Interactive API reads | p95 server duration for representative authorized read | TARGET_REQUIRED | Representative tenant and dataset; target region defined | OWNER_REQUIRED |
| Interactive mutations | p95 server duration excluding explicitly asynchronous work | TARGET_REQUIRED | Named action with policy, transaction, audit, and outbox | OWNER_REQUIRED |
| Peak domain writes | Committed facts/second, p95 bulk-action duration, error rate, and unauthorized partial commits | TARGET_REQUIRED | Named synchronized burst, batch distribution, retries, corrections, authorization revocation, audit, and outbox amplification | OWNER_REQUIRED |
| User-visible web | p75 LCP and interaction latency | TARGET_REQUIRED | Target mobile device and network profile | OWNER_REQUIRED |
| Scale | tenants, users per tenant, active sessions, and concurrent requests | TARGET_REQUIRED | Launch and planning-horizon profiles | OWNER_REQUIRED |
| Tenant placement | Maximum pool wait, saturation, noisy-neighbour impact, and movement interruption/reconciliation | TARGET_REQUIRED | Pooled, dedicated-database, and dedicated-cell candidates with routing-version failures | OWNER_REQUIRED |
| Database connections | Maximum writer/reader/job pool allocation, p95 checkout wait, timeout/rejection rate, and failover reserve | TARGET_REQUIRED | Maximum application nodes and database placements, Oban, administration, monitoring, and replication | OWNER_REQUIRED |
| OLTP footprint | Active rows and bytes, index ratio, WAL growth, autovacuum lag, and retained years | TARGET_REQUIRED | Per-domain data shape, corrections, history, audit, projections, archive, and legal hold | OWNER_REQUIRED |
| Read consistency | Maximum replica replay lag by approved read class and number of security-sensitive or read-your-write routes served unsafely | TARGET_REQUIRED; unsafe routes must be zero | Lagging/unavailable reader, permission revocation, placement/module change, and immediate confirmation | OWNER_REQUIRED |
| Asynchronous continuity | Oldest outbox/queue age, throughput, retries, duplicates, dead letters, and tenant-fairness impact | TARGET_REQUIRED | Peak writes with reports, notifications, integrations, failover, and lower-priority throttling | OWNER_REQUIRED |
| Report campaigns | reports/pages completed within deadline and retry budget | TARGET_REQUIRED | Defined template complexity and concurrency | OWNER_REQUIRED |
| Files | maximum upload, derivative expansion, and scan deadline | TARGET_REQUIRED | Allowed formats and malicious-file profile | OWNER_REQUIRED |
| Database HA | Committed-write RPO, failover RTO, application reconnect time, and outbox continuity | TARGET_REQUIRED | Instance and zone failure during a synchronized write burst | OWNER_REQUIRED |
| Database recovery | Point-in-time restore RPO/RTO, integrity, and reconciliation | TARGET_REQUIRED | Dated isolated restore at planning-horizon volume | OWNER_REQUIRED |
| Object recovery | RPO and RTO | TARGET_REQUIRED | Versioned object store and metadata reconciliation | OWNER_REQUIRED |
| Availability | monthly SLO and maintenance treatment | TARGET_REQUIRED | Core action and critical dependencies | OWNER_REQUIRED |

Every accepted row must also record the measurement tool, exclusions, evidence location, and review date.

## Capacity-profile rule

Student or user count is an input, never a placement target. Each candidate placement must use the per-domain model in [tenant placement and workload capacity](tenant-placement-and-capacity.md), including burst windows, write amplification, mixed reporting, connections, retention, backup, restore, and isolation requirements.

The current five-school attendance arithmetic is recorded in [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md). It is labelled as a planning hypothesis until owners approve the inputs and repeatable benchmark targets.
