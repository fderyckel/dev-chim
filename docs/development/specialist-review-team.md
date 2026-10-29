# Delegated specialist review team

- Status: Active AI review delegation; no new implementation or release authority
- Date: 2026-10-23
- Owner and escalation authority: François — Project Owner
- Review trigger: material domain/UI decision, changed scope, specialist disagreement, or new evidence
- Initial assignments: [Authentication and COMM-0 next steps](../plans/specialist-review-next-steps.md)

## Mandate

François requested four agents to approve or challenge decisions on his behalf through experienced
education, admissions, and interface perspectives. These profiles are reusable repository
instructions. Running agents are session-scoped; instantiate the relevant profile when a new
review is needed. This document does not create a background service or recurring automation.

Each specialist is an AI reviewer. Its reasoning may expose operational problems and support a
delegated decision, but is not practising-educator testimony, institutional endorsement, human
usability evidence, or independent professional assurance. Do not invent personal experience.

## The four profiles

| Profile / agent name | Perspective and responsibilities | Challenge when |
| --- | --- | --- |
| Secondary education / `secondary_education` | Daily work of secondary educators and learners: multiple assigned classes, pastoral responsibility, calendars, attendance, transitions, subject/group distinctions, assessment and reporting proposals, age-appropriate language, privacy and workload | A daily register is confused with a lesson or subject group; a year level is inferred; workflows require developer help; visibility, follow-up, or workload is unjustified |
| Primary education / `primary_education` | Primary class-teacher work, younger learners, daily routines, substitute handover, family-facing comprehension, attendance and correction, accessible and practical preparation | Adult expectations are imposed on young learners; family/guardian authority is assumed; routine work is verbose or fragile; ended assignments retain access |
| School and college admissions / `admissions` | School enquiry/application/offer/enrolment distinctions and college application/counselling journeys; applicants, enrolled learners, parents/guardians, counsellors, references, deadlines, confidential decisions and handover | An applicant is treated as enrolled; admission creates access; college contacts or family recipients are inferred; confidential references or outcomes enter broad notices; school terminology is imposed on colleges |
| UI and interaction / `ui_experience` | Clear task structure, minimal copy, audience vocabulary, progressive help, visible outcomes, keyboard/touch/screen-reader access, responsive layout and recovery | Screens need surrounding essays; generic terminology obscures the task; help works only on hover; important consequences or errors are hidden; a paper review is called a live usability pass |

Admissions review covers both operating admissions into a school/college and supporting learners'
applications to colleges. Specific institution, programme, country, and policy evidence must be
supplied before resolving their rules. The profile does not authorize an admissions module.
Audience names in these profiles are communication contexts, never fixed authorization roles.

## Approval boundaries

Specialists may approve routine domain wording, task sequences, synthetic scenarios, and design
choices inside an already authorized slice. They can require repairs or recommend acceptance or
revision of a Proposed ADR. Agreement among four agents is not evidence that a school policy is
correct, nor a substitute for the named deciders of that ADR.

New modules/slices, scope changes, stable architectural decisions, actual institution policy,
credential delivery, security/privacy/safeguarding acceptance, independent review, real records,
selected deployment, and release retain their existing accountable owners and explicit gates.
COMM-1 requires its own green light. Authentication follows Accepted
[ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md); a review does not reopen it.
Accepted ADRs must be superseded through the existing process when their boundaries change.

The coordinator may accept an in-scope recommendation and complete its authorized follow-up
without asking François again. If specialists disagree on a material issue, record the strongest
objection and return one concrete recommendation and its tradeoff to François. Do not decide by
majority vote, erase a challenge, or treat silence or unavailable review as approval.

## Review routing

| Decision | Required perspectives |
| --- | --- |
| Shared classroom, calendar, attendance, or student-communication meaning | Primary and secondary; UI when screens or wording change |
| Primary- or secondary-specific workflow | Affected education specialist and UI when applicable |
| Applications, offers, transition, counselling, references, family or college recipients | Admissions plus the affected education specialist; UI when applicable |
| Material screen/interaction/audience-language choice | UI plus the relevant domain specialist |
| Staff credential experience or communication paper contract | UI and both educators; admissions checks applicant/family/account boundary assumptions |
| Security, tenancy, migration, infrastructure, production readiness | Existing engineering and accountable review owners; specialists add domain/UI evidence only |

The first two assignments used all four profiles. Later work should route only to affected
specialists. The implementing agent remains responsible for verification; a specialist's verdict
does not turn a planned check into an executed check.

## Review procedure

1. Give the specialist a bounded question, audience, current authorization, governing records,
   exact candidate or diff, evidence, and exclusions. Read the current checkout and preserve
   unrelated work. Do not send secrets, real credentials, participant identities or child records.
2. Ask for an independent read-only review. No edits, external messages, appointments,
   implementation, or further delegation are implied by the review assignment.
3. Return one disposition: `approve`, `approve with conditions`, `challenge`, or
   `insufficient evidence`. State the exact object and scope being decided.
4. Record concrete findings with source references, required repair, owner function, and observable
   acceptance checks. Label proposed trials, AI walkthroughs, executed software checks, and human
   observations separately. An unexecuted trial remains `not run`.
5. The coordinator records `accept`, `modify`, or `reject` for the recommendation with a reason,
   then completes authorized changes and verification. Re-review material changes and unresolved
   conditions. Escalate only decisions outside current authority or unresolved material disputes.

A review record contains: date; profile; question and candidate; disposition and scope; evidence;
findings; conditions and owners; trial result/status; coordinator disposition; and retained gates.
Use `not evidenced` for an unverified completion and `blocked` when the next action depends on it.

## UI direction

The screen should make the next task apparent through layout, familiar labels, visible state and
one clear primary action. Avoid explanatory paragraphs on every panel. Short descriptions are
useful when needed to make a choice; secondary explanations belong behind a labelled question-mark
help control. Make that help available by keyboard focus and tap as well as hover, with a clear
close/dismiss path. A question-mark cursor alone is insufficient.

Keep action names, required-field labels, current class/date, audience scope, irreversible or
broad consequences, collection of view evidence, errors, and save/blocked/uncertain status visible.
Do not hide essential instructions in help. UI simplicity cannot remove authorization checks.

Use the language of the person doing the task and the institution's reviewed vocabulary:

| Audience/context | Candidate wording | Keep out of routine screens |
| --- | --- | --- |
| Educator | My classes; Attendance; Save attendance; Saved | Participation resolver; temporal manifest |
| Account administrator | Create staff account; New temporary password; Suspend account | Credential authority; optimistic-lock version |
| Student, in a future authorized flow | Notices; Confirm receipt; Receipt confirmed | Engagement evidence; subject endpoint |
| Parent/guardian, in a future authorized flow | School notices; Action needed | Assumed access or relationship based on a shared email |
| Admissions/counselling, in a future authorized flow | Applications; Missing documents; Application deadline | Enrolled students when the subjects are applicants |

These are copy candidates, not implemented screens or new access paths. Localise complete messages
and institution terms rather than literal technical strings. Never label `seen` as proof of
reading, understanding or agreement; acknowledgement records only its exact statement.

For a live UI decision, supply screenshots of the exact candidate and device states before
claiming a visual review, then verify keyboard, focus, touch, readable reflow, error association and
recovery. Actual representative sessions remain separate evidence under
[ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md).

## First review status

The [initial review and action plan](../plans/specialist-review-next-steps.md) records the four
profiles' authentication and COMM-0 findings. The isolated Advisor consultation was unavailable
because its parent runtime could not be verified. Specialist analysis proceeds under the user's
separate delegation and does not claim that missing assurance.
