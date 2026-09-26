# Temporal records, correction, and evidence contract

- Status: Conditionally Accepted; TR-01 through TR-08 remain binding and no production-domain implementation is authorized
- Owner: Platform engineering with domain records and security/privacy owners
- Governing record: [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- Review trigger: first durable correction action, first effective-dated resource, first ledger reversal, or retention/legal-hold implementation

## Purpose and scope

This contract gives future Chimwemwe modules a common way to describe edits, published revisions, corrections, reversals, effective time, history, audit, retention, and erasure. It preserves one PostgreSQL authority and the named-action boundary without prescribing one table layout or Ash extension for every domain.

The platform owns trusted context, capability evaluation, writer routing, action/idempotency conventions, audit envelope, outbox infrastructure, retention orchestration, and stable error vocabulary. A business module owns the meaning of publication, correction, reversal, effective date, historical view, reconciliation, and retained evidence for its records.

## Vocabulary

| Term | Meaning | Not equivalent to |
| --- | --- | --- |
| Aggregate identity | Stable identity of the enduring business subject | One physical row or revision |
| Revision | Immutable recorded representation of revisioned durable state | Mutable audit snapshot |
| Fact | Append-only domain occurrence with its own stable identity | Current aggregate state |
| Domain operation | Immutable identity and exact result for one publication, correction, reversal, or other action that may create several revisions or facts | Caller idempotency key or one created row |
| Recorded time | UTC time assigned by the writer inside the committing transaction | Caller timestamp, exact commit ordering, or domain effective date |
| Effective time | Date or instant when meaning applies in the domain | Database insertion time |
| Correction | Named action producing a successor revision | Generic update or history-row edit |
| Reversal or adjustment | New fact that changes the net meaning of an earlier fact | Deleting or overwriting the original fact |
| Domain history | Authoritative revision or fact chain | Security log, outbox, backup, or projection |
| Audit | Minimized evidence of actor, tenant, purpose, action, and outcome | Complete business-state reconstruction |
| Tombstone | Minimum lawful evidence that protected content was removed or redacted | Soft-deleted full content retained forever |

## Required classification

Every state-changing resource declares its semantics in its module contract and tests.

### Mutable working state

Use for a draft or replaceable value that has not acquired immutable business meaning. Named actions may update it in place with tenant and capability checks, optimistic concurrency, safe attribution, and validation. Ordinary timestamps do not make it historical evidence.

The domain must name the transition that ends mutable status. Publication, posting, approval, finalization, or another explicit action may move the aggregate to revisioned or append-only semantics.

### Revisioned durable state

Use when users or downstream records must be able to identify exactly what was published or relied on. The aggregate has one stable identity and a chain of immutable revisions. A correction creates a successor and records why, when, by whom, and which revision it supersedes.

One current pointer or selector may be maintained for efficient reads, but it is a transactionally maintained index over immutable revisions and changes only inside the correction/publication transaction. It is not a second editable representation or an alternate source of business meaning.

### Append-only fact

Use when the original occurrence must remain visible and net meaning changes through a reversal, adjustment, or compensating fact. The owning domain defines whether a reversal fully cancels, partially adjusts, or links to a replacement. A generic delete or replacement action is not exposed.

## Temporal declaration

Each revisioned or append-only resource declares:

- time precision: school-local Date or UTC instant;
- authoritative IANA time zone when Date values can be derived from instants;
- whether it has no effective interval, one effective point, or a half-open `[effective_from, effective_until)` interval;
- whether overlapping effective records are prohibited inside one selected aggregate revision or current timeline, allowed by purpose, or partitioned by an explicit scope key;
- supported reads: exact revision/fact, current, effective as of a date or instant, and optionally as known at recorded time;
- correction/reversal actions and stable reason-code vocabulary;
- which consumers pin an exact revision and which follow current meaning;
- classification, retention, legal hold, export, erasure, and tombstone policy; and
- query, index, volume, partitioning, recovery, and migration assumptions.

Callers cannot choose a time zone, recorded time, repository, tenant, or placement. If an instant must become a school-local date, the server uses the stored zone. A domain without recorded-time query support rejects `as_known_at`; it never approximates the answer from modification timestamps.

## Revision contract

The logical shape is:

```text
stable aggregate
  |
  +-- immutable revision 1 (recorded_at, effective interval)
  |       |
  |       +-- superseded by revision 2
  |
  +-- immutable revision 2 (recorded_at, effective interval, correction reason)
```

One aggregate revision may be an immutable snapshot or an atomically created set of effective segments. Current/effective uniqueness is evaluated within that selected revision or an equivalent current-timeline selector. Historical revisions may intentionally cover the same effective dates; creating a successor never truncates or rewrites their recorded intervals in place.

Required identity and provenance fields are conceptually:

- tenant ID and domain scope IDs;
- stable aggregate ID;
- immutable revision ID and monotonic aggregate revision;
- immutable domain-operation ID when one action creates multiple revisions or facts;
- platform-assigned `recorded_at`;
- optional `effective_from` and `effective_until`;
- exact predecessor/corrected revision ID;
- actor or service identity, purpose, correlation, and causation;
- stable reason code and optional classified note;
- source/import provenance when applicable; and
- idempotency binding for replayable writes.

Names and physical storage remain domain-owned. The contract does not require one platform revision table or polymorphic foreign key.

## Correction transaction

A correction action follows one path:

```text
trusted context
  -> module/release/entitlement/activation/capability gates
  -> load target revision on writer
  -> compare expected revision and idempotency binding
  -> validate effective time, retention, legal hold, and domain invariants
  -> create the complete successor revision or compensating fact set under one operation identity
  -> record current/effective selector or supersession metadata when applicable
  -> record minimal audit evidence and transactional outbox fact
  -> commit once
```

The target revision is explicit. Correcting “whatever is latest” is not allowed. A repeated identical request returns the exact committed operation identity and every created revision or fact. Reusing the key with changed target, effective time, reason, or payload returns an idempotency conflict. A concurrent action against the same expected revision returns a stable conflict; the first implementation does not create or merge branches. Planned prospective succession, correction of erroneous meaning, and reversal use distinct named actions, predecessor relationships, and reason vocabularies.

Required public failures include validation, forbidden, not found, stale revision conflict, idempotency conflict, effective-time conflict, retention/legal-hold conflict, retryable dependency, and non-disclosing internal failure.

## Read contract

Temporal reads are named and policy-protected:

- `get_revision(revision_id)` returns one authorized immutable revision;
- `get_current(aggregate_id)` returns the authoritative current revision when that concept exists;
- `get_effective(aggregate_id, as_of)` resolves declared domain time and returns conflict if data violates uniqueness;
- `list_history(aggregate_id)` returns an authorized, ordered, bounded revision or fact chain; and
- `get_as_known(aggregate_id, effective_as_of, recorded_as_of)` exists only for domains that explicitly implement and test both axes.

History access is not implied by access to current state. Superseded or erased material may have different classification and purpose restrictions. Security-sensitive current and correction reads stay on the PostgreSQL writer. Approved historical projections may use bounded-staleness infrastructure only after the owning contract permits it.

## Downstream consumer contract

Each downstream consumer chooses one behaviour explicitly:

1. **Pin exact revision.** A durable decision stores aggregate and revision IDs so its historical basis remains explainable.
2. **Follow current meaning.** A disposable, recomputable, or explicitly non-historical view resolves current state when read and accepts that the result may change after correction.
3. **Reconcile deliberately.** A correction outbox fact identifies affected state, and the consumer runs its own authorized, idempotent reconciliation action.

A durable consumer cannot silently switch between these modes or follow current meaning without preserving its historical basis. A domain that permits retroactive correction implements recorded-time reads where promised or requires exact revision pinning. Delivery of an event does not authorize reconciliation. Cross-module relationships retain tenant-qualified integrity, and consumer state never derives ownership from an event payload.

## Evidence layers

| Evidence layer | Owns | Must not become |
| --- | --- | --- |
| Domain revision/fact chain | Business meaning, predecessor, effective time, correction or reversal | Security access log |
| Security/access audit | Actor/service, tenant, purpose, assurance, action, outcome, safe references | Full domain snapshot or replay source |
| Transactional outbox | Minimal versioned fact for downstream delivery and reconciliation | Aggregate history or placement authority |
| Migration ledger | Source snapshot, source ID, mapping revision, target ID, reconciliation result | Invented source history |
| Projection/cache/search/report | Disposable read optimization | Correction or authorization boundary |
| Backup/WAL/PITR | Operational recovery of authoritative storage | Product history interface |

All layers inherit tenant and classification. Restricted content is referenced by safe IDs whenever the content itself is unnecessary.

## Retention, legal hold, and erasure

Every retained domain declares:

- retention owner and start event;
- minimum and maximum duration where applicable;
- legal-hold creation, review, release, and authorization;
- correction and export availability during module deactivation;
- deletion, anonymization, or redaction action and recovery boundary;
- tombstone and deletion-receipt contents; and
- projection, cache, search, analytics, backup, and integration propagation.

Legal hold and retention decisions use current writer state. Erasure cannot be implemented as an untracked SQL delete, expired cache, or projection removal. Conversely, a generic “immutable history” claim cannot override an accountable lawful erasure. The approved action minimizes retained tombstone data and records enough evidence to prove completion without retaining the protected content it was required to remove.

## Import and migration

An imported current row becomes a baseline revision or fact only when its source snapshot, source identifier, mapping revision, and import time are recorded. Source modification timestamps remain source attributes; they are not transformed into trustworthy recorded-time history.

Where source rows conflict, overlap, or refer to missing predecessors, migration stops for reconciliation. It does not synthesize a clean revision chain. Expand-and-contract delivery provides compatible identifiers and nullable provenance first, then bounded tenant-qualified backfill, separate validation, old-version drain, and accountable contract. Destructive cleanup waits for retention, recovery, and reconciliation approval.

## Validation scenarios

The [synthetic scenario review](temporal-records-synthetic-scenario-review.md) completes the paper walkthrough of all three cases below and records five bounded refinements. The scenarios remain design evidence until the neutral executable proof is authorized and recorded.

### Published calendar correction

A school publishes calendar revision 1. Attendance planning pins revision 1. A later emergency closure creates revision 2 with an effective school-local date, reason, expected revision, audit evidence, and outbox fact. Current calendar reads resolve revision 2. The existing planning record remains explainable against revision 1 until its owning module deliberately reconciles it.

### Append-only correction

A synthetic ledger fact is found to be wrong. A separately authorized reversal references the original and a replacement fact records the corrected meaning. Exact replay is idempotent, changed replay conflicts, the original remains visible within retention, and derived balances rebuild to the same result.

### Effective-dated configuration

A tenant schedules a future configuration revision, then submits a retroactive correction. Publication prevents overlapping active intervals for the same scope. An exact-revision read, effective-date read, and—only if declared—recorded-time read each return their defined result. Concurrent corrections to the same expected revision cannot both win.

These are design scenarios until executable evidence is recorded.

## Delivery gates

### T0 — decision contract

ADR 0018, this contract, the [synthetic scenario review](temporal-records-synthetic-scenario-review.md), and the [decision review](temporal-records-decision-review.md) define vocabulary, classification, action, query, consumer, evidence, retention, and migration boundaries. T0 is complete through Conditional Acceptance; no runtime implementation is added by these documents.

### T1 — neutral executable proof

After the core safe-write boundary is explicitly authorized, implement one neutral synthetic revisioned record and one append-only fact. Prove writer routing, tenant isolation, policy, concurrency, idempotency, effective intervals, audit/outbox atomicity, history queries, reconciliation, retention, legal hold, erasure receipt, migration, and recovery without adding an education module.

The first authorized [T1-A physical-model increment](../phase-1/evidence/temporal-qualification-physical-model.md)
implements only closed qualification resources and their PostgreSQL invariants. It does not
complete T1 or any TR-01 through TR-07 gate; callable actions and reads, atomic evidence,
retention/erasure, migration provenance, backup/restore, and performance limits remain open.

The authorized [T1-B revision-boundary increment](../phase-1/evidence/temporal-qualification-revision-boundary.md)
adds separate private publication and exact-target correction actions plus capability-separated
current/effective and exact/history reads. It proves the revision action's exact result,
idempotency, stale/concurrent conflict, one-branch behavior, and atomic state/audit/outbox claim.
It explicitly rejects recorded-time queries. It still does not implement append-only reversal,
a downstream consumer, retention/hold/erasure, import provenance, recovery, or performance
qualification, so T1 and TR-01 through TR-07 remain open.

The authorized [T1-C fact-and-reconciliation increment](../phase-1/evidence/temporal-qualification-fact-and-reconciliation.md)
adds separate private record and reverse-and-replace actions with immutable operation identity,
exact replay, one-winner correction races, minimized atomic evidence, and capability-separated
exact/history reads. A neutral append-only consumer-basis chain proves that source correction does
not mutate a pinned decision and that only a separately authorized action may reconcile to the
exact current source revision. An event is causation evidence, never authority.

T1-C closes the executable append-only branches of TR-01 through TR-05 and supplies one deliberate
reconciliation mode. T1 remains incomplete: TR-06 retention/hold/erasure and deactivation access,
TR-07 import provenance plus backup/restore/convergence, performance and recovery limits, and
accountable residual-risk review remain open.

### T2 — first domain adoption

Choose one separately authorized low-blast-radius domain. Its ADR or module contract declares temporal class, query modes, correction actions, consumer modes, retention, migration, and user experience. Reuse only the neutral primitives proven stable in T1.

### T3 — shared primitive review

After at least two domains, inventory duplication. Promote a common library only when it removes repeated risk without hiding domain policy or binding public contracts to Ash internals.

## Explicit non-goals

- no universal event-sourced architecture;
- no universal bitemporal query engine or polymorphic history table;
- no generic CRUD correction, restore, undelete, or audit-log replay;
- no AshPaperTrail, AshArchival, AshStateMachine, Reactor, or other framework dependency from this decision;
- no claim that timestamps alone provide history;
- no promise to retain protected content forever;
- no automatic downstream reinterpretation after correction;
- no production resource, migration, school module, UI, job, or public API; and
- no full-acceptance claim from planned or unexecuted scenarios.

## Related records

- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md)
- [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- [Temporal records decision review](temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)
- [Academic calendar authority](academic-calendar-authority.md)
- [Production-core migration discipline](../development/migrations.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Data classification](../security/data-classification.md)
- [Threat model](../security/threat-model.md)
