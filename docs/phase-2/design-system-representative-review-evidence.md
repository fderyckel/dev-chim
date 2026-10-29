# DS-3 representative profile review evidence

- Status: Session package ready; recruitment and all representative sessions remain open
- Authorization date: 2026-10-08
- Authorized by: François — Project Owner
- Protocol: [DS-3 representative profile review packet](design-system-representative-review-packet.md)
- Review surface: `/ui-preview` in local synthetic UI-0
- Boundary: Evidence register only; blank rows and readiness checks are not participant evidence

## Authorization and current disposition

The Project Owner's 2026-10-03 approval made the revised Quiet Light, Calm Dark, and Clear Reading
profiles eligible for representative testing. The 2026-10-08 green light authorizes recruitment,
facilitation, minimized recording, profile refinement or removal, and a later bounded disposition
using the linked protocol.

No participant session, accessibility-user finding, final profile acceptance, ADR 0028 acceptance,
durable preference, production interface, public API, identity integration, Ash preference
resource, or DS-4 implementation is claimed by this record.

## Readiness register

| Requirement                                              | Evidence                                                                                                                  | Status                       |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| Three complete candidate profiles                        | Quiet Light, Calm Dark, and Clear Reading in local UI-0                                                                   | Ready                        |
| Product-owner visual review                              | Revised dark and reading palettes approved to enter representative testing on 2026-10-03                                  | Complete for test entry only |
| Technical matrix                                         | Existing profile, keyboard, accessibility, reflow, forced-colour, reduced-motion, first-paint, and non-persistence checks | Complete for test entry only |
| Facilitator protocol                                     | Linked privacy-safe uncoached task script and measures                                                                    | Ready                        |
| Learner recruitment                                      | No participant record yet                                                                                                 | Open                         |
| School-staff recruitment                                 | No participant record yet                                                                                                 | Open                         |
| Keyboard lived-experience coverage                       | No participant record yet                                                                                                 | Open                         |
| Screen-magnification lived-experience coverage           | No participant record yet                                                                                                 | Open                         |
| High-contrast or forced-colour lived-experience coverage | No participant record yet                                                                                                 | Open                         |
| Reduced-motion lived-experience coverage                 | No participant record yet                                                                                                 | Open                         |
| Readability-focused typography coverage                  | No participant record yet                                                                                                 | Open                         |
| Profile dispositions                                     | No representative finding yet                                                                                             | Open                         |

## Participant register

Use study IDs only. Keep names, contact details, consent records, scheduling information, and any
identity key outside the repository in the approved restricted research location.

| Study ID | Broad perspective | Lived accessibility context | Device, viewport, and input | Date | Session record complete? |
| -------- | ----------------- | --------------------------- | --------------------------- | ---- | ------------------------ |
| Open     | Open              | Open                        | Open                        | Open | No                       |

Do not add a row for a planned, invited, or cancelled participant. A row exists only after consent
and a completed or explicitly withdrawn session. Record a withdrawal without retaining task
details when the participant requests that their data not be used.

## Per-participant session record

Copy this section once for each completed participant. Do not combine several unnamed opinions
into one record.

### Participant `P__`

| Field                                 | Recorded value                             |
| ------------------------------------- | ------------------------------------------ |
| Broad perspective                     | Open                                       |
| Relevant lived experience             | Open; participant-volunteered context only |
| Date                                  | Open                                       |
| Device and viewport                   | Open                                       |
| Browser zoom or magnification         | Open                                       |
| Input method                          | Open                                       |
| Contrast, colour, and motion settings | Open                                       |
| Counterbalanced profile order         | Open                                       |
| Consent recorded outside repository   | Open: `yes`, `withdrawn`, or `not valid`   |

| Task                                 | Completion | Seconds | Wrong turns | Help | Finding |
| ------------------------------------ | ---------- | ------- | ----------- | ---- | ------- |
| Establish synthetic context          | Open       | Open    | Open        | Open | Open    |
| Find UI preview                      | Open       | Open    | Open        | Open | Open    |
| Explain available choices            | Open       | Open    | Open        | Open | Open    |
| Compare Quiet Light                  | Open       | Open    | Open        | Open | Open    |
| Compare Calm Dark                    | Open       | Open    | Open        | Open | Open    |
| Compare Clear Reading                | Open       | Open    | Open        | Open | Open    |
| Explain three status meanings        | Open       | Open    | Open        | Open | Open    |
| Complete one recovery interpretation | Open       | Open    | Open        | Open | Open    |
| Reset to default                     | Open       | Open    | Open        | Open | Open    |
| Explain reload/non-persistence       | Open       | Open    | Open        | Open | Open    |

| Profile       | Reading comfort, 1–5 | Visual comfort, 1–5 | Confidence, 1–5 | Participant's stated benefit or harm |
| ------------- | -------------------- | ------------------- | --------------- | ------------------------------------ |
| Quiet Light   | Open                 | Open                | Open            | Open                                 |
| Calm Dark     | Open                 | Open                | Open            | Open                                 |
| Clear Reading | Open                 | Open                | Open            | Open                                 |

| Closing question                | Recorded response |
| ------------------------------- | ----------------- |
| Preferred profile, or none      | Open              |
| Rejected profile, or none       | Open              |
| First requested change          | Open              |
| Anything that would prevent use | Open              |
| Facilitator factual observation | Open              |

## Finding register

| ID   | Profile or invariant | Participant evidence | Severity | Affected perspectives | Owner | Decision | Status |
| ---- | -------------------- | -------------------- | -------- | --------------------- | ----- | -------- | ------ |
| Open | Open                 | Open                 | Open     | Open                  | Open  | Open     | Open   |

The finding text must distinguish the participant's words, the facilitator's observation, and the
team's interpretation. Do not upgrade an interpretation into a quotation.

## Profile disposition

| Profile       | Need demonstrated | Comfort and comprehension pattern | Open critical or serious findings | Disposition                           | Decision owner and date |
| ------------- | ----------------- | --------------------------------- | --------------------------------- | ------------------------------------- | ----------------------- |
| Quiet Light   | Open              | Open                              | Open                              | Open: `retain`, `revise`, or `remove` | Open                    |
| Calm Dark     | Open              | Open                              | Open                              | Open: `retain`, `revise`, or `remove` | Open                    |
| Clear Reading | Open              | Open                              | Open                              | Open: `retain`, `revise`, or `remove` | Open                    |

## DS-3 human-evidence gate

| Gate                                    | Current result                                     |
| --------------------------------------- | -------------------------------------------------- |
| Participant coverage                    | Open; zero completed participant records           |
| Required tasks                          | Open                                               |
| Accessibility lived-experience coverage | Open                                               |
| Critical and serious findings           | Not assessable before sessions                     |
| Profile retain/revise/remove decisions  | Open                                               |
| Product Owner disposition               | Open after completed evidence                      |
| Product-experience disposition          | Open after completed evidence                      |
| Accessibility disposition               | Open after completed evidence                      |
| DS-3 outcome                            | **Open — session readiness is not human evidence** |

Even a completed DS-3 round does not itself accept ADR 0028 or authorize DS-4. The ADR's dense,
narrow, correction/recovery, and public-boundary security conditions remain separately governed.

## Related records

- [DS-3 representative profile review packet](design-system-representative-review-packet.md)
- [ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md)
- [Experience design-system proposal](../plans/experience-design-system-and-governed-personalization-proposal.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)
