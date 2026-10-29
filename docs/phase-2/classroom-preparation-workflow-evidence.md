# Classroom preparation workflow evidence

- Status: Disabled local synthetic preparation workflow implemented and focused checks passing
- Date: 2026-10-06
- Governing decision: [ADR 0040](../adr/0040-session-bound-classroom-preparation-workspace.md)
- Scope: One exact server-bound class, educator assignment, and at most 60 fictional students
- Release claim: Local engineering evidence only; no real identity, student data, deployment, pilot, or production approval

## Demonstrated task

A synthetic administrator signs in over the local HTTPS application boundary, opens one preparation
workspace, creates “Year 6 Blue,” and adds a fictional student. The class and educator assignment
commit together. Each student click commits the person, student participation, year enrolment, and
class placement together. The prepared class then appears in the educator's attendance screen; the
educator opens its one-student register, submits an explicit mark, and reads the saved register back
from PostgreSQL.

The browser supplies only a class code/label or fictional display name plus action idempotency and
causation identifiers. Tenant, actor, membership, institution, calendar, year, calendar revision,
educator participation, class, enrolment, and placement scope are held by one durable PostgreSQL
workspace created by trusted local composition.

## Implemented boundary

`Chimwemwe.Classroom.Preparation` revalidates the encrypted application session inside the writer
transaction and locks the exact workspace. The workspace query rechecks the actor and membership,
current verified staff-account association, published institution, active exact calendar, published
exact year and pinned revision. Support sessions and missing or changed bindings fail closed.

Class preparation calls the existing `classroom.core.classes.create` and
`classroom.core.assignments.record` actions inside one outer transaction. Student preparation calls
the existing `people.core.persons.register`, `people.core.participations.record_student`,
`classroom.core.enrolments.record`, and `classroom.core.placements.record` actions inside one outer
transaction. Each child action keeps its own capability, deterministic request-bound idempotency,
minimal audit, Restricted outbox, and result evidence. A late denial or scope failure rolls back all
earlier child actions and their evidence.

The public adapter exposes one exact read and two named actions:

- `GET /api/v1/classroom/preparation`
- `POST /api/v1/classroom/prepare-class`
- `POST /api/v1/classroom/add-student`

They remain disabled by default and require the loopback HTTPS host, current application cookie,
exact origin, CSRF proof for writes, and checked OpenAPI-generated types. There is no people or class
directory, arbitrary identifier input, selector, search, pagination, edit, delete, import, or export.

## Persistence and migration review

The additive `classroom_preparation_workspaces` table has tenant-qualified foreign keys for the
membership, institution, calendar, year, educator participation, and optional prepared class. Its
database trigger validates the exact membership actor, current staff-account proof, published
calendar binding, immutable revision, prepared-class scope, and matching teaching assignment.
Only the one-way transition from an empty workspace to its prepared class is allowed. Deletion is
refused; rollback requires an empty table.

Fresh-database verification caught and corrected two composition faults before acceptance of this
evidence: migration function/trigger statements had to be prepared separately, and the optional
class compound foreign key required ordinary null semantics instead of `MATCH FULL`. All shared
test cleanup lists now truncate the new child table before their existing classroom parents.

## Verification recorded so far

| Check | Result |
| --- | --- |
| Fresh database create and all migrations | Passed |
| Actual `tools/classroom_demo.exs` startup against the fresh database | Passed; both local writers reached ready state |
| Preparation domain tests | 5 passed |
| Combined calendar foundation, connected calendar, attendance, and preparation tests | 31 passed |
| Strict core Credo analysis | Passed across 309 source files |
| Checked public OpenAPI and generated TypeScript contract | Passed |
| Classroom browser suite | 3 passed: seeded attendance, administrator preparation-to-attendance handoff, and connected calendar |
| Responsive layout and automated accessibility in the preparation journey | Passed at 320 px; no axe violations |
| Full core qualification | Passed: migration drift, strict lint, dependency audit, type analysis, 286 tests, and whitespace |
| Non-audit web qualification | Passed: formatting, lint, types, 8 token tests, 27 unit tests, and production build |
| Browser suites outside classroom | Passed: 33 UI-0, 6 connected UI-1A, and 1 unavailable-core test |
| Repository tooling | Passed: shell checks and changed/staged command rehearsal |
| Repository `make check` | Blocked at the frontend dependency audit by 9 known high-severity `braces`/`micromatch` findings whose offered repair is a breaking Stylelint downgrade; later web stages were run directly and passed |

The preparation tests cover exact authoritative reload, idempotent replay, invalid session and
workspace denial, rollback when educator-assignment capability is missing, rollback when placement
capability is missing, the 60-student ceiling, and absence of partial overflow records. The browser
test also confirms missing CSRF denial and reload of the prepared class after completing attendance.
The repository is not green because the required frontend dependency audit failed. No advisory was
suppressed and no forced breaking downgrade was applied in this classroom slice.

## Remaining boundary

This proof has one server-provisioned workspace, one class, one already-bound educator, and
fictional data. It does not provide real administrator or educator identity, staff selection,
calendar selection, multiple classes, student correction or transfer, class rename/retirement,
attendance correction/backdating, bulk import, records-policy approval, representative-user
validation, independent security/privacy review, selected deployment, pilot, or production use.

The next classroom slice is attendance correction and recovery: authorize a named correction,
retain the original submission, represent the replacement explicitly, handle concurrent roster or
session changes, and show authoritative correction state in the classroom screen.
