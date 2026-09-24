# Academic calendar synthetic scenario review

- Status: Completed design evidence; not stakeholder acceptance
- Date: 2026-09-24
- Owner: Product and platform engineering
- Governing record: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Scope: paper walkthrough over synthetic data; no production resource, migration, interface, or school policy

## Purpose

This review tests the proposed academic-calendar authority against two materially different calendar shapes before any implementation. It asks whether one school-scoped `AcademicYear` aggregate, primary `AcademicPeriod` sequence, week pattern, dated exceptions, deterministic resolver, and explicit template adoption can express both shapes without adding a second authority or a generic rules engine.

The examples are synthetic design fixtures. They are not claims about a particular school's policy and do not substitute for review by a school-domain representative.

## Method and source evidence

The walkthrough applies the proposed rules manually to fixed dates and compares the result with the supplied Frappe source model:

- Academic Year and Term date containment;
- School Calendar holiday rows and weekly-off generation;
- School Calendar Term's copied dates and stored instructional-day total;
- exact-school, ancestor-school, and global term candidate selection;
- School Calendar cloning across schools; and
- generated year and term boundary events.

The Frappe implementation is reference evidence, not an instruction to preserve its callbacks, duplicate child data, fixed roles, or hierarchy fallback.

## Evaluation rules

The review uses this deterministic order for a school-local date:

1. Resolve exactly one published year for the authenticated tenant and explicit school scope.
2. Resolve at most one primary period containing the date.
3. If no period contains the date, derive a non-instructional base status with reason `outside_period`; otherwise derive the base status from the year's instructional weekdays.
4. Apply at most one effective dated exception. A closure may override the reason outside a period so a named break remains visible. An opening is valid only inside a period.
5. Reject an opening outside every period and any conflicting effects on the same date.
6. Return stable year and period identifiers, publication revision, instructional status, and a typed reason.

Instructional-day totals are calculated from the same rules. They are not independently editable state.

## Scenario A: three-period, five-day school year

This fixture exercises an academic year spanning two calendar years, a Monday-to-Friday week, period gaps, closure ranges, a single-day closure, and an additional Saturday.

| Property | Synthetic value |
| --- | --- |
| School scope | `north-campus` |
| Time zone | `Europe/Brussels` |
| Academic year | 2026-08-24 through 2027-07-02 |
| Primary periods | Autumn: 2026-08-24 through 2026-12-18; Winter: 2027-01-04 through 2027-04-02; Spring: 2027-04-19 through 2027-07-02 |
| Ordinary instructional weekdays | Monday through Friday |
| Closed exceptions inside periods | 2026-10-26 through 2026-10-30; 2026-11-11; 2027-02-15 through 2027-02-19; 2027-05-13 through 2027-05-14 |
| Named-break annotations outside periods | Winter break: 2026-12-21 through 2027-01-01; Spring break: 2027-04-05 through 2027-04-16 |
| Open exception | Saturday 2027-03-13 |

The three periods contain 281 dates. The ordinary week pattern produces 205 candidate instructional dates. Thirteen ordinarily instructional dates are closed and one Saturday is opened, producing a derived total of 193 instructional dates: 79 in Autumn, 61 in Winter, and 53 in Spring. The 24 named-break annotations outside periods improve explanation but do not change that total.

### Resolver walkthrough

| School-local date | Expected result |
| --- | --- |
| 2026-08-24 | Published year, Autumn period, instructional, `week_pattern` |
| 2026-10-27 | Published year, Autumn period, non-instructional, referenced closure exception |
| 2026-12-19 | Published year, no period, non-instructional, `outside_period` |
| 2026-12-28 | Published year, no period, non-instructional, referenced Winter break exception |
| 2027-03-13 | Published year, Winter period, instructional, referenced open exception |
| 2027-07-03 | `not_found`; the date is outside the published year |

### Template walkthrough

An exact target-year template revision can be applied to an unpublished sibling-school draft. The draft may add a local closure before publication while retaining the applied template revision as provenance. Publishing a later template revision produces a comparison only; it cannot mutate either published school year.

This validates explicit adoption for same-year multi-school setup. It does not justify relative-date expressions or automatic year-to-year shifting.

## Scenario B: four-period, six-day school year

This fixture exercises a January-to-December operating pattern, four periods, a Monday-to-Saturday week, a Sunday opened for instruction, and a post-publication correction question.

| Property | Synthetic value |
| --- | --- |
| School scope | `southern-campus` |
| Time zone | `Africa/Blantyre` |
| Academic year | 2027-01-11 through 2027-12-03 |
| Primary periods | Period 1: 2027-01-11 through 2027-04-02; Period 2: 2027-04-19 through 2027-07-09; Period 3: 2027-07-26 through 2027-10-08; Period 4: 2027-10-25 through 2027-12-03 |
| Ordinary instructional weekdays | Monday through Saturday |
| Closed exceptions | 2027-03-03; 2027-05-14; 2027-08-16 through 2027-08-21; 2027-11-15 |
| Open exception | Sunday 2027-06-13 |

The four periods contain 279 dates. The ordinary week pattern produces 242 candidate instructional dates. Nine ordinarily instructional dates are closed and one Sunday is opened, producing a derived total of 234 instructional dates: 70, 71, 59, and 34 by period.

### Resolver walkthrough

| School-local date | Expected result |
| --- | --- |
| 2027-01-11 | Published year, Period 1, instructional, `week_pattern` |
| 2027-04-12 | Published year, no period, non-instructional, `outside_period` |
| 2027-06-13 | Published year, Period 2, instructional, referenced open exception |
| 2027-08-18 | Published year, Period 3, non-instructional, referenced closure exception |
| 2027-12-04 | `not_found`; the date is outside the published year |

### Correction challenge

If an emergency closure is declared after publication, callers need a new attributable calendar meaning without silently rewriting the snapshot already used by durable records. The [temporal-records synthetic scenario review](temporal-records-synthetic-scenario-review.md) applies ADR 0018's revisioned-durable-state class: the correction creates an immutable successor publication revision, current resolution uses that successor, and durable consumers retain the revision they relied on until they reconcile deliberately. This settles the paper representation but does not satisfy ADR 0018's binding executable conditions or authorize calendar publication.

## Cross-scenario findings

| Question | Result | Consequence |
| --- | --- | --- |
| Can one school-scoped year authority represent both patterns? | Yes, for these fixtures | Retain one aggregate and one primary sequence |
| Can periods be ordered, contained, non-overlapping, and still allow breaks? | Yes | Gaps are non-instructional by default; closure exceptions may annotate named breaks without opening the gap |
| Does one `weekly_off` value suffice? | No | Store the explicit set of instructional weekdays |
| Are date ranges needed as authoritative exception rows? | No | Accept a range as action input, then expand it atomically to canonical per-date exceptions |
| Should School Calendar Term's instructional total be migrated as truth? | No | Recalculate it and reconcile the source value as migration evidence |
| Is year/period identity enough for the resolver? | No | Include instructional status, typed reason, and publication revision |
| Should callers provide a time zone? | No | Convert instants server-side with the stored IANA zone; explicit dates are school-local dates |
| Do templates need relative expressions in v1? | No evidence | Use concrete target-year values and defer relative rules |
| Can template changes update published years? | No | Compare only; explicit adoption is limited to drafts |
| Is the published-correction paper model settled? | Yes, as an immutable successor publication revision | [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md) is Conditionally Accepted; its neutral and calendar-domain executable conditions remain prerequisites |
| Are simultaneous programme calendars within one school scope validated? | No | Keep them outside v1 and retain the ADR review trigger |

## Adopted refinements

The review supports five bounded refinements to the proposal:

1. The resolver's result includes `instructional` or `non_instructional` plus a typed reason, not only year and period identifiers.
2. Period membership establishes the base status; a year date outside every period is non-instructional, although a closure exception may replace `outside_period` with a named-break reason. An opening outside every period is invalid.
3. The canonical exception grain is one school-local date. Range actions expand atomically and reject conflicting effects on the same date.
4. Instructional-day counts are derived and may be materialized only as rebuildable projections.
5. Initial template revisions contain concrete target-year dates. Relative-date rules and automatic year shifting remain deferred.

These refinements remove ambiguity without adding a second model, runtime expression language, or new service.

## Evidence still required

This review does not satisfy the complete acceptance package. The following remain open:

- review and sign-off by a school-domain representative using representative operating calendars;
- satisfaction of the relevant binding conditions and calendar-domain executable proof of [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md);
- representative Frappe migration fixtures and reconciliation, including stored instructional totals;
- tenant, school-scope, authorization, concurrency, idempotency, outbox, and recovery tests;
- evidence for or against simultaneous programme calendars; and
- browser and phone workflow research and prototypes.

## Conclusion

Both synthetic patterns fit the proposed single-authority model after the five refinements above. No scenario requires a separate School Calendar authority, live hierarchy inheritance, editable day rows, or relative template language. The temporal review now supplies a paper correction path, but accountable review and executable proof remain material blockers, so ADR 0021 stays Proposed and no implementation is authorized.

## Related records

- [Academic calendar authority](academic-calendar-authority.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)
- [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- [Domain model authoring and metadata](domain-model-authoring-and-metadata.md)
- [Threat model](../security/threat-model.md)
