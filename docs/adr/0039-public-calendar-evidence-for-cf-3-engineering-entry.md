# ADR 0039: Public-calendar evidence for CF-3 engineering entry

- Status: Accepted
- Date: 2026-10-06
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Product and platform engineering
- Decision basis: Project Owner direction that official public operational calendars are the
  available external evidence and that the project must proceed without inventing reviewers
- Evidence: [CF-3 public calendar source review](../phase-2/cf-3-public-calendar-source-review.md)
- Partially supersedes: [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md),
  [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md), and
  [ADR 0034](0034-c25-03-delegated-educational-structure-acceptance.md) only for the timing of
  source and representative evidence before a disabled local synthetic CF-3 implementation

## Context

CF-3 connects the existing academic-calendar preparation screen to the authoritative private
calendar writer through the accepted same-origin session and named-action boundary. The prepared
review packet required named representatives across five institutional contexts, two operator-led
calendar records, representative usability observation, a separate product reviewer, and a
selected real identity connection before implementation could start.

Those records are not available. The Project Owner has directed the project to use the official
public operational calendars already identified and to deal explicitly with the resulting evidence
limit. Retaining an impossible prerequisite would stop synthetic engineering without improving
the truth of the evidence. Treating public documents as interviews or approval would instead
fabricate assurance.

The source review records current or recent calendars published by international schools through
their official sites or Finalsite-hosted resources. They provide real terminology, dates, terms,
closures, rotations, make-up days, and operational distinctions. They do not identify the internal
calendar owner, prove correction procedures, establish the institution's time-zone authority, or
show that representative users understand Chimwemwe's workflow.

## Decision drivers

- Continue the classroom-first plan with a reviewable connected calendar candidate.
- Use the strongest external evidence actually available without relabelling it.
- Keep the first browser write local, synthetic, disabled by default, and reversible.
- Separate engineering entry from real institutional adoption, pilot, deployment, and production.
- Preserve the accepted same-origin, session, authorization, exact-action, audit, outbox, and
  immutable-publication contracts.

## Considered options

1. Keep CF-3 blocked until named institutional representatives become available. Rejected for the
   synthetic engineering entry because the Project Owner has confirmed those records will not be
   supplied and the private writer plus public operational sources permit a bounded testable step.
2. Mark the public calendars as completed representative reviews. Rejected because documents do
   not provide testimony, task observation, accountable sign-off, or internal operating context.
3. Admit a disabled local synthetic CF-3 candidate using source-backed desk validation, while
   moving actual representative validation to the first real-data pilot or production-adoption
   decision. Selected.

## Decision

Official public operational calendars are sufficient external domain evidence to start and test a
**disabled-by-default local synthetic CF-3 implementation candidate**. This candidate is engineering
work, not an L2 release, public deployment, institutional adoption, pilot, or production claim.

The source review uses public records from International School Bangkok, KIS International School
Bangkok, Rugby School Thailand, Harrow International School Bangkok, International School of
Tanganyika, International School of Hamburg, Oberoi International School, and Gyeonggi Suwon
International School. The inventory is confirmed but not claimed to be a complete list of every
Finalsite customer.

The source review may establish that the contract encounters real terms, closures, non-student
days, make-up days, multiple public calendar categories, staggered starts, and timetable rotation
labels. It may not establish an unstated fact. Time zones, internal ownership, correction practice,
simultaneous-calendar authority, and unpublished workflows remain `not established` unless an
official source states them.

### Engineering admission

CF-3 may now implement and locally test only this boundary:

- the existing preparation screen calls the exact accepted academic-calendar actions;
- the server derives actor, tenant, membership, placement, module, capability, purpose, and field
  policy from the synthetic same-origin session;
- the writer remains authoritative and the browser refreshes from committed state;
- success, validation, denial, stale-version, expired-session, origin, CSRF, conflict, and
  interrupted-request states are explicit and tested;
- the implementation remains disabled by default outside its local synthetic qualification
  environment; and
- fixtures remain fictional. Public calendar facts are source evidence and test inspiration, not
  imported institutional records or permission to copy a school's operational dataset.

CF-3 does not gain timetable, recurrence, rotating-day, bell-period, room, event, athletics,
subscription, or calendar-feed authority. ISB day codes, KIS A/B weeks, and similar cycles are
recorded as evidence for a later scheduling/cycle contract, not forced into `AcademicCalendar`.

### Evidence tiers and retained gates

The following evidence classes remain distinct:

| Evidence | What it proves | What it does not prove |
| --- | --- | --- |
| Official public calendar | Real published terminology and visible operating patterns | Internal ownership, completeness, user comprehension, approval, or correction workflow |
| Synthetic engineering tests | The implementation preserves the accepted technical contract | Institutional fitness, accessibility for representative users, or production readiness |
| Project Owner synthetic disposition | Authority to build the bounded candidate | Independent or institution-side assurance |
| Later representative/pilot evidence | Fitness for the participating institution and actual operators | General production approval for every institution |

`C25-03-R` is therefore retained as **actual representative adoption validation**, but it no
longer blocks the disabled local synthetic CF-3 implementation. It blocks real institutional data
or import, an institutional pilot, deployment, claims of representative usability or operational
correctness, and production release. It may be satisfied by the first participating institution's
named domain and operator records rather than by pre-recruiting five unavailable reviewers.

The representative-user part of `C25-05` moves to the same adoption boundary. Automated
accessibility evidence, technical product review, and the Project Owner's synthetic disposition
remain required for the CF-3 engineering exit. Independent security/privacy review remains due
before Restricted data or an institutional pilot.

No real identity provider is required to build the disabled candidate. The already accepted
synthetic public-session adapter may qualify the local route. A selected provider-neutral identity
connection, origin, keys, edge, rate, recovery, and operating owners remain mandatory before any
deployed endpoint is enabled.

## Consequences

### Positive

- Engineering can proceed using real published calendar diversity without inventing people.
- Missing facts remain visible instead of being filled with guesses.
- The riskiest browser/session/action properties can be tested before a pilot partner exists.
- Representative effort is requested when there is a concrete participating institution and a
  real adoption decision to evaluate.

### Negative

- Public calendars may be incomplete, revised without notice, or omit internal operating rules.
- Synthetic usability and accessibility checks cannot predict every operator's understanding.
- A later participating institution may require a contract change after CF-3 has been built.
- Rotations and event calendars visible in the sources remain intentionally unsupported.

## Security, privacy, operability, and migration effects

No public school calendar is imported into tenant state. Test fixtures use fictional institution,
actor, calendar, and source identifiers. URLs and summarized public facts may remain in design
evidence, but no scraped event feed, personal event information, credential, token, restricted
record, or school contact is stored.

ADRs 0029 and 0030, TM-01, TM-02, TM-09 through TM-15, TM-17, and TM-19 remain binding. This
decision changes evidence timing, not the same-origin session, tenant isolation, named-action,
authorization, idempotency, immutable publication, audit, outbox, or redaction controls.

There is no migration or production-data authority. A later source import requires its own mapping,
provenance, reconciliation, records ownership, licensing, correction, and recovery decision.

## Validation evidence

The [CF-3 public calendar source review](../phase-2/cf-3-public-calendar-source-review.md) records
the official sources, directly published facts, source limitations, two materially different
pressure-test patterns, and the boundary findings used by this decision. The
[CF-3 connected calendar entry disposition](../phase-2/cf-3-connected-calendar-entry-review-packet.md)
records the Project Owner's bounded synthetic entry and retained adoption gates.

This is entry evidence only. CF-3 implementation, browser, action, security, and repository checks
remain to be executed and recorded before the slice can be called complete.

## Acceptance checks

CF-3 engineering is complete only when:

1. public source findings and unknowns remain traceable in the source review;
2. the browser uses no client-supplied tenant, placement, capability, role, or calendar authority;
3. only exact named actions and exact reads are exposed;
4. read-after-write state comes from the authoritative writer;
5. denial, stale version, session expiry, origin, CSRF, module, capability, rollback, and
   non-disclosure checks pass;
6. accessible success, validation, conflict, and recovery states pass the repository's technical
   browser checks;
7. rotation, recurrence, timetable, event, and subscription behavior remains outside the module;
8. the implementation cannot be enabled outside the explicit local synthetic environment; and
9. the required repository gate is run and reported without converting any failure into a green
   claim.

## Fallback and exit cost

If the public patterns expose a contradiction in calendar identity, ownership, publication, or
instructional-date meaning, keep the affected feature outside CF-3 and supersede ADR 0021 before
expanding it. If the connected adapter cannot preserve ADR 0030, keep the route disconnected and
retain the private writer.

Before real data, exit cost is limited to documents, synthetic fixtures, the local adapter, and its
tests. A pilot-specific contradiction must be resolved before importing data or relying on the
calendar for attendance.

## Review triggers

- a participating institution supplies contradictory domain or operator evidence;
- a real calendar requires simultaneous overlapping primary sequences or implicit hierarchy
  inheritance;
- a source import, subscription, or external calendar feed is proposed;
- a real identity connection, public origin, pilot, deployment, or Restricted data is proposed;
- the interface is claimed to be representative-user approved; or
- rotation, recurrence, timetable, clock-time, event, or room behavior is proposed for this module.

## Related records

- [CF-3 public calendar source review](../phase-2/cf-3-public-calendar-source-review.md)
- [CF-3 connected calendar entry disposition](../phase-2/cf-3-connected-calendar-entry-review-packet.md)
- [Academic calendar authority](../architecture/academic-calendar-authority.md)
- [Academic calendar implementation evidence](../phase-2/academic-calendar-contract-evidence.md)
- [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md)
- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0034](0034-c25-03-delegated-educational-structure-acceptance.md)
- [Threat model](../security/threat-model.md)
