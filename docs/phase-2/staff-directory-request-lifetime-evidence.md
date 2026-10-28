# Staff directory request-lifetime repair

- Date: 2026-10-26
- Status: Implemented; focused and full maintained verification passed
- Authority: François authorized fixing the access-profile failure and active dependency advisories, coordinating one full check and preserving other chats' changes
- Governing record: [ADR 0055](../adr/0055-staff-self-presentation-and-navigation.md)

## Reproduction and repair

The previous staff browser run failed at `accounts.spec.ts:183`: Add access profile stayed
disabled after selecting Classroom teacher. Its snapshot showed the placeholder selected.
Three deterministic client regressions failed on the original source: an older arrival load
reset the selected profile to blank; an account-route change reused editing state before the
new authorized load; and a response after `pagehide` restored cleared account/identity data.

The directory now remounts its page state for each account identity. Only the latest request in
that page's active lifetime may publish state or finalize busy flags. Arrival cleanup, page
departure and confirmed logout invalidate pending work. Loads and named-action confirmations
share the same request lifetime, so a late action cannot start a fresh load or reveal a result
after departure. A current validated session retains Reload status/Sign out recovery through a
non-401 inventory failure; record, identity and secret clearing remains fail-closed.

No staff action, input, capability, role rule, CSRF/session requirement, tenant check or disabled
access-profile guard changed. A normal profile action still refreshes the authoritative inventory
and respects its returned lock version and roles. This fixes presentation lifecycle; it grants
no new authority or Classroom integration permission.

## Focused evidence

`mise exec -- npx vitest run tests/unit/staff-directory.test.tsx` failed all three initial
regressions before the repair, including the exact profile-to-placeholder reset. The final
two-file run with `staff-presentation.test.tsx` passed **10 tests**. Six request-lifetime cases
cover the three reproductions, late action departure, a normal grant/authoritative refresh,
and authenticated failure followed by safe retry. Existing self-presentation and classroom-draft
checks remain intact. Targeted Prettier, ESLint and whitespace checks passed.

The UI specialist's source review identified retry/sign-out recovery as an initial condition.
It was repaired and tested before browser verification; the final source disposition is
**approve**, with no remaining concrete issue. This is AI source review, not a new visual or
representative-human trial.

## Coordinated verification

The education-review chat owns the active Ash/Bandit/JOSE dependency upgrade and focused security
regressions. This chat owns the staff client and the single final `make check`. The communications
chat is staging its independent increment outside the shared checkout. The login chat kept the
retained reviewer preview on 3115/3116/4115 and stopped only its newly started qualification-port
process; no user preview, credential or unrelated change was removed by this repair.

The dependency handoff reports Ash 3.37.2, Bandit 1.14.0 and JOSE 1.11.13; all other lock entries,
including AshPostgres 2.15.2 and AshSql 0.8.4, remain as before the upgrade. Its compile/audit,
33 focused tests and independent review passed. Direct HTTP/2/WebSocket and every remaining
JOSE behavioral matrix were not exhaustively reproduced; upstream fixed versions, clean active
audit and bounded exploit/control regressions are the recorded evidence. The archive is unchanged.

## Final verification

The unchanged staff Playwright journey passed standalone (**1 test**, 17.9 seconds), then passed
again in the complete gate (**1 test**, 23.3 seconds):

```sh
cd clients/web
../../bin/with-verification-lock --resource web-qualification -- mise exec -- npm exec playwright -- test --config playwright.staff.config.ts
```

The single coordinated full gate exited **0**:

```sh
CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_dependency_fix_20261026 CHIMWEMWE_DEMO_E2E_PORT=3100 make check
```

It passed all **483 core tests**, **69 web unit tests** and **107 browser tests** (36 UI-0,
6 core connection, 1 unavailable core, 3 classroom, 60 four-institution demo, 1 staff journey).
Core audit reported no retired or advisory packages, and both npm audits reported zero findings.
Formatting, compilation, generated contracts, migration drift, strict lint, type analysis,
token/dependency guards, production build, documentation/fixture tests and shell tooling passed.
No required stage in the maintained command was skipped; the unchanged archive was not rerun.

The before/after digest of all **800 non-Markdown tracked/unignored candidate files** matched:
`0489c22a1e6cd169ede116b25fe7c63cd32d0be56d099f23b9542ffff4e861df`.
Only documentation/evidence was finalized afterward, followed by documentation and whitespace
checks. No other chat started a duplicate full run or changed shared runtime sources during it.

Local logs: `/tmp/chimwemwe-staff-load-{red,green,browser-fixed}-20261026.log` and
`/tmp/chimwemwe-staff-dependency-final-20261026.log`. Failed iterations remain evidence; no
assertion, limit, authorization check or audit gate was suppressed. No repair blocker remains
in this candidate; representative-human, connected-release and production gates remain separate.
