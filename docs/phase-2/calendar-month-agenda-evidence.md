# Shared Month and Agenda calendar evidence

- Date: 2026-10-23
- Owner: Product experience and client engineering
- Authority: François's instruction to implement the first increment in the local fictional demo
- Governing record: [ADR 0043](../adr/0043-governed-model-and-workflow-views.md)
- Plan: [Calendar view increment](../plans/calendar-view-proposal.md)
- Status: Local synthetic implementation verified; representative and release gates retained

## Delivered behaviour

The selected institution demo's Calendar page now uses `ModelViewWorkspace`. Calendar provides
Month and Agenda modes, date navigation/jump, an explicit Example date, type filtering, complete
selected-day entries, overflow disclosure, continuing ranges and read-only record details.
List shares the month, filter and selection. Narrow layouts initially choose Agenda; explicit
mode choice persists during that workspace's lifetime. Agenda does not repeat the selected day
below its already-complete chronological entries.

The reusable implementation lives in `clients/web/src/model-views`. The demo supplies its own
field mappings, namespaced source identities, inclusive dates and explicit coverage/context.
`scopeField` and `contextStatuses` are optional code-owned mappings; calendar display context is
optional. A separate project-milestone test source uses different fields and meaning. A source
declaring only List/Form receives no Calendar or other view automatically.

The adapter retains institution/year identities, explicit instructional weekdays, calendar zone
and period vocabulary. Display week start is separate from instructional weekdays. Teaching
periods are quiet range context; student closures retain `all students · no instruction`; events
remain information only. College session-specific deadlines retain separate identities/scope.
Invalid record identity/date/range/display fields or invalid display context fail visibly.

## Boundaries

The calendar increment adds no core resource, table, migration, new API/read, identity, mutation, scheduler, timed
event, recurrence, stored definition, runtime model discovery, tenant switcher or release.
Details use only records already supplied by the validated selected-demo adapter. Existing
calendar-preparation named actions and Form override remain owned by that workflow. Its synthetic
records cannot be edited through the selected-demo viewer. Dates remain inclusive local dates.

## Executed technical checks

| Check | Result |
| --- | --- |
| Focused calendar/workspace/preparation/demo unit tests | 21 passed after Agenda duplication cleanup; final shared-view suite has 10 passing tests including UI repairs, explicit weekdays and partial-month coverage |
| `make web-check` | Final rerun passed dependency audits, formatting, JavaScript/CSS/style contract, TypeScript, token/dependency tests, 52 unit tests and production build, including the last partial-month correction and concurrent demo-shell changes |
| `npm run test:e2e:demo` | 16 passed independently; 16 passed again in the complete integration run with the final responsive/empty-state repairs |
| `CHIMWEMWE_DEMO_E2E_PORT=3060 npm run test:e2e:demo` | An intermediate shared-checkout rerun had 20 passes and 4 selector Back-navigation failures. The selector disabled native form autocomplete and the final demo run passed all 24 tests across the four startup contexts |
| Demo browser coverage | Month/Agenda/List, source-specific deadlines, staff event/student closure, keyboard detail open/close/focus, retained context, fixed reference date, responsive mode at 1440/768/320 and narrow Month opt-in |
| Browser date coverage | America/Los_Angeles and Pacific/Auckland; fixed all-day dates across the November daylight-saving boundary |
| Browser accessibility | Automated axe scans and no page overflow at the tested widths, including optional narrow Month |
| Synthetic overlap fixture | 600 same-day entries plus one two-year context range validate without dropped identities; 600 same-day details render with at most 42 grid cells under a four-second local regression budget; leap-day and Sunday/Monday layout checks pass; this is not school capacity evidence |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_final8_20261023 make check` | Passed on the final combined checkout: documentation and repository tooling; 335 core tests; both web dependency audits; formatting, lint, types, 52 unit tests and production build; 70 browser tests (36 foundation, 6 bridge, 1 unavailable bridge, 3 classroom, 24 institution demo); shell tooling. No required stage skipped |
| `git diff --check` | Passed; repeated after evidence updates |

Screenshots are generated under `clients/web/playwright-report/demo-instance-results/` for each
institution. Desktop, phone Agenda and optional phone Month captures were inspected by the
implementing agent and the UI specialist. These are executable synthetic checks and AI visual
inspection, not representative-human usability or independent accessibility certification.

Earlier attempts were reported and repaired: one integration run stopped on a concurrently
edited ADR 0045/index mismatch, and the next exposed an old narrow-screen assertion tied to a
fixed count of repeated closure text. The regression now verifies accessible closure content in
either calendar mode. A separate web qualification attempt respected another chat's lock.
The complete integration run above finished successfully after these conditions were resolved.
The final one-line partial-month navigation correction and its regression test were added after
the integration build; focused tests and the final full web check cover that last change.
Concurrent local-demo selector work was preserved. Its shell/projection edits were included in
the final web check and four-institution browser rerun. That rerun first exposed the separate Back
navigation condition above; the selector owner repaired it and the final combined gate passed.
The Playwright demo configuration now accepts a validated
`CHIMWEMWE_DEMO_E2E_PORT` base port so four test servers can avoid another chat's occupied ports.

## Specialist disposition

All three profiles reviewed the implementation read-only on 2026-10-23. The coordinator accepts
their recommendations within the authorized increment:

| Profile | Disposition and evidence | Conditions / coordinator response |
| --- | --- | --- |
| Primary education | Approve with conditions; source preserves closure/staff distinction, explicit weekdays/year identity, inclusive dates and no invented kindergarten timetable | No blocking domain repair; root owns executed checks. Added a Tue/Sat fixture test independent of Sunday display week start; accepted |
| Secondary education | Approve with conditions; source preserves continuing period context, distinct session deadlines, exact scope and inclusive ends | No blocking domain repair; retain exact-calendar identity before any later multi-calendar adoption and record root browser checks; accepted |
| UI and interaction | Approve after inspecting refreshed desktop, phone Agenda and phone Month screenshots and the repaired source | Narrow Month now uses compact counts, List has explicit no-match/clear-filter recovery, and Agenda avoids duplicate selected-day cards. Final read-only re-review closes both remaining conditions; accepted |

Their owner functions are education product, frontend/client engineering, accessibility ownership
and the implementing coordinator. Root-owned tests are distinct from their source and screenshot
inspection. No reviewer closes real-data, independent security/privacy, representative institution
or production-release gates.

## Reuse and retained work

Another approved source declares a `calendar` view with title/start/optional end and optional
status/scope mappings, then supplies bounded records to the workspace. Exact coverage/reference
semantics belong to an optional `CalendarViewContext`; the renderer never discovers or fetches
them. Consumer field names and school rules do not enter the shared renderer.

Week/Day timed views need the explicit date-time/zone contract in the plan. Gantt, further timeline
views, recurrence and editing remain separate increments. Actual representative trials and
connected adoption remain `not run` and gated. Advisor consultation was skipped for execution of
the settled plan; delegated specialist reviews own the relevant design assessment.
