# CF-3 connected calendar entry disposition

- Status: Approved for a disabled local synthetic implementation candidate
- Original packet prepared: 2026-10-05
- Decision recorded: 2026-10-06
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Target slice: CF-3, the first same-origin synthetic calendar preparation write
- Governing decision: [ADR 0039](../adr/0039-public-calendar-evidence-for-cf-3-engineering-entry.md)
- Source evidence: [CF-3 public calendar source review](cf-3-public-calendar-source-review.md)

## Decision

François confirmed that official public operational calendars are the external evidence available
to the project and directed the project to proceed without requiring unavailable school contacts.
CF-3 may therefore move from the local unsaved prototype to a disabled-by-default local synthetic
implementation candidate.

This decision does not claim that a school calendar owner, institutional representative,
educational-domain professional, or representative operator reviewed Chimwemwe. It does not turn
public documents into interviews or approval.

## Evidence accepted for engineering entry

The source review records official public calendars from eight international schools whose
calendars are published on official school pages or Finalsite-hosted resources. The confirmed,
non-exhaustive set includes four Thailand schools and four additional international schools.

Two materially different records are carried as the primary contract pressure tests:

1. KIS International School Bangkok's three-term 2025–26 calendar with 180 school days, fixed
   closures, professional-development days, and a separate A/B-week cycle.
2. International School of Tanganyika's four-term 2026–27 calendar with 180/181 instructional
   days, tentative religious holidays, professional-development days, and conditional make-up
   days.

The review also records ISB's multiple public calendar categories and rotating day codes, Rugby
School Thailand's boarding/exeat distinctions, Oberoi's grade-staggered starts and half-days, and
Gyeonggi Suwon's semesters plus overlapping quarters. Those patterns establish real boundary
pressure without expanding CF-3 into scheduling or events.

## Scope now authorized

CF-3 may implement and test:

- one exact local synthetic calendar preparation journey;
- exact named registration, draft, replacement, preview, publication, read, and date-resolution
  operations through the accepted same-origin boundary;
- server-derived actor, tenant, membership, placement, module, capability, purpose, and field
  policy from the synthetic application session;
- authoritative read-after-write refresh;
- explicit success, validation, denial, stale-version, conflict, expired-session, inactive-module,
  origin, CSRF, and interrupted-request states; and
- technical keyboard, focus, narrow-layout, error-recovery, and automated accessibility checks.

The implementation remains disabled outside the explicit local synthetic environment. It may use
the accepted synthetic public-session adapter; no selected real identity provider is required to
build it.

## Explicitly not authorized

CF-3 does not authorize:

- real institutional, learner, staff, identity, or calendar data;
- import, scraping, synchronization, subscription, Google Calendar, ICS, or another event feed;
- generic calendar CRUD, arbitrary filtering, collection traversal, or export;
- timetable, rotating-day, recurrence, bell-period, half-day, room, boarding, event, athletics, or
  parent-conference behavior;
- a real identity connection, public origin, deployed endpoint, pilot, or production release; or
- claims of representative usability, institutional correctness, or calendar-owner approval.

## Source limitations carried forward

The public documents do not establish internal calendar ownership, institution-confirmed IANA time
zones, correction workflows, simultaneous-calendar authority, downstream revision use, or operator
comprehension. Tests must not guess those facts or describe them as source-confirmed.

Location-based time zones may be used only in clearly fictional test fixtures. Public calendar
facts remain design evidence and may not be copied into tenant state as institutional records.

## Retained adoption and release gates

The following no longer block CF-3 engineering but remain mandatory before their stated boundary:

| Record | When it is required |
| --- | --- |
| Named institution-side domain and calendar-owner validation | Before real institutional data or import, an institutional pilot, deployment, production reliance, or a claim of operational correctness |
| Representative operator usability/accessibility evidence | Before an institutional pilot or a claim of representative usability |
| Independent security/privacy review and institution-side records owner | Before Restricted data or an institutional pilot |
| Selected provider-neutral identity connection and exact public origin | Before any deployed endpoint is enabled |
| Deployment, edge/TLS, keys, rate, recovery, support, and operating ownership | Before deployment qualification |

The former five-context `C25-03-R` requirement is retained as an adoption-validation concern, not
as a demand to pre-recruit five unavailable people before synthetic engineering. The first
participating institution must validate its own structure, terminology, ownership, calendar
pattern, unsupported cases, and correction expectations before its data is used.

## Synthetic product and security disposition

François's 2026-10-06 direction supplies the Project Owner and interim Security/Privacy disposition
for this bounded synthetic entry. The implementation must conform to ADRs 0029 and 0030 and prove
TM-01, TM-02, TM-09 through TM-15, TM-17, and TM-19 at the affected boundary. This is not an
independent review and cannot be reused for real Restricted data or deployment.

## CF-3 implementation exit checklist

- [ ] Only exact named calendar actions and exact reads are exposed.
- [ ] Browser input cannot supply tenant, placement, capability, role, module state, or authority.
- [ ] The writer supplies committed state and immediate read-after-write confirmation.
- [ ] Success, validation, denial, stale-version, conflict, session, module, origin, CSRF, rollback,
      interrupted-request, and stable non-disclosure states are tested.
- [ ] Keyboard, focus, narrow layout, error recovery, and automated accessibility checks pass.
- [ ] Rotation, recurrence, timetable, event, subscription, and import behavior remains absent.
- [ ] Fixtures are fictional and contain no copied school operational dataset or personal data.
- [ ] The candidate cannot be enabled outside the explicit local synthetic environment.
- [ ] The required repository gate is run and its exact result is reported.

## Consolidated entry decision

| Field | Recorded value |
| --- | --- |
| Decision date | 2026-10-06 |
| Project Owner | François |
| External evidence | Official public operational calendars; completed source review |
| Representative testimony | Not available and not claimed |
| Product/security authority for synthetic entry | François — Project Owner and interim Security/Privacy Owner |
| Identity used for engineering | Existing disabled synthetic public-session adapter |
| Blocking conditions before CF-3 implementation | None beyond the implementation contract and exit checks above |
| Conditions retained after CF-3 | Institution-side validation, representative usability, independent security/privacy, selected identity/deployment, real-data, pilot, and production gates |
| CF-3 entry outcome | **approve for disabled local synthetic implementation candidate** |

Approval authorizes implementation and verification, not completion. CF-3 becomes complete only
after the exit checklist and implementation evidence are recorded.
