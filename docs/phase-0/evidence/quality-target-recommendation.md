# Quality-target recommendation

- Status: Accepted without amendment by the 2026-09-16 technical approval
- Prepared on: 2026-09-16
- Architecture contract: [Quality-attribute targets](../../architecture/quality-attribute-targets.md)
- Machine record: [`quality-target-recommendation.json`](../../../spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json)

## Decision position

This package proposed numeric targets so the capacity and recovery exercises had falsifiable pass/fail gates. The project owner subsequently authorized the architect's best estimate and accepted every row without amendment in the [technical approval record](quality-targets-approval.md). The original machine recommendation remains immutable and review-pending by itself; the source-bound approval artifact supplies the accountable decision.

The common planning envelope is five synthetic tenants, 8,200 learners, 8,200 attendance facts in one period, a 30-second peak window, 25-fact session batches, 13.12 million baseline facts per year, and 131.2 million baseline facts over ten years. Those inputs are capacity hypotheses, not a business forecast or records-retention decision.

## Proposed targets

| Area | Proposed numeric gate | Required confirmation |
| --- | --- | --- |
| Interactive reads | p95 at most 300 ms; p99 at most 750 ms; server errors at most 0.1% | Target-region representative read journeys |
| Interactive mutations | p95 at most 750 ms; p99 at most 2 s; server errors at most 0.1% | Full named action with policy, transaction, change evidence, and outbox |
| Peak domain writes | At least 550 committed facts/s; batch p95 at most 1 s and p99 at most 2 s; errors at most 0.1%; zero unauthorized partial commits | Three repeated five-school bursts with mixed reads, retry, audit, and outbox |
| User-visible web | p75 LCP at most 2.5 s, INP at most 200 ms, CLS at most 0.1 | Agreed mid-tier phone, network, and high-frequency journeys |
| Scale | Five tenants, 8,200 learners, 2,000 signed-in users, 100 concurrent interactive requests | Accountable launch and planning-horizon forecast |
| Tenant placement | Pool wait p95 at most 25 ms and p99 at most 100 ms; other-tenant p95 degradation at most 20%; movement interruption at most 60 s; zero reconciliation mismatch or accepted stale route | Pooled/dedicated comparison and durable movement drill |
| Database connections | Two app nodes with 10 writer connections each, no baseline reader, five job/outbox connections, 25 reserved, 50 total against 100 maximum; p95 checkout at most 25 ms; rejection at most 0.1% | Selected deployment and application-node topology |
| OLTP footprint | Two active attendance years or 26.24 million baseline facts; 131.2 million planning-horizon facts; index/table ratio at most 1.5; WAL/logical payload ratio at most 4; dead-tuple age at most 300 s | Records policy, physical schema, managed storage, autovacuum, archive, and legal hold |
| Read consistency | Zero unsafe security/read-your-write routes; bounded-staleness at most 30 s; zero missing immediate confirmations; fallback consumes at most 20% of writer connection budget | Real separate writer/reader connections and route inventory |
| Asynchronous continuity | Outbox age p95 at most 60 s and p99 at most 300 s; zero missed committed events, unhandled duplicates, or burst dead letters | Dispatcher, consumers, failure, replay, and fairness evidence |
| Report campaigns | 100 ten-page reports within 15 minutes and at most three retries each | Reference template and selected renderer |
| Files | Upload at most 25 MiB, derivative expansion at most 5x, scan p95 at most 60 s | Allowed formats, malicious samples, quarantine, and failure modes |
| Database HA | Zero acknowledged committed-write loss, failover within 120 s, application reconnect within 60 s, zero missing outbox events | Selected HA deployment topology |
| Database recovery | PITR gap at most 5 minutes, restore within 4 hours, zero integrity mismatches, drill at least every 90 days | Planning-horizon deployment restore and reconciliation |
| Object recovery | RPO at most 15 minutes, RTO at most 4 hours, zero metadata/object mismatches | Versioned object store and authoritative metadata reconciliation |
| Availability | At least 99.9% monthly; scheduled maintenance separately reported and capped at four hours per quarter | Product and operations service-level decision |

The 550 facts/s write gate is twice the 273.3 facts/s thirty-second arithmetic and therefore tests headroom rather than merely replaying the estimate. It is not evidence that one local machine represents the eventual deployment.

## Decision questions

Reviewers must resolve these points before copying values into the authoritative target table:

- Are 30 seconds, 25 facts per session batch, 2,000 signed-in users, and 100 concurrent requests credible planning inputs?
- Is synchronous same-region durability required to support a zero acknowledged-write RPO, and is its latency/cost acceptable?
- Does the four-hour restore target apply to the full planning-horizon footprint, and what retention/legal-hold policy determines that footprint?
- Are 30-second stale reports acceptable, and which exact routes qualify? Security, placement, module-gate, and read-your-write routes never do.
- Do the proposed file, report, object, availability, and browser targets match actual product commitments?

## Approval outcome

The [technical approval](quality-targets-approval.md) records the decision authority, date, accepted target identifiers, conditions, evidence binding, and 2026-12-15 review date. These targets remain engineering baselines rather than service promises; failed measurements open an explicit amendment or design decision instead of silently changing a target.
