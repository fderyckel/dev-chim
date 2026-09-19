# Retained-data migration annual-envelope measurement

- Status: Measured with bounded remediation
- Date: 2026-09-16
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)
- Source revision: `50defa1a2190f25414aced0bc6887d8f3e7c1524` plus the source-digested working-tree slice

## Question

Can the retained-data expand, tenant backfill, validation, and contract rehearsal preserve tenant isolation and retained values at one synthetic 800-learner school-year of planning volume, and what local time, WAL, storage, batch-latency, and lock behaviour does it expose?

This is a planning-envelope measurement, not an approved production target or a claim about a managed production topology.

## Envelope and method

Each of three fresh disposable PostgreSQL databases contained:

- 1,280,000 primary-tenant rows, representing the current hypothesis of 800 learners, 200 days, and eight attendance opportunities;
- 32,000 rows in a separate control tenant; and
- 1,312,000 rows in total.

The [measurement runner](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/retained_data_migration_measurement.ex) loaded the current complete lab schema, seeded synthetic retained rows across 200 timestamps, and ran the existing migration artifacts. Before backfill it created a temporary partial index on `(tenant_id, inserted_at, id) WHERE canonical_name IS NULL` with `CREATE INDEX CONCURRENTLY`. The existing typed runner retained its hard maximum of 100 rows per transaction.

The primary tenant was backfilled first. The runner then proved that all 32,000 control-tenant rows still had a null candidate value before backfilling that tenant separately. It validated both constraints, removed the support index concurrently, ran the destructive contract, and compared a count plus aggregate fingerprint across the contract boundary. Every database was removed after its repetition.

Every schema migration attempt retained the existing `250ms` lock timeout. The measurement retried only PostgreSQL `lock_not_available` after the failed migration transaction had rolled back, with a 250ms delay and a hard limit of 120 attempts. Attempt counts are evidence; this is not an approved production retry policy.

## Command and checked artifact

```sh
cd spikes/ash-foundation-lab
mise exec -- env MIX_ENV=test mix phase0.retained_data.measure \
  --primary-rows 1280000 \
  --control-rows 32000 \
  --repetitions 3
```

The checked [machine-readable result](../../../spikes/ash-foundation-lab/priv/maintenance/retained-data-migration-measurement.json) records the complete environment, PostgreSQL settings, method, each repetition, source-file SHA-256 values, limitations, and summarized variance. The Phase 0 checker rejects source drift, changed envelope or method, incomplete settings, failed assertions, missing repetitions, and malformed timing, WAL, storage, or fingerprint evidence.

Environment: local Apple M5 with 24 GiB memory, macOS 26.6.2, PostgreSQL 18.6, Elixir 1.20.3, Erlang/OTP 29, `fsync=on`, `full_page_writes=on`, `synchronous_commit=on`, and `wal_level=replica`.

## Results

| Measurement | Minimum | Median | Maximum |
| --- | ---: | ---: | ---: |
| Primary backfill elapsed | 124.88 s | 129.50 s | 159.01 s |
| Primary backfill throughput | 8,049.9 rows/s | 9,883.9 rows/s | 10,249.9 rows/s |
| Temporary support-index build | 3.38 s | 3.40 s | 5.52 s |
| Final relation footprint | 418.7 MB | 427.2 MB | 428.8 MB |
| Total WAL per repetition | 2.370 GB | 2.524 GB | 2.535 GB |

The primary backfill executed 12,800 separately committed batches in every repetition. Per-batch p50 was 3.07-4.09ms and p95 was 4.63-5.35ms, but p99 was 356.84-456.03ms and the maximum was 398.27-699.41ms. The tail therefore matters even though median batches were fast.

The seeded relation occupied 311.3-311.9MB. The temporary support index increased the relation to 388.8-389.4MB. After the updates, it occupied 496.3-506.3MB; after support-index removal and contract it occupied 418.7-428.8MB. Backfill alone generated 1.301-1.416GB of WAL; the complete seed-to-contract exercise generated 2.370-2.535GB.

Expand, validation, and contract acquired their required lock on the first attempt in all three repetitions. The enforcement gate did not: it required 80, 108, and 43 attempts, taking 51.51, 64.36, and 24.16 seconds respectively while preserving the per-attempt 250ms lock budget. This directly falsifies any plan that assumes enforcement can run as an immediate one-shot step after an update-heavy backfill on this environment.

All three repetitions passed every safety assertion:

- the primary backfill left the control tenant untouched;
- both tenant row counts were preserved;
- every candidate value matched its legacy value;
- both constraints were validated;
- the candidate column became non-null and the legacy column was removed;
- the temporary support index was removed; and
- the retained count and fingerprint were identical before and after contract.

## Decision impact and bounded remediation

The missing annual-volume retained-data measurement is now complete. Migration readability and operational safety remain **Pass with bounded remediation**, not an unqualified pass.

Before a production retained-data contraction, Platform engineering and operations must own a reviewed plan that:

1. creates and later removes an appropriate backfill support index without blocking the declared peak window;
2. exposes progress, batch latency, remaining rows, WAL, storage, locks, autovacuum, and replica lag;
3. schedules and bounds the enforcement retry window instead of weakening the per-attempt lock timeout;
4. selects batch size and worker concurrency from measurements on the chosen production service tier and mixed workload;
5. proves old-version drain, dual-write compatibility, tenant placement, and resumability; and
6. gates destructive contract on backup/PITR, restore or forward-repair proof, accountable approval, and an explicit maintenance window.

These conditions are localized operational choreography. They do not require a second domain framework or weaken the tenant-scoped action and migration contracts, but they must be dispositioned by accountable reviewers before ADR 0002 can be accepted.

## Limits

- The host is a local single-node PostgreSQL installation, not the proposed managed writer, HA standby, read replica, or production storage tier.
- The row envelope is a synthetic planning hypothesis, not an owner-approved scale target or measured attendance schema.
- The run did not include concurrent application writes, two independently deployed application versions, report load, multiple backfill workers, replica lag, failover, backup, or restore.
- The support index is measurement choreography, not yet a generated or approved production migration artifact.
- Relation and WAL values are specific to this lab schema, generated text shape, PostgreSQL settings, and hardware.
- The result does not approve the destructive contract, Ash, ADR 0002, a placement profile, or a production service level.

See the [small compatibility rehearsal](retained-data-migration-rehearsal.md), [Ash pressure-test scorecard](ash-pressure-test.md), [PostgreSQL availability and burst evidence](postgresql-availability-and-burst.md), and [quality targets](../../architecture/quality-attribute-targets.md).
