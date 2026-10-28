# Staff reviewer presentation repairs

- Status: Scoped repairs reviewed; dependency remediation and full maintained verification passed
- Started: 2026-10-25
- Final review: 2026-10-26, Europe/Brussels
- Governing decision: [ADR 0055](../adr/0055-staff-self-presentation-and-navigation.md)
- Authority: navigation, wording, signed-in identity and local fictional-roster repairs, then
  specialist login review; credentials outside Git; full verification subsequently authorized

The original local AI screen reviews found unavailable feature links, missing signed-in identity,
account creation below the initial viewport, “1 students” and weak numbered one-pupil fixtures.
The repairs and observed results below remain separate from representative-human evidence.
The isolated Advisor preflight returned `parent_runtime_unavailable`; no independent Advisor
assurance is claimed. The initial scoped increment deferred `make check`; the first authorized
full attempt on 26 October stopped at the maintained core dependency audit. The remediation
follow-up below records the patched dependencies and subsequent passing full gate.

## Implemented scope

The patch was prepared separately while the integration owner held the shared runtime stable,
then applied only to its owned files after that owner released it. It adds two fixed navigation
hints to own preferences, uses the existing
own display name in headers, chooses preferences as the ordinary-staff landing page, adds an
early account-creation action, corrects singular/plural copy and confirms unsaved class switching.
No action authorization is removed or delegated to those hints.

Signed-in name/navigation clear on departure, current-session failure and confirmed logout.
Missing or malformed client hints hide optional destinations. A stale/direct link still reaches
the original server authorization check. Navigation is not derived from job titles or inventory
probing. The early creation action focuses the existing staff selector without bypassing review.
The teacher introduction is shorter, and the classroom-language note appears only to staff with
classroom availability. Date, class, identity and saved/blocked/uncertain states remain visible.

An opt-in test-only review fixture prepares Oak/Aspen daily registers with four distinct fictional
learners each. The reviewer-specific fixture uses Birch/Willow, Cedar/Maple and Juniper/Elm for
separate currently assigned teachers. No age, year-level or subject-group meaning is inferred.
All existing source, class, correction and admission bounds remain unchanged.

The refreshed local run preserves each reviewer's sign-in email/password while creating a
new isolated fictional database; the earlier database and credentials remain retained. Its
dedicated loopback ports are 3115/3116/4115, keeping qualification ports 3015/3016/4015 free.
Origin, Host, TLS, backend/proxy and browser helper agree and passed actual sign-in checks.
No private access file, screenshot containing credentials, cookie, password or token belongs in
Git. All four specialists used their individual local credentials through a helper that reads
them in memory, never through model-visible plaintext or a passwordless endpoint.

## Executed checks

All database verification uses the repository `core-test` lock and a fresh fictional database.
The scoped run on `chimwemwe_staff_presentation_20261025_01`, seed 29, passed **38 tests**:

```sh
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
mise exec -- env MIX_ENV=test mix run tools/check_staff_openapi.exs --write
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/staff_directory_test.exs apps/chimwemwe_core/test/chimwemwe/public_api/staff_login_test.exs apps/chimwemwe_core/test/chimwemwe/identity/local_session_test.exs --seed 29
```

New cases cover exact-self minimized fields, missing/cross-tenant context, no authority from the
Teacher label, grant/revocation, module/capability unavailability, forged navigation input,
ordinary-staff preferences landing, anonymous denial and stale-session refusal after access changes.

Client checks passed:

```sh
npm run generate:staff
npm run generate:check:staff
npx vitest run tests/unit/staff-presentation.test.tsx tests/unit/classroom-attendance.test.tsx
npm run typecheck
npm exec -- eslint src/components/staff-shared.tsx src/components/staff-directory.tsx src/components/staff-preferences.tsx src/components/staff-login.tsx src/components/classroom-attendance.tsx tests/unit/staff-presentation.test.tsx tests/staff/accounts.spec.ts
```

The generator commands run in `clients/web/openapi-client-generator`; the other commands run in
`clients/web`, all through `mise exec`. The final two-file unit run passed **5 tests**, including
singular/plural, missing-hint fallback, audience-specific language information, cancelled/discarded
draft switching and identity/roster clearance on departure.

Under `web-qualification`, the connected staff Playwright journey passed **1 test** and the
existing classroom/calendar config passed **3 tests**. The final staff repetition after the wording
delta again passed its one journey; this is not counted as a second distinct test.

```sh
npm exec playwright -- test --config playwright.staff.config.ts
npm exec playwright -- test --config playwright.classroom.config.ts
```

Targeted Prettier and Elixir formatting, strict Credo, staff OpenAPI drift, Dialyzer (zero errors/
skips), documentation validation and whitespace checks passed. Logs include
`/tmp/chimwemwe-staff-presentation-core-20261025-01.log`,
`/tmp/chimwemwe-staff-presentation-static-20261025-01.log`,
`/tmp/chimwemwe-staff-presentation-classroom-20261025-01.log` and
`/tmp/chimwemwe-staff-presentation-browser-20261026-final.log`.

Early iterations are not hidden: the new UI test initially captured the request constructor
before its browser-relative-URL setup; its harness was corrected. Type checking rejected the
test's unsupported Testing Library `exact` options, and strict Credo requested a fixture alias;
both were corrected without disabling checks. An initial private UI-account check did not confirm
sign-in while three other accounts passed. Its repeat and all four specialist-owned final runs
passed. These local functional attempts are not performance samples or a relaxed impact threshold.

## Exact local candidate and access

The private run is retained at
`/Users/francois/.local/share/chimwemwe/review-runs/2026-10-25-YNeklr-r2` with a separate
`chimwemwe_staff_demo_review_20261025_yneklr_r2` database. Its 25 October folder date is creation
provenance; final captures/reviews include 26 October and display the institution writer's date.
It includes the separately qualified same-writer prerequisite and the security-fixed dependency
set from the integration owner; that owner's earlier full gate does not verify ADR 0055's changes.

All 17 owned runtime/test/tooling/generated files match the served copy. The sorted SHA-256
manifest is retained locally as `source-manifest.sha256`, with manifest digest
`e3edef2839e4176229ce78d18fd6ac6c87b96cb29a105df962d646b4c72ae9cd`.
The local port adapter/bootstrap/helper are separate review assets, not production interfaces.

The final safe per-profile records are in local `access-checks-final.json`. They confirm current
identity and automatic landing, two assigned four-pupil registers for the educators/UI reviewer,
administrative and unassigned-class denials, the creation action's viewport/focus, draft switching
and logout clearance. Admissions has no classroom or inventory authority and lands on preferences.
No attendance was submitted in these four local reviewer walkthroughs.

Credential files remain owner-only outside Git; usernames/passwords were verified unchanged from
the retained previous run. The public pack/results/runtime log and repository diff were checked
for those password values without printing them. No real identity, human observation or delivery
claim is made by these generated local accounts.

## Four specialist dispositions

All four reviewed with their own local login and current clean desktop/320px captures. After the
initial approval, the educators' density feedback prompted shorter introductory text and the
admissions language note was made conditional; the affected final screens were reviewed again.

| Profile | Final scoped disposition | Reasons and retained human questions | Coordinator |
| --- | --- | --- | --- |
| Primary education | Approve | Current identity, correct feature links, distinct Birch/Willow rosters and draft switching are clear; assess remaining mobile density with real teachers | Accept; no blocking primary finding in this repair |
| Secondary education | Approve | Cedar/Maple remain daily registers with exact class/date and four distinct pupils; cancellation/discard and role boundaries pass; workload/capacity remain unproven | Accept; retain uncoached roster/switching trial |
| Admissions | Approve; no remaining finding in this bounded review | Preferences landing and own identity are clear; unavailable links/classroom-language note are absent; direct classroom/inventory stay denied | Accept; wider admissions/family/college work remains paper-only |
| UI and interaction | Approve | Early creation is visible and focuses the selector; identity, roster, wording and reduced mobile explanation are clear | Accept; retain human density, access-state comprehension and accessibility trials |

These are AI screen/interaction reviews and executed software checks, not practising-educator
testimony or observed human task success. Saved/corrected/error recovery, realistic class workload,
full keyboard/touch/screen-reader accessibility, real identity/delivery, institutional policy,
independent security/privacy and release retain their own gates. The local validation pack keeps
all actual human sessions `not run`.

## Full verification follow-up — 2026-10-26

François subsequently authorized `make check`. The exact command ran through the repository's
integration and core-test locks with `CHIMWEMWE_TEST_DATABASE=chimwemwe_check_staff_20261026_cfbc8879`.
It exited **2**, stopping at core step 6/9, `mix hex.audit`.

Documentation validation, repository-tool formatting/lint, all 33 repository-tool/demo tests,
shell checks, Elixir formatting, compilation with warnings as errors, all three OpenAPI drift
checks, migration drift and strict Credo passed before the stop.

The maintained dependency audit reported **12 advisories: 10 high and 2 medium**:

| Locked dependency | Audit result |
| --- | --- |
| Bandit 1.13.1 | 11 advisories: 9 high, 2 medium, covering HTTP/HTTP2/WebSocket handling |
| Ash 3.37.1 | 1 high advisory, EEF-CVE-2026-96581 / GHSA-vw7c-67pf-gh96, describing attribute-multitenancy bypass in primary-key upserts |

These are audit findings, not a new exploit-path assessment. They affect the maintained core;
this failure is separate from the historical archive audit. No dependency pin or audit policy was
changed, and the failed check was not bypassed. Remediation and a fresh full gate are required
before this result can be treated as passing. The follow-up below repairs the dependency set;
this initial failed attempt remains retained as historical evidence.

The stop prevented the unused-dependency check, Dialyzer, full core tests, core final whitespace
step, every web check/build/browser suite and the final tooling boundary from running in this
attempt. The earlier scoped successes remain historical evidence, not a substitute for them.

The private verification record and log are retained at
`/Users/francois/.local/share/chimwemwe/verification-runs/2026-10-26-staff-repairs-e4f9d044`.
All 960 tracked/non-ignored source files were unchanged during the command. A password-value
scan across those files and the Git diff passed for all four local reviewer credentials; files
remain owner-only outside Git. Post-record documentation/whitespace checks are reported separately.

## Retained verification boundary

The passing maintained check does not implement publication, grant production release, commit
credentials, commit/push or create an archive-audit exception. The unchanged 20% source-impact
requirement and all existing limits remain. The four domain/UI specialist approvals remain
scoped design review; dependency remediation has separate engineering/security evidence.

## Dependency remediation follow-up — 2026-10-26

François authorized fixing the maintained Bandit/Ash advisories and rerunning the full gate.
His separately verified coordination instruction in the navigation chat also authorizes its
subsequently observed eight JOSE advisories. That chat owns the staff access-profile repair and
the single final `make check`; this chat owns the dependency repair and focused security review.
The communications owner stages separately until qualification is complete.

The maintained core now pins **Ash 3.37.2** and **Bandit 1.14.0**, and the shared lock selects
**JOSE 1.11.13**. Only those three lock entries changed from the pre-repair working tree;
AshPostgres 2.15.2, AshSql 0.8.4 and the other dependencies remain unchanged. Sources are the
[Ash security advisory](https://github.com/ash-project/ash/security/advisories/GHSA-vw7c-67pf-gh96),
[Bandit changelog](https://github.com/mtrudel/bandit/blob/1.14.0/CHANGELOG.md) and
[JOSE release](https://github.com/potatosalad/erlang-jose/releases/tag/1.11.13).
No audit suppression, application-policy change, schema migration or archive update was added.

A read-only boundary investigator confirmed the adapter/framework enforcement points and
compatible constraints. No maintained application entry point exposing tenant upserts was
found; the vulnerable Ash library behavior was reproduced using a private test-only PostgreSQL
resource. The fixture uses a temporary table and one sandbox connection; it adds no production
resource or domain action. The regression covers primary-key and all-tenant identity conflicts,
single/bulk creates, skipped-return modes, unchanged victim data and legitimate same-tenant writes.

Bandit checks use an ephemeral loopback socket for bare-LF/CR chunk extensions and valid bodies,
plus the shared header parser's significant-digit limits. Leading-zero content lengths remain
valid. JOSE checks reject noncanonical ECDSA signatures and invalid GCM tags while preserving
valid signatures/decryption. No crypto fallback is globally enabled. These are focused library
regressions, not exhaustive reproductions of all eleven Bandit or eight JOSE advisories, and do
not demonstrate that every reported vulnerable operation was reachable through the application.

The old lock accepted the cross-tenant upserts, malformed chunk extension and altered JOSE
inputs in the focused fixture. During harness development, fixture configuration errors were
corrected before the valid baseline. An initially over-strict expectation about leading zeros
was corrected: they are now a passing legitimate control, while significant digits are bounded.

Executed under the `core-test` lock on `chimwemwe_dependency_security_20261026`:

```sh
mise exec -- mix deps.unlock ash bandit jose
mise exec -- mix deps.get
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
cd apps/chimwemwe_core && mise exec -- env MIX_ENV=test mix hex.audit
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/platform/dependency_security_test.exs apps/chimwemwe_core/test/chimwemwe/identity/local_credentials_test.exs apps/chimwemwe_core/test/chimwemwe/identity/oidc_callback_verifier_test.exs --seed 29
cd apps/chimwemwe_core && mise exec -- env MIX_ENV=test mix credo --strict
```

Commands start at the repository root except the explicitly labelled app-directory checks.
The audit reports no retired/advisory packages. All **33 focused tests pass** (17 new dependency
security cases and 16 existing credential/OIDC cases); strict Credo passes. The unchanged
AshPhoenix dependency emitted type warnings during recompilation; the application compilation
with warnings-as-errors passed. The independent read-only candidate review found no concrete
surviving bypass or regression; the coordinator accepts that disposition. The reviewer confirmed
the HTTP/2, WebSocket and remaining-JOSE behavioral proof limits above. Local reviewer credentials
and retained preview data remain outside Git and unchanged.

### Final coordinated gate

The navigation chat completed the single full run with **exit 0**:

```sh
CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_dependency_fix_20261026 CHIMWEMWE_DEMO_E2E_PORT=3100 make check
```

All **483 core tests**, **69 web unit tests** and **107 browser tests** passed. The browser
breakdown is 36 UI-0, 6 core connection, 1 unavailable core, 3 classroom, 60 four-institution
demo and 1 staff journey. The maintained Hex audit is clean, and both npm audits report zero
findings. All remaining contract, migration, formatting, lint, type, token/dependency guard,
build, repository-tool and shell checks passed; no required maintained stage was skipped.
The unchanged archive was not rerun. The separately repaired staff access-profile request
lifetime is recorded in its [own evidence](staff-directory-request-lifetime-evidence.md).

The command's terminal exit was independently inspected, and the full log is retained at
`/tmp/chimwemwe-staff-dependency-final-20261026.log`. The integration owner recorded matching
before/after hashes for all 800 non-Markdown candidate files, aggregate
`0489c22a1e6cd169ede116b25fe7c63cd32d0be56d099f23b9542ffff4e861df`.
Only documentation was finalized afterward, with separate documentation and whitespace checks.
No dependency or staff-repair blocker remains in this checked candidate. Separately authorized
COMM-1 work resumed after the freeze was released and needs its own qualification; this result
does not cover that later changed candidate.

This verifies the updated maintained checkout at the recorded checkpoint. The retained reviewer
preview remains its earlier isolated snapshot and has not been rebuilt by this repair; its four
logins and fictional database were preserved. Historical source-impact measurements and
representative/release gates are not silently requalified by dependency updates or a passing
functional gate.

## Bandit advisory follow-up — 2026-10-28

The next maintained `make check` stopped at `mix hex.audit` after the newly published
[GHSA-pxjf-g536-7r93](https://github.com/mtrudel/bandit/security/advisories/GHSA-pxjf-g536-7r93)
classified Bandit versions before 1.14.1 as vulnerable to unauthenticated HTTP/2 request-body
memory amplification. Documentation, repository tooling, compilation, OpenAPI drift, migration
drift and strict Credo had passed before that stop. The candidate now pins Bandit 1.14.1, the
first fixed release, and the focused dependency suite rejects a future downgrade below that
version. This follow-up changes no route, authorization policy, capacity threshold or release
authority; the fresh full-gate result is recorded with the integrating commit.
