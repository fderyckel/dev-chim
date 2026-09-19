# Withdrawn AWS PostgreSQL topology example

- Status: Withdrawn; provider selection deferred beyond Phase 0
- Owner: François — Project Owner
- Decision date: 2026-09-16
- Historical machine record: [`managed-postgresql-topology.json`](../../../spikes/ash-foundation-lab/priv/maintenance/managed-postgresql-topology.json)

## Decision

AWS will not be used for the project, so the earlier Amazon RDS estimate is not a selected architecture, procurement choice, or Phase 0 exit requirement. ADR 0017 accepts a **provider-neutral PostgreSQL contract** instead: PostgreSQL is authoritative, recovery and availability targets are explicit, reads are consistency-aware, and deployment-specific qualification is required before production.

The machine record remains unchanged as historical evidence of the estimation method and to preserve source-bound measurement integrity. It must not be interpreted as approving AWS, `eu-central-1`, RDS, a particular instance class, or a 35-day retention policy.

## Historical estimate

The withdrawn example used Amazon RDS for PostgreSQL 18.6 in `eu-central-1`, a Multi-AZ DB instance, a `db.m7i.large` starting class, 100 GiB encrypted gp3 storage, and a direct-pool connection hypothesis. Those values were planning inputs, not measured production capacity.

The reusable part is the connection/admission shape: begin with an explicit total database connection budget, reserve capacity for operations and recovery, bound callbacks per tenant and placement before pool checkout, and add readers or a pooler only from evidence.

## Later deployment qualification

When the non-AWS hosting approach is selected, the infrastructure phase must use synthetic data to qualify:

- engine/version availability and upgrade policy;
- high availability, failover, client reconnection, and split-brain protections;
- point-in-time recovery and full-horizon restore against the accepted RPO/RTO targets;
- multi-node pre-checkout fairness and total connection budgets;
- storage growth, backup retention, residency, observability, and operational ownership; and
- tenant movement and non-HTTP routing through the trusted placement boundary.

That campaign is a production-readiness gate for the chosen deployment, not unfinished Phase 0 work.

## Historical provider references

These links explain the withdrawn estimate only:

- [RDS PostgreSQL versions](https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-versions.html)
- [Multi-AZ DB instance deployment](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)
- [Multi-AZ failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html)
- [DB instance hardware](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.Summary.html)
- [RDS storage](https://docs.aws.amazon.com/us_en/AmazonRDS/latest/UserGuide/CHAP_Storage.html)
- [Point-in-time restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
