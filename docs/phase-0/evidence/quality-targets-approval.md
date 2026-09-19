# Quality-target approval evidence

- Status: Accepted technical planning baseline; implementation validation required
- Decision authority: Project-owner instruction to use the architect's best engineering estimate
- Execution owners: The accountable roles recorded on each target
- Decided: 2026-09-16
- Review: 2026-12-15 or an earlier material-change trigger
- Machine record: [`quality-target-technical-approval.json`](../../../spikes/ash-foundation-lab/priv/maintenance/quality-target-technical-approval.json)

The project owner removed the separate accountable target-approval dependency and directed the software architect to provide the best expert estimate. On that authority, all 16 rows in the [numeric recommendation](quality-target-recommendation.md) are accepted without amendment as the technical planning baseline in the authoritative [quality-attribute targets](../../architecture/quality-attribute-targets.md). The machine record binds the recommendation by SHA-256 and records the accepted target IDs, conditions, decision date, and review date.

This acceptance makes the measurements falsifiable; it does not turn estimates into observed production performance. The [combined local run](capacity-and-recovery-measurement.md) passes write, failover, replica-safety, outbox, and one-percent PITR choreography gates but preserves a failed raw pooled noisy-tenant gate. The database-proxy follow-up passes locally, and the [pre-checkout Elixir follow-up](precheckout-admission-measurement.md) closes the local connection-admission gap. The AWS example is [withdrawn](managed-postgresql-topology.md); selected-deployment, browser, report, file, and object-store evidence remains required before those capabilities can claim production readiness.

The accepted scale and retention figures remain synthetic infrastructure assumptions, not an approved demand forecast or records policy. Legal retention, residency, privacy, commercial commitment, and budget authority are explicitly outside this technical acceptance.
