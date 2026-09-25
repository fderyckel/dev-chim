# ADR 0018 T1-B governed revision-boundary evidence

- Status: Implemented; T1-B verification passing; complete repository verification blocked by concurrent out-of-scope checkout changes
- Date: 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0018](../../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md), [decision review](../../architecture/temporal-records-decision-review.md), [temporal contract](../../architecture/temporal-records-correction-and-evidence.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), and [threat model TM-01/TM-09/TM-10/TM-14/TM-15](../../security/threat-model.md)
- Scope: revisioned half of the neutral T1 proof; no append-only correction action, retention/erasure, consumer, public interface, or school module

## Question

Can the T1-A physical revision model support separate protected publication and correction intent,
an exact atomic operation result, and non-disclosing temporal reads without becoming a generic
temporal library or opening a public mutation surface?

## Implemented boundary

`Chimwemwe.Platform.TemporalQualification` exposes two governed writes:

| Boundary | Required capability | Result |
| --- | --- | --- |
| `publish_revision/3` | `platform.temporal_qualification.revisions.publish` | New stable aggregate, revision 1, complete segment set, current selector, operation ID, audit reference, and event ID |
| `correct_revision/3` | `platform.temporal_qualification.revisions.correct` | One consecutive immutable successor of the exact expected current revision with the same complete result shape |

The underlying `Aggregate.publish_revision` and `Aggregate.correct_revision` Ash actions are
private. The boundary validates trusted execution context before action input and accepts no
actor, tenant, placement, repository, routing, domain, authorization, or Ash option from the
caller. Publication and correction remain separate actions; there is no mode flag, generic write,
or request to correct whichever revision happens to be current.

Inputs contain a caller-selected synthetic aggregate UUID, a stable reason code, UUID idempotency
and causation identifiers, and one to 32 normalized, non-overlapping half-open Date segments.
Publication also names the synthetic scope. Correction instead names the exact expected current
revision. Revision, operation, and segment identities plus recorded time are writer-owned.

## Transaction and evidence

Each action runs inside the trusted writer boundary and an Ash-managed PostgreSQL transaction. It:

1. takes a tenant-and-aggregate advisory transaction lock;
2. rechecks its code-owned capability from current writer state;
3. claims tenant-and-action idempotency bound to actor, aggregate, and canonical request;
4. creates or locks the aggregate and verifies the exact expected selector;
5. inserts the immutable revision and every segment, then advances the selector;
6. writes one minimized security audit fact and one minimal outbox fact; and
7. stores the complete committed result before committing once.

Exact replay returns the original aggregate, revision, operation, predecessor, recorded time,
segment identities and values, audit reference, and event ID. Changed request or actor conflicts.
Concurrent identical publication returns one exact result to both callers. Racing different
corrections against one expected revision permit one winner and return a stable conflict to the
other without a branch or surviving loser claim.

The audit summary contains only safe identifiers, stable reason, segment count, and the validated
purpose. The outbox payload contains identifiers, aggregate revision, predecessor when present,
and segment count; it carries no segment values or authority. The existing closed platform
safe-write evidence resources are reused as qualification scaffolding. This does not promote a
common temporal persistence or action framework.

## Read contract

All reads revalidate trusted context, route to the writer, and resolve capability from current
tenant authority:

| Read | Capability | Behavior |
| --- | --- | --- |
| `get_current/3` | `platform.temporal_qualification.revisions.read_current` | Complete selected revision |
| `get_effective/4` | `platform.temporal_qualification.revisions.read_current` | The single selected segment effective on the supplied Date |
| `get_revision/3` | `platform.temporal_qualification.revisions.read_history` | One exact immutable revision |
| `list_history/3` | `platform.temporal_qualification.revisions.read_history` | Ordered history, bounded to 100 revisions with an explicit truncation flag |
| `get_as_known/5` | `platform.temporal_qualification.revisions.read_history` | Explicit `unsupported_query` after context, input, and capability checks |

Current access does not imply disclosure of superseded revisions. Tenant predicates apply to every
read; a valid identifier from another tenant returns the same not-found shape as an absent record.

## Executable scenarios

Seven T1-B tests prove:

1. both Ash actions remain private and no generic mutation function exists;
2. publication atomically returns a complete result and the named reads preserve their meanings;
3. sequential and concurrent exact replay return the same complete result, changed request or
   actor conflicts, and one idempotency key remains independent between tenants;
4. correction requires the exact current revision, preserves revision 1, advances current to
   revision 2, separates current from history authority, and rejects recorded-time approximation;
5. racing corrections serialize so exactly one wins and the revision chain does not branch;
6. missing capability or trusted context, cross-tenant reads/writes, unapproved input keys, and
   overlapping intervals fail closed without leaving action evidence; and
7. a database failure after outbox insertion rolls back aggregate, revision, segments, audit,
   outbox, and idempotency, after which the exact request succeeds.

The six T1-A tests continue to prove database-level chain, tenant/scope, immutability, interval,
writer-time, alternate-write, and append-only physical invariants. All data is synthetic.

## Qualification limits

- Date precision only; no school time zone or instant conversion is claimed.
- At most 32 segments per qualification action and 100 revisions per history response.
- Writer-only reads; no replica or projection routing is qualified.
- Recorded-time querying is unsupported rather than approximated.
- No throughput, latency, history-volume, index-growth, or production connection claim.
- No schema migration was required: T1-B uses the reviewed T1-A tables and existing compatible
  action-result payload, audit, and outbox columns. Migration/snapshot drift passes.

## ADR 0018 condition status

| Gate | T1-B evidence | Remaining before the whole gate can pass |
| --- | --- | --- |
| TR-01 | Governed revisioned aggregate actions and reads now execute | Governed append-only reversal/replacement action and complete T1 proof |
| TR-02 | Revision action/read capability, context, tenant, history-disclosure, and physical alternate-write negatives pass | Equivalent governed fact path and later retention/export disclosure paths |
| TR-03 | Revision operation identity, exact multi-record replay, changed request/actor, stale/concurrent conflict, and no branching pass | Multi-fact reversal operation proof before whole-T1 closure |
| TR-04 | Writer time, revision-scoped interval integrity, exact/current/effective/history reads, and unsupported recorded-time rejection pass | Recorded-time proof only if a later domain promises it; whole-T1 close after fact action |
| TR-05 | Revision state, audit, outbox, and idempotency commit or roll back together | Pin/follow-current/reconcile consumer evidence and fact-action atomicity |
| TR-06 | No claim | Retention, legal hold, erasure receipt, deactivation, and projection propagation |
| TR-07 | No migration was added and migration/resource-snapshot drift passes | Baseline import, reconciliation, expand/contract limits, backup/restore, and projection convergence |
| TR-08 | Preserved: qualification-owned duplication remains and no temporal library is promoted | Two real domain implementations before any shared persistence machinery |

TR-01 through TR-07 remain open as whole gates. ADR 0018 remains Conditionally Accepted.

## Verification

Focused command:

```sh
cd apps/chimwemwe_core && mise exec -- env MIX_ENV=test mix test \
  test/chimwemwe/platform/temporal_qualification_action_test.exs \
  test/chimwemwe/platform/temporal_qualification_test.exs
```

Current T1-B result: 13 focused tests passed. Targeted formatting and strict Credo pass for all 13
T1-B source/test files, migration/resource-snapshot drift passes, and Git whitespace validation
passes.

`make check` was run on 2026-09-25 and stopped in Phase 0 repository/documentation validation
because concurrent local-bridge work changed the shared root dependency lock without refreshing
the recorded Ash security-patch lock digest. The independent `bin/core-check` was also run and
stopped at formatting on four concurrent `local_bridge` files. Those files and the dependency
changes are outside T1-B and were not modified here. A separate full Dialyzer run likewise reached
the analyzer but reported six errors only in concurrent module-lifecycle and local-bridge Mix-task
files. Complete repository verification therefore cannot be claimed from this mixed checkout;
rerun `make check` after that work is reconciled.

## Next gate

The next bounded T1 increment should implement the governed append-only reversal-and-replacement
action with one operation identity and exact multi-fact result, plus one synthetic downstream
consumer proving an explicit pin, follow-current, or deliberate reconciliation mode. Retention,
legal hold, erasure, import, and recovery remain later increments.
