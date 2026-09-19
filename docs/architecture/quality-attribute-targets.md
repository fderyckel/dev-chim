# Quality-attribute targets

- Status: Accepted technical planning baseline - implementation validation required
- Owner: The accountable execution roles in the table, coordinated by platform engineering
- Accepted: 2026-09-16 by project-owner instruction using the architect's best engineering estimate
- Review: 2026-12-15, or earlier on a material scale, scope, provider, region, or topology change

The project owner explicitly authorized the architect to adopt the best engineering estimate instead of retaining a separate accountable target-approval gate. The [technical approval record](../phase-0/evidence/quality-targets-approval.md) accepts the complete [numeric recommendation](../phase-0/evidence/quality-target-recommendation.md) without amendment. These are falsifiable engineering planning targets, not customer-facing commitments, a budget approval, a legal-retention decision, or an approved business forecast.

The [combined local measurement](../phase-0/evidence/capacity-and-recovery-measurement.md) evaluates the five-school burst and PostgreSQL recovery subset. Its raw pooled run preserves the failed noisy-tenant result. The [database-proxy fairness follow-up](../phase-0/evidence/tenant-fairness-backpressure-measurement.md) and [pre-checkout Elixir follow-up](../phase-0/evidence/precheckout-admission-measurement.md) pass their local gates. The former AWS estimate is [withdrawn](../phase-0/evidence/managed-postgresql-topology.md); the selected non-AWS deployment must later repeat the provider-specific gates.

| Area | SLI | Numeric target | Load and environment | Owner |
| --- | --- | --- | --- | --- |
| Interactive API reads | p95 server duration for representative authorized read | p95 <= 300 ms; p99 <= 750 ms; server errors <= 0.1% | Representative tenant and dataset; target region defined | Product and platform engineering |
| Interactive mutations | p95 server duration excluding explicitly asynchronous work | p95 <= 750 ms; p99 <= 2,000 ms; server errors <= 0.1% | Named action with policy, transaction, audit, and outbox | Product and platform engineering |
| Peak domain writes | Committed facts/second, p95 bulk-action duration, error rate, and unauthorized partial commits | >= 550 facts/s; p95 <= 1,000 ms; p99 <= 2,000 ms; errors <= 0.1%; partial unauthorized commits = 0 | Three synchronized 8,200-fact bursts in 25-fact batches, with retries, authorization negatives, audit, outbox, and mixed reads | Platform engineering and operations |
| User-visible web | p75 LCP, INP, and CLS | LCP <= 2,500 ms; INP <= 200 ms; CLS <= 0.1 | Representative high-frequency journeys on an agreed mid-tier phone and mobile network | Product and web engineering |
| Scale | Tenants, learners, signed-in users, and concurrent requests | 5 tenants; 8,200 learners; 2,000 simultaneously signed in; 100 concurrent interactive requests | Synthetic launch/planning envelope, not an approved business forecast | Product and operations |
| Tenant placement | Pool wait, noisy-neighbour impact, movement interruption, and reconciliation | pool p95 <= 25 ms; pool p99 <= 100 ms; other-tenant degradation <= 20%; writer interruption <= 60 s; mismatches = 0; accepted stale routes = 0 | Pooled, dedicated-database, and dedicated-cell candidates with routing-version failures | Platform engineering, security, and operations |
| Database connections | Writer/reader/job allocation, checkout wait, rejection, and reserve | 2 nodes x 10 writer; 0 reader; 5 job/outbox; 25 reserved; 50 budgeted; PostgreSQL max 100; p95 checkout <= 25 ms; timeout/rejection <= 0.1%; reserve >= 25% | Direct-pool baseline; administration, monitoring, maintenance, replication, and failover included | Platform engineering and operations |
| OLTP footprint | Active/retained facts, index ratio, WAL growth, and vacuum lag | 2 active years / 26,240,000 facts; 10-year / 131,200,000-fact planning horizon; index/table <= 1.5; WAL/logical payload <= 4.0; oldest dead-tuple age <= 300 s | Sizing envelope only; does not authorize retention, deletion, or archive policy | Platform engineering, records governance, and operations |
| Read consistency | Replica lag and unsafe routes | security-sensitive/read-your-write unsafe routes = 0; bounded staleness <= 30 s; missing read-your-write results = 0; writer fallback budget <= 20% | Paused replay, lag, outage, revocation, placement/module change, and immediate confirmation | Platform engineering and security |
| Asynchronous continuity | Oldest outbox age, missed events, duplicates, and dead letters | p95 age <= 60 s; p99 <= 300 s; missed events = 0; unhandled duplicates = 0; burst dead letters = 0 | Peak writes, failover, replay, tenant fairness, and lower-priority throttling | Platform engineering and operations |
| Report campaigns | Reports/pages completed within deadline and retry budget | 100 reports x 10 pages within 15 minutes; <= 3 retries/report | Defined reference template and renderer on selected candidate | Product and operations |
| Files | Upload, derivative expansion, and scan deadline | upload <= 25 MiB; derivative expansion <= 5x; p95 scan <= 60 s | Allowlisted, malformed, malicious, quarantined, and scan-failure profiles | Product, security, and operations |
| Database HA | Committed-write RPO, failover RTO, application reconnect, and outbox continuity | committed-write RPO = 0 bytes; failover <= 120 s; reconnect <= 60 s; missing outbox events = 0 | Synchronous same-region standby, writer loss during burst, endpoint switch, retry, and reconciliation | Platform engineering and operations |
| Database recovery | PITR RPO/RTO, integrity, and drill frequency | RPO <= 300 s; RTO <= 14,400 s; integrity mismatches = 0; drill interval <= 90 days | Isolated point-in-time restore at 131,200,000-fact planning horizon | Platform engineering and operations |
| Object recovery | RPO, RTO, and reconciliation | RPO <= 900 s; RTO <= 14,400 s; metadata/object mismatches = 0 | Versioned object-store restore and authoritative metadata reconciliation | Platform engineering, records governance, and operations |
| Availability | Monthly SLO and scheduled maintenance | >= 99.9% monthly; <= 4 scheduled-maintenance hours/quarter | Core action and critical dependencies; planned maintenance reported separately | Product and operations |

The machine approval binds the exact recommendation by SHA-256. Each implementation campaign records its tool, exclusions, evidence location, and date. A failing measurement does not silently rewrite a target; it opens an explicit amendment or design decision.

## Capacity-profile rule

Student or user count is an input, never a placement target. Each candidate placement must use the per-domain model in [tenant placement and workload capacity](tenant-placement-and-capacity.md), including burst windows, write amplification, mixed reporting, connections, retention, backup, restore, and isolation requirements.

The current five-school attendance arithmetic is recorded in [tenant-placement capacity evidence](../phase-0/evidence/tenant-placement-capacity.md). It remains a synthetic planning hypothesis even though the engineering targets used to test it are now accepted.
