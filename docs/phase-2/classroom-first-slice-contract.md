# First classroom slice: calendar publication and daily attendance

- Status: Implementation brief under the authorized six-week plan; domain details proposed
- Prepared on: 2026-10-03
- Owner: Product and platform engineering
- Review trigger: domain ADR disposition, representative findings, implementation entry, or a changed release gate
- Governing plan: [Classroom-first six-week delivery](../plans/classroom-first-six-week-plan.md)
- Evidence status: Scenarios and checks below are planned, not executed or representative-reviewed

## First demonstrable slice

An authorized staff member signs in, opens the exact educational context, defines a small academic
year and its terms, previews instructional dates, and publishes. The screen then displays the
committed calendar and publication revision. The educator's later attendance workflow consumes
that exact calendar through named reads.

Before connected execution, satisfy the plan's institutional, operator, calendar, identity, and
experience gates. While those are open, eligible private synthetic foundation work can proceed
within its existing authorization. Do not introduce an active/public institution alias to bypass
the draft-only boundary in ADR 0034.

## Proposed calendar contract to settle in ADR 0021

Use an explicit tenant-qualified calendar identity owned by one exact `institutional_unit_id`.
An academic year and its periods belong to that calendar. The class chooses an explicit calendar
and published year/revision; an institution selector or parent relationship never selects it by
implication. Two calendars may cover the same dates; overlapping published years conflict within
one calendar, not across the whole tenant or institution. The first UI exercises one calendar;
it must not introduce tenant-wide uniqueness that prevents later calendars.

The initial definition contains year dates, named terms, an explicit IANA time zone, instructional
weekdays, and dated closures. Preserve the existing period-containment and gap semantics: a date
outside all terms is non-instructional. Resolve a supplied local date against the exact calendar
and publication revision, returning an explicit result or a typed failure. Do not use a mutable
current-year flag, an ancestor fallback, or an arbitrary latest row.

Published meaning is immutable. Subsequent calendar amendments need an explicit successor and
impact contract before implementation; this first slice rejects direct edits to published state.
Attendance pins the revision it used. Template adoption, multiple programme scopes, additional
instructional-day exceptions, and calendar correction UI are deferred beyond the initial calendar
slice, not silently removed from the wider Proposed ADR's future concerns.

This paragraph is a concrete candidate for the ADR revision, not acceptance of that ADR. The
revision must reconcile its decision, resolver, constraints, scenarios, and migration language
before persistence begins.

## Named action and screen sequence

Names below express intent; final code-owned names and capability keys belong in the domain ADR.

| Intent | Required behavior |
| --- | --- |
| Register draft educational institution | Stable tenant-qualified identity and synthetic unpublished profile under ADR 0034; no inferred operator or permission |
| Define draft academic year | Bind exact calendar/institution, dates, time zone, actor and tenant; return stable identity and optimistic version |
| Define terms and instructional pattern | Validate containment, ordering and overlaps; no writes to generated calendar days |
| Record a dated closure | Validate local date and uniqueness; changes remain within the draft |
| Preview publication | Explain invalid dates/conflicts without mutation; show term boundaries, closures and resulting instructional dates |
| Publish academic year | Revalidate current permission, module state, institutional eligibility, all calendar invariants and expected version on the writer; atomically commit state and evidence |
| Read published calendar | Return a minimal allowed view with exact revision from the authoritative writer for immediate confirmation |

The browser uses the accepted same-origin session and named-action boundary. It supplies domain
inputs and expected versions, never trusted actor/tenant/placement/capability claims. A preview
does not authorize a later write. No generic CRUD or runtime action invocation endpoint is added.

## Follow-on roster and attendance semantics

People, accounts, staff affiliations, teaching assignments, enrolments, and class placements have
separate identities and lifecycles. A role label is neither proof of teaching assignment nor a
substitute for a capability. For the initial daily register, institution/year enrolment and class
placement are sufficient; do not fabricate course registrations to satisfy a future course model.

Build the expected roster from placements effective on the selected class-local date. Submission
pins the roster basis and calendar revision. Revalidate the basis at commit; if preparation has
become stale, return a conflict and require an explicit refreshed review. Do not silently add or
drop learners from the educator's submission.

Use one daily register per class and local date. Initial mark vocabulary is proposed as present,
absent, and late, with unmarked as unfinished working state. Reject incomplete submissions rather
than assuming unmarked students are present or absent. Absence reasons, health details, and free
text are excluded from this first contract. Representative review must settle the vocabulary,
permitted backdating window, who may correct a past date after an assignment ends, and the minimum
correction reason before attendance persistence. Historical responsibility never grants current
access on its own.

Correction preserves the prior submission, original actor, effective date, calendar and roster
basis, and correction attribution. Ending an enrolment or teaching assignment preserves the
historical records. A later student move is not a deletion or reinterpretation of past attendance.

## Synthetic acceptance scenarios

Use two synthetic tenants, two classes in the primary tenant, two separately authorized staff
actors, and fictional student records. Never substitute actual people for fixtures.

| ID | Scenario | Expected evidence |
| --- | --- | --- |
| CF-S01 | Publish valid year with two terms and one closure | Stable year/period IDs; correct boundary, gap and closure resolution; refreshed UI matches committed revision |
| CF-S02 | Missing actor/tenant, wrong tenant, forged route, insufficient capability, or inactive module | Named read/write refuses without disclosing another tenant's existence or records |
| CF-S03 | Select an ancestor or another class without explicit permission | Hierarchy and navigation grant no calendar or roster authority |
| CF-S04 | Invalid term range, overlapping terms, duplicate closure, stale expected revision | Stable validation/conflict response; no partial publication or outbox fact |
| CF-S05 | Identical retry, altered request with reused key, simultaneous publication | Exact authorized retry returns original result; changed request conflicts; at most one accepted transition |
| CF-S06 | Inject failure after audit/outbox insert but before transaction commit | State, audit, idempotency result and event all roll back |
| CF-S07 | Interrupt consumer, restart, and replay the event | No pre-commit consumption; one durable idempotent effect; safe tenant-qualified receipt and recovery |
| CF-S08 | Expired/revoked session, removed membership, forged cookie, missing origin/CSRF | Rejected at the proper boundary; UI explains recovery without leaking credentials or restricted data |
| CF-S09 | Placement begins/ends at a date boundary; another student joins after roster preparation | Expected roster follows effective dates; changed preparation basis requires explicit conflict resolution |
| CF-S10 | Assigned educator submits complete daily attendance | One register for class/date, pinned basis, minimized audit/event, refreshed committed marks |
| CF-S11 | Unassigned educator, ended assignment, duplicate student, incomplete marks, or concurrent correction | Denied or explicit conflict; no silent overwrite, inferred mark, or expanded roster visibility |
| CF-S12 | Correct attendance; subsequently change placement/calendar | Original attribution and pinned historical meaning remain inspectable under explicit authority |
| CF-S13 | Administrator prepares class; educator completes attendance by keyboard and narrow screen | Routine preparation needs no developer; validation, denial, conflict and success are accessible; actual user observations recorded |

CF-S01–S08 qualify the first calendar slice where applicable. CF-S09–S13 qualify the roster and
attendance follow-ons. Apply the existing sensitive-collection boundary to every new roster read:
bounded class scope, minimal fields, explicit traversal limits and negative enumeration tests;
the first slice includes no general student directory or export.

These checks exercise TM-01, TM-02, TM-09 through TM-15, TM-17 and TM-19 from the
[threat model](../security/threat-model.md). Existing infrastructure evidence is reusable context,
not proof that a new domain action passes them.

## Evidence required at implementation exit

Record the exact candidate, migration review, positive and negative action checks, generated API
contract checks, browser scenarios, transaction/recovery outcomes, and `make check` result.
Inspect tenant keys, compound foreign keys, uniqueness, indexes, migration locking and rollback
behavior. Separate actual domain/representative decisions from engineering results and list any
unresolved gate. No scenario in this brief is marked passed by the existence of the document.
