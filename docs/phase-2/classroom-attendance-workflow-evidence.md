# Local classroom attendance workflow evidence

- Date: 2026-10-05
- Owner: Product and platform engineering
- Authority: Project Owner's “green light on next”, after CF-4B
- Governing record: [ADR 0038](../adr/0038-local-classroom-attendance-workflow.md)
- Status: Local workflow verified; repository-wide audit blockers remain
- Boundary: Local synthetic engineering; disabled by default; no production or real-data claim

## Delivered user task

An explicitly synthetic educator starts a current application session, opens an assigned class,
marks each student Present, Absent or Late, submits, and reloads the saved register from PostgreSQL.
No student is automatically marked present. The screen supports phone and desktop widths and
native keyboard radio controls. Logout invalidates the session on the writer.

The proof uses the actual named institution, published-calendar, people, enrolment, teaching and
placement actions to prepare three fictional students. It does not require or modify the separate
calendar preparation screen. The proof educator's role is stripped to the two attendance
capabilities after preparation; institutional affiliation does not grant permission.

Run `make classroom-demo`, then open `https://localhost:3013/classroom`. The script creates a
fresh database named `chimwemwe_attendance_demo_<timestamp>_<process>` and prints its name. Each
run retains that database for review; it never resets an existing one. The loopback TLS certificate
is ephemeral and self-signed, so a normal browser requires its local certificate exception. No
certificate is installed into the operating system. Ports 3013, 3014 and 4013 must be free.
Stop the command to stop the local servers. The sign-in fixture and callback verifier exist only
in test support and the explicit proof script; they cannot select an arbitrary actor or tenant.

## Boundary and persistence

`Classroom.Attendance` supplies `assigned_classes`, `prepare`, and `submit`. These require the
current D.3 session again inside the writer transaction, independent module/capability gates,
current staff-account association and effective teaching assignment. Support sessions are refused.
Today comes from the pinned published year's time zone. The named browser contract has no date
selector, directory, search, filter, pagination or export. Responses are no-store; route parameter
logging is disabled. The checked OpenAPI artifact and generated TypeScript types describe exact
inputs and bounded responses.

A tenant/actor/UTC-day ledger caps cumulative disclosure at 12 classes and 720 distinct people.
An individual roster caps at 60 students. Over-limit reads fail rather than return a partial
register. Attendance stores pinned person/participation/enrolment/placement IDs and versions,
calendar revision, roster hash and explicit marks. Names are read for display, not copied into the
historical record. Class and source locks prevent accepting a stale roster. READ COMMITTED is
required. There is one immutable submission per tenant/class/local date; exact retry is bound to
the original actor and request and rechecks current access.

Attendance, its minimal audit, Restricted outbox event and idempotency receipt commit together.
Only a submission reference is returned in the receipt and event. The existing Internal-only
outbox dispatcher is unchanged and cannot deliver this Restricted event. This proves durable
recording, not an attendance consumer or downstream delivery.

Two additive Ash resources own the generated migration. The submission has a compound tenant/class
foreign key, unique class/date key, roster bounds and immutable update/delete guard. Rollback
refuses retained attendance, exposure, audit or outbox evidence. No existing school data is
backfilled and no production database is migrated.

## Verification

Results on 2026-10-05:

| Check | Result |
| --- | --- |
| Full core suite on freshly migrated `chimwemwe_attendance_gate` | 277 passed |
| Attendance-specific domain and HTTP tests | 15 passed; positive flow, no assumed mark, missing/revoked/forged session, account/capability denial, unknown/unassigned/cross-tenant class, support refusal, stale person and added placement, malformed/incomplete/duplicate marks, wrong date, concurrent submission, immutable row, exact retry, atomic failure, non-instructional day, scope limits and HTTP guards |
| Dialyzer | Zero errors, zero skips |
| `mix credo --strict`, compile with warnings as errors, migration drift, both checked OpenAPI artifacts | Passed |
| Generated TypeScript drift and generator dependency audit | Passed; zero generator vulnerabilities |
| `CHIMWEMWE_UI0_SYNTHETIC=true npm run check` | Formatting, JS/CSS/contracts, types, 8 token tests, 27 unit tests and build passed |
| `npm exec playwright -- test --config playwright.classroom.config.ts` | Passed against actual HTTPS, sessions and PostgreSQL; explicit three-student marks, reload, logout and new-session reload; 1440/768/320 widths, no overflow, keyboard controls and zero axe violations at each width |
| Empty migration apply / rollback one / reapply | Passed on `chimwemwe_attendance_empty` |
| Retained migration rollback | Refused as intended; submission, outbox event and migration version remained present (`1 / 1 / 1`) |
| Documentation, repository tooling and `git diff --check` | Passed |

`CHIMWEMWE_TEST_DATABASE=chimwemwe_attendance_gate make check` was run. Its initial attempt
encountered another task's verification lock; the owner completed and released that lock. The
subsequent run passed documentation, repository tests, formatting, compilation, contract drift,
migration drift and core lint, then stopped at `mix hex.audit`: existing Ash 3.33.11 is reported
under **EEF-CVE-2026-94201 (HIGH)**. A separately owned fix was qualified on another branch; this
slice does not absorb it or claim it is present in this checkout.

The gate therefore did not reach its type-analysis, core-test, web or final-tooling stages.
Type analysis, all core tests, the focused HTTPS browser workflow, web checks and final tooling
were run explicitly as recorded above. A separate frontend `npm audit --audit-level=high` still
reports the existing **nine high-severity** `braces` dependency-chain findings. Existing UI-0 and
UI-1 browser suites were not rerun in this increment. No advisory is suppressed and no forced
package downgrade is applied. The repository is **not green**.

The connected proof caught and fixed a real composition fault: ordinary browser `en-US` language
preferences previously failed the session adapter's exact locale allowlist. HTTP negotiation now
maps supported language ranges to application locales; the adapter itself remains strict.
The same HTTP proof also covers standard Plug request IDs: non-UUID tracing identifiers receive a
valid domain correlation UUID rather than causing authentication failure.
Screenshots were visually inspected after the automated accessibility checks. All evidence is
synthetic engineering evidence, not representative-user or independent security approval.

## Remaining scope

At this slice's verification boundary, the first submission could not be corrected or backdated.
The subsequent [attendance correction and request-recovery slice](attendance-correction-and-recovery-evidence.md)
now adds a today-only immutable successor action; backdating remains outside the boundary. One disabled local synthetic
[classroom preparation workflow](classroom-preparation-workflow-evidence.md) now creates its exact
class and fictional students without a developer, but multiple-class administration, staff or
calendar selection, real onboarding, representative attendance policies, cumulative-budget
calibration and retention, actual identity provider qualification, Restricted consumers and
connected-release conditions remain open.
C25-03-R/C25-05/C25-06 and the earlier production gates are unchanged. No external identity
provider, real child record, production deployment or representative-user sign-off is claimed.
