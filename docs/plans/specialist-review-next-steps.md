# Specialist review decisions and next steps

- Status: Initial AI reviews and paper trials complete; implementation and release gates retained
- As of: 2026-10-23
- Owner and escalation authority: François — Project Owner
- Review trigger: completed trial, new evidence, unresolved challenge, or request for implementation authority
- Review profiles: [Delegated specialist team](../development/specialist-review-team.md)
- Delivery priority: [Authorized classroom-first plan](classroom-first-six-week-plan.md)

## Outcome

Four independent AI specialists reviewed the supplied Week 1 authentication/evaluation plan and
the current COMM-0 proposal. Each supports the direction with conditions. All distinguish this
paper assessment from representative educator evidence, actual usability testing, security/privacy
assurance, and release approval. The coordinator accepts their request for bounded paper revisions
and trial preparation. No specialist has authorized COMM-1 or connected authentication.

The supplied authentication plan targeted 9–11 October and sessions on 12–16 October 2026. Those
dates have elapsed. Treat its unverified actions as `not evidenced`, not completed or definitely
missed. Preserve the existing six-week priority and reforecast connected work once actual inputs
are supplied; do not move its gates or assume a booking.

## Initial specialist dispositions

| Profile | Authentication/evaluation plan | COMM-0 / ADR 0045 | Coordinator disposition |
| --- | --- | --- | --- |
| Secondary education | Approve with conditions for preparation; connected readiness insufficiently evidenced | Approve paper direction with conditions; revise before acceptance recommendation | Accept: distinguish daily registers from lesson/subject groups; test class switching and pastoral handoff |
| Primary education | Approve with conditions for preparation; connected readiness insufficiently evidenced | Approve paper direction with conditions; revise before acceptance recommendation | Accept: ordinary class-teacher and substitute scenarios, closed class notices, honest family reachability |
| Admissions | Approve staff-only preparation with conditions; connected readiness insufficiently evidenced | Approve staff paper direction with conditions; challenge inferred applicant/family/college delivery | Accept: explicitly exclude unqualified applicant, guardian, referee and external-college targeting |
| UI and interaction | Approve sequence with conditions; human usability/accessibility insufficiently evidenced | Approve paper direction with conditions; actual screen usability insufficiently evidenced | Accept: concise audience wording, receipt-only example, account-administration tasks and accessible optional help |

Evidence was gathered read-only from the governing documents. The findings below are AI document
analysis, not observed participant behaviour. The isolated Advisor review was unavailable because
the parent runtime could not be verified; this report claims no independent advisory sign-off.

## Authentication decision and open work

| Item | Decision / current evidence | Next action and owner |
| --- | --- | --- |
| Initial login path | Settled by Accepted [ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md): administrator-provisioned staff credentials; OIDC optional | Keep this choice; no new selection vote or repeated approval |
| Existing credential proof | [Local evidence](../phase-2/local-credential-administration-evidence.md) ends at a credential-proof page; login grants no classroom authority | Platform engineering prepares the LA-1 authority and later handoff acceptance packet; do not describe separate demos as integrated |
| Next engineering boundary | LA-1 remains the next ordered slice in the [qualification plan](local-authentication-production-qualification-plan.md); this review authorizes preparation, not new implementation | Specify named create/status/reissue/suspend intent, staff eligibility, current membership/capability/module gates, audit/outbox payloads, migration review and denial matrix against that plan |
| Administrator evaluation | Supplied session exercises calendar and class setup but omits the account lifecycle it is meant to qualify | UI prepares tasks for correct staff selection, account creation, status, expiry, reissue, suspension, denial and recovery; engineering verifies executable coverage later |
| Educator evaluation | Existing attendance/correction proof is synthetic and today-only | Educators prepare class/date/complete marks/save/reload/correct/lost-response trials; keep first-login onboarding separate until the handoff is qualified |
| School operating policy | Backdating, ended-assignment correction and pastoral follow-up are not settled by the demo | Record questions for the actual institution/records owner; do not add override, health notes, historical editing or automatic messaging |
| Integration verification | Calendar repair is approved by the UI specialist and its final focused browser regression passes; the full rerun stops on unrelated demo-instance test typing errors | See the dated repair record below; a passing repository gate still would not close connected-entry conditions |

The [attendance proof](../phase-2/classroom-attendance-workflow-evidence.md),
[preparation proof](../phase-2/classroom-preparation-workflow-evidence.md), and
[correction/recovery proof](../phase-2/attendance-correction-and-recovery-evidence.md) define the
actual candidate. Its engineering caps and tiny fixtures are not validated school capacity or
policy. Multi-class and substitute cards below are paper boundary tests, not implementation claims.

## Environment and human dependencies

No completed environment/owner pack or confirmed representative sessions were supplied in these
assignments. These statuses mean `not evidenced in this review`; they do not assert that nobody
has made arrangements elsewhere. François may supply existing decisions rather than decide again.

| Required input | Current review status | Accountable next step |
| --- | --- | --- |
| Evaluation institution, isolated non-production environment, operator and exact HTTPS origin | Not evidenced | François supplies the existing selection or names a delegate to select it; engineering validates |
| Authoritative staff source/association, credential-administration capability and actual holders | Not evidenced | François and the institution name authority; platform engineering checks the domain boundary |
| First administrator, MFA/step-up and lost-administrator recovery | Not evidenced | François names the responsible operator/security owner and approved procedure |
| Private temporary-password delivery and recipient verification | Not evidenced | François names the actual delivery owner and approved method; never store credentials in evidence |
| Support, incident, monitoring, privacy and retention owners | Not evidenced | François assigns actual people and records disposition in an approved restricted location |
| Representative educator and administrator sessions, consent, devices and facilitator | Not evidenced; elapsed proposed dates are not confirmations | François or a named school contact confirms bookings; repository retains study IDs and redacted status only |

The [LA-1–LA-6 plan](local-authentication-production-qualification-plan.md) owns the full controls.
Connected work remains blocked on its applicable inputs and independent/human review; fictional
paper and isolated synthetic preparation may continue within current authority. None of these
four profiles can invent a hostname, appoint a real operator, deliver a password, book a school
participant, or substitute itself for a required representative.

## COMM-0 decisions and remaining conditions

This section retains the initial findings. The subsequent
[delegated paper review](../phase-2/communications-comm-0-experience-evidence.md#delegated-paper-review--23-october-2026)
has now resolved the included staff-proof choices. Its
[COMM-1 proposal](communications-comm-1-staff-announcement-proposal.md) was prepared without
implementation permission. François subsequently accepted ADR 0045 and authorized that bounded
proof, starting with [source-fence qualification](../phase-2/communications-comm-1-source-fence-qualification.md)
and agent review before proceeding. The current decision rules belong to ADR 0045; historical open items
and trial results below are not instructions to reopen those settled paper choices.

The paper direction is supported: announcement first; authoritative audience; frozen intended
subjects; current access checks; separate delivered/seen/acknowledged evidence; aggregate-first
metrics; closed student interaction. Governing
[ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md) is now Accepted by
François. The initial delegated recommendation did not itself grant that acceptance or authority.

| Finding | Paper disposition | Owner / closure evidence |
| --- | --- | --- |
| Acknowledgement example says received and read | Use receipt-only wording for the illustrative first proof; preserve the exact statement and distinction from consent, agreement and comprehension | UI + admissions; explicit copy in the [experience evidence](../phase-2/communications-comm-0-experience-evidence.md) |
| Class notice leads with moderated questions | Make closed interaction the ordinary scenario; retain moderation as a conditional future variant requiring its policy and coverage | Both educators; class journey and C-03 trial |
| Applicants, referees and external college contacts are not explicitly named in exclusions | Make their unsupported targeting explicit; a staff counsellor may receive a staff notice without gaining external disclosure authority | Admissions; audience checklist and C-04 trial |
| Daily class vs subject teaching group | Never infer a subject group from a daily register or a label; accepted audience ownership must establish each meaning | Secondary reviewer; C-03 trial |
| Corrected critical instructions and prior acknowledgement | Preserve original facts; no inferred acknowledgement of a successor. Audience choice, whether renewed acknowledgement is required, and exact receipt/revision binding remain entry questions | Product/records/security owners, informed by educators and UI; C-05 records the unresolved policy |
| Urgent closure and unreachable families | Show exact affected scope and excluded populations; no claim of emergency reachability or family delivery | Both educators + future emergency/safeguarding owner; C-06 |
| Publish preview could become a wall of explanations | Compact field/value review, clear edit actions, visible exclusions/approval/consequences; secondary provenance in optional details | UI; paper trial now, screenshots and interaction checks on a later authorized candidate |

The [eight entry questions](../phase-2/communications-comm-0-experience-evidence.md#comm-1-entry-questions)
now have explicit paper dispositions and conservative engineering test limits in the proposal;
none is a measured capacity or legal-retention claim. A staff foundation is not a ready-made
enumeration API. Source-fence qualification and other executable evidence remain future gates,
followed by the separate exact-institution, synthetic staff proof authorization if desired.
Urgent alerts, students, guardians, applicants, external colleges, adapters, messaging, scheduling
infrastructure and real records do not enter that proof automatically.

## Delegated trial cards

These cards are fictional paper exercises. `Pass` means the paper contract produced the stated
decision under AI reasoning; it does not mean software ran or a human completed a task. A policy
gap is an honest unresolved result. The assigned specialists' actual AI outcomes appear below.

| ID | Lead / supporting profile | Fictional task | Observable paper acceptance condition |
| --- | --- | --- | --- |
| A-01 | UI / primary | Administrator selects an existing staff association, creates account, privately hands off temporary password; staff replaces it; admin reissues then suspends | Identify each action and authority; operator notices and cancels a wrong-but-eligible selection; domain rejects ineligible/cross-tenant/denied requests; applicable state and sessions cannot survive reissue/suspension; no invented delivery method or classroom access |
| A-02 | Primary / UI | Class teacher submits today's complete register, loses the response, reloads, then corrects one mark; substitute assignment has ended | Saved/uncertain state is explicit; authoritative reload precedes retry; preserve prior marks; ended assignment denies; tomorrow's correction routes to an unanswered owner question |
| A-03 | Secondary / UI | Teacher switches between two assigned daily registers and attempts an unassigned one; an absence needs pastoral follow-up | Identify class/date and daily purpose; no lesson-attendance claim; deny unassigned access; follow-up remains an institution policy question without extra data collection |
| C-01 | UI / admissions | Published staff notice shows 84 intended, 79 reachable, 61 seen, 55 acknowledged, 5 without an eligible account; a separate pending publication/correction has a stale preview | Explain each number without claiming reading/consent or a seen/acknowledged subset; no blame for unreachable staff; stale source blocks the pending publication; exact institution and exclusions visible |
| C-02 | Primary / secondary | Attempt Year 7 notice from academic year/class label and primary family notice for a child with no account or qualified guardian relationship | Both targets unavailable for the declared gaps; no age/label/parent inference and no false did-not-read metric |
| C-03 | Secondary / primary | Ordinary exact-class notice, then request subject-group targeting or moderated student questions | Closed is baseline; daily register is not a subject group; absent group/policy/moderator/endpoint contracts keep variants unavailable |
| C-04 | Admissions / primary | Offered-but-unenrolled applicant; guardian who is staff; counsellor attempts confidential reference to external college | No applicant-to-student inference; ordinary staff access only through staff relationship; family/reference/college disclosure remains unsupported |
| C-05 | Primary / UI | Staff acknowledged revision 1; revision 2 changes collection time from 15:00 to 12:00 | Preserve exact original receipt; show correction; never carry old acknowledgement forward as new; explicitly flag undecided correction audience and renewed-action policy |
| C-06 | Secondary / primary | One site closes, approver is unavailable, recipients unreachable and a later channel has an outage | Scope never silently broadens tenant-wide; no ad-hoc approval bypass; display exclusions/failure and unresolved emergency fallback ownership; no operational emergency claim |
| U-01 | UI / all | Review concise staff/educator/applicant/guardian wording and optional question-mark help | Name the task and next action without an essay; essential status/consequences stay visible; optional help has focus/tap path. Interactive accessibility remains untested without a candidate |

### Trial outcomes

The assigned leads completed all ten cards as AI paper walkthroughs on 2026-10-23. Supporting
profiles contributed the initial independent reviews; these are not ten independently replicated
experiments. No executable or human-participant trial was run as part of these cards.

| Card | Lead's observed paper result | Retained limitation / coordinator disposition |
| --- | --- | --- |
| A-01 | Authority and credential-lifecycle reasoning passes; actual private handoff blocked | Accept. Delivery/recipient verification and classroom handoff remain unqualified. Refine the card: authorization cannot detect an administrator intending a different but eligible staff member; visible identity review and cancellation are required |
| A-02 | Save/reload/correct and ended-assignment denial follow the current contract | Accept paper pass. Tomorrow's correction remains a blocked records-policy question; this did not execute attendance software |
| A-03 | Two assigned daily registers remain separate; unassigned access denied; pastoral follow-up is an owner question | Accept paper pass. No lesson attendance, new class administration, messaging or real school policy introduced |
| C-01 | Frozen intended/reachable/seen/acknowledged counts remain distinct; stale pending publication blocks | Accept paper pass. Separate published metrics from the pending preview; do not infer a seen-but-unacknowledged overlap from aggregate subtraction |
| C-02 | Both inferred Year 7 and unqualified family audiences are refused | Accept paper pass for correct exclusions; cohort/student/guardian contracts remain absent |
| C-03 | Ordinary class notice is closed; subject-group inference and unqualified moderated variant refused | Accept paper pass for boundary denials, not a publication or delivery result |
| C-04 | Offered applicant creates no student audience; guardian-as-staff qualifies only independently as staff; external reference remains unsupported | Accept paper pass. Delivery remains blocked on the missing domain/relationship/disclosure/endpoint contracts |
| C-05 | Original receipt survives; no fresh acknowledgement is inferred | Accept `blocked policy` for correction audience/renewal. Preservation guard passes; actual product/records decision remains open |
| C-06 | Missing approver stops the action; unreachable recipients and outage remain explicit | Accept `blocked policy` for emergency fallback/owner. Secondary reviewer found a one-site/tenant-wide ambiguity; coordinator added exact-affected-scope-or-block wording and the reviewer verified that repair |
| U-01 | Written concise-copy and accessible-help rules are coherent | Accept paper pass for the rule. No screen discoverability, focus, keyboard/touch, screen-reader or human accessibility result claimed |

For C-01's same-snapshot fictional example, 84 = 79 reachable + 5 with no eligible account;
79 - 61 = 18 reachable without a recorded seen fact, and 79 - 55 = 24 reachable without a recorded
acknowledgement. Do not report 61 - 55 as six seen-but-unacknowledged people unless the exact
revision/view policy guarantees that acknowledgement is a subset of seen; that is not established
by these aggregate numbers. Named follow-up remains separately authorized.

For future human trials record study ID, perspective, device/input method, consent status,
facilitator, actual date, task outcome, wrong turns, elapsed time and assistance. Keep identities,
contacts, consent and appointments in the approved restricted location. Set usability targets from
reviewed evidence rather than inventing a speed threshold. The blank
[DS-3 participant register](../phase-2/design-system-representative-review-evidence.md) does not
qualify credential, classroom or communication journeys.

## Ordered next steps

| Step | Owner | Deliverable / condition to proceed |
| --- | --- | --- |
| 1. Establish the team and initial decisions | Coordinator + four specialists | Reusable profiles, routing and first source-backed findings; completed in this review |
| 2. Revise the COMM-0 paper examples and run these AI cards | Coordinator + assigned profiles | Completed in this review: wording/closed-interaction/scope clarifications and ten AI outcomes; unresolved policies retained |
| 2a. Repair the observed calendar date-resolution failure | Product/client engineering, with UI challenge | Calendar repair and UI review complete; final focused browser test passes. Full checks rerun and blocked separately on demo-instance test types |
| 3. Assemble the LA-1 engineering entry packet | Platform engineering, with educator/UI challenge | Exact action/denial/audit/migration/browser acceptance criteria, dependencies and credential-to-classroom handoff boundary; preparation allowed, implementation authority checked separately |
| 4. Fill the environment/owner pack and rebook real sessions | François or a named human delegate | Actual selections, named owners, restricted booking/consent evidence, revised forecast; no invented deadlines or bookings |
| 5. Authorize and qualify the next bounded authentication increment | François + required engineering/security owners | Existing authority reconfirmed by evidence or one explicit new slice authorization; retain applicable LA-1–LA-6 and connected gates |
| 6. Dispose of ADR 0045 and the COMM-1 entry packet | Named ADR deciders, informed by specialists | Included paper questions resolved and proposal prepared by delegated review; formal ADR disposition and a separate COMM-1 authorization remain distinct |
| 7. Evaluate actual screens and representative work | UI, educators, school representatives and required independent owners | Candidate screenshots and interaction evidence, uncoached task results, repairs and explicit go/no-go at the applicable level |

Steps 2–3 can progress while step 4 is pending. COMM-0 remains parallel paper work; it does not
displace the classroom-first priority or authorize feature expansion during the proposed freeze.
No commit, push, external outreach, appointment or deployment is authorized by this document.

## Initial review-package verification

Verification on 2026-10-23 before the subsequently authorized calendar repair:

- `make check`: **failed** at `check-web` / `web-classroom-e2e`. Documentation, repository tooling
  tests (4), core verification (309 tests, audits and type analysis), web generation/audits,
  formatting/lint/types, token tests (8), dependency tests (5), unit tests (31), production build,
  local browser tests (33), connected-interface tests (6), unavailable-state test (1), and both
  attendance browser tests passed.
- The third classroom browser test fails at `clients/web/tests/classroom/calendar.spec.ts:99`.
  After publication, keyboard activation of `Resolve date from database` receives
  `The draft was not saved. Review the highlighted issue.` instead of the resolved-date status.
- Focused reproduction from `clients/web`:
  `../../bin/with-verification-lock --resource web-qualification -- mise exec -- npm exec playwright -- test --config playwright.classroom.config.ts tests/classroom/calendar.spec.ts`
  also **failed** at the same assertion. No repair or passing retry is claimed.
- `make check-tooling`: passed separately because the full gate stopped before this stage.
- `make docs-check`, `git diff --check`, and `git diff --cached --check`: passed for the final
  review changes.

During browser startup, Next.js regenerated its client agent block with an H2 instead of an H1.
The final documentation check caught the missing page heading. A stable H1 was added outside that
generated block in `clients/web/AGENTS.md`; no framework instructions or runtime behaviour changed.

No required verification stage was silently omitted; the failed gate remains failed. The ten AI
paper cards are separate from these executed software checks. Representative sessions, selected
deployment qualification, independent security/privacy and safeguarding reviews were not
performed. Prior pasted success counts describe earlier candidates. The repository was not green
at this checkpoint; the repair and later verification are recorded separately below.

### UI specialist's calendar triage

At the failed checkpoint, the full run and focused retry failed after successful publication at
the same resolve assertion. Read-only source review identified a likely fixture/date mismatch:

- [Synthetic UI data](../../clients/web/src/fixtures/synthetic-view-data.ts) fixes the initial
  resolution date at 2026-10-15.
- [Connected demo fixture](../../apps/chimwemwe_core/test/support/classroom_fixture.ex) starts the
  server-selected academic year at `Date.utc_today()`.
- [Calendar component](../../clients/web/src/components/academic-calendar-preparation.tsx)
  initialized from the UI date without updating it when the authoritative year loaded. Its shared
  HTTP-400 handler also used draft-save failure wording for a date-resolution rejection.

On 23 October, that initial date precedes the demo year. `outside_year` maps to HTTP 400 in the
[calendar controller](../../apps/chimwemwe_core/lib/chimwemwe/public_api/calendar_controller.ex),
which is consistent with the observed message. The failed response body was not inspected, so the
specific response code and complete cause remain to be confirmed. Source review rules out the
initial default-submit-button hypothesis: the action is a button outside the save form with its
own resolve request.

Coordinator accepts the bounded repair recommendation: confirm the actual response; initialise a
connected date against the authoritative year; preserve published state; give invalid/out-of-year
checks date-specific feedback; verify mismatched initial date, valid keyboard resolution and
explicit out-of-range rejection, then rerun the relevant and full checks. No application repair is
implemented by the initial review package; dependency work remains separate.

## Calendar repair and UI review — 23 October 2026

François subsequently authorized the calendar date-check fix, UI-expert review and a new
`make check`. The existing initial-date correction in the checkout was preserved: loading an
authoritative academic year keeps a selected date if it is in range and otherwise selects the
year's start. The browser test reads the year boundaries from the actual prepared calendar.

Date checks now use their own inline feedback instead of the draft-save error. An out-of-year
date is rejected without changing the published state; an empty/invalid date gets a concise input
message. The date field exposes validation through its label, associated error and `aria-invalid`.
A network/service interruption keeps the date valid, preserves publication and offers retry.
Existing session-denial and conflict handling remains in place.

The expanded focused browser journey passed before UI review. It exercises an in-range selection
surviving publication, the real HTTP-400 out-of-year rejection, blank date, keyboard resolution,
interrupted-request recovery and clearing feedback after success. Wide and 320-pixel error states
also passed axe checks and produced screenshots for the specialist. No real participant evidence
is claimed.

The UI specialist reviewed the source and wide/narrow error screenshots and returned `approve`
after two requested refinements: the inline alert sits outside the input label so the accessible
name stays `Local calendar date`, and the existing invalid year-start test derives its date from
the loaded year-end plus one day. Network/service failure does not mark a valid date invalid.
The coordinator accepted and implemented these findings; the browser journey asserts the stable
accessible name and network-failure validity. The reviewer verified both repairs and closed its
conditions before the full `make check` was started. This is AI source/rendered-state review,
not representative human validation.

The first post-repair `make check` passed documentation, repository tooling, all 309 core tests,
type analysis and audits, then stopped on a Prettier warning in the unrelated
`clients/web/src/server/demo-instance-loader.ts`. That one file was formatted without changing
its logic. The subsequent full `make check` again passed all 309 core tests and reached web
type-checking, then **failed** in `clients/web/tests/unit/demo-instance.test.ts`: environment
fixtures passed to the demo loader omit the required `NODE_ENV` field. This is separate concurrent
demo-instance development; no calendar type errors were reported. The repository is not green.

Final calendar verification after both UI-requested refinements:

- `../../bin/with-verification-lock --resource web-qualification -- mise exec -- npm exec playwright -- test --config playwright.classroom.config.ts tests/classroom/calendar.spec.ts`
  from `clients/web`: **passed**, 1 browser journey, 19.6 seconds. This includes stable accessible
  name, network failure leaving the date valid, and the dynamically derived negative test date.
- `make check-tooling`: passed separately, since the full gate stopped before tooling.
- `make docs-check`, `git diff --check` and `git diff --cached --check`: passed on the final review
  record and code changes.
- Because web type-checking stopped the full gate, its later token/dependency/unit tests,
  production build and remaining browser suites (including the concurrently added demo suite)
  were not run by that gate. Only the calendar browser journey above was run separately after
  the final refinements. No skipped stage is presented as passed.

The calendar fix is complete at the existing synthetic boundary. Full repository integration
remains blocked on the unrelated demo test fixtures. No implementation or release gate outside
the authorized calendar repair was upgraded.
