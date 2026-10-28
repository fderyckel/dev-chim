# CW-1 Classroom workspace evidence

- Date: 2026-10-27
- Status: Implemented and locally verified; final coordinated check passed
- Authority: François explicitly authorized implementing the [proposal](../plans/classroom-workspace-integration-proposal.md), preserving labels, four institutions, phones and concurrent work, with one coordinated final `make check`
- Governing decision: [ADR 0057](../adr/0057-local-classroom-workspace-navigation.md)

## Delivered boundary

`/staff/home` and `/staff/apps` use the existing local harness guard and current session/own
presentation reads. No classes, roster, counts, marks or privileged inventory are prefetched.
Optional entries require exact true hints; own preferences and recovery stay available. Arrival,
departure and logout invalidate old requests. Login landings are unchanged.

Code-owned Home sections and Apps groups separate bounded IDs/labels/entries from canonical
destinations. Renaming or moving a group does not change route/action identity or access. Unknown
entries and duplicates cannot add destinations; hints remain presentation only. Connected layout
editing and persistence remain later CW-2/CW-3. Existing four-pack editors are unchanged.

Classroom shows My classes, per-assignment dates and the selected Attendance register/date.
Desktop has a compact task menu; phone has a labelled disclosure. Duplicate source label/date
pairs are blocked for source clarification, without invented campus/year/subject metadata.
No personal Calendar destination or new domain read is introduced.

Known drafts use a native modal Stay/Discard dialog before controlled Home/Apps/preferences,
class switching, My classes or Reload class. Stay/Escape retain marks and restore focus. Native
full-document history/reload departures warn through `beforeunload` where supported; forced
departure may discard memory. Staff links use document navigation and protected history restores
reload for fresh authorization. No pending request key or marks are persisted.

Pending/uncertain writes block ordinary departure and further writes until authoritative reload;
Cancel correction cannot erase an uncertain request or claim the register was unchanged.
Sign-out remains available during a pending attendance request and uncertainty. Obsolete
responses cannot restore cleared identity/records or claim success. A new-day read retains the
original register date and refuses to infer the earlier result; authorized records follow-up
is required when that bounded read cannot reconcile it. No replay occurs through navigation.

Existing core/domain contracts, 12/60 and UTC-day 12/720 disclosure ceilings, tenant/session/
CSRF/module checks, pinned basis, idempotency, append-only correction and outbox behavior remain
unchanged. No core source, schema, migration, credential or fixture changes belong to CW-1.

## Review and verification

Primary, secondary and UI profiles required guarded destructive reload, uncertain-correction
cancellation refusal, source date/ambiguity handling, departure lifetimes and honest rollover.
Coordinator accepted these in-scope conditions. Source review also caught retained correction
requests surviving a deliberate reconciled-draft Discard and initial session failure blocking
Sign in. Both were repaired and regressed. Rendered review required correction-specific status
labels instead of Saved register above uncertain draft marks; the regenerated capture closes
that condition. All three profiles returned **approve** for the final source/rendered candidate.
Admissions meaning is unchanged; the other review chat has separately authorized all-four
own-login walkthroughs after this candidate's final gate.

Focused checks: `npx vitest run tests/unit/classroom-workspace.test.tsx tests/unit/staff-presentation.test.tsx`
passed 24 cases; the complete `npx vitest run` passed **102** cases after the final environment
repair. Early test-harness issues (native dialog and captured transport simulation)
were corrected; assertions were updated from native confirm to the explicit Stay/Discard contract.
No access check or authoritative-save condition was weakened. Targeted type/lint/style and
documentation/whitespace checks passed. The final staff browser repeat passed **2/2** in 27.7s,
including session/preferences-only entrances, anonymous denial, initial-session recovery,
1440/768/320 reflow and axe, native modal focus/Tab/Escape/Stay/Discard, actual submission,
lost correction response/reconciliation and revocation clearing. Exact safe captures are retained
locally in `clients/web/playwright-report/cw1-review/`; no credential trace/video is retained.

The first coordinated `make check` exited **2**: **559 core passed**, core and both npm audits
were clear, but a node-only unit suite rejected the global browser-dialog test shim.
Guarding that shim by browser-environment availability repairs the test setup; all 102 units
then passed. That attempt never reached browser suites/build/final shell stages. During its core
stage, the rendered-status label and whitespace-normalized collision fixture were refined before
web verification started. Its log remains `/tmp/chimwemwe-cw1-first-check-20261027.log`.
The final repeat used the frozen repaired candidate with no concurrent check run and exited **0**.

### Final qualification

```sh
CHIMWEMWE_TEST_DATABASE=chimwemwe_cw1_final_20261027 CHIMWEMWE_DEMO_E2E_PORT=3100 make check
```

Full output: `/tmp/chimwemwe-cw1-final-check-20261027.log`.

| Check | Actual result |
| --- | --- |
| Documentation, repository tools and fictional-fixture validation | Passed |
| Core format/compile, contract and migration drift, strict lint and Dialyzer | Passed |
| Core tests | **559 passed** |
| Hex audit and both npm audits | No retired/advisory packages; zero npm vulnerabilities |
| Generated clients, formatting, JS/CSS/style lint and TypeScript | Passed |
| Design-token tests and dependency guards | **8** and **5** passed |
| Complete web unit suite | **102 passed** |
| Production web build | Passed |
| UI-0 / core-connected / unavailable-core browsers | **36 / 6 / 1 passed** |
| Existing Classroom browsers | **3 passed** |
| Four-institution demo browsers | **60 passed**, including labels/layouts, switch/history isolation, phone reflow and keyboard/accessibility |
| Staff browsers including CW-1 | **2 passed** |
| Communications publication browser | **1 passed** |
| Shell/tooling and Git whitespace stages | Passed |

Total browser cases: **109**. No maintained required stage was skipped in the final repeat.
The unchanged archived Phase 0 suite and clean-checkout rehearsal were not separately rerun;
neither belongs to this maintained gate. Human usability and the later four own-login preview
walkthroughs are not claimed by these software results.

The **855** non-Markdown source/test/configuration files were byte-identical before and after the
successful final command. SHA-256 of the sorted compact JSON path-to-file-hash manifest:
`1b195c6296c486726dc3176e2469be4ad0d81f579f64f7970607d3e05aa88861`.
Compared with the prior qualified COMM-1 manifest, all **518** recorded core files are unchanged;
the eight modified existing web files and six new workspace files are within this slice.
The expanded final manifest also includes previously omitted tracked root/vendor/lock files.
Private source snapshot and logs are retained outside Git at
`/Users/francois/.local/share/chimwemwe/cw1-qualification-20261027.qyrlofn7`.
Final evidence-only Markdown updates receive another documentation/whitespace check.

All primary, secondary and UI conditions are closed; no CW-1 implementation/qualification blocker
remains. The Advisor completion preflight again returned `parent_runtime_unavailable`; no Advisor
approval is claimed. The preview-review chat owns the separately requested qualified preview
refresh and four own-login walkthroughs; existing credentials, data and review environments stay
outside Git. CW-1 adds no fixture/seed, migration or permission change for that handoff.

Cross-chat lane ownership was acknowledged by communications, login and reviewer chats. They
hold shared source/qualification lanes; separate private previews use alternate retained ports.
CW-1 does not commit, push, reset or absorb their changes. All prior COMM-1, dependency,
staff-directory, demo-layout and retained preview work is preserved.

## Retained gates

Local synthetic software checks and AI specialist review do not establish human usability,
independent security/privacy acceptance, real institution policy, real identity/data, connected
deployment, pilot or production readiness. The unchanged archived Phase 0 checks are separate.
