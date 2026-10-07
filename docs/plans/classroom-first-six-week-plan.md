# Classroom-first six-week delivery plan

- Status: Authorized delivery direction; implementation and release evidence remain separate
- Decision date: 2026-10-03
- Delivery window: 2026-10-05 through 2026-11-15
- Accountable owner and decider: François — Project Owner
- Delivery responsibility: Product and platform engineering
- Authorization: François's “green light” to the chat proposal for a six-week classroom-first shift
- Review trigger: weekly demonstration, missed dependency, new domain meaning, or release boundary

## Decision and precedence

For these six weeks, deliver one usable classroom journey before expanding corporate/legal or
horizontal platform capabilities. This plan replaces the corporate-first execution priority in
the [Phase 2 sequence](phase-2-entry-and-school-structure-proposal.md) and brings forward the
minimal people, calendar, class, enrolment, and attendance work needed by that journey. It does
not require completion of the entire structural hierarchy or the entire Phase 2.2 people backlog.

The Project Owner has authorized this bounded programme. Do not ask for the same prioritization
approval again. At the plan's original approval, it did not accept ADR 0021, invent representative
review, or close C25-04/C25-05. ADR 0035 later closed C25-04 for synthetic L1, and the Project
Owner's 2026-10-03 instruction to start calendar construction conditionally accepted the revised
ADR 0021 for bounded private synthetic L1. Independent evidence and release conditions remain
applicable. Amend a Proposed ADR or supersede an Accepted ADR before implementation changes its
stable boundary.

Existing corporate work and unrelated changes are preserved. No rollback, deletion, commit, or
push is authorized by this plan. A paused feature remains available for later reconsideration;
there is no automatic return to corporate expansion when the six weeks end.

## Product outcome

An educator signs in, opens an assigned class, sees the students enrolled for an explicit local
date, submits daily attendance, and sees the saved result after refresh. An authorized school
administrator can prepare its calendar, people, teaching assignment, and roster through simple
screens. Developers must not be required for routine class preparation.

The target is a connected evaluation environment with real staff authentication and synthetic
student records. Real staff authentication still requires the qualified connection, appropriate
identity-data handling, and selected-environment review. It is not permission to use real student
records, run a school pilot, or release production software. An internal synthetic proof is useful
progress, but is not completion of the connected target.

## Capacity and work discipline

| Share of available effort | Work | Accountable delivery function |
| --- | --- | --- |
| 65% | Academic domain actions and their browser screens, developed together | Product and application engineering |
| 20% | Identity integration, authorization, database integrity, audit/outbox, recovery, and end-to-end verification | Platform and application engineering |
| 15% | Educator/administrator walkthroughs, domain questions, accessibility, and friction fixes | Product experience, with François arranging actual representatives |

These are effort allocations, not staffing or elapsed-time estimates. No team size, availability,
named external reviewer, or booked user session is assumed. François owns resolving those human
dependencies; engineering owns making the candidate and evidence reviewable.

Keep one classroom delivery slice active at a time; review and identity qualification may proceed
alongside it. Every new abstraction must name the classroom task and weekly demonstration it
enables. Prefer a bounded domain implementation over a new shared framework. Reuse the current
session, authority, module, persistence, temporal, audit, outbox, and design-system foundations.

Pause corporate relationship/catalogue expansion, consolidation rules, structural moves,
jurisdictional modeling, generic temporal/workflow engines, new design-system capabilities, and
new infrastructure services. Fix existing defects when they block this journey or required checks.
Retain only the minimum educational identity and primary-operator work needed for valid use.

## Included academic scope

| Area | Included | Deferred |
| --- | --- | --- |
| Educational context | One exact institutional identity and required accountable operator; reuse existing legal identity | Hierarchy editor, reorganizations, affiliations, multi-country administration |
| Calendar | Year, terms, explicit time zone, instructional weekdays, dated closures, preview and publication | Template catalogue/adoption, automatic rollover, scheduling solver |
| People | Minimal tenant-owned person, student participation, staff affiliation, explicit staff account association | HR/payroll, guardian graph, admissions CRM, identity merging |
| Class/register | Daily attendance group, explicit calendar reference, effective-dated teaching assignments | Curriculum authoring, course catalogue, timetable optimization |
| Enrolment | Institution/year enrolment and separate effective-dated class placement; explicit ending with preserved history | Applications, waitlists, promotion, complex transfers |
| Attendance | Daily marks, submission, confirmation, attributable correction | Period attendance, messaging, analytics, automated interventions |

The daily register is not a substitute for a course offering. Programme enrolment, course
registration, and section placement retain the distinct meanings already approved in the Phase 2
product direction. Student and teacher are useful UI terms, not fixed roles. A person need not
have an account; staff affiliation and teaching assignment never grant permission by themselves.

## Weekly delivery and evidence

| Week | Dates | Demonstration and exit evidence |
| --- | --- | --- |
| 1 | 5–11 October | Settle the bounded domain contracts and institutional prerequisites; walk through calendar/setup/attendance with an educator and administrator; identify one identity connection and environment; record gate owners, review bookings, and unresolved findings honestly |
| 2 | 12–18 October | An authenticated authorized staff member defines and publishes a small calendar from the browser; refresh reads committed state; audit/outbox and rollback/retry evidence pass |
| 3 | 19–25 October | Prepare synthetic staff, students, class, teaching assignment, enrolment, and placement using simple screens; date-specific roster is correct |
| 4 | 26 October–1 November | Assigned educator submits daily attendance and reloads it; denied class/tenant and duplicate request cases pass |
| 5 | 2–8 November | Correct attendance; resolve concurrent changes; exercise session expiry, ended assignments, roster changes, and interrupted outbox delivery |
| 6 | 9–15 November | Representative users complete the journey without developer assistance; fix observed issues; complete repository and end-to-end verification; record the achieved release level |

Week two is the first complete browser-to-PostgreSQL write, not the start of interface work after
several independent backends. Dates are targets dependent on the recorded gates, not evidence of
delivery. If connected entry is still blocked at the end of week one, report the owner and missing
evidence immediately, continue eligible private synthetic work, and revise the demonstration
forecast explicitly. Do not fill the delay with new corporate abstractions or call a mock login
real authentication.

## Ordered work queue

| Order | Bounded work item | Current disposition |
| --- | --- | --- |
| CF-0 | Record the course change, first-slice contract, dependencies, and acceptance scenarios | Complete for the current plan; later evidence remains attached to its owning slice |
| CF-1 | Minimal institutional identity under ADR 0034; implement the minimum operator/publication contract accepted by ADR 0035 | Private synthetic registration, initial assignment, publication and exact read implemented; [verification and calendar handoff](../phase-2/institutional-foundation-evidence.md) records the achieved boundary |
| CF-2 | Reframe ADR 0021 and implement the calendar contract with a small preparation screen | Revised ADR conditionally accepted for synthetic L1; executable pre-persistence validation/resolution is implemented; persistence and the preparation screen follow CF-1 |
| CF-3 | Qualify one actual identity connection and the first same-origin calendar write | Prepare alongside CF-1/CF-2; connected execution requires the gates below |
| CF-4 | Minimal people, staff-account association, class, teaching assignment, enrolment, and placement, with preparation screens | CF-4A private synthetic person, dated participation and verified staff-account association implemented; [evidence and enrolment handoff](../phase-2/people-foundation-evidence.md). [CF-4B classroom setup](../phase-2/classroom-foundation-evidence.md) adds class, teaching assignment, enrolment and dated placement. The [disabled local preparation workflow](../phase-2/classroom-preparation-workflow-evidence.md) now creates one exact class and up to 60 fictional students from the browser and hands that class into attendance; real identity, representative review and release gates remain open |
| CF-5 | Attendance submission, correction, and recovery through the complete UI | First immutable daily submission is implemented and the prepared-class browser handoff passes; named correction, concurrency recovery, interrupted delivery, retained records policy and real-session gates remain next |
| CF-6 | User evaluation, repair, and final verification | Planned; no user findings or completion results claimed |

## Entry conditions on the critical path

| Dependency | Current evidence and constraint | Required next disposition | Owner / deadline |
| --- | --- | --- | --- |
| Educational identity | ADR 0034 closes C25-03 only for unpublished synthetic L1 | Use that bounded entry; preserve C25-03-R actual five-context validation before connected use | François arranges representatives; review schedule in week one, evidence before connection |
| Primary legal operator | C25-04 closed for synthetic L1 under ADR 0035; a published institution needs one effective verified primary operator | Implement and verify initial assignment/publication under the accepted contract; broader transfer/reorganization features remain outside this classroom increment | Platform engineering under the delegated decision; retained external legal/records validation before connected or real use |
| Calendar | Revised ADR 0021 is conditionally accepted for bounded private synthetic L1; the exact-owner validation/resolution contract is executable | After CF-1, persist the accepted aggregate/actions and add the small preparation screen with full tenant, capability, idempotency, audit/outbox, rollback, and migration proof | Product/platform; next active calendar increment after the institutional/operator prerequisite |
| People and participation | Existing Phase 2.2 proposal separates person, account, membership, and participation | Record the bounded people/account association ADR and enrolment/assignment/attendance action and records contracts | Product/platform and domain/records review; before dependent persistence |
| Real authentication | D.2 foundations and bounded D.3 adapter exist; no qualified real connection is demonstrated | Choose and qualify one connection and environment under ADRs 0029/0030; retain current-session, origin/CSRF, revocation, and redaction controls | François supplies institutional connection context; platform/security qualify before connection |
| Connected experience | C25-05 and 2.0-E remain open; UI-1A is local read-only qualification | Complete the representative/accessibility/security disposition for the bounded journey; do not promote the local token or silently enable public routes | Product experience/security and François; before first connected workflow |
| Legal adoption evidence | ADR 0031 retains external adoption validation for affected later use | Review the actual minimum legal dependency and obtain the applicable disposition; do not assume freezing corporate work waives it | François and corporate/legal review; before affected L2 use |
| Real student data / pilot | C25-06 and L3 remain open | Keep synthetic student data throughout this programme; selected deployment, independent privacy/security, records ownership and lower gates precede any later pilot | François; outside this six-week completion claim |

Existing 2026-12-15 review dates do not postpone a condition that is due before the first affected
workflow. No gate is closed by the resource allocation, a future review booking, or a passing test.

## Completion contract

- Staff can prepare the synthetic class and an educator can complete attendance without developer
  assistance, using an actual qualified authenticated session.
- Domain checks reject missing/stale context, wrong tenant, unauthorized class, invalid effective
  dates, revoked membership, ended assignments, and inactive module state.
- Historical attendance pins its original calendar/roster basis; later changes never silently
  change who was expected or what the date meant.
- State, required audit evidence, idempotency result, and outbox fact commit in one transaction.
  Consumers run after commit; retry/replay has idempotent effects and interruption recovery is proven.
- UI confirmation comes from authoritative committed state. Loading, denial, expiry, conflict,
  retry, validation, and success states are accessible and understandable.
- Required `make check` and meaningful domain/browser/recovery checks pass on the final candidate;
  failures and skipped checks are reported explicitly. Repository consistency does not approve release.

Weekly reports state: demonstrated user task, evidence, remaining condition, accountable owner,
and next demonstration. At six weeks, record achieved scope and the next product priority rather
than automatically resuming the paused corporate backlog.

## Related records

- [First classroom slice contract](../phase-2/classroom-first-slice-contract.md)
- [Phase 2 entry register](../phase-2/entry-decision-register.md)
- [People and identity proposal](phase-2-identity-people-relationships-and-access-proposal.md)
- [Academic calendar ADR](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- [Educational acceptance](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)
- [Identity implementation evidence](../phase-2/identity-session-and-support-access-implementation-evidence.md)
- [Threat model](../security/threat-model.md)
