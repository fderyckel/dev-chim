# ADR 0040: Session-bound classroom preparation workspace

- Status: Proposed
- Date: 2026-10-06
- Accountable owner: Product and platform engineering
- Deciders: François — Project Owner, with educational records and security/privacy review
- Implementation authority: The Project Owner's “go ahead” authorizes this disabled local synthetic CF-4 preparation slice; real records, production identity and deployment remain separate
- Supersedes: None

## Context

The classroom-first plan has private named actions for people, class, enrolment, teaching assignment
and placement, plus a connected educator attendance screen. Routine preparation still requires a
developer to seed those records. Exposing generic people, calendar or class collections would solve
that usability gap by weakening the exact-scope and sensitive-enumeration boundaries.

The connected calendar preparation contract is being developed separately. This slice must consume
one already-published synthetic year without selecting a latest, active or client-supplied calendar.

## Decision drivers

- Let a school administrator prepare one usable fictional class without developer assistance.
- Reuse the existing named domain actions, authorization, idempotency, audit and outbox boundaries.
- Keep tenant, institution, calendar, year and educator scope server-owned and writer-validated.
- Avoid a people directory, class catalogue, calendar selector or generic CRUD surface.

## Considered options

1. Add generic administrative collections and forms: broadens sensitive enumeration and public API scope before one workflow is proven.
2. Keep preparation in a seed script: leaves the daily classroom workflow dependent on developers.
3. Bind one durable preparation workspace to the current actor, membership, institution, published year and educator participation: selected.

## Decision

Add one disabled-by-default, loopback-only, same-origin classroom preparation screen and named
adapter actions. A trusted local composition step creates one durable preparation workspace with
an exact tenant, actor, membership, published institution, active calendar, published academic
year, immutable calendar revision and current staff participation. The workspace identity is held
by server configuration and is never accepted from the browser.

The screen may create exactly one class and assign the workspace educator in one atomic operation.
It may then add at most 60 fictional students. Adding a student atomically calls the existing
`register_person`, `record_student_participation`, `enrol_student` and `place_student` actions.
Class creation atomically calls `create_class` and `assign_teacher`. Each underlying named action
retains its own capability, idempotency, audit and Restricted outbox evidence. The outer writer
transaction makes the multi-action user intent all-or-nothing.

Every request revalidates the application session in the writer transaction and locks the exact
workspace. The workspace must still match the actor and membership, current verified staff-account
association, published institution, active exact calendar and published exact year. It stores the
created class identity so reloads read one authoritative PostgreSQL scope. Read access requires both
the existing class and people exact-read capabilities. Writes require every underlying action's
existing capability. Affiliation, teaching assignment and interface visibility grant no authority.

The public contract contains an exact workspace read plus `prepare_class` and `add_student` named
actions. Inputs contain only the class code/label or fictional student display name, action
idempotency and causation identifiers. They contain no tenant, institution, calendar, year,
educator, person, enrolment or placement identifiers. There is no list, search, pagination,
arbitrary date, bulk import, edit, delete or export.

The workspace is a local synthetic authorization and workflow scope, not a new school-domain
aggregate or a production provisioning model. It is tenant-qualified, PostgreSQL-authoritative,
additive and retained while referenced school records exist. The calendar preparation workstream
does not need to adopt this local bootstrap mechanism.

## Plain-English summary

### What this means

A synthetic school administrator can name a class, assign the already-bound educator, and add
fictional students. The new class then appears in that educator's attendance screen.

### What was agreed

Build and verify one narrow local preparation path using the existing school actions. Do not open
general student, staff, class or calendar directories and do not claim production readiness.

### Context

Attendance already works after a developer prepares the class. The next useful step is to let the
school-facing user perform that preparation from the app.

### Examples

Creating “Year 6 Blue” creates one class and its teaching assignment together. Adding “Synthetic
Learner A” creates the person, participation, year enrolment and class placement together. If any
part fails, none of that student's records commit.

## Consequences

### Positive

The classroom slice now begins with school-facing preparation and reaches the existing attendance
workflow without a developer editing data. Exact scope and named actions remain visible in the
implementation and evidence.

### Negative

Only one locally provisioned workspace and class are supported. Student correction, transfers,
class renaming, staff selection, calendar selection and real onboarding remain later decisions.

## Security, privacy, operability, and migration effects

The routes inherit the local HTTPS, host, origin, CSRF, encrypted-cookie and no-store controls from
ADR 0038. Inputs and responses are bounded; support sessions are refused; errors are non-disclosing.
Fictional names remain Restricted data and never enter outbox payloads. The additive workspace table
uses tenant-qualified foreign keys and exact actor/membership binding. Rollback is refused when a
workspace retains a created class or when preparation-created domain evidence exists. No new service,
cache, directory, scheduler or production deployment is introduced.

## Validation evidence

Verify session/workspace binding, capability revocation, cross-tenant and altered-workspace denial,
exact input rejection, 60-student bound, idempotent replay, atomic failure, authoritative reload,
attendance handoff, missing origin/CSRF, narrow layout and keyboard accessibility. Run `make check`
and record every failure or skipped stage separately in the implementation evidence.

## Fallback and exit cost

Keep the routes disabled and continue using the existing isolated demo seed if the preparation proof
fails. Never fall back to browser-supplied scope or a generic collection. Retained school records and
their audit/outbox evidence require forward repair rather than destructive rollback.

## Review triggers

Connected calendar preparation; more than one class; staff or calendar choice; student correction
or transfer; first real record; production identity or deployment; representative school-user review.

## Related records

- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [Classroom slice contract](../phase-2/classroom-first-slice-contract.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0037](0037-class-register-enrolment-and-placement.md)
- [ADR 0038](0038-local-classroom-attendance-workflow.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md)
