# Temporal records decision review

- Decision: Conditionally Accept ADR 0018
- Decision date: 2026-09-24
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

## Options considered

### Fully Accept now

Rejected. No neutral temporal implementation yet proves revision chains, multi-fact correction results, revision-scoped intervals, temporal reads, retention/legal hold, erasure receipts, or recovery. Full Acceptance would convert planned evidence into an unsupported completion claim.

### Keep Proposed until all runtime proof exists

Rejected. The paper model, alternatives, fallback, failure modes, three materially different scenarios, and five refinements are sufficiently stable to govern a bounded neutral proof. Keeping the decision entirely Proposed would obscure which principles are settled and make the proof less accountable.

### Conditionally Accept with fail-closed implementation gates

Accepted. The shared vocabulary, classifications, named-action semantics, evidence separation, consumer modes, and non-goals become the governing contract. Physical schemas, common libraries, domain reason codes, retention periods, erasure policy, and school-module adoption remain evidence- and owner-dependent.

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

## Full Acceptance gate

ADR 0018 may move from Conditionally Accepted to Accepted only after:

1. TR-01 through TR-07 have executable evidence for the neutral proof;
2. `make check` passes for the candidate without skipped required checks;
3. platform engineering records performance, migration, and recovery limits rather than treating local correctness as production sizing;
4. the accountable approver reviews the evidence and residual risks; and
5. any condition failure has either been repaired, explicitly narrowed with a fail-closed fallback, or handled by a superseding ADR.

Independent security/privacy review remains mandatory before real restricted child data. A school records owner and any domain-specific legal, finance, or safeguarding owner review the first applicable domain contract; those reviews are not fabricated by this platform-level decision.

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
- [Slice 1G role-rename evidence](../phase-1/evidence/authority-role-rename.md)
- [Production-core migration discipline](../development/migrations.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
