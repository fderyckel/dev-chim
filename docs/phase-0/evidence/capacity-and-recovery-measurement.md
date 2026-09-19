# Five-school capacity and PostgreSQL recovery measurement

- Status: Raw pooled noisy-tenant target failed; bounded local follow-up passed; managed confirmation required
- Measured on: 2026-09-16
- Owner: Platform engineering and operations
- Target package: [Quality-target recommendation](quality-target-recommendation.md)
- Machine record: [`capacity-recovery-measurement.json`](../../../spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json)
- Harness: [`measure_phase0_capacity_recovery.py`](../../../tools/measure_phase0_capacity_recovery.py)
- Source revision: `50defa1a2190f25414aced0bc6887d8f3e7c1524` with a recorded dirty working tree and source hashes

## Command and environment

```sh
mise exec -- uv run python tools/measure_phase0_capacity_recovery.py \
  --repetitions 3 \
  --retained-rows 1312000 \
  --output spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json
```

The run used PostgreSQL 18.6 with `fsync=on`, `full_page_writes=on`, `synchronous_commit=on`, `wal_level=replica`, WAL archiving, 40 connections, and a 128 MiB shared-buffer allocation on a 10-core Apple Silicon Mac with 24 GiB memory. The harness created disposable local primary, physical standby, WAL archive, and isolated PITR restore clusters and removed them after the run.

## Capacity result

The supported shape submitted exactly 8,200 facts as 328 tenant-qualified 25-fact session transactions. Each transaction atomically wrote the facts, one audit row, and one outbox event. Mixed operational reads ran concurrently.

| Repetition | Bounded elapsed | Committed facts/s | Batch p95 | Batch p99 | Bounded WAL | Mixed-read p95 | Per-fact comparison elapsed | Per-fact WAL |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 29.047 ms | 282,301.098 | 0.884 ms | 2.699 ms | 2,954,264 B | 6.453 ms | 158.531 ms | 12,252,368 B |
| 2 | 27.327 ms | 300,069.528 | 0.654 ms | 2.627 ms | 2,924,416 B | 6.445 ms | 159.255 ms | 12,262,768 B |
| 3 | 26.567 ms | 308,653.593 | 0.637 ms | 2.577 ms | 2,946,688 B | 6.454 ms | 160.621 ms | 12,398,392 B |

The local bounded path exceeds the proposed 550 facts/s gate and remains far below the proposed one-second batch p95. Those margins demonstrate that the neutral database shape is not locally write-bound; they do not size a networked managed tier. The per-fact comparison needed 8,200 transactions rather than 328 and generated roughly four times the WAL, reinforcing the session-batch contract.

Every repetition also proved:

- exactly 328 batches, 8,200 facts, 328 audit rows, and 328 outbox rows;
- cross-tenant compound-foreign-key rejection with no partial batch residue;
- same-key retry returning zero additional facts and retaining one batch; and
- mixed reads completing during the burst.

## Failed noisy-tenant gate

The raw shared database had no fairness or per-tenant backpressure layer. Three repetitions compared tenants 2-5 alone with the same tenants while tenant 1 drove eight concurrent writers:

| Repetition | Other-tenant baseline p95 | Under noisy tenant p95 | Degradation | Proposed maximum | Result |
| ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 0.245 ms | 0.665 ms | 171.429% | 20% | Fail |
| 2 | 0.243 ms | 0.774 ms | 218.519% | 20% | Fail |
| 3 | 0.285 ms | 0.625 ms | 119.298% | 20% | Fail |

Absolute latency stayed below one millisecond, but the relative-isolation target is deliberately not waived because the machine was fast. This artifact and its failing disposition remain immutable baseline evidence.

## Bounded fairness follow-up

The separate [tenant-fairness measurement](tenant-fairness-backpressure-measurement.md) binds itself to this failed artifact and repeats the three comparisons with a disposable two-slot-per-tenant admission proxy. Its worst other-tenant degradation was 0.225%; tenant 1 was backpressured by 601-603 attempts per repetition, tenants 2-5 admitted all 400 attempts, and the tenant, atomicity, idempotency, audit, and outbox assertions passed.

That closes local algorithm feasibility only. The proxy rejects after database checkout and transaction start; the later [pre-checkout measurement](precheckout-admission-measurement.md) closes the local admission seam. Pooled placement still requires the same proof through the real application pool, multiple application nodes, and selected deployment. Stronger physical placement remains the fail-closed alternative.

## Connection exhaustion

With `max_connections=40` and three superuser-reserved slots, 37 non-superuser connections held the available application capacity. All five additional attempts were rejected before a transaction began, and a new application connection succeeded 16.001 ms after the held connections drained. This proves bounded rejection and recovery choreography, not the accepted planning allocation of 50 of 100 connections; the selected deployment must repeat the application-pool checkout test.

## Replica lag, outage, and recovery conflict

- Replay was paused while a local-commit marker advanced the primary by 536 WAL bytes. The standby did not expose the marker, no security-sensitive route used the stale state, and replay caught up in 7.504 ms after resumption.
- While the standby was stopped, the bounded-staleness route decision was `reject`, the primary-required route remained available, and no uncontrolled report fallback was directed to the writer.
- A five-second standby query holding a relation lock was cancelled after 1,032.496 ms when replay needed a conflicting primary `DROP TABLE`. This preserves replay and HA readiness at the expense of the stale-tolerant query, as the architecture contract requires.

These cases use real independent PostgreSQL processes and connections. They do not establish a managed reader's network lag, cost, storage pressure, or zone failure behaviour.

## Failover and outbox continuity

The primary was stopped immediately during an 800-transaction burst after 314 transactions had completed. The physical standby was promoted and the application connected to its explicit new endpoint.

| Measure | Result | Proposed gate | Local result |
| --- | ---: | ---: | --- |
| Sampled acknowledged-write RPO | 0 bytes | 0 bytes | Pass |
| Promotion/failover RTO | 255.840 ms | At most 120 s | Pass locally |
| Application reconnect | 12.893 ms | At most 60 s | Pass locally |
| Missing outbox events | 0 | 0 | Pass |
| Duplicate outbox facts | 0 | 0 | Pass |

The known pre-failure idempotency key existed after promotion, two retries created no duplicate, every committed batch retained exactly one outbox fact, and the interrupted workload returned a failure rather than an ambiguous success. A managed multi-zone endpoint must repeat this proof because the local processes share one host and filesystem.

## Point-in-time recovery

The isolated PITR exercise used 1,312,000 retained rows, which is one percent of the 131.2-million-row attendance planning horizon.

| Measure | Result |
| --- | ---: |
| Base-backup size | 210,782,551 B |
| Base-backup duration | 285.017 ms |
| Forced WAL archive availability | 0.313 ms |
| Isolated restore RTO | 119.259 ms |

The restore contained the target marker, excluded the later marker, retained the complete tenant/id fingerprint, and ran on an isolated port. The result validates target-LSN recovery and integrity checks. It cannot be linearly extrapolated to the ten-year footprint; a managed 131.2-million-row restore remains mandatory before the proposed four-hour RTO is accepted.

## Decision implications

1. Retain the accepted 550 facts/s and one-second p95 planning targets; repeat them in the selected deployment with the actual named action, Ash bulk strategy, application pool, network, and schema.
2. Do not approve the four-school pooled production placement yet. Promote the passing pre-checkout shape into the real pool boundary, repeat it across application nodes in the selected deployment, or use stronger placement.
3. Do not add a read replica from annual row count. The local writer was not read-bound; only later mixed-load deployment evidence may trigger a reader.
4. Do not add PgBouncer by default. First prove the proposed direct-pool budget on the selected node and placement count; adopt a pooler only if checkout or connection limits fail.
5. Retain synchronous same-region HA as the candidate for zero acknowledged-write RPO, subject to managed latency, zone-failure, endpoint, and cost evidence.
6. Do not select cross-region DR from this local run. Residency, regional RPO/RTO, promotion, split-brain prevention, failback, and reconciliation remain accountable decisions.

## Limits

- The workload is neutral synthetic SQL representing the future named batch contract; it is neither a production attendance module nor an Ash bulk-strategy benchmark.
- Local throughput and sub-second recovery are choreography evidence, not production service-tier capacity or availability claims.
- PITR covers one percent of the attendance planning horizon.
- Production identity, durable tenant movement, real external adapters, web, files, object storage, report rendering, and provider operations remain outside this run.
- The target package was accepted on 2026-09-16. Provider/topology selection and final production placement remain later evidence-driven decisions under ADRs 0003 and 0017.
