# ADR 0018: Temporal records, correction, audit, and evidence semantics

- Status: Conditionally Accepted
- Date: 2026-09-24
- Decision date: 2026-09-24
- Accountable owner: Platform engineering and domain records owners
- Deciders: François — Project Owner and interim Security/Privacy Owner, with architecture review
- Required later reviewers: independent security/privacy reviewer before real restricted data; school records and applicable domain owners before first domain adoption
- Supersedes: None

## Context

School records change for different reasons. A draft may be edited before it has durable meaning. A published calendar or effective-dated assignment may need a later correction without erasing what users previously relied on. An attendance, financial, or other ledger-like fact may need reversal rather than replacement. Security audit, integration events, migration provenance, and backup recovery provide different evidence again.

The platform already requires named actions, optimistic concurrency, idempotency, transactional outbox facts, tenant isolation, retained-data migration discipline, and PostgreSQL authority. Those controls do not by themselves define whether a changed value is an edit, correction, successor revision, reversal, erasure, or historical view.

The supplied Frappe academic-calendar implementation demonstrates the risk: year and term dates are updated in place and callbacks update generated events. ADR 0021 therefore cannot safely publish or correct an academic calendar until Chimwemwe defines stable identity, recorded and effective time, correction provenance, history queries, downstream reconciliation, retention, and erasure boundaries.

This decision establishes a conditionally accepted cross-domain contract. It does not authorize a universal history table, event-sourced platform, Ash extension, production resource, migration, or school business module.

## Decision drivers

- Preserve the original meaning and provenance of durable school records within their approved retention period.
- Distinguish ordinary draft editing, published-state correction, and ledger reversal.
- Answer current, effective-date, exact-revision, and—where explicitly required—“as known then” questions without hidden latest-row behaviour.
- Keep actor, tenant, purpose, authorization, concurrency, idempotency, and outbox guarantees on every correction path.
- Prevent audit logs, integration events, projections, and backups from becoming competing sources of business truth.
- Support lawful retention, legal hold, redaction, and erasure without claiming that all content is immutable forever.
- Add shared vocabulary and checks only where they remove repeated risk; keep domain meaning with the owning module.

## Considered options

1. Permit in-place updates and rely on a generic audit log. This is operationally simple but cannot reliably reconstruct domain meaning, effective intervals, correction chains, or downstream decisions.
2. Event-source every domain aggregate. This can preserve history but imposes event design, replay, projection, migration, versioning, and operating cost on records that do not need it.
3. Add one universal bitemporal/history table or adopt a framework extension such as AshPaperTrail for every resource. This creates a common mechanism but risks a second generic model that cannot decide domain correction, retention, authorization, or reversal semantics.
4. Require each domain to classify durable state and implement a bounded revision or reversal contract using shared temporal and evidence vocabulary. Add reusable platform primitives only after at least two implementations prove the same stable need.

## Decision

Conditionally adopt option 4. The vocabulary, lifecycle classifications, named correction semantics, consumer modes, evidence separation, and non-goals govern future design now. The [decision review](../architecture/temporal-records-decision-review.md) keeps executable temporal behavior, retention, recovery, and first-domain adoption behind eight fail-closed conditions.

Conditional Acceptance closes the paper-decision gate and makes a neutral T1 proof eligible for a separately bounded implementation slice. It does not accept a physical schema, common persistence library, domain reason vocabulary, retention period, erasure policy, public interface, or school module.

Every production resource with state-changing actions will declare one of these semantics for each relevant lifecycle stage:

1. **Mutable working state.** An unpublished draft or replaceable operational value may change in place through named actions with authorization, optimistic concurrency, attribution, and ordinary audit. It is not represented as immutable historical evidence merely because a row has timestamps.
2. **Revisioned durable state.** Publication or another domain transition freezes an immutable revision under a stable aggregate identity. A correction creates a successor revision that names the prior revision and correction reason. It never rewrites the published revision in place.
3. **Append-only fact.** A ledger-like fact is not replaced. A correction creates an explicit reversal, adjustment, or compensating fact linked to the original according to domain rules.

A domain may use more than one class across its lifecycle—for example, mutable calendar draft followed by immutable publication revisions—but it must not expose two authoritative representations of the same state.

### Time and identity

- `aggregate_id` identifies the enduring business subject.
- `revision_id` or `fact_id` identifies one immutable recorded representation.
- A correction or publication that creates multiple revisions or facts has one immutable domain-operation identity and one exact committed action result. That identity is distinct from the caller's idempotency key and from each created row identity.
- `recorded_at` is assigned by the authoritative writer in UTC inside the committing transaction and is never caller-supplied or backdated. Aggregate revision, not timestamp precision, orders concurrent changes.
- `effective_from` and optional `effective_until` express domain time only when the owning domain needs it. The domain declares Date or UTC-instant precision and, for dates, the authoritative IANA time zone.
- Effective intervals use an inclusive start and exclusive end. A domain requiring one effective value prevents overlap inside the selected aggregate revision or equivalent current timeline with database constraints, serialization, or both. Superseded historical revisions may cover the same effective dates and must not be rejected by an incorrectly global interval constraint.
- `supersedes_revision_id`, `corrects_revision_id`, or `reverses_fact_id` records the exact predecessor semantics; planned succession, correction of erroneous meaning, and reversal use distinct named actions and reason vocabularies. Those relationships are tenant-qualified and cannot cross aggregates unless the domain explicitly defines a compensating relationship.

The platform will not pretend that every revisioned resource supports full bitemporal queries. A domain explicitly declares whether it supports only current and exact-revision reads, effective-date reads, or an “as known at recorded time” read. An unsupported temporal query fails explicitly rather than approximating from `updated_at`.

### Correction action

A correction is a named, separately authorized domain action. It requires the trusted actor and tenant, purpose and correlation, the exact target or expected current revision, a stable reason code, effective-time input when applicable, and an idempotency key when replay is possible. Optional explanatory text inherits the corrected record's classification and is excluded from unsafe logs and event payloads.

In one writer transaction, the action validates policy and invariants, locks or compares the expected revision, creates the complete successor revision or set of compensating facts under one domain-operation identity, records the selector or supersession metadata needed to resolve current/effective meaning without altering prior business payload or provenance, records minimal audit evidence, and writes the required outbox fact. Exact replay returns that complete committed operation result. A second concurrent correction of the same expected revision receives a stable conflict; v1 does not merge correction branches.

A retroactive correction changes the authoritative view only according to its declared effective semantics. It does not silently reinterpret a durable downstream record that captured an earlier revision. A durable decision stores the exact revision it used or requires an explicit reconciliation action; follow-current mode is limited to disposable, recomputable, or explicitly non-historical views. A domain that permits retroactive correction either implements and tests recorded-time queries where historical reproduction needs them or requires consumers to pin exact revisions. Outbox delivery may request reconciliation but never grants authority or rewrites consumer state by itself.

### Evidence separation

- **Domain history** answers what business meaning was recorded, corrected, superseded, reversed, and effective.
- **Security/access audit** records who attempted or completed a protected action, under which tenant, purpose, assurance, and outcome. It is minimized and is not the domain state store.
- **Transactional outbox facts** trigger or reconcile downstream work. They are minimal integration contracts, not a complete audit or replay source for the aggregate.
- **Migration provenance** maps imported source snapshots and identifiers to target revisions without inventing history that the source cannot prove.
- **Backups, WAL, and point-in-time recovery** restore storage after failure. They are not user-facing history or correction interfaces.
- **Caches, search, reports, analytics, and calendar feeds** are disposable projections that rebuild from authoritative domain state and revision-aware facts.

### Retention, legal hold, and erasure

Correction does not mean deletion, and ordinary deletion does not erase protected history. Each domain declares classification, retention start, retention duration, legal-hold behaviour, export scope, and the accountable deletion or anonymization action.

Immutability applies within the approved retention and legal-hold contract. If law or policy requires erasure, a separately authorized action may remove or irreversibly redact protected content while retaining the minimum lawful non-sensitive tombstone and deletion receipt. The platform must not promise both permanent content retention and complete erasure. Legal hold blocks an otherwise eligible erasure until released by the accountable authority.

## Consequences

### Positive

- Published and ledger-like records retain explainable correction chains instead of relying on mutable rows and generic logs.
- Current, historical, and effective-date queries have explicit meanings.
- Downstream modules can choose exact-revision stability or deliberate reconciliation rather than accidental reinterpretation.
- The approach preserves PostgreSQL and named domain actions without requiring event sourcing or a second runtime model.
- Retention and erasure are governed explicitly rather than hidden behind soft delete.

### Negative

- Domain owners must classify records and design correction behaviour instead of receiving generic CRUD history automatically.
- Revision rows, indexes, correction reasons, reconciliation, and retention increase storage and operational work.
- “As known then” queries are unavailable until a domain explicitly implements and tests recorded-time semantics.
- Concurrent and retroactive corrections require careful constraints, user experience, and conflict handling.
- A later common library may still be justified after repeated implementations, creating some initial duplication.

## Security, privacy, operability, and migration effects

Every revision, predecessor link, correction, reversal, audit record, outbox fact, query, export, and retention action is tenant-qualified and uses trusted placement. Missing actor, tenant, purpose, target revision, required reason, or current route fails closed. Correction, history viewing, export, legal hold, and erasure use distinct tenant-defined capabilities; edit or publication authority does not imply them.

The writer performs correction and security-sensitive temporal reads. Replica or projection results cannot authorize, resolve a correction race, or decide the current protected revision. Database constraints preserve non-null tenant keys, tenant-qualified predecessor relationships, immutable recorded timestamps, unique revision identity, and revision-scoped non-overlap where the domain requires one effective value.

Audit and reason data are minimized and classified. Restricted original content is not copied into logs or outbox payloads. History reads, exports, and support tools re-authorize the real actor and purpose and do not reveal a superseded record merely because its identifier is known.

Source systems without trustworthy history are imported as a baseline observation with source snapshot, source identifier, import time, and mapping revision. Modified timestamps or current rows do not prove prior states. Migration conflicts, missing predecessors, overlapping effective intervals, and unverifiable correction chains fail into reconciliation instead of being silently fabricated.

## Validation evidence

Current evidence consists of the accepted action, outbox, tenant, PostgreSQL, migration, module-lifecycle, and metadata boundaries plus the [academic-calendar synthetic scenario review](../architecture/academic-calendar-synthetic-scenario-review.md) and the [temporal-records synthetic scenario review](../architecture/temporal-records-synthetic-scenario-review.md). The latter completes the three required paper walkthroughs: a published calendar correction after reliance, an append-only reversal and replacement, and a prospective effective-dated change followed by retroactive correction. It supports the bounded classification and action contract after five documented refinements, but it is not accountable review or executable proof.

The 2026-09-24 [decision review](../architecture/temporal-records-decision-review.md) conditionally accepts the bounded contract and records TR-01 through TR-08 as binding gates. Before full Acceptance, the neutral proof must satisfy TR-01 through TR-07, pass the complete repository gate, record performance/migration/recovery limits, and receive accountable residual-risk review. Real domain retention, legal-hold, erasure, and reason vocabularies remain owner decisions rather than conclusions from synthetic fixtures.

The 2026-09-25 [T1-C evidence](../phase-1/evidence/temporal-qualification-fact-and-reconciliation.md)
implements the neutral append-only record/reversal branch and one deliberate-reconciliation
consumer. It closes those executable portions of TR-01 through TR-05 only. TR-06, TR-07,
performance/migration/recovery limits, and final accountable review remain open, so this ADR stays
Conditionally Accepted.

The executable proof for the first authorized implementation must include positive and negative capability tests, missing-context and cross-tenant denial, direct alternate-write constraints, stale and concurrent revision conflicts, exact idempotent replay, changed-request rejection, effective-interval overlap rejection, transaction rollback across state/audit/outbox/idempotency, revision-specific and current reads, downstream reconciliation, retention/legal-hold behaviour, erasure receipt behaviour, and backup/restore of the correction chain.

Planned tests and this documentation do not satisfy the binding conditions or authorize a production domain implementation.

## Fallback and exit cost

If two implementations do not share enough stable structure, retain only the vocabulary and action obligations and keep persistence domain-specific. If a bounded domain later proves that event sourcing materially reduces correction or reconstruction risk, adopt it behind that domain's named interfaces through a superseding ADR; do not make it the platform default.

Before production data exists, exit cost is documentation and prototypes. After adoption, changing revision identity or interval semantics requires expand-and-contract migration, dual-read compatibility, backfill, constraint validation, consumer reconciliation, retained-history verification, and an accountable contract step. Stable aggregate and revision identifiers keep that migration bounded.

## Review triggers

- Two domains require materially different meanings for the same proposed shared primitive.
- A domain needs correction branching, merge, temporal joins, or recorded-time queries beyond the bounded contract.
- Retention, legal hold, safeguarding, finance, or privacy requirements conflict with the proposed immutability boundary.
- History volume, interval queries, indexes, partitioning, or correction bursts miss accepted targets.
- A proposal introduces generic CRUD correction, mutable published revisions, audit-log reconstruction, live consumer reinterpretation, universal event sourcing, or a framework history dependency.
- The first representative migration cannot preserve or honestly bound source provenance.

## Related records

- [Temporal records, correction, and evidence contract](../architecture/temporal-records-correction-and-evidence.md)
- [Temporal records decision review](../architecture/temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](../architecture/temporal-records-synthetic-scenario-review.md)
- [T1-C fact-and-reconciliation evidence](../phase-1/evidence/temporal-qualification-fact-and-reconciliation.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md)
- [Production-core migration discipline](../development/migrations.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
