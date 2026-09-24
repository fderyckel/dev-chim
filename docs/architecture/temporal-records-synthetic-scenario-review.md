# Temporal records synthetic scenario review

- Status: Completed design evidence; not accountable acceptance or executable proof
- Date: 2026-09-24
- Owner: Platform engineering with domain records and security/privacy owners
- Governing record: [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- Scope: paper walkthrough over synthetic data; no production resource, migration, interface, retention policy, or school business module

## Purpose

This review pressure-tests the proposed temporal-record contract against the three walkthroughs required by ADR 0018: a correction to a published calendar after another record has relied on it, an append-only reversal and replacement, and a prospective configuration change followed by a retroactive correction.

The fixtures are deliberately synthetic. They test whether the contract separates domain history, effective time, security audit, outbox facts, projections, and retention without requiring a universal event store or bitemporal engine. They do not establish school, accounting, safeguarding, privacy, or retention policy.

## Method

Each walkthrough fixes the tenant, scope, identities, recorded times, effective times, action input, downstream consumer mode, and expected reads. It then challenges:

- exact replay and changed-request reuse of an idempotency key;
- stale and concurrent correction attempts;
- cross-tenant and missing-context access;
- the boundary between immutable domain history, audit, outbox, and projections;
- prospective change versus correction of an earlier meaning;
- current, exact-revision, effective-date, and recorded-time reads; and
- whether durable downstream state is pinned or deliberately reconciled.

Times are illustrative UTC values assigned by the authoritative writer. Dates are interpreted in the stored school time zone. Identifiers are descriptive fixture labels, not proposed public identifier formats.

## Scenario 1: published calendar correction after reliance

This scenario extends the southern-campus fixture in the [academic-calendar review](academic-calendar-synthetic-scenario-review.md). It uses a revisioned durable aggregate because publication gives the calendar a meaning that other records may rely on.

### Fixed fixture

| Property | Synthetic value |
| --- | --- |
| Tenant | `tenant-a` |
| School scope | `southern-campus` |
| Time zone | `Africa/Blantyre` |
| Aggregate | `calendar-2027` |
| Published revision 1 | `calendar-r1`, aggregate revision 1, recorded 2027-01-05T09:00:00Z |
| Affected school-local date | 2027-08-18 |
| Durable dependent record | `attendance-plan-44`, recorded 2027-07-01, pins `calendar-r1` |
| Correction action | `record_emergency_closure` targeting `calendar-r1` with expected aggregate revision 1 |
| Correction reason | `emergency_closure` |
| Idempotency key | `calendar-closure-2027-08-18-v1` |

At 2027-08-20T08:00:00Z, an authorized actor records that the school was closed on 2027-08-18. The action creates `calendar-r2`, aggregate revision 2, with effective school-local date 2027-08-18, one immutable correction-operation identity, a predecessor link to `calendar-r1`, minimal audit evidence, and one minimal outbox fact. It does not update the business payload or provenance of `calendar-r1`.

### Expected reads and consumers

| Question | Expected result |
| --- | --- |
| `get_revision(calendar-r1)` for 2027-08-18 | Instructional under the meaning recorded in revision 1 |
| `get_revision(calendar-r2)` for 2027-08-18 | Non-instructional with reason `emergency_closure` |
| `get_current(calendar-2027)` | `calendar-r2` |
| Current resolver for 2027-08-18 | Non-instructional under `calendar-r2` |
| `attendance-plan-44` historical basis | Remains `calendar-r1`; it is not silently reinterpreted |
| Rebuildable calendar feed | Follows current meaning and rebuilds from `calendar-r2` |
| Attendance reconciliation | Runs only through its own authorized, idempotent action if its owner decides the correction affects durable attendance state |

An optional `get_as_known` implementation could show what the platform knew on 2027-08-18 before the correction was recorded. Without that declared query mode, the calendar must reject the query; `updated_at` is not an approximation. The pinned dependent record remains explainable without requiring full recorded-time querying.

### Challenges

- Exact replay with the same key and canonical request returns the same correction-operation and `calendar-r2` result.
- Reusing the key with a different date, reason, or target revision is an idempotency conflict.
- A second correction against expected revision 1 is a stale revision conflict after revision 2 commits.
- Missing context, another tenant, another school scope, or an actor lacking the correction capability fails before history is disclosed or changed.
- Replaying the outbox fact cannot grant attendance authority or mutate `attendance-plan-44`.

### Result

The aggregate remains one calendar authority. The paper model selects an immutable successor publication revision rather than an in-place edit or a second effective-day authority. A durable consumer must pin the revision it relied on or reconcile deliberately; only a disposable or explicitly recomputable view may follow current meaning without storing that historical basis.

## Scenario 2: append-only reversal and replacement

This fixture represents a generic posted school account fact. It is not an accounting-policy decision or authorization for a finance module. The original occurrence must remain visible, so the scenario uses append-only facts rather than revisioned replacement.

### Fixed fixture

| Property | Synthetic value |
| --- | --- |
| Tenant | `tenant-a` |
| Account scope | `account-17` |
| Original fact | `charge-f1`, +250,000 minor units, effective 2027-02-01, recorded 2027-02-03T10:00:00Z |
| Correction action | `reverse_and_replace_charge` targeting `charge-f1` |
| Correction reason | `amount_entered_incorrectly` |
| Idempotency key | `charge-f1-correction-v1` |
| Correction operation | `charge-correction-1` |

At 2027-02-10T11:00:00Z, the action atomically creates:

1. `charge-f2`, a -250,000 reversal linked to `charge-f1`; and
2. `charge-f3`, a +200,000 replacement linked to `charge-correction-1` and the corrected business subject.

All three facts remain immutable within the declared retention contract. Their net is +200,000 minor units. The balance is a rebuildable projection, not a fourth authoritative fact and not a mutable value written back onto `charge-f1`.

### Expected reads and consumers

| Question | Expected result |
| --- | --- |
| Exact fact read for `charge-f1` | Original +250,000 fact and its safe correction relationship |
| Correction-operation read | Exact committed result containing `charge-f2` and `charge-f3` |
| Account fact history | `charge-f1`, `charge-f2`, and `charge-f3` in domain order |
| Rebuilt balance contribution | +200,000 minor units |
| Security audit | Actor, tenant, purpose, action, outcome, and safe identifiers; no duplicate financial payload |
| Outbox | Minimal correction fact sufficient to trigger authorized projection rebuild or reconciliation |

### Challenges

- Exact replay returns the same two created fact identities as one committed correction result.
- Changed amount, target, or reason with the same key conflicts.
- A second full reversal of `charge-f1` conflicts under the domain's single-full-reversal invariant; a later adjustment must use its own named action and explicit relationship.
- A transaction failure after either new fact, audit evidence, outbox fact, or idempotency result rolls back the entire correction operation.
- Deleting `charge-f1` or reconstructing it from the audit/outbox is invalid. Lawful erasure or redaction, if applicable, requires a separate policy and action not established by this fixture.

### Result

The shared contract fits append-only correction, but a row identity alone is insufficient: one logical correction may create several facts. The domain therefore needs one immutable correction-operation identity and an exact action result in addition to individual fact identities and relationship links.

## Scenario 3: prospective and retroactive effective-dated configuration

This fixture uses a synthetic school-scoped operational threshold. The threshold has no production meaning; it exists only to test effective intervals and recorded-time interpretation.

### Fixed fixture

| Property | Synthetic value |
| --- | --- |
| Tenant | `tenant-a` |
| School scope | `north-campus` |
| Time zone | `Europe/Brussels` |
| Aggregate | `operating-threshold-1` |
| Time precision | School-local Date |
| Revision 1 recorded | 2027-01-10T09:00:00Z |
| Revision 2 recorded | 2027-03-01T09:00:00Z |
| Revision 3 recorded | 2027-05-10T09:00:00Z |

Revision 1 publishes value 5 for `[2027-01-01, infinity)`. Revision 2 is a planned prospective change, not an error correction: it publishes value 5 for `[2027-01-01, 2027-04-01)` and value 7 for `[2027-04-01, infinity)`. Revision 3 corrects the effective timeline after evidence shows value 6 should have applied from 2027-02-15: it publishes value 5 for `[2027-01-01, 2027-02-15)`, value 6 for `[2027-02-15, 2027-04-01)`, and value 7 for `[2027-04-01, infinity)`.

Each aggregate revision is immutable. Creating revision 2 does not truncate revision 1 in place, and revision 3 does not rewrite either earlier timeline. A physical implementation may store an immutable snapshot or an atomically created set of segments; the contract does not require one storage shape.

### Expected queries

| Query | Expected result |
| --- | --- |
| Current effective value on 2027-01-20 | 5 from revision 3 |
| Current effective value on 2027-03-15 | 6 from revision 3 |
| Current effective value on 2027-04-15 | 7 from revision 3 |
| Exact revision 1 on 2027-03-15 | 5 |
| Exact revision 2 on 2027-03-15 | 5 |
| Exact revision 3 on 2027-03-15 | 6 |
| As known on 2027-03-20 for effective date 2027-03-15 | 5 from revision 2, only if `get_as_known` is explicitly supported |
| As known on 2027-05-20 for effective date 2027-03-15 | 6 from revision 3, only if `get_as_known` is explicitly supported |

Non-overlap applies inside each selected aggregate revision. Applying one global exclusion constraint across all historical segments would incorrectly reject the intentionally overlapping effective dates in revisions 1, 2, and 3. The database design must scope interval uniqueness to the selected revision or use an equivalent constraint-safe representation.

### Challenges

- The prospective action uses a planned-change reason and predecessor relationship; it is not mislabeled as an error correction.
- The retroactive action targets revision 2 and requires expected aggregate revision 2. Two concurrent corrections cannot both publish revision 3.
- A gap or overlap inside the candidate timeline fails before publication.
- A durable decision made on 2027-03-20 either pins revision 2 or belongs to a domain that implements recorded-time reads. A later current-effective query cannot reconstruct its historical basis safely.
- Cross-tenant or caller-selected time zone, recorded time, repository, or placement input is rejected.

### Result

The contract supports effective-dated state without a universal bitemporal engine. It must, however, state that current/effective interval constraints are revision-scoped, distinguish planned successors from corrections, and require pinning or explicit recorded-time support wherever a durable decision must be reproduced.

## Cross-scenario findings

| Question | Result | Consequence |
| --- | --- | --- |
| Do all changes fit generic mutable CRUD plus an audit log? | No | Retain explicit mutable, revisioned, and append-only classes |
| Is one immutable row created by every correction? | No | Add one correction-operation identity and exact multi-record result |
| Can one global effective-interval exclusion cover current and historical revisions? | No | Enforce non-overlap within the selected aggregate revision or equivalent representation |
| Is every successor an error correction? | No | Distinguish planned supersession from correction and reversal |
| May a durable decision simply follow current meaning? | No | Pin its revision or reconcile through its owning action |
| Must every domain implement full bitemporal reads? | No | Require `get_as_known` only when the domain promises it; otherwise pin revisions and reject unsupported queries |
| Can audit or outbox reconstruct domain state? | No | Keep domain history authoritative and the other evidence layers minimal |
| Is one universal revision table justified? | No evidence | Keep physical persistence and policy with the owning domain |

## Adopted refinements

The review supports five bounded refinements to ADR 0018 and its architecture contract:

1. A correction that creates multiple revisions or facts has one immutable correction-operation identity and one exact committed action result, separate from the caller's idempotency key and the created row identities.
2. Effective-interval uniqueness is evaluated inside the selected aggregate revision or an equivalent current timeline; superseded historical revisions may cover the same effective dates.
3. Planned prospective supersession, correction of erroneous meaning, and reversal of an append-only fact use distinct named actions, relationships, and reason vocabularies.
4. A durable downstream decision pins the exact revision it used or reconciles deliberately. Follow-current mode is limited to disposable, recomputable, or explicitly non-historical views.
5. A domain permitting retroactive corrections must either support and test recorded-time queries where reproduction requires them or require consumers to pin the exact revision. It cannot infer prior knowledge from modification timestamps.

These refinements clarify the shared contract without choosing a universal table, framework extension, workflow engine, or event-sourced architecture.

## Evidence not established

The walkthrough completes the three paper scenarios required by ADR 0018, but it does not provide:

- independent security/privacy, school-records, finance, legal, or other first-domain review;
- a real domain's correction reason vocabulary, retention period, legal-hold rule, or erasure disposition;
- executable authorization, tenant-isolation, concurrency, idempotency, interval, transaction, outbox, recovery, or migration evidence;
- volume, query-plan, partitioning, backup, restore, or retention-cost measurements;
- browser or phone correction, conflict, history, reconciliation, or redaction workflows; or
- evidence that two implemented domains share enough structure for a common persistence library.

## Conclusion

All three synthetic scenarios fit the bounded classification and named-action approach after the five refinements above. They do not justify generic CRUD history, a universal bitemporal engine, one shared revision table, or event sourcing. The paper evidence gate is complete, and the subsequent [decision review](temporal-records-decision-review.md) conditionally accepts ADR 0018 with TR-01 through TR-08 binding. The neutral T1 executable proof remains open, ADR 0021 stays Proposed, and no production-domain implementation is authorized.

## Related records

- [Temporal records, correction, and evidence contract](temporal-records-correction-and-evidence.md)
- [Temporal records decision review](temporal-records-decision-review.md)
- [Academic calendar synthetic scenario review](academic-calendar-synthetic-scenario-review.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md)
- [Production-core migration discipline](../development/migrations.md)
- [Data classification](../security/data-classification.md)
- [Threat model](../security/threat-model.md)
