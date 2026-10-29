# Local attendance correction and request-recovery evidence

- Date: 2026-10-08
- Owner: Product and platform engineering
- Authority: Project Owner's “green light on next” and “go on next bounded slice”
- Governing record: [ADR 0041](../adr/0041-local-attendance-correction-and-recovery.md)
- Status: Local synthetic workflow verified; repository-wide frontend audit blocker remains
- Boundary: Disabled local synthetic classroom workflow; today's register only

## Delivered user task

An assigned synthetic educator can open today's saved register, choose **Correct attendance**,
change one or more marks and save a correction for the fixed `marking_error` reason. Reloading the
class shows the corrected marks and correction number from PostgreSQL. The original submission and
every previous correction remain immutable.

The browser starts from the authoritative current marks and does not enable save until at least one
mark changes. A stale revision cannot overwrite a correction that committed first. After a lost
HTTP response, the browser reloads the register: if the submitted correction committed, it shows
that revision; if the predecessor remains current, it retains the exact request for an idempotent
retry. This is browser request recovery, not proof of downstream event delivery.

Run `make classroom-demo`, sign in through the synthetic local session and open
`https://localhost:3013/classroom`. The same disabled-by-default, loopback-only, self-signed HTTPS
and fictional-record boundary from the attendance workflow remains in force.

## Domain and persistence boundary

`Classroom.Attendance.correct` is a named action with a capability separate from submission. It
revalidates the current application session, module activation, staff-account association, staff
participation and current teaching assignment inside the writer transaction. The client cannot
select tenant, actor, date, roster or calendar authority. Cross-tenant and other-submission
identifiers fail closed.

The action requires the root submission, exact current revision, complete replacement marks,
stable `marking_error` reason, idempotency key and causation ID. It locks the submission, resolves
the latest revision and appends one full immutable successor. Database constraints preserve the
tenant-qualified root and predecessor links, consecutive correction numbers and one chain. The
bounded proof permits ten corrections per register and rejects stale, branched, incomplete,
extra, unchanged or over-limit input.

Current reads resolve the latest correction while retaining the original pinned roster, calendar
revision, local date and roster basis. Later placement changes do not rewrite the submitted class.
The UI exposes the current revision and correction number; it does not expose the retained history.

Correction, minimal audit, Restricted outbox fact and idempotency result commit in one transaction.
The event contains only the submission ID, correction ID and correction number. The repository's
dispatcher remains Internal-only, so no Restricted consumer delivery or interruption-recovery
claim is made.

## Verification

Results on 2026-10-08:

| Check | Result |
| --- | --- |
| Attendance domain and exact HTTP suite | 22 passed; append-only first/subsequent correction, exact replay, authoritative latest read, immutable records, stale/concurrent conflict, separate capability, wrong/cross-tenant submission, ended assignment, revoked session, pinned roster, invalid/no-op/extra/over-limit input, atomic late-failure rollback and exact route/input guards |
| Full core verification on `chimwemwe_attendance_correction_full` | 293 passed; formatting, compilation, both OpenAPI drift checks, migration drift, Credo, Hex audit, unused dependency check, Dialyzer with zero errors/skips and whitespace check passed |
| `CHIMWEMWE_UI0_SYNTHETIC=true npm run check` | Formatting, JavaScript/CSS/contracts, types, 8 token tests, 27 unit tests and production build passed |
| Classroom HTTPS Playwright suite | 3 passed; correction success, phone-width accessibility, committed-but-lost response recovery, sign-out and new-session persistence |
| Existing browser suites run directly after the audit stopped `make check` | UI-0: 33 passed; connected UI-1A: 6 passed; unavailable-core recovery: 1 passed |
| Empty correction migration rollback and reapply | Passed on `chimwemwe_attendance_correction_rollback_20261008` |
| Retained correction migration rollback | Refused with `retained attendance correction evidence requires forward repair`; correction, event and migration version remained `1 / 1 / 1` |
| Documentation, repository tooling and whitespace | Passed |

The first complete web check encountered three simultaneous five-second unit-test timeouts after
an approximately three-minute stall. The same 27-test unit suite immediately passed in 2.47
seconds, and the complete web check then passed in 12 seconds. No product or test code was changed
between those runs; this is recorded as transient local resource contention rather than hidden.

`make check` was run on the completed core and API candidate. It passed documentation, repository
tooling and the complete 293-test core gate. Its web gate then stopped at the retained
frontend dependency audit: ten high-severity findings are reported. Nine remain in the transitive
`braces`/`micromatch` chain behind the existing Stylelint compatibility boundary; the tenth is a
new direct Next.js advisory set whose offered fix is outside the declared dependency range. The
generator audit has zero findings. Focused and full web checks, every browser suite, and final
tooling checks were run separately as recorded above. No advisory was suppressed and no forced
dependency change was applied. The repository is not green.

## Remaining scope

This slice does not add backdating, administrator correction, free-text reasons, absence details,
history or export UI, more than ten corrections, a Restricted outbox consumer, real identity,
real records, representative policy approval, pilot or deployment. C25-03-R, C25-05, C25-06 and
the connected-release gates remain open. Those require their own bounded decisions and evidence.
