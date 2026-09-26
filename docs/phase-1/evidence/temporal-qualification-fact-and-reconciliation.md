# ADR 0018 T1-C append-only fact and reconciliation evidence

- Status: Implemented bounded qualification increment; ADR 0018 remains Conditionally Accepted
- Date: 2026-09-25
- Owner: Platform engineering
- Scope: Neutral synthetic append-only fact actions and one deliberate-reconciliation consumer only
- Governing records: [ADR 0018](../../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md), [temporal contract](../../architecture/temporal-records-correction-and-evidence.md), and [Phase 1 plan](../../plans/phase-1-core-foundation-plan.md)

## Outcome

T1-C adds the append-only half of the neutral temporal proof and one synthetic downstream
consumer. It does not add an academic calendar, finance ledger, education module, public API,
dispatcher, reusable temporal framework, or production-data policy.

`Fact.record_entry` creates one immutable entry. `Fact.reverse_and_replace` targets one exact
entry and atomically appends its derived full reversal plus one replacement under a new immutable
operation. PostgreSQL assigns recorded time, binds every fact to a same-tenant and same-scope
operation, admits only one correction operation per target entry, rejects reversal-of-reversal,
and prevents update or deletion of facts and operations.

`ConsumerBasis.pin_revision` records which exact current revision one neutral consumer used.
Source publication or correction never changes that basis. `ConsumerBasis.reconcile_revision`
requires the exact current basis and exact current source revision, then appends a consecutive
successor. An outbox event may be supplied as causation evidence, but possession of that event
does not grant reconciliation authority.

## Supported boundary

The supported entry point remains `Chimwemwe.Platform.TemporalQualification`. It exposes:

- `record_fact_entry/3` and `reverse_and_replace_fact/3`;
- `get_fact/3`, `get_fact_operation/3`, and bounded `list_fact_history/3`;
- `pin_consumer_revision/3` and `reconcile_consumer_revision/3`; and
- `get_consumer_current/3` and bounded `list_consumer_history/3`.

The resource actions are private. The boundary accepts exact allowlisted inputs, validates trusted
context before use, derives tenant and writer placement, and accepts no caller-selected actor,
tenant, repository, recorded time, generated identity, reversal quantity, authorization flag, or
Ash option.

The code-owned capability requirements are deliberately separate:

- `platform.temporal_qualification.facts.record`;
- `platform.temporal_qualification.facts.reverse_and_replace`;
- `platform.temporal_qualification.facts.read_history`;
- `platform.temporal_qualification.consumers.pin`;
- `platform.temporal_qualification.consumers.reconcile`; and
- `platform.temporal_qualification.consumers.read_history`.

## Atomic evidence and replay

Every successful action rechecks current tenant authority on the writer, serializes its write
scope, and commits domain state, minimized security audit, one transactional outbox fact, and the
completed idempotency result in one transaction. Exact retries return the stored complete result.
Changed input or actor conflicts. The fact outbox payload contains operation and fact identifiers
and counts, but not effective dates or quantities.

Synthetic post-outbox failures prove that fact or consumer state, audit, outbox, and the claim all
roll back together and that the same request can then succeed. Racing corrections of one entry and
racing reconciliations from one expected basis have one winner and cannot branch.

## Migration review

The reviewed migration adds only the qualification-owned fact-operation and consumer-basis
tables and replaces the existing fact guard in place. Generator output was corrected so the
self-referencing consumer foreign key is created only after its tenant-qualified destination
index. The down path removes that foreign key before the index and restores the original fact
guard. It refuses rollback while any T1-C operation or consumer basis is retained.

The empty synthetic schema was applied, rolled back, and reapplied without rolling back the
separate module-lifecycle migration. A retained fact operation separately proved the rollback
refusal. AshPostgres migration and snapshot drift is clean.

## Executable evidence

Focused tests prove:

- private named actions and absence of generic mutation;
- positive, denied-capability, missing-context, cross-tenant, cross-scope, and history-disclosure behavior;
- exact result replay and changed-request or changed-actor conflict;
- one immutable operation for record and one two-fact result for correction;
- duplicate, stale, and racing correction conflict without branching;
- exact fact, exact operation, bounded operation history, current consumer basis, and bounded basis history;
- a source correction leaves an existing consumer pinned;
- a denied actor cannot reconcile merely by holding the source correction event identifier;
- explicit authorized reconciliation appends a successor and preserves the prior basis; and
- late-failure rollback across domain state, audit, outbox, and idempotency.

Verification on 2026-09-25:

- the focused temporal/authority selection passed 24 tests;
- `make test-fast` passed all 107 production-core tests;
- compilation with warnings as errors, strict Credo, and AshPostgres migration/snapshot drift
  passed;
- the empty T1-C migration rollback/reapply and retained-state rollback-refusal probes passed;
- the final `./bin/core-check` passed all nine Phase 1 core stages, including the OpenAPI and
  migration drift checks, strict Credo, the dependency audit, Dialyzer with zero errors, and all
  107 production-core tests;
- the earlier full `make check` run passed the complete Phase 0 gate, the then-current 106-test
  Phase 1 core gate, the web dependency audit, the web build, and 20 web unit tests;
- the separately resumed UI-1A browser checks passed six connected and one unavailable-state test;
  and
- the required `make check` command is not green because UI-0 Playwright refused to start its
  hermetic server while an unrelated existing `next dev` process owned `127.0.0.1:3000`. That
  process was not terminated. UI-0 end-to-end tests remain the only skipped gate segment for this
  candidate.

## Decision effect and remaining gates

T1-C closes the neutral append-only branches of TR-01 through TR-05 and supplies one deliberate
reconciliation mode for TR-05. It does not complete ADR 0018.

TR-06 remains open for retention, legal hold, separately authorized erasure/redaction receipts,
projection propagation, and mandatory retained-data access during module deactivation. TR-07
remains open for source-baseline provenance, conflict reconciliation, backup/restore of complete
correction and consumer chains, and post-restore convergence. Performance, migration, and
recovery limits plus accountable residual-risk review also remain required before Full
Acceptance. TR-08 continues to prohibit a common temporal persistence library until two real
domains demonstrate the same stable primitive.
