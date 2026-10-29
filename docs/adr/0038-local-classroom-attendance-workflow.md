# ADR 0038: Local classroom attendance workflow

- Status: Proposed
- Date: 2026-10-05
- Accountable owner: Product and platform engineering
- Deciders: François — Project Owner, with educational records and security/privacy review
- Implementation authority: The Project Owner's “green light on next” authorizes this bounded local synthetic screen and attendance increment after CF-4B
- Supersedes: None

## Context

The calendar and classroom foundations are private persisted actions. The next increment must
make one school task visible: an assigned educator marks today's register and reloads the saved
result. A real institutional identity connection, representative attendance policy, connected
release review and real student data are not yet qualified.

## Decision drivers

Deliver one screen-to-PostgreSQL action, preserve current session and class authorization, and
avoid a general student directory or another framework.

## Considered options

1. Extend the read-only UI-1A bearer bridge to writes: rejected; it lacks the accepted session boundary.
2. Wait for every production qualification: unnecessarily prevents local synthetic engineering.
3. Exercise the accepted D.3 session adapter through an explicitly enabled loopback HTTPS proof,
   with a small Next.js screen and exact named attendance actions: selected.

## Decision

Introduce `classroom.attendance` v1.0.0 dependent on `classroom.core`. The first screen provides
assigned classes, today's exact roster, explicit Present/Absent/Late choices, Submit attendance,
and authoritative confirmation after refresh. No mark is assumed. Today is calculated on the
writer in the pinned academic year's time zone. Non-instructional days, another date and empty
registers cannot be submitted. Correction and backdating require representative policy and a
later named increment; this first submission is immutable.

The local proof uses synthetic identity evidence with the existing encrypted Secure HttpOnly
host-only cookie, current application session, exact origin and session-bound CSRF. It retains
HTTPS even on loopback. Startup enables the classroom routes explicitly; default application
startup remains closed. No real provider is claimed. The proof login cannot select an arbitrary
actor or tenant. Next.js forwards only the named same-origin contract; it establishes no authority.

Domain reads and submission validate the current session again inside the writer transaction,
require the explicit attendance capability, an unrevoked staff-account association bound to the
same actor/membership, current staff participation, and a teaching assignment effective today.
Support elevation is refused. Affiliation or assignment does not grant a capability. A prior
screen or CSRF token never preserves authorization after revocation.

The only collection scopes are today's assigned classes (maximum 12) and one assigned class's
roster (maximum 60). There is no pagination, search, arbitrary date, sort, filter, directory or
export. A tenant/actor/UTC-day exposure record limits cumulative disclosure to 12 distinct classes
and 720 distinct people across repeated reads and changed assignments. It contains identifiers
only, is Restricted, and is access-control accounting rather than a business event. Clock-day
rollover supplies a new budget, not a retained-data erasure policy. Real-data retention and abuse
calibration remain review conditions.

Prepare attendance returns an exact calendar revision and hash of sorted current student,
enrolment, placement and person-version facts. Submission supplies that basis and one explicit
allowed mark for every person, with no duplicates, omissions or additions. The writer locks the
class and source rows, recomputes the basis and rejects stale preparation. One submission per
class/local date is allowed. Exact actor/request-bound retry returns its original receipt after
current authorization; a changed request or a second independent submission conflicts.

The immutable submission stores IDs, marks, pinned roster facts and calendar revision without
copying person names. Current names are display data, not historical name assertions. State,
minimal audit, Restricted outbox and idempotency result commit atomically. The UI confirms through
an authoritative read. The Internal-only dispatcher remains unable to deliver Restricted events;
consumer qualification and correction/recovery UI remain later work, not claimed by this proof.

This is an additive, disabled-by-default local engineering qualification under ADRs 0030 and 0037.
It does not supersede the accepted same-origin production architecture, reinterpret synthetic
proof as real authentication, or close C25-03-R/C25-05/C25-06. Production routes, deployment, real
records, actual provider secrets and routine whole-school preparation remain outside this increment.

## Plain-English summary

### What this means

A synthetic educator can open an assigned class, explicitly mark each student and see saved
attendance after reloading. An unassigned account cannot see that class's students.

### What was agreed

Build and verify the local workflow now. Actual institutional sign-in, user policy review and
production use stay separate.

### Context

Calendar, people and class records are now useful together in one visible classroom task.

### Examples

A new student joining after the register was opened causes a conflict and an explicit refresh.
A double click or a retry after a lost response cannot create a second register.

## Consequences

### Positive

Proves a named browser action through current sessions, classroom authorization and PostgreSQL.

### Negative

Today's submission cannot yet be corrected. The local proof uses a prepared synthetic class;
routine administrative preparation screens and real sign-in still need subsequent delivery.

## Security, privacy, operability, and migration effects

Apply TM-01, TM-02, TM-09 through TM-15, TM-18 and TM-19. Responses are no-store, errors are
non-disclosing, inputs are exact and bounded, and logs/events contain no names or marks. New
tables are additive and tenant-qualified; retained attendance, exposure or event evidence blocks
rollback. No production migration, new service or generic collection engine is introduced.

## Validation evidence

Prove browser submission/refresh, keyboard and narrow layout, missing session/origin/CSRF,
revocation, cross-tenant/class denial, cumulative scope bounds, non-instructional dates, incomplete
marks, stale roster, idempotent retry, concurrent submission, transaction rollback and retained
migration refusal. Run `make check` and report every failure and skipped stage separately. The
[implementation evidence](../phase-2/classroom-attendance-workflow-evidence.md) records the verified
local workflow and the separate dependency-audit blockers.

## Fallback and exit cost

Keep the routes disabled if qualification fails. Never fall back to a client-supplied actor,
a local bearer write bridge or an optimistic Saved label. Retained records require forward repair.

## Review triggers

Real identity connection, first correction/backdating, roster bounds, Restricted consumers,
representative terminology, administrative preparation and first deployment.

## Related records

- [Classroom-first contract](../phase-2/classroom-first-slice-contract.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0037](0037-class-register-enrolment-and-placement.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md)
