# CF-4B classroom setup foundation evidence

- Status: Private synthetic implementation verified; complete repository gate disposition below
- Date: 2026-10-04
- Owner: Product and platform engineering
- Governing record: [ADR 0037](../adr/0037-class-register-enrolment-and-placement.md)
- Authorization: Project Owner's “go ahead” following the class/register, teaching assignment,
  enrolment and placement proposal

## Delivered boundary

`Chimwemwe.Classroom.Foundation` supplies seven named mutations: create class, enrol student,
assign teacher, place student, end enrolment, end teaching assignment and end placement. Four
exact administrative reads return record identity, binding, version and interval. There is no
roster, list, search, count, export, browser route or implied permission grant.

The `classroom.core` manifest composes the actual People and Calendar declarations and depends
on `people.core` and `academics.calendar`. A class pins institution, calendar, academic year and
publication candidate revision. Enrolment is a distinct student/year record; teaching uses staff
participation. A placement connects that enrolment to a class in the same year. Intervals are
half-open and must fit their year and parent. Ending can shorten once, prospectively. To move a
student, end one placement and create the adjacent next placement. Retained earlier rows remain
readable by explicit administrative capability.

The test fixture registers and publishes an institution through CF-1, creates student/staff
participation through CF-4A, then registers, defines and publishes the calendar through the
concurrently developed CF-2B named writer. It uses synthetic records throughout. No raw SQL
publication fixture stands in for that integration.

Every mutation uses trusted execution context and the authoritative writer. Current independent
capabilities and module/dependency gates apply to retries too. State, minimal audit, Restricted
outbox and actor/request-bound idempotency completion commit together. No person name appears in
an event. The dispatcher remains Internal-only; classroom events stay retained until a separately
qualified Restricted consumer is available.

## Migration review

`20261004203031_add_classroom_foundation.exs` was generated from the four resources and outbox
constraint change, then reviewed. The generated teaching-assignment foreign key initially
preceded the class tenant column/compound index; it was moved after that index. Down ordering
likewise removes the referencing key before the parent index. Custom statements run after all
four tables. All tenant columns are non-null; every parent reference includes tenant with
`MATCH FULL` and restricted deletion. Scope indexes enforce one class code per year and one
enrolment per participation/year; interval indexes support scoped overlap checks.

Guards serialize placement changes on the enrolment row and teaching changes on participation.
They reject isolation modes other than READ COMMITTED, preventing stale transaction snapshots
from bypassing parent/child checks. They validate exact published calendar binding, date containment, kind/institution compatibility,
overlap and immutable identity. A participation-ending trigger refuses cutting off existing
classroom intervals; child records must be ended first. Calendar immutability remains owned by
CF-2B. No existing table is rebuilt, no data backfill runs and no partitioning is introduced.
The outbox constraint change requires a normal PostgreSQL validation/table lock; selected
production lock budgeting remains outside this private synthetic migration.

Rollback first refuses any retained classroom record or related audit/outbox/idempotency fact.
It does not erase history to make down succeed. Empty reversal and reapplication are checked
separately from retained-data refusal.

## Verification

Candidate: the working tree based on `10d0851`, including the concurrent CF-2B calendar writer.
No committed-candidate or production readiness claim is made.

| Check | Observed result |
| --- | --- |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_classroom_test MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/classroom/foundation_test.exs` through `mise exec` | 19 passed |
| Fresh `chimwemwe_classroom_gate`: create, migrate, then `MIX_ENV=test mix test` through `mise exec` | 262 passed, including calendar and classroom suites |
| Fresh `chimwemwe_classroom_migration`: migrate, rollback one classroom migration, reapply | Passed |
| Retained rollback after the positive four-record classroom scenario | Expected refusal: `retained classroom foundation cannot be rolled back`; all four records, five guards and migration version remained |
| Documentation validator and repository tooling checks | Passed; four documentation-tool tests passed |
| Formatting, warnings-as-errors compilation, UI-1A OpenAPI drift, migration drift, strict Credo, Hex audit, unused dependency check, Dialyzer | Passed in the final required full-gate run; Dialyzer reports zero errors |
| Generated web contracts and generator dependency audit | Passed; generator audit reports zero vulnerabilities |
| Web dependency audit | Fails with nine high-severity dependency findings rooted in `braces` / GHSA-vfj7-8cjw-p6xm |

The final required `CHIMWEMWE_TEST_DATABASE=chimwemwe_classroom_gate make check` passed
documentation, repository tooling and the entire core boundary (262 tests and zero Dialyzer
errors), then failed at the web dependency audit above. The repository is **not fully green**.
The web format/lint/type/unit/build and browser stages were consequently not reached and have
not been rerun in this increment; no browser source was changed by CF-4B. The later
`make check-tooling` stage was run separately and passed. No check was suppressed and no forced
dependency downgrade is part of this slice.

The focused tests cover all seven mutations and four exact reads; absent context/capabilities;
cross-tenant, cross-institution and wrong-year references; draft/wrong calendar revision;
unknown authority inputs; student/staff kind; stale versions; invalid/overlapping/adjacent dates;
one-way endings and child-before-parent ordering; current module gates on reads and retries;
actor/request-bound replay; concurrent retry and conflicting placements; competing placement and
parent ending; Restricted-event delivery refusal; local-date and UTC recording boundaries;
unsupported transaction isolation; direct-write guards; and rollback after outbox before result
completion. Tests are synthetic engineering evidence, not human workflow or privacy approval.

Early integration runs identified two calendar trigger issues (ambiguous variable names and
cross-table record-field access). The calendar task corrected them. The existing focused test
database received those exact corrected function bodies; the 262-test result above uses a fresh
database with the complete corrected migrations. The classroom READ COMMITTED guard was added
during migration review and its resource snapshots regenerated; source, migration and current
snapshot agree.

## Handoff and limits

Next is a bounded classroom preparation/educator workflow: exact current staff-account binding,
current capability and dated teaching responsibility, class-scoped roster on a chosen local date,
calendar/roster basis conflict, then attendance submission and its qualified side effect. This
increment does not prove that journey, session integration, browser usability, representative
terminology or real-data readiness. Prospective one-way ending is not retrospective correction;
enrolment re-entry and class renaming/retirement remain separate contracts.

ADR 0037 remains Proposed beyond the authorized private increment. Representative records and
privacy review, retention/erasure, connected experience, real identity and deployment conditions
remain open. No commit or push is part of this implementation request.
