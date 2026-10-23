# Reusable calendar view proposal

- Status: Proposed; paper design only, implementation awaits François's green light
- Date: 2026-10-23
- Owner: Product experience and client engineering
- Governing direction: [ADR 0043](../adr/0043-governed-model-and-workflow-views.md)
- First proposed consumer: the startup-selected, local fictional institution demo
- Review basis: [Delegated specialist profiles](../development/specialist-review-team.md)

## Recommendation

Make Calendar a reusable presentation of an explicitly approved dataset. Improve the existing
model-view renderer and use it in the institution demo's Calendar page. Start with a useful month
calendar and an accessible agenda. Keep List as an alternative presentation of the same records.
Develop timed Week/Day, Gantt and other timeline experiences in subsequent bounded increments.

This is a proposal for the next local synthetic increment, called MV-2 here. It does not authorize
implementation or change an Accepted architectural boundary. ADR 0043 remains Proposed; its
existing MV-1 authority and all connected, real-data and release gates remain unchanged.

## Current checkout evidence

| Existing piece | What it supplies | Gap addressed by this proposal |
| --- | --- | --- |
| [View contract](../../clients/web/src/model-views/model-view-contract.ts) | Explicit `list`, `form`, `calendar` and `gantt` types; declared fields and date mappings | Reuse this contract rather than introduce a second calendar framework |
| [View workspace](../../clients/web/src/model-views/model-view-workspace.tsx) | Basic month grid, previous/next month, date selection and simple read-only Gantt | Clear ongoing ranges, overflow disclosure, agenda, record selection and shared navigation state |
| [Calendar preparation](../../clients/web/src/components/academic-calendar-preparation.tsx) | Calendar as its default, with a workflow-owned editable Form override | Preserve its existing writer and date-resolution behaviour while improving shared presentation |
| [Institution demo](../../clients/web/src/components/demo-instance-view.tsx) | Separate lists of teaching periods, student closures and informational events | Its Calendar page needs an actual calendar layout |
| [Demo projection](../../clients/web/src/lib/demo-instance.ts) | Prepared fictional calendar records with inclusive `from`/`through` dates and scope labels | Add only explicit local presentation mappings needed to retain source meaning |

The existing month grid shows at most two event titles on a day without an overflow control.
Long-running periods are usually labelled only on their first day or the selected date. Navigating
into a later month can therefore lose their visible names. These are source-code observations,
not a live visual or representative-user review.

## Experience

The page leads with the institution's calendar title, academic-year label, calendar scope and
time zone. Its compact toolbar offers Calendar/List, previous/next, the visible month, a labelled
date jump, and a return to the example date. Month/Agenda are modes inside Calendar, not additional
model-view types. Do not show unavailable modes or unrelated workflow controls.

| Need | Proposed behaviour |
| --- | --- |
| See the school month | Numbered date grid with a clear selected date and readable weekday headings |
| Understand terms and semesters | Quiet range bands with names, exact dates on selection, and continuation cues across weeks/months |
| Recognise closures | Written closure type and affected scope, with a visual treatment distinct from ordinary events |
| Read everything on a busy day | A labelled `+N more` control opens that day's complete agenda; nothing is silently hidden |
| Inspect an entry | Read-only details show title, type, exact inclusive dates and supplied scope; no new record fetch |
| Work on a phone | Agenda initially, with Month still available; choosing a mode explicitly persists for the mounted workspace |
| Move between views | Preserve date range, filters and stable selected record in memory; do not reset to the earliest event |
| Recover from an empty period | Distinguish no matching entries, no entries in the supplied range, invalid data and unavailable data |

Agenda is chronological within the visible month, grouped by date. Ongoing teaching periods are
shown as range context rather than repeated full event cards on every instructional day. A selected
day includes all entries whose ranges overlap it. List uses that same range and active filters,
with a visible range label, and shows one row per source record rather than expanding ranges.

Initial filters are only supplied entry types: teaching periods, student closures and events.
Any scope selector must use explicit source identities already supplied by the selected demo,
never parse labels or obtain records from another institution. If the source does not establish
an exact association, display its supplied scope and state the limitation; do not invent one.

Use the institution's terms, semesters or other supplied labels. Do not infer age, year level,
class membership, lesson attendance, staff leave, or a teaching timetable from a calendar entry.
An informational event never changes instructional-day status. A student closure never means
that all staff are off duty. Calendar visibility never creates learner or family account access.

### Interaction and concise language

- A date control selects a day; a separate entry control selects an event. No nested buttons.
- The month grid uses one documented keyboard pattern with visible focus, arrow-key date movement,
  an announced selected date, and a labelled route into the day agenda. View-tab arrows remain
  separate from date navigation. Agenda provides equivalent access without operating the grid.
- Details appear beside/below the calendar on wide screens and as a dismissible panel on phones.
  Opening, closing and returning focus have explicit keyboard and touch behaviour.
- Type, scope, selected state, exact dates, errors and empty states are visible in words. Colour
  is redundant. Secondary explanations may use labelled question-mark help with focus/tap/hover
  access and a dismiss path; necessary consequences stay visible.
- In the fictional demo, use `Example date`, not a misleading `Today`. Keep the fixed date visible.
  A later live workflow would resolve Today in its explicit calendar zone.
- Week headings and date formatting come from a code-owned consumer locale configuration. Do not
  hard-code Monday or English into the reusable component or equate a weekend with a closure.

## Reusable view contract

Retain the direction documented in [governed model views](../architecture/governed-model-views.md):
owned source/read result -> explicit display definition -> renderer. A consumer opts into Calendar
only when dates have a reviewed meaning. Merely having a date field never makes a model eligible.

MV-2 should use small typed consumer adapters and the existing renderer dispatch. A plugin loader,
runtime model discovery, tenant-authored definitions or universal event database is unnecessary.

| Contract concern | Proposed rule |
| --- | --- |
| Source and identity | Retain stable `sourceRef` plus source record identity; namespace period/closure/event IDs to avoid collisions |
| Fields | Use only explicitly declared display fields; retain entry type and exact supplied scope |
| Calendar mapping | Retain title/start/end mappings; declare supported modes and initial mode as code-owned presentation options |
| View state | Workspace owns selected date, visible range, active mode/filter and selected source key in memory |
| Source replacement | Reset state when the source changes; when filtering removes selection, show that state and clear stale details |
| Definition validation | Unknown kinds/versions, undeclared fields and incompatible date mappings produce a bounded unavailable state |
| Record validation | Invalid dates, reversed ranges, missing identities or duplicate source keys produce a visible data error; do not silently drop entries |
| Compatibility | Keep existing MV-1 definitions and preparation behaviour working; version any incompatible date contract rather than reinterpret `date` |

The local demo adapter may add narrowly allowlisted presentation fields from its already-validated
pack if needed. It must preserve code-owned kind/scope associations instead of reverse-engineering
the human-readable `scope` string. Retain exact selected institution/year identities and any
session association. Supply the fixture's explicit instructional weekdays as context separately
from display week-start configuration; never substitute Monday-Friday. Do not collapse two
same-named, same-date college deadlines that have different session identities. It adds no
collection read, core resource, API or stored metadata. The current demo has no instructional-day
resolver: the calendar must not manufacture one or treat an empty date as proof of no instruction.

## Date semantics and bounds

The first increment handles all-day local dates only. Both existing calendar adapters already
provide inclusive start/end dates; preserve that meaning, including one-day closures and events.
Do not convert these values through the device time zone. Non-calendar demo relationships use a
different half-open interval contract; never reuse that contract accidentally for calendar dates.

Choose the initial month from the demo's explicit example date and show its relationship to the
loaded academic range. Navigation uses the supplied year/coverage bounds, not the earliest/latest
event: an empty month inside a loaded academic year remains a valid month. Outside loaded coverage,
show a clear boundary rather than claim there are no institutional events. Date jumps do not fetch
more records. Render only the visible month/day details, not one DOM record per day of every range.

No source event count is a validated school-capacity limit. Measure a declared synthetic stress
fixture and record its count, longest range and overlap density before choosing a rendering cap.
If a cap is needed, disclose the incomplete result; never present truncation as a complete calendar.

Before timed events or Week/Day time grids, define a separate contract for instants versus local
wall time, IANA zone, daylight-saving gaps/folds, exclusive timed end, cross-midnight display and
overlap layout. Daylight-saving tests must prove dates remain stable for all-day records too.
Recurrence, recurrence exceptions and timetable publication require separate domain work.

## Delivery sequence

| Increment | Deliverable | Admission |
| --- | --- | --- |
| MV-2: proposed next | Shared Month/Agenda calendar in the selected fictional institution demo; Calendar/List switching, navigation, range/closure/event distinction, overflow and details | François's green light for this bounded local presentation increment; relevant specialist conditions and focused verification |
| Subsequent timed-calendar increment | Week/Day modes for a workflow that actually owns timed records | Explicit workflow authorization and reviewed date-time/zone contract; no timetable or admissions module inferred |
| Subsequent Gantt increment | Improve the existing read-only range chart with appropriate grouping and scale for an authorized consumer | Evidence from a real workflow need and explicit per-source eligibility; dependency links, critical path and scheduling remain separate |
| Subsequent timeline increment | A separately declared timeline view for meaningful milestones/ranges | Reviewed view-kind/schema extension and source mapping; shared selection and source contract retained |
| Later connected adoption | Bounded server-owned calendar reads and any named actions | Existing identity, tenant, module, sensitive-enumeration, representative review and release gates |

Keep later views off the first demo's selector until declared and qualified for that consumer.
The existing preparation screen's Gantt and Form remain its own explicitly declared views.
Do not route selected-demo entries into the separate core-backed calendar editor: their records
and authority are different. Future edits must invoke a workflow-owned named action, never a
renderer-generated save, drag-to-reschedule or generic CRUD operation.

## Proposed implementation and acceptance packet

The future change should be confined to model-view components/styles, their tests, the selected
demo's local calendar projection/consumer, and associated documentation. Preserve calendar
preparation and date-resolution behaviour. No new dependency is selected by this paper proposal;
the current owned primitives are the starting point. A third-party engine would require a
separate concrete need, compatibility/accessibility evidence, licence and maintenance review.

Before calling MV-2 implemented, record the following actual results:

1. All four fictional institution selections show a genuine month grid and matching Agenda/List
   entries. School and college vocabulary, scope and fixed example date remain correct. Verify
   same-day student closure/staff event and same-named college deadlines in separate sessions.
2. Cross-month ongoing periods, year boundaries, leap days, overlapping closures/events, empty
   loaded months, reversed/missing dates, duplicate keys and busy-day overflow have focused tests.
3. Calendar/List/mode switching retains context; invalid/stale selection does not show another
   record. Event selection is read-only and creates no network read or mutation.
4. Date-only fixtures yield identical dates with browsers in contrasting zones, including across
   daylight-saving changes. Week start and supplied locale configuration are tested explicitly.
   A non-Monday-Friday case preserves its declared instructional weekdays independently of the
   displayed first day of the week. Kindergarten cohorts acquire no invented AM/PM timetable.
5. Existing calendar-preparation Form, preview, publication and date-resolution regression checks
   pass. A List/Form-only source still receives no Calendar, Gantt or Timeline automatically.
6. Missing/corrupt demo context, tenant/hash/Host mismatch and request-selected institution remain
   denied by the demo adapter. Cross-pack records never enter the calendar or detail state.
7. Capture desktop, tablet and 320-pixel phone screenshots; inspect range readability, meaningful
   labels, focus, touch, zoom/reflow and no page overflow. Run automated accessibility checks and
   the full keyboard/agenda/detail/focus-return path. Human representative trials stay separate.
8. Run focused unit/browser checks, the declared overlap stress fixture, `git diff --check` and
   repository `make check`; report exact outcomes and skipped stages without claiming release.

Relevant retained threats are TM-01/TM-02 (tenant/authority), TM-04 (stale copies), TM-09 (sensitive
evidence), TM-16 (presentation metadata) and TM-17 (scope inferred from structure), in the
[threat model](../security/threat-model.md). The first demo remains fictional and read-only;
calendar filters, counts and detail panels cannot widen the validated pack's context.

## Specialist paper review

The 2026-10-23 primary and secondary education reviewers approve the paper direction with
conditions. The coordinator accepts their recommendations: preserve inclusive ranges and exact
scope/identity, separate closures from information/staff events, retain explicit weekdays and
institution vocabulary, disclose busy-day overflow, and label the fixed date honestly. These
conditions are incorporated above. Their owner functions are education product, the local
fixture-adapter owner and frontend engineering. The observable trials are the acceptance packet
above; every future MV-2 trial remains `not run`.

UI review is in progress; its final disposition will be recorded before handoff.
No live UI trial, representative school session or independent security review has been run for
this proposal. Advisor consultation was unavailable because the parent runtime was not verifiable.

## Proposal verification

Documentation and repository verification will be recorded after the proposal is finalized.
Future MV-2 acceptance tests above are planned checks, not implementation evidence.
