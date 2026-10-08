# DS-3 representative profile review packet

- Status: Authorized and ready for recruitment and sessions; no participant session is recorded
  yet
- Authorization date: 2026-10-08
- Authorized by: François — Project Owner
- Governing records: [ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md),
  the [design-system proposal](../plans/experience-design-system-and-governed-personalization-proposal.md),
  and [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- Review surface: `/ui-preview` in local synthetic UI-0
- Evidence register: [DS-3 representative review evidence](design-system-representative-review-evidence.md)
- Boundary: Qualitative local evaluation of Quiet Light, Calm Dark, and Clear Reading; no real
  data, production client, saved preference, identity integration, public interface, ADR
  acceptance, or DS-4 authority

## Decision this review supports

The review answers one bounded question:

> Do the three complete candidate profiles help representative people work comfortably and
> understand the same hierarchy, status, recovery, and reset behavior?

The possible disposition for each profile is `retain`, `revise`, or `remove`. A participant is not
asked to approve Chimwemwe, ADR 0028, production personalization, or a school workflow. The
Project Owner's 2026-10-03 visual approval made the revised profiles eligible for this review; it
did not make them final public choices.

## What remains invariant

Every participant sees the same:

- page and section hierarchy;
- controls, focus, selection, and reset behavior;
- neutral, information, positive, attention, and critical meanings;
- loading, empty, denied, retryable, conflict, and unexpected-error language; and
- explicit statement that the local synthetic choice is not saved.

The session tests whether people understand these invariants across the profiles. It must not
invite arbitrary colors, CSS, remote fonts, hidden status meaning, or per-component styling.

## First-round participant coverage

Use 8–12 unique participants for the first qualitative round. This is a discovery round, not a
statistical sample or accessibility certification.

The completed set must include:

- at least three learners across meaningfully different learning contexts or ages;
- at least three school staff members, including one person who routinely performs browser-dense
  work and one who routinely performs short or time-sensitive tasks;
- a person who normally navigates by keyboard without a pointer;
- a person who normally uses screen magnification;
- a person who normally uses high-contrast or forced-colour settings;
- a person who normally uses reduced-motion settings; and
- a person who actively benefits from readability-focused typography.

These perspectives may overlap when the participant genuinely has the relevant lived experience.
Do not label a person as representing an accessibility need merely because the facilitator turns
on a setting for them.

Prefer adult learners for the first round. Do not recruit a minor until the responsible
institution has approved the consent, assent, safeguarding, supervision, and withdrawal process.
No session with a minor may rely on this repository packet alone as the safeguarding procedure.

## Privacy and research conduct

- Use only the visibly synthetic UI-0 fixtures. Never enter a participant's, learner's, school's,
  or staff member's real information.
- Tell participants that the interface is being tested, not them, and that stopping has no
  consequence.
- Obtain the locally required informed consent before beginning. Obtain assent and the required
  adult consent for any approved minor session.
- Record a study ID such as `P01`, not a participant name, account, email address, school, or other
  direct identifier in the repository.
- Describe context broadly, such as `secondary learner` or `school office staff`; keep the
  identity key, consent record, and scheduling details outside the repository under the approved
  research owner.
- Do not record audio, video, screen, keystrokes, or assistive-technology output by default. If a
  recording is genuinely needed, obtain separate consent and store it only in the approved
  restricted research location.
- Do not infer disability, age, confidence, or preference from observation. Record only what the
  participant volunteers or what the task directly demonstrates.

## Session setup

1. Start the repository-owned local synthetic browser with `make web-dev`.
2. Confirm the page visibly says `Local prototype`, `synthetic data`, and `Local preview only`.
3. Use a fresh browser tab at the participant's ordinary viewport. Do not use browser storage,
   saved profile state, real authentication, or a connected school workflow.
4. Let the participant use their normal input and accessibility setup. Record the browser,
   viewport, zoom, input, and relevant platform settings without recording sensitive device data.
5. Start on Home. Do not open the profile chooser for the participant.
6. Keep a second facilitator-only note surface outside the participant's viewport.
7. Use a counterbalanced comparison order after the participant discovers the chooser:
   `Quiet Light → Calm Dark → Clear Reading`, `Calm Dark → Clear Reading → Quiet Light`, or
   `Clear Reading → Quiet Light → Calm Dark`. Rotate the sequence across participants.
8. Reload before the final non-persistence question so the participant sees the actual default
   behavior.

If a platform setting cannot be tested reliably, record it as `not run` with the reason. Never
convert a missing setup into a pass.

## Moderator opening

Read this without promising that the profiles are good:

> We are testing this interface, not you. It uses made-up information and does not save your
> choice. Please work as you normally would and say what you expect, notice, dislike, or find
> uncomfortable. You may pause or stop at any time. I will not help unless you become blocked; if
> I help, I will record that.

Ask what device, input method, zoom, contrast, motion, and reading settings the participant
normally uses. Do not ask for a diagnosis.

## Uncoached tasks

Give one task at a time. Do not name the target control or status before the participant finds it.

### Task 1 — Establish context

Starting on Home, ask:

> Tell me what you think this page is, whose information you are viewing, and whether anything
> here is real or saved.

Record whether the participant identifies the local synthetic boundary before attempting an
action.

### Task 2 — Find the review surface

Ask:

> Find where you would inspect or change how this interface looks and feels.

Record completion, path, wrong turns, input method, and whether the label `UI preview` is
understandable.

### Task 3 — Discover the choices

Ask:

> Without changing anything yet, explain what choices seem available and what you expect them to
> change.

Record whether the participant expects a complete experience change or mistakes the controls for
arbitrary styling, saved settings, authority, or real account preferences.

### Task 4 — Compare all three profiles

Use the assigned counterbalanced order. For each profile, ask the participant to:

1. select it using their normal input;
2. identify the page title, the main review region, and one secondary explanation;
3. distinguish `Information`, `Needs attention`, and `Critical` in their own words;
4. locate one recovery state and explain the next step they would take; and
5. rate reading comfort, visual comfort, and confidence from 1 to 5, then explain the rating.

Do not ask whether a color is pretty. Ask whether the hierarchy, meaning, and next step remain
clear and whether any surface causes strain or discomfort.

### Task 5 — Choose or reject

Ask:

> Which profile, if any, would you choose for a normal session? Is there one you would never use?
> What specific need does your choice help?

`None` is a valid answer. Record disliked and rejected profiles; do not turn every preference into
a requirement to keep more choices.

### Task 6 — Reset and persistence

Ask:

> Return to the Chimwemwe default. Now leave or reload the page. What do you expect to happen to
> your choice?

Record whether reset succeeds, whether the default is recognized, and whether the participant
correctly understands that this local preview is not saved.

## Accessibility-focused variants

Use the same tasks and meanings. Change only the participant's normal access path:

- **Keyboard:** no pointer; record focus visibility, order, obscured focus, and whether radio and
  reset behavior are understood.
- **Magnification:** use the participant's normal magnification or zoom, up to the reviewed 400%
  range; record loss of context, two-dimensional scrolling, clipped content, and fatigue.
- **High contrast or forced colours:** use the participant's normal platform setting; record
  selection, focus, status distinction, and any invisible boundary.
- **Reduced motion:** use the participant's normal setting and ask whether any transition or
  loading treatment remains distracting.
- **Readability-focused typography:** compare Clear Reading against the other profiles; record
  whether the larger type, line spacing, and muted paper surface improve or worsen reading.

The facilitator turning on an unfamiliar setting for a participant is a technical demonstration,
not representative evidence for that setting.

## Measures

Record these values for every task:

| Measure              | Allowed values                                                                    |
| -------------------- | --------------------------------------------------------------------------------- |
| Completion           | `unassisted`, `assisted`, `not completed`, or `not run`                           |
| Time                 | Elapsed seconds, interpreted qualitatively rather than as a performance benchmark |
| Wrong turns          | Count plus a short factual description                                            |
| Status comprehension | Participant's words plus `correct`, `partial`, or `incorrect`                     |
| Help                 | Exact neutral prompt given, or `none`                                             |
| Reading comfort      | 1–5 plus participant explanation                                                  |
| Visual comfort       | 1–5 plus participant explanation                                                  |
| Confidence           | 1–5 plus participant explanation                                                  |
| Preference           | `Quiet Light`, `Calm Dark`, `Clear Reading`, or `none`                            |
| Rejected profile     | Profile and reason, or `none`                                                     |

Report counts and observed patterns. Do not calculate a false precision score or claim population
preference from this small qualitative round.

## Finding severity and response

| Severity | Meaning                                                                                                                               | Required response                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Critical | The participant cannot complete an essential task, loses meaning or control, or experiences a serious accessibility or safety failure | Stop promotion of the affected profile or interaction; revise before another acceptance decision |
| Serious  | Repeated misunderstanding, strain, inaccessible operation, or incorrect status/recovery interpretation                                | Revise and rerun the affected tasks with relevant participants                                   |
| Moderate | Avoidable delay, wrong turn, unclear copy, or profile-specific discomfort with a usable recovery                                      | Record owner and disposition before closing the round                                            |
| Minor    | Polish issue that does not materially affect completion, meaning, accessibility, or comfort                                           | Backlog or accept explicitly with rationale                                                      |

When a finding changes semantic status meaning, focus, hierarchy, reset, or the non-persistence
boundary, treat it as a design-system issue. When it concerns a fixture's school meaning, keep it
outside this profile decision and route it to the workflow owner.

## First-round completion rule

The first round is complete only when:

- 8–12 unique participant records cover the learner, staff, and lived accessibility perspectives
  above;
- every participant attempted profile discovery, all three profile comparisons, status meaning,
  one recovery task, reset, and the non-persistence question;
- every critical and serious finding is either closed by a verified change or leaves the affected
  profile marked `revise` or `remove`;
- every retained profile demonstrably helps at least one stated participant need and has no open
  serious harm for another covered perspective;
- findings and rejected choices are recorded, not summarized away; and
- the Product Owner, product-experience reviewer, and accessibility reviewer record the bounded
  profile disposition.

Completing this round may close the DS-3 human-evidence gate. It does not by itself accept ADR
0028: dense-workflow, narrow-workflow, correction/recovery, and public-boundary security evidence
remain separate acceptance conditions. It also does not authorize DS-4.

## Facilitator close

Ask:

> What is the one thing you would change first? Is there anything about these choices that would
> make you avoid using the interface?

Thank the participant, confirm where withdrawal or follow-up requests go, and transfer only the
minimized session result into the evidence register.

## Related records

- [DS-3 representative review evidence](design-system-representative-review-evidence.md)
- [ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md)
- [Experience design-system proposal](../plans/experience-design-system-and-governed-personalization-proposal.md)
- [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)
