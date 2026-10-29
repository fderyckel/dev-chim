# Local demo layout editor evidence

- Date: 2026-10-25
- Status: Implemented and locally qualified; latest maintained full check passed on 26 October
- Governing record: [ADR 0048](../adr/0048-local-demo-application-shell.md)
- Authority: Project Owner explicitly authorized in-memory app-group and educator Home editors on 25 October 2026

## Boundary

Organize apps edits an institution-navigation preview; Customize my Home edits separate personal
landing layouts. The editors arrange only the four existing read-only destinations across the
three demo apps. Canonical destination names, sources and routes remain code-owned. Group labels
and placements are independent presentation data. Repeated aliases remain one search result;
All available pages keeps every destination findable even after all groups are removed.

Draft, preview and applied state are separate. Preview does not apply a draft; Cancel discards
it. Leaving the page discards unapplied changes, with a visible notice and a full-page unload
warning for dirty drafts. Apply layout affects this preview only. Native reset dialogs name the
scope, support Cancel/Escape and restore focus. A Home reset leaves app organization and other
Home layouts unchanged. Up to four named Home layouts have an explicit Make default choice;
selecting another layout does not silently change the starting layout.

Section/item editing supports keyboard and touch through move up/down and move-to-section
controls. Movement/removal announces its result and restores meaningful focus. Short plain-text
names are required and section names are distinct. The first proof supports up to eight sections
and one placement per page within a section; a page may appear in several sections.

A demo-only root React provider stores presentation references in memory across client-side
navigation. The URL-derived scope only discards state; the existing server adapter remains
authoritative for the selected fictional dataset. A scope/data mismatch shows no personalized
content. Reload, institution change and restored full-page history discard both temporary
profiles, including unfinished editor drafts and previews. Layouts contain no record payload, learner/class identifiers, permissions or arbitrary
URLs. There is no browser storage, file write, API write, preference persistence or account link.
Existing institutional summary, calendar, phone workspace navigation and core qualification
clients retain their own boundaries.

## Review

The authorized primary, secondary and UI profiles independently approved the bounded implementation
after source and rendered review. All inspected the actual Home editor/applied phone images and
applied desktop image, alongside the app-editor/applied phone images. These are AI design reviews,
not representative-human or release evidence.

| Profile | Disposition and evidence | Coordinator response |
| --- | --- | --- |
| Primary education | Approve: canonical destinations, personal section meaning, institutional summary/calendar, honest temporary state and recovery preserved | Accept within the authorized synthetic slice |
| Secondary education | Approve: custom headings do not merge subject/pastoral contexts or change assignments; college Contacts retained | Accept; neutral contacts search wording applied |
| UI and interaction | Approve after conditions: editor entry and Make default must hand focus to a surviving control | Modify: heading receives entry focus; default selection returns focus to the layout selector; Enter-key assertions passed across all four institutions |

The root demo provider renders the first complete shell without a loading boundary that could
consume the first Tab before the skip link is available. Invalid names receive focus and an
associated error. Restored full-page history remounts the provider's descendants to discard drafts
as well as applied state; unit coverage checks both.

Live inspection confirmed the unfocused skip link lies above the viewport. Its overlap in early
full-page captures was a capture artifact from a scrolled viewport; the final exports start
at the top. App test captures explicitly scroll the focused global navigation into view.
The skip link itself remains available by keyboard. Local captures are retained under
`clients/web/playwright-report/layout-editor-review/` (ignored verification artifacts).

Architecture Advisor transport was unavailable because its parent runtime could not be verified.

## Verification

| Exact check | Result |
| --- | --- |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_layout_editor_20261025 make check` | Failed with exit 2 at core tests: **448/462 passed, 14 failed**. Documentation, repository tooling, pack validation and preceding core static/contract/migration/audit stages passed. Core final stage, web and shell stages were not reached by this command |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_layout_editor_web_20261025 CHIMWEMWE_DEMO_E2E_PORT=3100 make check-web` | Web prechecks passed: generated client, both npm audits (zero findings), formatting, lint/style contract, types, 8 token tests, 5 dependency guards, **59 unit tests** and production build. **106 browser tests passed**: UI-0 36, core connection 6, unavailable core 1, classroom 3 and four-institution demo 60. The final staff suite could not start because `https://localhost:3015/sign-in` was already in use; overall command exited 2 |
| `CHIMWEMWE_DEMO_E2E_PORT=3100 mise exec -- npm run test:e2e:demo` under the web-qualification lock | **60 passed** across all four packs, including editor keyboard entry/default selection, preview/cancel/apply, aliases/search, independent Home/app state, scoped resets, institution/history lifecycle, no storage/writes, phone recovery/validation/movement, overflow and axe checks |
| Same demo command with `-- layouts.spec.ts --grep 'phone editing'` | **4 passed** after correcting full-page capture positioning; final app phone images regenerated |
| `make check-tooling` | Passed independently after the full run stopped |
| `make docs-check` and `git diff --check` | Passed after the documentation updates |

The first browser attempt correctly refused another chat's live qualification lock. After it
cleared, initial browser runs exposed the loading/first-Tab issue; it was repaired and the final
suite passed. A first standalone web attempt found one formatting issue, which was corrected
before the qualified run above. No competing process or lock was removed.

Manual browser inspection applied a Teaching day Home with Teaching & learning and Student support
sections, checked visible canonical links/context, and captured both 320px and 1440px layouts.
Representative educator usability, connected preferences, persistence and template-sharing trials
were not run and are not part of this local increment.

## Integration reconciliation and remaining blocker

The initial 14 core failures were in separately owned work: five communications-source-fence qualification
tests, six staff-audience race tests, two classroom foundation tests and one People foundation
test. Failures include unexpected `retryable_dependency` results and source-fence ordering. See
[`communications_source_fence_qualification_test.exs`](../../apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs),
[`staff_audience_race_test.exs`](../../apps/chimwemwe_core/test/chimwemwe/people/staff_audience_race_test.exs),
[`classroom/foundation_test.exs`](../../apps/chimwemwe_core/test/chimwemwe/classroom/foundation_test.exs)
and [`people/foundation_test.exs`](../../apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs).
Those files and the concurrent persistence/attendance repairs were not changed for this editor.

The owning chat subsequently repaired its test setup and ran a fresh full shared-checkout
`make check`. Inspection of `/tmp/chimwemwe-nested-full-20261025-02.log` confirmed **462 core tests
passed**, **59 web unit tests passed**, and **106 browser tests passed**, including all 60 demo
tests. This clears the initial core blocker. That full run then exited 2 at the same occupied
staff endpoint, before any staff browser test ran. Its final shell stage was not reached;
`make check-tooling` was independently executed successfully above. This is another chat's
observed verification result, not an additional command claimed as executed by this editor's
coordinator.

The occupied staff endpoint was observed on port 3015 (PID 85906 at qualification time). Its
running app was preserved; the staff browser suite remains **not run** in this qualification.
The existing staff launcher/config fixes its ports, so an alternate port was not substituted.
Full repository green remains unestablished.

Concurrent changes to persistence/attendance qualification and source-fence records are outside
this editor slice and are preserved. No repository-green, connected-preference, real-data,
human-usability or production claim follows from the local editor.

## Qualification follow-up — 26 October 2026

François requested the [Classroom workspace proposal](../plans/classroom-workspace-integration-proposal.md)
and a fresh staff browser run. No runtime code or data adapter was changed in this follow-up;
the proposal preserves flexible labels and separates new staff-owned presentation routes from
the four-pack viewer. Its runtime increment remains proposed.

The previous qualification-port conflict is cleared. The staff suite started, but its one test
failed at `accounts.spec.ts:183`: Add access profile remained disabled; its failure snapshot
showed the profile placeholder selected. The cause is not established and no staff code or test
guard was modified. This supersedes the occupied-port limitation as the current staff result.

The separate web check passed both npm audits, generated client/format/lint/type checks, 8 token
tests, 5 dependency guards, **63 unit tests** and production build. The four-institution demo
repeat passed **60 browser tests**, including flexible groups/Home editing, phone reflow,
keyboard access and institution/history isolation. Documentation, shell tooling and whitespace
checks passed separately.

The required fresh `make check` stopped at the core dependency audit: Hex reported 20 advisories
across Bandit, Ash and JOSE (11 high, 9 medium). Later core/static/test and web/browser stages
were not reached by that command. Exact commands, skipped suites and retained local log paths
are in the proposal's verification record. These current failures prevent repository-wide green;
other chats' staff, dependency and classroom changes remain preserved.

The subsequently authorized [staff/dependency repair](staff-directory-request-lifetime-evidence.md)
closed both failures. The single coordinated full check passed with 483 core, 69 web unit and
107 browser tests, including the staff journey and all 60 demo tests. Runtime sources were stable
during that gate; no active dependency advisory remains. This supersedes the earlier blockers
without changing this demo's memory-only or synthetic-data boundary.
