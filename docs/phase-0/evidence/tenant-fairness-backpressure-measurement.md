# Tenant-fairness and backpressure measurement

- Status: Historical local fairness candidate passed; pre-checkout follow-up passed; deployment qualification remains
- Owner: Platform engineering and operations
- Measured on: 2026-09-16
- Decision status: Evidence retained; targets accepted, while production topology and placement remain evidence-driven

## Question and preserved baseline

The [combined capacity/recovery measurement](capacity-and-recovery-measurement.md) deliberately remains the raw pooled baseline. Its three noisy-tenant repetitions degraded the other tenants' p95 latency by 119.298%, 171.429%, and 218.519%, failing the proposed 20% maximum every time.

This follow-up asks one narrower question: can a bounded per-tenant admission shape protect tenants 2–5 while tenant 1 is noisy without weakening tenant isolation, atomic batches, idempotency, audit, or transactional-outbox facts?

The machine-readable [fairness result](../../../spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json) binds itself by SHA-256 to the raw failed artifact, the target recommendation, this runner, and the shared capacity runner. It does not replace or edit the failed evidence.

## Disposable candidate

The local proxy gives each tenant two transaction-scoped advisory-lock slots. An admitted call holds its slot for 20 ms and executes the existing bounded 25-fact transaction. A call that cannot acquire either slot waits for the same bounded interval and returns `-1` without writing a batch. The workload runs one client for each of tenants 2–5 and eight clients for tenant 1.

This is algorithm-feasibility evidence only. The proxy has already checked out a database connection and opened a transaction before it rejects work. A production controller must enforce tenant fairness and placement capacity before database pool checkout, classify the rejection as tenant rate limiting or dependency saturation, preserve the idempotency key, and expose bounded retry guidance only when it knows that interval.

## Exact run

```sh
mise exec -- uv run python tools/measure_phase0_tenant_fairness.py \
  --repetitions 3 \
  --output spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json
```

The runner created a fresh local PostgreSQL 18.6 cluster with `fsync=on`, `synchronous_commit=on`, `full_page_writes=on`, `wal_level=replica`, and 40 maximum connections. Every repetition first measured tenants 2–5 alone, reset the synthetic tables, then ran the same four tenants while tenant 1 attempted 800 batches.

## Results

| Repetition | Other-tenant baseline p95 | Other-tenant p95 under noise | Degradation | Tenant 1 admitted / rejected | Tenants 2–5 admitted / rejected | Result |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 22.311 ms | 22.219 ms | -0.412% | 197 / 603 | 400 / 0 | Pass |
| 2 | 22.245 ms | 22.295 ms | 0.225% | 199 / 601 | 400 / 0 | Pass |
| 3 | 22.297 ms | 22.341 ms | 0.197% | 198 / 602 | 400 / 0 | Pass |

The worst other-tenant degradation was 0.225%, below the proposed 20% maximum. The noisy tenant was measurably backpressured in every repetition, while every tenants-2–5 attempt was admitted. This closes the failed local algorithm-feasibility rerun; it does not approve pooled production placement.

## Safety assertions

Every repetition passed all of these checks:

- every admitted batch had exactly 25 state facts, one audit fact, and one outbox fact;
- rejected attempts created no partial batch;
- no state, audit, or outbox row crossed a tenant boundary;
- an explicit cross-tenant insert failed and rolled back the candidate batch;
- an exact retry returned 25 then 0 inside a rolled-back probe; and
- the safety probes left the measured workload counts unchanged.

The checker also recomputes each degradation from the raw p95 values, recomputes the three-run summaries, verifies the failed-baseline and source hashes, and requires the local candidate disposition to remain passing.

## What this changes

The local pooled candidate now has a viable fairness/backpressure algorithm shape. The earlier conclusion changes from "no local fairness mechanism has passed" to "one disposable local candidate passed." The architecture still requires pre-checkout admission; this database-local proxy must not be promoted into the production core or used as evidence that database connections are protected.

The four-school pooled placement therefore remains undecided. Acceptance still requires:

1. implementation and measurement at the application worker and pool-checkout boundary with trusted tenant context;
2. the same three-run comparison in the selected deployment and actual application pool;
3. concurrent authorization, revocation, outbox dispatch, reports, jobs, and lower-priority work;
4. approved tenant-rate-limit versus dependency-saturation errors and idempotent retry behaviour;
5. accepted workload inputs, numeric targets, connection budget, breach blast radius, and accountable placement decision; and
6. the already-required managed failover, full 131.2-million-row restore, and production routing/movement evidence.

Stronger physical placement remains the fail-closed alternative if the production-bound controller or managed rerun misses its target.

## Limits

- The candidate is neutral synthetic SQL in the disposable Phase 0 lab, not a school module or production framework API.
- The local single-node scheduler, storage, and network do not reproduce the selected deployment or multiple application nodes.
- The experiment does not contain an application connection pool, so it cannot prove rejection before checkout.
- Two slots and 20 ms are experimental controls, not accepted production settings.
- The target package and all placement and topology decisions remain pending accountable review.
