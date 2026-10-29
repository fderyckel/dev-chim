# Synthetic staff directory and connected-login evidence

- Status: Implemented and locally verified synthetic candidate; no release or real-data authority
- Date: 2026-10-25
- Governing decisions: [ADR 0049](../adr/0049-privileged-synthetic-staff-account-directory.md) and [ADR 0050](../adr/0050-local-credential-application-session.md)
- Authorization: François's explicit green light on the next synthetic slice

## Candidate and retained gates

The isolated candidate connects real local password verification to the existing opaque
application-session boundary. The account inventory, details, tenant-defined access profiles,
institutional suspension, temporary-password reissue and self language preferences operate over
fictional, exact verified staff associations. Provisioning grants no role or teaching assignment.
The guarded pages are `/sign-in`, `/first-login/password`, `/accounts`, `/accounts/[id]` and
`/my-preferences`; existing classroom authorization remains authoritative.

Use [the local runbook](../operations/synthetic-staff-directory.md): `make staff-demo` creates a
fresh fictional database and prints run-specific operator credentials only in the invoking
terminal. The route is `https://localhost:3015/sign-in`. No fixed password, external identity
link or passwordless classroom-demo admission is used by this harness.

LA-1–LA-6, selected deployment, administrator MFA/step-up, protected delivery, bootstrap/recovery,
representative human review, independent security/privacy review, retention and explicit
real-data/release authority remain open. Synthetic implementation evidence does not close those
production qualification gates.

## Verification

### Domain, credential and HTTP checks

The focused combined run in fresh database `chimwemwe_staff_slice_20261024_03` passed **55 tests**
across `password_hash_test.exs`, `password_policy_test.exs`, `local_credentials_test.exs`,
`local_session_test.exs`, `staff_directory_test.exs` and `public_api/staff_login_test.exs`.
Subsequent self-reissue and expired-cookie assertions are included in the final integration run,
not retrospectively counted in that 55-test result.

Coverage includes:

- exact source selection; missing/cross-tenant/context/capability denials; stale versions and
  changed-input idempotency conflicts; safe replay without password redisplay;
- current composed-role ceiling, independent account-security authority, no self access changes,
  no cross-tenant global reissue, and role changes preserving suspension;
- atomic rollback when durable evidence fails; minimized inventory observations and Restricted
  outbox facts; database identity/locale/version guards and bounded inventory refusal;
- sealed permanent proof, forged/expired/temporary proof denial, exclusive session origins,
  credential/access/source revocation, password-reissue races and current source participation;
- actual hash-basis replacement without a credential-version bump and principal-binding actor
  round-trip invalidation;
- full Unicode passphrases, NFC/code-point policy, spaces preserved, whole-password blocklist,
  safe legacy bcrypt compatibility and malformed/unsupported hash refusal;
- exact origin, pre-authentication CSRF, loopback/host checks, generic public failure,
  absolute first-login deadline and authoritative session termination when changing identities.

New hashes use Argon2id at 32 MiB, two passes and parallelism one. The engineering reviewer
measured approximately 20.7 ms median hash and 19.9 ms median verification locally; four concurrent
hashes completed in approximately 34 ms. This is a local engineering measurement, not deployed
load qualification or a target-hardware acceptance result. The maintained compromised-password
corpus and its refresh operation remain a production gate.

### Migration trials

Both root-executed trials passed under the core verification lock using
`MIX_ENV=test mix run tools/qualify_staff_login_migration.exs` after creating a fresh database:

| Database | Result |
| --- | --- |
| `chimwemwe_staff_migration_20261025_01_empty` | Apply both new migrations, empty rollback and reapply passed; expected origin nullability and columns checked. |
| `chimwemwe_staff_migration_20261025_01_retained` | Retained local-session rollback refused before destructive work; row digests and migration versions unchanged; retained opaque cookie still validated. |

The generated migrations were inspected for tenant keys, compound foreign keys, uniqueness,
exclusive origins, lock timeouts and retained-data refusal. Existing external origins are not
backfilled with invented local identity. The databases are retained rather than reset.

### Browser and interface checks

The frontend's final focused command
`npm exec playwright -- test --config playwright.staff.config.ts` passed **1 test in 13.5 seconds**
under the web qualification lock. This complete journey exercised:

- neutral French login failure, secure cookies and no-store responses;
- candidate review/cancel, provisioning, separate role grant, one-time display without browser
  storage, reissue-result focus/viewport, dismissal and refresh;
- temporary first-login cancellation/retry, permanent replacement, fresh permanent sign-in and
  the existing assigned classroom;
- French preferences without identity/authority changes, denied-directory status reload and
  automated accessibility checks;
- stale conflict → reload → reconfirm → suspension, followed by stale-session/classroom denial;
- same-browser teacher-to-operator succession and Back with no former learner groups, plus logout
  and Back to a blocked directory without a manual reload.

The Back assertion accepts Chromium's navigation-aborted result only where the page restoration
guard immediately reloads the protected document; it still requires the exact destination and
fresh authorized empty/blocked state. No boundary assertion or browser-restoration guard was removed.

Targeted formatting, ESLint, TypeScript, staff stylesheet contract, keyboard/help, automated
accessibility and 320/768/1440-pixel responsive checks passed. Automatic failure screenshots,
trace and video are disabled for the credential journey. Clean screenshots contain no credentials.
Their local location is the task visualization folder, `staff-accounts/`, with directory, account,
sign-in, first-password, blocked recovery and French preferences images.

### Repository integration

The first `make check` attempt stopped because another authorized chat held `core-test`.
After coordination and release, `make check` passed documentation, repository tooling,
compilation, OpenAPI/migration drift, strict Credo, dependency audit and Dialyzer, then failed
**33 of 434** core tests in the reused default database. One owned expired-session test had
invalid fixture timestamp ordering; that was corrected without relaxing the database constraint.
Other failures showed global-account/invitation fixture residue. The fresh-database rerun in
`chimwemwe_staff_full_20261025_01` passed **376 of 434** core tests and exposed 58 order-dependent
fixture failures: retained invitation references in later setup, unintended global-account
admission in the concurrent audience tests, and a directory peer actor also used by a third
tenant fixture. The responsible agents corrected fixture isolation and teardown without relaxing
source, cross-tenant or database guards: a fresh directory teacher actor, owned account/token
cleanup, an explicitly unlinked audience-fixture baseline and audience-suite invitation/session
teardown. The six focused credential/directory/session/API files then passed **56 tests** in
13.9 seconds (seed 202604).

The next full run, `CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_full_20261025_02 make check`, passed
**434 core tests** and all core static/drift/audit checks. It stopped at the web dependency audit:
two high and one moderate findings in existing transitive development dependencies. Compatible
patch updates changed `undici` 8.11.2 → 8.12.3, `zod` 4.6.5 → 4.6.7 and `fast-uri` 3.1.8 → 3.1.9.
No direct dependency range or existing local `braces` override changed; the unrelated icon
dependency addition was preserved. The resulting package tree reported zero audit findings.
The following run in `chimwemwe_staff_full_20261025_03` passed **433 of 434** core tests and
exposed an intermittent staff-audience callback budget gap: a 2.1-second callback could commit
despite the intended two-second bound. That concurrent component's owner added explicit
post-callback enforcement while retaining the threshold. No failed run is represented as
repository-green.

The first standalone web continuation also identified a missing formatter exclusion for generated
`.next-staff/` output. That output is now excluded consistently with the other Next build
directories.

The repaired continuation
`./bin/with-verification-lock --resource integration -- make check-web check-tooling` passed:
both dependency audits reported zero findings; generated contracts, formatting, lint/style/token
checks, TypeScript, token/dependency guards, **54 web unit tests**, build, shell checks and
**91 browser tests** passed (UI-0 36, UI-1A 6, unavailable-core recovery 1, classroom 3,
fictional institution/demo shell 44, connected staff 1). This continuation is separate from
the final full `make check` result.

The staff-audience owner then completed the explicit non-restartable callback-budget repair.
Their fresh-database seven-file regression passed **143 tests**, followed by two race-suite runs
of **21 tests each**, including the earlier failing seed. Three new regressions check rollback
with server interruption deliberately disabled, a shorter existing timeout and earlier work in
the same transaction. Compilation, formatting, strict Credo, documentation and whitespace checks
passed. Their runtime checkpoint was released before the final directory integration run.

The final full command
`CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_full_20261025_04 make check` passed with **exit 0** against
that stable checkpoint on 25 October 2026:

| Required boundary | Executed result |
| --- | --- |
| Documentation | Repository/ADR validation passed. |
| Repository tools and fictional packs | Ruff format/lint; 4 documentation-tool, 23 demo-data and 6 demo-instance tests passed. |
| Core static and contracts | Shell/format, warnings-as-errors compilation, all three OpenAPI artifacts, migration drift, strict Credo, dependency audit and Dialyzer passed. |
| Core regression | **437 tests passed**, including the three added callback-deadline controls. |
| Web static, dependencies and build | Both audits reported zero findings; generated clients, formatting, JavaScript/CSS/style contracts, TypeScript and production build passed. |
| Web test tooling and units | **8 token tests, 5 dependency guard tests and 54 unit tests passed.** |
| Browser integration | **91 passed**: UI-0 36, UI-1A 6, unavailable core 1, classroom 3, institution/demo shell 44, connected staff 1. |
| Repository tooling | ShellCheck and dry-run verification routing passed. |

No required step of `make check` was skipped. The two migration trials are additional scoped
evidence. Deployment/load, independent security/privacy, representative-human accessibility and
real-identity checks were not performed; they remain qualification gates. Concurrent owners held
runtime/migration changes until this integration run finished. The result applies to this
checkpoint, not to subsequent work in another chat.

## Specialist review

| Reviewer | Disposition and reasons | Root disposition |
| --- | --- | --- |
| Primary education profile | Approve the synthetic source after real sign-in recovery, current staff eligibility and shared-device test repairs. No classroom authority follows merely from credentials. | Accept; source/session denials and browser succession are exercised. |
| Secondary education profile | Approve after role changes preserve suspension and changing identities terminates the preceding application session. | Accept; domain and browser checks cover both boundaries. |
| Admissions profile | Approve the bounded staff candidate; applicant/guardian/referee identities and wider admissions disclosure remain outside this inventory. | Accept; no account creation or authority from relationships/name/email coincidence. |
| UI profile | Approve after one-time-result focus, explicit irreversible dismissal, blocked-state reload and plain-language repairs. Refreshed French preferences and blocked-recovery screenshots close the final visual conditions. | Accept; final browser journey passed. Full-check outcome is recorded here. |
| Identity, directory and security/privacy engineering agents | No remaining blocking engineering objection within the synthetic contract after proof/source/revocation, absolute first-login deadline, role ceiling, plaintext replay, deadlock and shared-device repairs. | Accept within the bounded trusted-writer model; retain the qualification limits below. |

The UI profile inspected actual clean directory screenshots at 1440 and 320 pixels, account detail,
blank sign-in, blank first-password and French preferences at 320 pixels. The frontend performed
the browser runs; the UI specialist did not claim to execute them. AI reviews are delegated design
and engineering review, not representative testimony, human accessibility qualification or
independent security/privacy assurance. Classroom pages remain English; the staff preferences UI
states that limitation visibly.

The installed Advisor skill's initial and completion preflights both returned
`parent_runtime_unavailable`. No consultation process or Advisor sign-off is claimed; that route
does not block root-owned verification or the separately authorized specialist team.

## Security/privacy interpretation and retained limits

Current guidance was checked against [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)
for passphrase length, NFC/code-point processing, complete-password verification and whole-secret
screening, and [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
for Argon2id and bounded legacy bcrypt compatibility. These references support specific design
choices; they do not certify the complete application or establish an authentication assurance level.
The [EDPB guide](https://www.edpb.europa.eu/sme/be-compliant/be-compliant_en) confirms that
minimization, restricted default accessibility, storage limits and demonstrable accountability
must be considered throughout processing; these remain broader obligations than password security.

The current credential fingerprint detects changed hash/status/principal binding at validation;
named security actions also change credential/access versions. Arbitrary privileged SQL that
restores an exact historical credential tuple is outside the supported named-writer guarantee.
Do not describe current-basis validation as an irreversible revocation ledger against unrestricted
database administrators.

Institutional suspension is separate from global credential state. This candidate supplies no
reactivation, email/login rename, privileged delegation, last-administrator recovery, public reset,
directory synchronization or bulk export. Self-reissue is refused to avoid turning the sole
synthetic operator into an unqualified recovery ceremony. The inventory's 25-record limit is a
reviewed evaluation budget, not a scalable production directory claim.

Before real identities, the controller/processor allocation, lawful basis and notice, processor
contracts/transfers, access/erasure handling, account/security retention and holds, backup-erasure
convergence, DPIA screening and incident/breach ownership need explicit evidence under LA-1–LA-6.
Data minimization, safe audit and synthetic tests alone do not establish GDPR compliance.

Concurrent account-principal and staff-audience work is preserved. This integration check does not
grant COMM-1 publication authority or reverse its separate failed source-workload qualification.
