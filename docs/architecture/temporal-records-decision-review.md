# Temporal records decision review

- Decision: Accept ADR 0018
- Conditional decision date: 2026-09-24
- Full acceptance date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Architecture owner: Platform engineering
- Governing record: [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- Review scope: cross-domain vocabulary and neutral implementation contract; no school business module or production-data approval

## Decision question

Is the temporal-record contract sufficiently bounded and evidenced to govern a neutral executable proof, or must ADR 0018 remain Proposed until every runtime and domain-specific condition is already implemented?

## Evidence reviewed

The decision considers:

- the accepted named-action, tenant, writer-routing, transactional-outbox, migration, module-lifecycle, and governed-authoring boundaries;
- the first Slice 1G safe-write increment, which proves one tenant-qualified named mutation with capability checks, optimistic concurrency, exact idempotent replay, immutable audit evidence, a minimal transactional outbox fact, rollback, and migration review;
- the [academic-calendar source analysis and synthetic review](academic-calendar-synthetic-scenario-review.md);
- the [three-scenario temporal review](temporal-records-synthetic-scenario-review.md), covering immutable calendar succession, append-only reversal and replacement, and retroactive effective dating; and
- the accepted Phase 0 threat baseline, especially TM-01, TM-09, TM-10, TM-13, TM-14, and TM-15.

This evidence establishes a coherent decision boundary and exposes the remaining runtime questions. It does not prove the temporal implementation, real retention policy, school records policy, or lawful-erasure behavior.

## Review representation

François authorizes this conditional platform decision as Project Owner and current interim Security/Privacy Owner. The record does not claim that an independent security/privacy reviewer, school records owner, finance owner, legal owner, or safeguarding owner participated. Those reviewers become mandatory before their data or domain enters scope, as recorded in the binding conditions and the existing Phase 0 residual-risk process.

This separation is deliberate: ADR 0018 accepts a platform vocabulary and fail-closed proof contract, not a school's retention schedule, accounting treatment, safeguarding process, or lawful-erasure determination.

## Full Acceptance decision

On 2026-09-27, François reviewed the completed Slice 2.0-C evidence and approved all six residual
risks recorded in that evidence. The complete repository gate had already passed for the accepted
candidate with no skipped required checks, so this review does not request or claim a duplicate
run.

The six approved dispositions are:

1. Synthetic erasure remains engineering evidence, not a legal conclusion or domain retention
   schedule; each adopting domain retains an accountable policy owner.
2. Offline backups may retain protected bytes until approved expiry; restore must reapply current
   erasure state before interfaces reopen.
3. Local single-node evidence is not selected-deployment qualification; capacity, locks, WAL,
   RPO/RTO, encryption, and operator execution remain L3 gates.
4. Every external projection, cache, search, analytics, export, or integration adapter must prove
   its own propagation and acknowledgement behavior before adoption.
5. Independent security/privacy and learning-institution records-owner review remain mandatory
   before Restricted data or a pilot.
6. TR-08 remains binding: one neutral proof does not authorize a universal temporal persistence
   library.

These are accepted downstream conditions, not unresolved platform-level blockers. ADR 0018 is
therefore Accepted for bounded domain-owned implementations. This acceptance neither defines a
real institution's records policy nor qualifies a deployment, public interface, or real-data
pilot.

## Initial options considered on 2026-09-24

### Fully Accept at the initial review

Rejected at the initial review. No neutral temporal implementation yet proved revision chains,
multi-fact correction results, revision-scoped intervals, temporal reads, retention/legal hold,
erasure receipts, or recovery. Full Acceptance then would have converted planned evidence into an
unsupported completion claim.

### Keep Proposed until all runtime proof exists

Rejected. The paper model, alternatives, fallback, failure modes, three materially different scenarios, and five refinements are sufficiently stable to govern a bounded neutral proof. Keeping the decision entirely Proposed would obscure which principles are settled and make the proof less accountable.

### Conditionally Accept with fail-closed implementation gates at the initial review

Accepted at the initial review. The shared vocabulary, classifications, named-action semantics,
evidence separation, consumer modes, and non-goals became the governing contract. Physical
schemas, common libraries, domain reason codes, retention periods, erasure policy, and
school-module adoption remained evidence- and owner-dependent.

## Accepted now

The following are accepted as the platform direction:

1. Every state-changing lifecycle is classified as mutable working state, revisioned durable state, or append-only fact.
2. Published or posted meaning is never corrected through generic in-place mutation.
3. Planned succession, correction, reversal, and erasure are distinct named actions with distinct authorization and reason semantics.
4. Recorded time and effective time are separate, and unsupported recorded-time queries fail explicitly.
5. A multi-record correction has one immutable domain-operation identity and one exact committed result.
6. Durable decisions pin the revision they used or reconcile deliberately; only disposable or explicitly non-historical views may follow current meaning without preserving a historical basis.
7. Domain history, security/access audit, transactional outbox, migration provenance, projections, and backup/recovery remain separate evidence layers.
8. PostgreSQL remains authoritative; no universal event store, bitemporal engine, polymorphic history table, or framework history extension is adopted.

## Binding conditions

Conditional Acceptance carries the following fail-closed gates.

| ID | Condition | Required evidence | Failure effect |
| --- | --- | --- | --- |
| TR-01 | Neutral temporal proof | One synthetic revisioned aggregate and one append-only fact in the production core, with no education module | Blocks every production temporal resource |
| TR-02 | Tenant and capability safety | Positive authorization plus missing-context, denied-capability, cross-tenant, cross-scope, history-disclosure, and alternate-write negatives | Blocks the affected action and read path |
| TR-03 | Correction identity and concurrency | Immutable operation identity, expected revision, exact multi-record replay, changed-request conflict, stale/concurrent conflict, and no correction branching | Blocks correction and publication |
| TR-04 | Temporal integrity and reads | Writer-assigned recorded time, revision-scoped interval constraints, exact/current/effective reads, unsupported `as_known_at` rejection, and recorded-time proof where promised | Blocks effective-dated use |
| TR-05 | Atomic evidence and downstream behavior | State, audit reference, outbox fact, and idempotency result commit or roll back together; consumers prove pin, follow-current, or deliberate reconciliation semantics | Blocks side effects and downstream adoption |
| TR-06 | Retention, hold, erasure, and deactivation | Synthetic retention and legal-hold state, separately authorized redaction/erasure receipt, projection propagation, and mandatory access during module deactivation | Blocks retained or regulated records |
| TR-07 | Migration and recovery | Expand-and-contract review, baseline-import provenance, conflict reconciliation, backup/restore of correction chains, and post-restore projection convergence | Blocks retained-data migration or cutover |
| TR-08 | Common-library restraint | Two implemented domains demonstrate the same stable primitive before shared persistence machinery is promoted | Blocks a universal temporal library, not domain-owned implementations |

Every condition inherits the existing writer-routing, tenant, classification, telemetry, migration, and module-lifecycle gates. Passing a condition for one resource does not silently qualify another resource with different retention, authorization, volume, or correction semantics.

## Authorization effect

This decision closes the T0 paper-decision gate and makes a neutral T1 proof eligible for a separately bounded Phase 1 implementation slice. It does not itself add or authorize:

- an academic-calendar, attendance, admissions, enrollment, finance, safeguarding, or other school module;
- production data, a public API, UI workflow, worker, dispatcher, or production runtime;
- a generic write invoker, universal revision table, temporal framework dependency, or event-sourced platform; or
- a real retention period, legal-hold rule, erasure outcome, accounting rule, or school records policy.

ADR 0021 remains Proposed. Before its calendar domain may be accepted or implemented, the relevant ADR 0018 conditions must pass, a school-side records owner must review the calendar correction and retention behavior, and that module needs separate authorization.

## Implementation progress

The 2026-09-25 [T1-A physical-model evidence](../phase-1/handover-evidence.md)
adds a closed neutral aggregate/revision/segment/fact qualification model and proves a bounded set
of PostgreSQL identity, tenant, immutability, interval, timestamp, concurrency, and physical query
invariants. It introduces no callable temporal action, history interface, audit/outbox contract,
retention action, recovery proof, shared temporal library, or school module.

T1-A is therefore progress toward TR-01, TR-02, TR-03, TR-04, and TR-07, not completion of any
TR-01 through TR-07 gate. The Full Acceptance gate below is unchanged.

The 2026-09-25 [T1-B revision-boundary evidence](../phase-1/handover-evidence.md)
adds separate capability-protected publication and exact-target correction actions, immutable
operation results with exact and concurrent replay, stable stale/concurrent conflict, atomic
state/audit/outbox/idempotency behavior, and writer-routed current, effective, exact, bounded
history, and explicitly unsupported recorded-time reads.

This closes the executable revision branches of TR-02 through TR-05, but not those conditions as
whole T1 gates. The append-only fact still has no governed reversal/replacement action, TR-05 has
no downstream pin/follow/reconcile consumer, TR-06 has no retention/hold/erasure proof, and TR-07
has no baseline import, reconciliation, backup/restore, or projection-convergence proof. TR-01
through TR-07 therefore remained open at that checkpoint, and ADR 0018 remained Conditionally
Accepted.

The 2026-09-25 [T1-C fact-and-reconciliation evidence](../phase-1/handover-evidence.md)
adds the append-only record and reverse-and-replace actions, immutable multi-fact operation
identity, exact replay, correction-race serialization, capability-separated operation history,
and one append-only deliberate-reconciliation consumer chain. It proves that a source correction
does not silently reinterpret a pinned consumer and that an event identifier cannot authorize
reconciliation.

This closes the neutral append-only branches of TR-01 through TR-05 and one consumer mode under
TR-05. It does not close TR-06 or TR-07, record production performance/migration/recovery limits,
or supply the final accountable residual-risk review. At that checkpoint ADR 0018 therefore
remained Conditionally Accepted rather than moving to Accepted.

The 2026-09-26
[Slice 2.0-C evidence](../phase-2/temporal-completion-and-recovery-evidence.md) closes the neutral
engineering branches of TR-06 and TR-07 and confirms the accumulated TR-01 through TR-07 proof.
It covers separately authorized retention/hold/erasure, minimized immutable receipts, mandatory
access while inactive, immutable baseline-import and conflict-reconciliation provenance, direct
database-write rejection, retained rollback refusal, PostgreSQL dump/restore, governed projection
convergence, and bounded local performance/storage measurement.

The implementation is not a school records policy, selected-deployment qualification, or second
domain. TR-08 therefore continues to prohibit a universal persistence abstraction. On 2026-09-27,
the accountable owner separately reviewed this completed evidence and approved all six stated
residual risks as the downstream conditions recorded above. That post-evidence review completes
the Full Acceptance step without relabelling the earlier implementation authorization.

## Full Acceptance gate — satisfied on 2026-09-27

The gate required:

1. TR-01 through TR-07 have executable evidence for the neutral proof;
2. `make check` passes for the candidate without skipped required checks;
3. platform engineering records performance, migration, and recovery limits rather than treating local correctness as production sizing;
4. the accountable approver reviews the evidence and residual risks; and
5. any condition failure has either been repaired, explicitly narrowed with a fail-closed fallback, or handled by a superseding ADR.

Independent security/privacy review remains mandatory before real restricted child data. A school records owner and any domain-specific legal, finance, or safeguarding owner review the first applicable domain contract; those reviews are not fabricated by this platform-level decision.

TR-01 through TR-07, the complete repository gate, the recorded local limits, and the accountable
residual-risk review are satisfied for the neutral platform proof. TR-08 remains a deliberate
restraint on shared-library promotion rather than a blocker for domain-owned implementations.

## Review triggers

Reopen this decision when:

- T1 cannot preserve the accepted identity, time, correction, consumer, or evidence semantics;
- a real domain requires correction branching, merge, temporal joins, or universal recorded-time querying;
- retention, legal-hold, erasure, or backup policy conflicts with immutable revision history;
- temporal volume or query behavior requires partitioning or another physical design that weakens tenant-qualified integrity; or
- two domains prove that the proposed shared vocabulary hides rather than clarifies their meaning.

## Related records

- [Temporal records, correction, and evidence contract](temporal-records-correction-and-evidence.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md)
- [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [Slice 1G role-rename evidence](../phase-1/handover-evidence.md)
- [ADR 0018 T1-C evidence](../phase-1/handover-evidence.md)
- [Slice 2.0-C temporal completion and recovery evidence](../phase-2/temporal-completion-and-recovery-evidence.md)
- [Temporal retention and recovery runbook](../operations/temporal-retention-and-recovery.md)
- [Production-core migration discipline](../development/migrations.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
