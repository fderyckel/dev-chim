# ADR 0037: Class register, enrolment and dated placement

- Status: Proposed
- Date: 2026-10-04
- Accountable owner: Product and platform engineering
- Deciders: François — Project Owner, with educational records and security/privacy review
- Implementation authority: The Project Owner's “go ahead” authorizes this bounded private synthetic CF-4B increment following CF-4A; broader domain acceptance and connected use remain separate
- Supersedes: None

## Context

The classroom-first plan needs a daily class register before attendance. People participation,
account association and current permissions already have independent boundaries. The calendar writer is being delivered concurrently. This increment consumes an exact published
year and its candidate revision. Its integration tests use that named writer with synthetic
records; they do not qualify a connected browser journey.

## Decision drivers

Keep enrolment separate from class placement, preserve dated history, and avoid building course,
timetable or HR abstractions before a classroom workflow works.

## Considered options

1. Put a mutable class ID on a student: loses movement history and conflates enrolment.
2. Build a general course registration engine: exceeds the daily-register requirement.
3. Separate class, year enrolment, teaching assignment and placement: selected.

## Decision

Add private `classroom.core` v1.0.0, dependent on `people.core` and `academics.calendar` v1.0.0.
A class belongs to one exact published institution, calendar, year and immutable revision. Its
code is unique within that year; its label is a minimal administrative name. No current-year,
ancestor, operator, programme or account inference selects these references.

An enrolment references a student participation and exact published year. The participation's
institution must own that calendar. There is initially one enrolment per participation/year.
A teaching assignment references a staff participation and class; it does not require an account
and grants no capability. A class placement references an enrolment and class in the same year
and institution. Non-overlapping placements allow movement between classes. Two placements for
one enrolment may never overlap; concurrent teaching by different staff is allowed, while
repeated overlapping assignments of the same staff participation to the same class are refused.

All dated records have finite half-open intervals `[effective_from, effective_until)` contained
within the year (whose inclusive end becomes the next exclusive day) and their participation or
enrolment interval. Dates use the pinned year's time zone. Initial past starts are present-day
baseline observations, not invented recorded-time history. Named ending actions may shorten an
interval once, with an expected version, today or later, but cannot extend or retroactively
rewrite it. End child placements before shortening an enrolment. End assignments/enrolments
before shortening participation; the database rejects truncating an existing dependent interval.
Enrolment re-entry, retrospective correction, class renaming/retirement and calendar amendments
need later named contracts. No delete action exists.

Named mutations are `create_class`, `enrol_student`, `assign_teacher`, `place_student`,
`end_enrolment`, `end_teaching_assignment` and `end_placement`. Each has an independent capability
under `classroom.core`; exact administrative reads use `classes.read`, `enrolments.read`,
`assignments.read` and `placements.read`. These tenant-wide administrative capabilities are
explicit grants, never derived from teaching, people or hierarchy. No roster/list/search/count,
public route, UI write, attendance, course registration, student login or real data is exposed.
The later bounded educator roster must independently enforce current account association,
capability, teaching responsibility, local date, cumulative exposure and the exact calendar.

Each mutation rechecks module/dependency/capability gates on the writer, binds idempotency to
actor and exact normalized input, and commits state, minimal audit, Restricted outbox and result
atomically. Exact retry rechecks current authority and returns the original receipt. Classroom
events contain only aggregate ID/version; the existing Internal-only dispatcher remains unable
to consume them. No automatic classroom consumer is added.

Database guards enforce immutable identity, published calendar binding, interval containment,
overlap exclusion and one-way ending. Parent row locks serialize competing placements and
shortening. This private writer requires PostgreSQL READ COMMITTED; database guards reject
other transaction isolation modes so a pre-existing snapshot cannot miss a committed child. Tenant-qualified foreign keys and checks remain independent of interface hiding.
The named actions are the authorization boundary; database guards do not grant direct SQL access.

## Plain-English summary

### What this means

A student can be enrolled for a year and move classes without erasing earlier placement. A
teacher can be assigned to that class without receiving extra permissions.

### What was agreed

Only this private synthetic implementation is authorized. The calendar publication writer,
classroom preparation screen and actual educator workflow still require their own evidence.

### Context

A school needs to know both which year a student attends and which class they attended on a date.

### Examples

A placement ending on 12 October excludes that day; a replacement placement may begin that day.
A draft year, different institution or overlapping second placement is refused.

## Consequences

### Positive

Stable class, enrolment and placement identities support a later date-specific register without
adding enterprise hierarchy. Teaching and permissions remain independent.

### Negative

This increment is not yet usable from the browser. Historical corrections and re-entry are
limited deliberately; no generic update bypass exists.

## Security, privacy, operability, and migration effects

All records/evidence are Restricted and synthetic. Four additive tables use compound tenant
references. No backfill, service, partitioning or production deployment is introduced. Retained
rows or classroom audit/outbox/idempotency facts prevent rollback; empty migrations can reverse.
Parent guards add a restriction to participation ending: dependent classroom intervals must be
shortened first. Before real data, owners must settle retention, erasure, representative terminology,
correction authority and independent privacy review. Relevant threats are TM-01, TM-02, TM-09
through TM-15, TM-17 and TM-18.

## Validation evidence

Verify all named actions, exact reads, independent permission failures, missing/stale context,
cross-tenant and cross-institution references, draft/wrong revision, invalid dates, one-way ending,
concurrent overlap/retry, atomic failure after outbox, direct-write guards and retained rollback.
Record actual results and `make check` disposition in the classroom foundation evidence. Integration tests exercise the named calendar publication writer; browser integration remains
separate.

## Fallback and exit cost

Keep the module private. Fail closed on a missing published year; never substitute a draft or
latest row. Retained records require forward repair, not destructive rollback.

## Review triggers

Calendar writer contract changes; first roster or connected UI; representative class/enrolment
terminology; historical correction; first real student data.

## Related records

- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [Classroom contract](../phase-2/classroom-first-slice-contract.md)
- [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md)
