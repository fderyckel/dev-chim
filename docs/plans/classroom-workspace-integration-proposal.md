# Classroom workspace integration proposal

- Status: CW-1 implemented and locally verified on 2026-10-27; CW-2/CW-3 remain later increments
- Date: 2026-10-26
- Accountable owner and decider: François — Project Owner
- Delivery functions: Product experience, classroom application and identity/platform engineering
- Authority: François requested the proposal and subsequently authorized its CW-1 implementation on 2026-10-27, preserving flexible labels, all four institutions, phone navigation and other chats' changes, with one coordinated final `make check`
- Governing direction: [Classroom-first plan](classroom-first-six-week-plan.md) and [application navigation proposal](application-navigation-and-workspaces-proposal.md)

## Recommended next increment

Bring the existing authenticated, synthetic classroom journey into a coherent Classroom workspace:

**Home or Apps → Classroom → My classes today → assigned daily register → attendance → confirmed saved result.**

Reuse the existing classroom actions, staff sign-in and current navigation hints. The next
implementation changes orientation and presentation only. It must preserve the existing
submission, correction and uncertain-result recovery contracts. This document prepares that
increment; the authorized implementation is governed by [ADR 0057](../adr/0057-local-classroom-workspace-navigation.md) and does not reopen the classroom-first priority.

The four-institution viewer stays independently runnable. Its fictional directories and calendar
remain read-only; selecting Bangkok, the college, kindergarten or English school never selects
an authenticated tenant or supplies a classroom assignment.

## Flexible organization, stable destinations

| Layer | Educator or institution arrangement | Stable contract |
| --- | --- | --- |
| Global navigation | No additional top-level tab for each new module | Home, Apps, identity/context and recovery stay reachable |
| App groups | Teaching & learning may become Classroom work, Planning or another short label; approved entries may move or have aliases | Stable destination IDs, canonical page names, data sources and named actions |
| Classroom workspace | Classroom can be placed in any approved group | My classes means current assigned work; attendance keeps its exact register/date and purpose |
| Personal Home | Rename/reorder sections and place available workflow entries independently of institution grouping | No class IDs, student records, saved marks or permissions in the arrangement |

Changing a label, group or starting layout changes placement only. It cannot choose a tenant,
switch a class/date, grant a role, activate a module or rename Submit attendance into another
action. Canonical task names remain visible in search, the workspace and action confirmations.
Aliases resolve to one destination and one search result. Empty layouts retain Apps and reset.

The approved demo editor remains memory-only. Durable personal layouts, shared institution
publication, team templates and default adoption are separate later increments. This proposal
does not add a layout payload to the concurrent staff-preferences contract.

## Concrete workspace and phone behavior

### Proposed staff-owned entrances

CW-1 proposes exactly two new browser presentation routes, `/staff/home` and `/staff/apps`.
Home and Apps links in the staff frame target these paths. `/classroom` retains the existing
My classes/attendance route; `/accounts`, `/my-preferences`, `/sign-in` and first-login password
replacement keep their current contracts. Existing login landing choices remain unchanged;
this increment does not save a new starting-page preference.

Add the two paths explicitly to the staff navigation allowlist when implementing CW-1. No
generic return URL, fixture-root fallback or client-selected scope is allowed. The current
`requireStaffDemo()` checks environment and loopback Host only. Each new page renders an inert
loading/blocked frame until both the existing `/api/v1/session` and own
`/api/v1/staff-preferences` reads succeed. Those reads provide confirmed identity and disposable
destination hints; Phoenix still enforces every destination/action. Missing/malformed hints
hide optional entries. Failed/current-session reads clear protected self presentation and
provide sign-in or retry recovery without an inventory probe.

Staff Home offers the currently available Classroom entry; Staff Apps lists only the existing
hint-approved destinations and own-preferences recovery. Neither page reads or prefetches
classes, roster names, counts or marks. They do not use the four-pack selector/banner,
`DemoLayoutProvider`, demo `/`, `/demo/apps`, or `AppShell`'s fixture Example account/Home links.
The implementation uses bounded group IDs, labels and approved references as presentation
configuration, keeping labels separate from route/action identity. Its initial composition is
code-owned defaults; connected layout editing remains CW-2/CW-3. Existing demo editing is intact.

### Daily-register task

The first workspace has one primary entry, **My classes**, followed by the selected register's
**Attendance** task. A teacher with one assigned class still sees its explicit identity. Multiple
classes use their current owned labels and returned dates. This is the existing daily-register
workflow; the current assigned-class response supplies only ID, label and local date, not a
register-type or multi-campus context field. If approved labels/dates do not distinguish two
assignments, require source-label clarification; never guess a class, show an opaque ID as a
substitute for meaning, or invent subject/year/pastoral metadata. That collision triggers source
contract review, rather than a new field or permission in CW-1.

Today is supplied by the writer in the pinned academic year's time zone. Show that date and the
selected register beside the roster and submit/correction controls. Each assigned class owns its
returned local date; the browser does not assume one universal today for every class. No zone,
academic-year or institution label is fabricated from fields the response does not supply. No arbitrary date picker,
backdating, lesson-attendance model or college course-session workflow is added. The four demo
institutions retain their own reviewed terms and fixed dates; this daily-register proof does not
qualify school attendance semantics for the college or kindergarten.

Desktop uses a compact local task menu. Phone uses one labelled workspace disclosure with the
same entries and current selection; it does not squeeze a permanent sidebar into 320 pixels.
Opening a workspace replaces its local menu. Home and Apps remain visible and keyboard/touch
reachable. Keep one clear primary action, explicit state, sufficient touch targets and focus
handoffs. Secondary explanation belongs in focusable/touch-accessible help.

Changing class or leaving Attendance through application-controlled Home/Apps/local links must
offer Stay or Discard for a known draft; Stay retains marks and focus. Guard browser-history
navigation where the application can control it and warn on full departure where supported.
A forced reload/close, process termination or declined unload warning can discard memory; do
not promise that these departures are preventable or that a pending request survives them.

A known uncertain submission/correction requires authoritative reconciliation before another
class or attendance write. Application navigation offers reconciliation instead of silently
discarding that state. Sign-out remains available when a result is uncertain, and loss of
authority clears records immediately; neither is conditional on retaining permission to reconcile.
Signing out or leaving does not prove an uncertain action was cancelled. Reentry requires fresh
authority and an authoritative read, with no automatic replay or optimistic Saved status.
An exact pending-request locator or recovery key is not persisted in this increment.

At the writer's local-day rollover, keep the opened register's original date visible and obey
the existing refusal/reload contract. Never move draft marks or an uncertain request into a new
day. If the bounded current-day read no longer permits reconciliation of a previous-day action,
show that limitation and require authorized records follow-up; do not infer its result, backdate
or broaden history reads. Saved confirmation retains its PostgreSQL-backed meaning. Earlier
correction revisions remain durably retained, but CW-1 adds no correction-history screen or
collection; the current read exposes only its present revision/correction state.

### Calendar is context before it is another destination

The classroom response already supplies the authoritative local date and pinned calendar basis.
Use that context in the first workspace. The existing `/academic-calendar` page is an owned
preparation/publication workflow, not an educator's personal Calendar read. The four-pack Calendar
is another independent source. Neither becomes the educator's Calendar merely through a link.

A later Calendar entry requires its own reviewed bounded read and capability/source contract.
Until that exists, omit that entry from the working workspace; retain it only in the broader
capability proposal. This narrows the earlier illustrative My classes/Calendar/Attendance menu
without removing either existing calendar experience.

## Source and identity boundary

| Existing surface | Current source and protection | Proposed use |
| --- | --- | --- |
| Four-institution Home/Apps and `/demo/*` | ADRs 0046/0048: allowlisted pack, digest/tenant checks, loopback guard and explicit demo selection | Preserve every current route, institution choice, editor and phone menu; no classroom record join or new operational link |
| Staff own presentation | ADR 0055: own-preferences display name and exact `navigation.classroom` / `navigation.accounts` hints, no privileged inventory probe | Reuse confirmed identity and current optional destination hints; malformed/missing hints hide optional entries |
| Proposed `/staff/home` and `/staff/apps` | Harness exposure guard plus successful existing session/own-presentation reads before identity/optional links | Staff-owned Home/Apps; no new API, demo provider, roster prefetch or automatic login/default change |
| `/classroom` | Existing staff/session-bound classroom controller and generated client | Host the proposed workspace around the existing assigned-class/attendance flow |
| `/classroom/setup` and connected calendar preparation | Separate exact preparation workspaces and administrative action contracts | Retain existing qualification entry points; do not advertise them through a teacher hint or assume administrator authority |

Share inert navigation/heading/disclosure presentation from the shell, not the demo data adapter
or `DemoLayoutProvider`. The first connected candidate uses a code-owned default arrangement.
Reusing its appearance does not make the four-pack selector, URL `demo` parameter, browser
storage or client context an actor, tenant, institution, placement or source selector.

Use only the existing same-origin endpoints for session/own presentation, today's assigned
classes, attendance preparation, submission and correction. No new generic endpoint, collection,
navigation registry, resource enumeration, migration or persisted field is proposed for this
first increment. Availability hints remain disposable; every read/action rechecks the actual
session, staff association, current teaching assignment, module gates and capabilities.

Preserve the present limits: 12 assigned classes, 60 roster members per class and the tenant/actor/
UTC-day cumulative ceiling of 12 distinct classes and 720 distinct people. Navigation, aliases
and layouts cannot reset that budget. The named actions retain pinned calendar/roster basis, idempotency,
append-only correction, concurrency refusal, audit and Restricted outbox guarantees. A server
denial never falls back to a directory pack, cached roster, guessed role or another institution.
On session loss, logout, identity change or protected-history restoration, clear/revalidate
records and self presentation before rendering them again.

## Delivery and acceptance

| Step | Deliverable and owner function | Go / conditional / no-go |
| --- | --- | --- |
| CW-P — 26 October proposal | This dated proposal, source inventory, specialist dispositions and test result; product/platform engineering | Completed paper review; historical verification and subsequent repair closure below |
| CW-1 — authorized implementation | Reuse the shell's inert presentation around the current staff classroom flow, with a small task menu, default Home/Apps entrance and draft-safe departure; classroom/client engineering | Authorized on 27 October; actual implementation, specialist closure and final qualification belong in [CW-1 evidence](../phase-2/classroom-workspace-evidence.md) |
| CW-2 — later personal composition | Separately reviewed approved Home entries/blocks with an exact context resolver and eligible sources; classroom/product experience | Conditional on CW-1's demonstrated journey; no generic renderer or fixed-class shortcuts inferred from available resources |
| CW-3 — later durable arrangements | Actor-and-tenant-qualified save/default/reset, revision conflict handling, separate shared-profile capabilities and explicit template adoption; identity/platform/product | No-go in CW-1; requires its own contract/ADR and authorization |

The proposed CW-1 completion checks are:

1. Staff sign in through the existing local credential flow; only confirmed available entries
   appear. An ordinary staff account retains its preferences landing. Job titles and group labels
   do not supply access; direct/stale links still exercise the original denial paths.
2. An assigned educator opens today's exact register, deliberately marks every student, submits
   once, refreshes and reads the confirmed result. Preserve correction, stale-basis conflict,
   lost-response reconciliation, session/assignment revocation, unassigned and cross-tenant denial.
3. Draft departures cover class selection, staff Home/Apps, local menu, Back/Forward and full reload.
   Cancellation retains marks. Test controlled departure versus forced reload/close, uncertain
   submission and correction, sign-out and session loss separately. Reentry never assumes that an
   uncertain action failed or succeeded. Cross the writer's local midnight with draft and
   uncertain states; marks and requests never migrate to another date. Record limitations when
   the original date can no longer be read under the current bounded contract.
4. All four directory packs retain Home/Apps/workspace navigation, flexible labels, alias/search,
   editor apply/cancel/reset, source isolation, invalid-selection refusal, institution switch,
   refresh and history. No learner/register payload crosses the two proof contexts.
5. Desktop, 768px and 320px checks cover confirmed identity and source-supplied class/date/state, keyboard and touch,
   disclosure/error/dialog semantics, meaningful focus, long/localized labels and no horizontal
   page overflow. Keep layout drafts separate from attendance drafts. Record axe results and
   clean rendered captures; do not capture credentials, cookies or tokens.
6. Run generated-contract checks and the appropriate existing core/unit/browser suites, including
   staff, classroom and all four demos, then `make check`. Record failed/skipped stages explicitly.

Product experience owns preparing a representative teacher walkthrough; François arranges the
actual participants. Human usability remains not run. AI source/design approval does not replace
independent privacy/security, real identity, selected-environment, real-data or release gates.

## Review and verification record

The 26 October proposal request changed documents only. Its paper review changed no runtime
workspace, menu, data source or school workflow. CW-1 was subsequently authorized on 27 October;
the [implementation record](../phase-2/classroom-workspace-evidence.md) supersedes that paper-only
boundary for the bounded delivered candidate. The authorized primary, secondary and UI profiles reviewed the paper and
current source independently; no rendered Classroom candidate or human trial was claimed.

| Profile | Initial disposition and required clarification | Coordinator response |
| --- | --- | --- |
| Primary education | Approve with conditions: exact staff entrances; no invented register type; logout/revocation must not create a reconciliation trap; retained revisions versus history UI; local midnight | Modify: dedicated staff paths, minimal response fields, recovery/authority split, no history enumeration and rollover trials made explicit |
| Secondary education | Approve with conditions: separate proof sources; per-class dates; no inferred college/subject/campus metadata; honest forced-departure recovery and cumulative ceilings | Modify: exact source/route map, label-collision review, limits and memory-loss boundary incorporated |
| UI and interaction | Approve with conditions: staff-owned Home/Apps and explicit allowlist; exposure guard is not authentication; no fixture account/root links; compact task menu and bounded departure promises | Modify: two protected presentation routes, successful existing reads before display, unchanged login landing and narrow menu specified |

All three profiles reread the refined document and returned **approve** on 26 October; their
initial conditions are closed at paper level and no material design challenge remains.
These are AI design reviews, not
independent security/privacy or release acceptance. Admissions is not instantiated: applicant, family-recipient and offer/enrolment semantics
are unchanged. Architecture Advisor preflight returned `parent_runtime_unavailable`; no Advisor
approval is claimed.

### Executed verification on 26 October 2026

| Exact check | Result |
| --- | --- |
| `cd clients/web && ../../bin/with-verification-lock --resource web-qualification -- mise exec -- npm exec playwright -- test --config playwright.staff.config.ts` | Started on free qualification ports; **1 failed**, at access-profile selection (`accounts.spec.ts:183`). Trace/video/automatic credential captures remained disabled; no access guard or test expectation was changed |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_workspace_proposal_20261026 CHIMWEMWE_DEMO_E2E_PORT=3100 make check` | **Failed, exit 2** at core dependency audit. Documentation, repository tooling/fixture checks and preceding core format/compile/contract/migration/lint stages passed. Hex audit reported 20 advisories: Bandit 11, Ash 1, JOSE 8; 11 high and 9 medium. Dialyzer/core tests, full web/browser and final shell stages were not reached by this command |
| `make web-check` | **Passed**: generated-client checks, both npm audits (zero findings), formatting, lint/style contract, types, 8 token tests, 5 dependency guards, **63 unit tests** and production build |
| `cd clients/web && ../../bin/with-verification-lock --resource web-qualification -- env CHIMWEMWE_DEMO_E2E_PORT=3100 mise exec -- npm run test:e2e:demo` | **60 passed** across all four institutions, including flexible labels, independent Home arrangements, phone/keyboard navigation, aliases/search, editor state/reset, institution/history isolation and automated accessibility |
| `make check-tooling` | **Passed** independently after the full run stopped |
| `make docs-check` and `git diff --check` | Passed after the proposal/refinements; repeated after final evidence |

Logs are retained locally as `/tmp/chimwemwe-classroom-workspace-{staff,full,web,demo,tooling}-20261026.log`.
Standalone UI-0, core-connection and classroom browser suites were not rerun in this document-only
request after the full gate stopped. Their historical passes do not establish current full
qualification. The paper's proposed CW-1 acceptance trials remain **not run**.

The initial staff browser repeat started on the now-free qualification ports, then failed at
`tests/staff/accounts.spec.ts:183`: Add access profile stayed disabled after selecting Classroom
teacher; the failure snapshot showed its placeholder selected. At that checkpoint this was a qualification
failure replacing the previous occupied-port block. No staff code, test expectation or access guard
was changed to obtain a pass. A source-level hypothesis is that an overlapping or late account
inventory load resets the controlled selection to the account's current roles. The review did
not establish the request ordering, so this is **not a confirmed root cause**. Identity/client
engineering should capture synthetic request/selection ordering before fixing it; the disabled
guard and complete qualification assertion must remain.

The audit result is a required qualification stop, not an exploit/reachability assessment.
Dependency versions, locks and the other chat's runtime work were preserved in that proposal-only
increment. Neither its paper approval nor the passing scoped web checks established repository-wide green.

### Subsequent authorized repair closure — 26 October

François then authorized fixing both blockers and coordinating one full gate across the active
chats. The [request-lifetime repair and final evidence](../phase-2/staff-directory-request-lifetime-evidence.md)
records the reproduced selection reset, stale response/departure guards, retry recovery and
dependency-owner handoff. Ash 3.37.2, Bandit 1.14.0 and JOSE 1.11.13 clear the 20 active findings.
The staff journey passed standalone and in the single full `make check`, which exited 0 with
483 core, 69 web unit and 107 browser tests. All 60 four-institution demo tests passed. No
required maintained stage was skipped; runtime/test/configuration source bytes remained stable
through the gate. The two repair blockers are closed. CW-1 runtime integration itself remains
proposed and has not been implemented by this repair.

### CW-1 implementation closure — 27 October

François subsequently authorized runtime CW-1. The [implementation evidence](../phase-2/classroom-workspace-evidence.md)
records staff-owned Home/Apps, flexible code-owned composition, phone task navigation,
draft/request recovery repairs, three-profile source/rendered approval and the final successful
`make check`: 559 core, 102 web unit and 109 browser tests. Four-institution demo editing remains
intact; connected layout editing/persistence remains CW-2/CW-3. Historical failed attempts above
remain retained rather than being relabelled as passes.

## Governing records and rollback

This proposed composition retains [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md),
[ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md),
[ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md),
[ADR 0037](../adr/0037-class-register-enrolment-and-placement.md),
[ADR 0038](../adr/0038-local-classroom-attendance-workflow.md),
[ADR 0040](../adr/0040-session-bound-classroom-preparation-workspace.md),
[ADR 0041](../adr/0041-local-attendance-correction-and-recovery.md),
[ADR 0043](../adr/0043-governed-model-and-workflow-views.md),
[ADR 0046](../adr/0046-selected-local-demo-institution.md),
[ADR 0048](../adr/0048-local-demo-application-shell.md) and
[ADR 0055](../adr/0055-staff-self-presentation-and-navigation.md).
Before a later implementation changes a stable boundary, add/amend a Proposed ADR or supersede
an Accepted ADR as applicable. Threats TM-01/02/04/09/13/16/17/19/20 in the
[threat model](../security/threat-model.md) remain relevant. No production gate is closed here.

Keep the existing staff/classroom entry points independently usable. A failed shell composition
falls back to those routes within the same authenticated context, preserving authoritative
attendance and refusing guessed source/tenant fallbacks. With no persistence migration in CW-1,
removing its presentation must not alter school records or the four-institution viewer.
