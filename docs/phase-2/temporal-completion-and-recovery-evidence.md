# Slice 2.0-C temporal completion and recovery evidence

- Status: Engineering implementation and accountable ADR acceptance review complete
- Date: 2026-09-26
- Acceptance review date: 2026-09-27
- Scope: Local synthetic neutral proof only
- Accountable owner: François — Project Owner and interim Security/Privacy Owner
- Delivery owner: Platform engineering

## Outcome

Slice 2.0-C implements the remaining neutral ADR 0018 proof without adding a learning-institution
resource, generic temporal framework, public route, background worker, production runtime, real
record, or real retention policy.

Four closed tenant-owned resources add current disposable projections, immutable import
provenance, current retention/hold state, and immutable lifecycle receipts. Resource-specific
private actions declare retention, place and release a legal hold, redact eligible retained
content, register a baseline import, record and reconcile a source conflict, and rebuild one
current projection. Every action derives authority and routing from validated context. Retention
and import changes commit with audit, outbox, and idempotency evidence; projection rebuild remains
disposable and cannot authorize a write.

## TR-01 through TR-07 disposition

| Gate | Disposition for the neutral proof | Evidence |
| --- | --- | --- |
| TR-01 — neutral proof | Satisfied | The existing revisioned aggregate and append-only fact remain separate. Slice 2.0-C adds only bounded qualification resources, not a reusable domain model. |
| TR-02 — tenant and capability safety | Satisfied | Positive actions plus denied capability, missing trusted context, cross-tenant lookup, inactive-module, and direct alternate-write negatives. Tenant-qualified compound references cover projection, import, control, receipt, and redaction links. |
| TR-03 — identity and concurrency | Satisfied | Prior exact replay, changed request, stale target, and correction race evidence is extended by exact retention/import replay and a one-winner legal-hold race. Current controls advance exactly one version through a matching immutable receipt. |
| TR-04 — temporal integrity and reads | Satisfied | Prior writer time, interval, exact/current/effective, bounded history, and explicit unsupported recorded-time evidence remains intact. Erasure preserves stable chain/effective identifiers while redacting payload. |
| TR-05 — atomic evidence and consumers | Satisfied | Injected late completion failure rolls retention/import state, receipt/provenance, audit, outbox, and idempotency back together. Projection staleness after correction is observed and converges only through its governed rebuild. |
| TR-06 — retention, hold, erasure, and deactivation | Satisfied for synthetic policy | Hold blocks erasure; matching release and eligible erasure are distinct capabilities and versions. Inactive retained modules permit mandatory hold/erasure work while ordinary projection work stays closed. Content is redacted, projection purged, receipt minimized, and direct restoration rejected. |
| TR-07 — migration and recovery | Satisfied for local synthetic recovery | Baseline provenance and no-target conflict reconciliation are immutable. Empty rollback/reapply passes, retained rollback refuses, custom-format dump/restore preserves the correction/import/erasure chain, and a deliberately deleted projection converges after governed rebuild. |

TR-08 remains a restraint, not a missing neutral-proof feature: no common temporal persistence
library may be promoted until two real domains prove the same stable primitive.

## Database and alternate-writer evidence

The reviewed migrations use non-null tenant ownership, compound tenant-qualified destination keys,
deferrable receipt/control and redaction references where the one transaction creates both sides,
separate `NOT VALID` and validation steps, and individually prepared trigger statements. The down
paths refuse when retained control, receipt, import, redaction, audit, outbox, or idempotency facts
exist.

Database guards reject:

- control deletion, immutable-field changes, skipped versions, or a state change without the exact
  matching receipt;
- receipt update or deletion;
- import-provenance update or deletion;
- redaction without a tenant-qualified receipt; and
- payload restoration after redaction.

## Recovery rehearsal

The 2026-09-26 isolated local rehearsal produced two aggregates, three linked revisions, five
segments, one fact, one disposable projection, two retention controls, three receipts, and one
import record. The custom-format source and restored databases matched exactly on all eight
counts. Retained rollback failed with the explicit `cannot remove temporal retention guards while
retained evidence exists` condition.

After restore, the verifier deleted the projection, invoked the capability-protected rebuild, and
reported convergence on the authoritative current revision. It also required zero missing
predecessors, missing import targets, projection/current disagreements, and malformed redactions.
The dump and temporary databases contained synthetic data only and were removed after recording
the results.

## Local measurement and enforced limits

A 100-aggregate sequential local sample used two segments per baseline, one successor correction,
one retention declaration, one baseline import, and one projection rebuild per aggregate. On the
developer PostgreSQL 18.6 writer it measured:

| Action | p50 | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Publish | 2.423 ms | 2.901 ms | 110.059 ms |
| Correct | 2.362 ms | 2.784 ms | 16.730 ms |
| Declare retention | 2.290 ms | 2.831 ms | 23.318 ms |
| Register import | 2.027 ms | 2.470 ms | 18.723 ms |
| Rebuild projection | 1.488 ms | 1.825 ms | 6.787 ms |

After `ANALYZE`, 3,973 estimated rows across the temporal tables and indexes occupied 2,031,616
bytes. At this deliberately small cardinality PostgreSQL selected sequential scans for exact
projection, control, and import lookups (0.041–0.089 ms execution); tenant-qualified unique indexes
remain present for larger cardinalities. These observations are reproducible local evidence, not a
production SLO, capacity forecast, partitioning trigger, or selected-deployment result.

The neutral contract enforces at most 32 segments per publish/correction and 100 results per
revision, fact-operation, or consumer-basis history read. It exposes no bulk retention, import,
erasure, or projection action. A real domain must set its own row-volume, retention, burst, lock,
WAL, backup, and recovery budgets before adoption.

## Accountable residual-risk disposition

1. The erasure behavior is a synthetic redaction contract, not a legal conclusion or domain
   schedule. Domain records owners still own actual policy.
2. Offline backups may retain protected bytes until approved expiry; restore must reapply current
   erasure state before interfaces reopen.
3. The rehearsal is single-node local PostgreSQL with synthetic data. Selected-deployment
   capacity, locks, WAL, RPO/RTO, encryption, and operator execution remain L3 gates.
4. No external projection, cache, search, analytics, export, or integration adapter is connected;
   every adopting domain must name and prove its propagation acknowledgements.
5. Independent security/privacy and learning-institution records-owner review remain mandatory
   before restricted child data or a pilot.
6. One neutral proof does not justify a universal temporal library; TR-08 remains binding.

On 2026-09-27, François, as Project Owner and interim Security/Privacy Owner, reviewed and approved
all six residual risks above. They remain binding downstream conditions: the approval does not
create a real retention policy, qualify a selected deployment, approve Restricted data, substitute
for independent or learning-institution records review, or permit a universal temporal library.
This dated post-evidence decision is distinct from the earlier implementation authorization and
moves ADR 0018 to **Accepted** at the platform level.

## Verification

- Focused temporal qualification suite: 25 tests passed before the final repository gate.
- Slice 2.0-C completion suite: 7 tests passed, including recovery-fixture generation.
- Empty migration apply/rollback-two/reapply: passed on a fresh synthetic database.
- Retained rollback refusal: passed by failing closed.
- PostgreSQL custom-format dump/restore/count comparison: passed.
- Governed post-restore projection rebuild and invariant verifier: passed.
- `make check`: passed with 25 repository-tool tests, 106 foundation tests, 149 production-core
  tests, 20 web unit tests, 19 browser tests, zero dependency-audit findings, zero type-analysis
  errors/skips, and no migration, generated-contract, formatting, lint, or whitespace drift.
- Isolated clean-checkout bootstrap plus `make check`: passed; the recorded candidate was clean
  before bootstrap and remained clean after verification.
- The 2026-09-27 acceptance reused the already completed full-gate result; it did not run a
  duplicate `make check` or clean-checkout rehearsal.

## Related records

- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [Temporal decision review](../architecture/temporal-records-decision-review.md)
- [Temporal contract](../architecture/temporal-records-correction-and-evidence.md)
- [Retention and recovery runbook](../operations/temporal-retention-and-recovery.md)
- [Migration discipline](../development/migrations.md)
- [Threat model](../security/threat-model.md)
