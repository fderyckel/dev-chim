# CF-3 connected calendar entry review packet

- Status: Prepared for review; no review response or approval is recorded
- Prepared: 2026-10-05
- Accountable owner: François — Project Owner
- Target slice: CF-3, the first same-origin synthetic calendar preparation write
- Governing records: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md),
  [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md),
  [ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md), and
  [ADR 0034](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)

## Decision requested

This packet asks reviewers whether the bounded CF-3 workflow may move from a local, unsaved
prototype to a disabled-by-default same-origin synthetic implementation candidate. Approval would
permit the browser to call only the accepted named calendar actions through the authoritative
session boundary and to refresh from committed writer state.

Approval would **not** authorize a public deployment, real learner or staff data, a pilot, a real
data import, generic calendar CRUD, a timetable, clock-time scheduling, a recurrence engine, or
production release. C25-06, selected-environment qualification, independent security/privacy
review, records ownership, recovery, deployment, and real-data gates remain separate.

Until the completed records below are accepted, the `/academic-calendar` page remains explicitly
local, synthetic, unsaved, and disconnected. Repository tests or a Project Owner instruction to
continue engineering cannot substitute for the named representative findings.

## What François must submit

Submit one completed copy of this document, with links or attachments for the evidence below.
Names may be kept in a restricted review record when publication is inappropriate, but the
repository disposition must identify the reviewer through a stable privacy-preserving reference.

1. **C25-03-R representative validation:** five context records covering primary/early-years,
   secondary, combined formal education, college/community college, and university operations.
   One person may cover several contexts only when their current or recent experience is recorded
   for each context.
2. **Two real calendar-pattern records:** at least two materially different current or recent
   calendar patterns, with privacy-preserving institution descriptions, actual local terminology,
   ownership, dates, periods, instructional weekdays, closures, gaps, time zone, and exceptional
   cases. These records may be supplied by the C25-03-R reviewers.
3. **Educational-domain consolidation:** one named educational-domain owner consolidates all five
   context findings, identifies every blocking objection, and records an overall disposition.
4. **C25-05 product-experience/accessibility record:** one named accountable reviewer evaluates
   the bounded journey, and representative calendar operators for the two patterns complete the
   tasks below without developer interpretation.
5. **C25-05 security/privacy record:** one named accountable reviewer accepts or rejects the
   proposed same-origin session and named-action treatment for synthetic data. The interim
   security/privacy owner may review this synthetic entry; that is not independent deployment or
   real-data approval.
6. **Actual identity-connection choice:** identify the provider-neutral connection and exact
   synthetic environment to qualify under ADRs 0029/0030. Do not put credentials, tokens, secrets,
   callback codes, or real restricted records in this packet or the repository.

Items 1–5 supply the human records needed to decide whether CF-3 implementation may cross the
public browser boundary; only accepted dispositions close those conditions. Item 6 is additionally
required before a connected execution is enabled.

## Safe review setup

Use synthetic or de-identified information only. Do not enter names of learners, guardians,
teachers, staff accounts, health information, safeguarding information, credentials, or private
identity-provider data.

The current review surface is the unsaved local prototype:

1. From the repository root, the facilitator runs `make web-dev`.
2. Open `http://127.0.0.1:3000/academic-calendar`.
3. Confirm the page says `Not saved` and `Local browser calculation · no core connection`.
4. Reviewers may change every visible field and select `Preview calendar`.
5. Nothing in this review should create, save, publish, or connect a calendar.

The prototype evidence is recorded in
[Academic calendar preparation prototype evidence](academic-calendar-preparation-prototype-evidence.md).
The authoritative private writer evidence is recorded separately in
[Academic calendar executable-contract evidence](academic-calendar-contract-evidence.md).

## A. C25-03-R representative records

Complete one record for each of the five contexts. Use the assigned scenarios, seven common
questions, and three context-specific questions in the
[institutional-structure review packet](institutional-structure-review-packet.md#representative-institution-reviews--g2).
The answers must cover the actual context rather than only the synthetic example.

### Representative record template

| Field | Recorded value |
| --- | --- |
| Reviewer name or restricted reviewer reference | Open |
| Current role and relevant operating experience | Open |
| Context | Open: primary/early-years, secondary, combined, college/community college, or university |
| Organization/context represented | Open; a privacy-preserving descriptor is acceptable |
| Review date | Open |
| Assigned scenarios completed | Open |
| Seven common answers | Open; attach the completed question table |
| Three context-specific answers | Open; attach the completed question table |
| Actual vocabulary used | Open |
| Institution, unit, site, and accountability mapping | Open |
| Missing cases or misleading meanings | Open |
| Concerns and proposed changes | Open |
| Conditions, with owner and affected gate | Open |
| Disposition | Open: `approve`, `approve with condition`, or `do not approve` |

Copy the template five times and label each copy with its context. A blank answer, job title without
the completed questions, unnamed group opinion, repository author, product-owner assertion, or AI
analysis does not satisfy C25-03-R.

## B. Real calendar-pattern records

Record at least two materially different patterns. Different labels on the same dates are not
materially different. Examples of material difference include terms versus semesters or blocks;
different instructional weekdays; an academic year crossing a different civil-year boundary;
substantial gaps; different closure treatment; or more than one explicit calendar for one owning
unit. Do not force a difference that does not exist in the reviewed institutions.

### Calendar-pattern template

| Field | Pattern record |
| --- | --- |
| Pattern reference | Open |
| Representative reviewer and context | Open |
| Current or recent year represented | Open |
| Exact owning institution or unit, described without restricted data | Open |
| Why this unit owns the calendar | Open |
| Whether the unit needs more than one simultaneous calendar | Open |
| Local name for academic year | Open |
| Year start and end dates | Open |
| IANA time zone | Open |
| Period type and local period labels | Open |
| Ordered period date ranges | Open |
| Dates intentionally outside all primary periods | Open |
| Ordinary instructional weekdays | Open |
| Dated closures and local closure terminology | Open |
| Opening exceptions or other unsupported cases | Open |
| How a published mistake is corrected today | Open |
| Which later records rely on the published calendar | Open |
| Contract fit | Open: `fits`, `fits with condition`, or `does not fit` |
| Required condition or change, owner, and gate | Open |

For each pattern, the reviewer must also answer:

1. Can they select one exact calendar without relying on a parent, active unit, default, label, or
   latest record?
2. Does the year/period/weekday/closure model reproduce the intended instructional dates?
3. Are gaps and closures explained correctly rather than silently treated as teaching days?
4. Can two legitimate calendars coexist without one overriding the other?
5. Would a downstream attendance record know which exact published revision it used?
6. What real case cannot be represented safely by the first contract?

Any need for simultaneous overlapping primary sequences, implicit hierarchy inheritance, mutable
published history, or ambiguous ownership is a blocking ADR 0021 review trigger rather than a UI
preference.

## C. Educational-domain consolidation

| Field | Recorded value |
| --- | --- |
| Educational-domain owner | Open |
| Role and relevant experience | Open |
| Review date | Open |
| Five context records reviewed | Open |
| Two calendar-pattern records reviewed | Open |
| Blocking objections | Open |
| Non-blocking implementation conditions, owners, and gates | Open |
| Accepted residual risks | Open |
| Required ADR or contract change | Open; `none` is valid only with a reason |
| Overall disposition | Open: `approve`, `approve with condition`, or `do not approve` |

A blocking objection must be resolved before CF-3. A finding that changes tenant ownership,
calendar identity, institutional ownership, primary-operator meaning, immutable publication, or
hierarchy non-authority requires the governing decision to be superseded before implementation.

## D. C25-05 product experience and accessibility

The reviewer observes each representative operator using the local prototype. The operator should
think aloud, but the facilitator must not explain field meaning or tell them which answer is
correct. Record assistance separately from successful completion.

### Required operator tasks

1. Identify the institution, academic year, save/publication state, and whether the screen is
   authoritative.
2. Enter or adapt one reviewed calendar pattern, including the year, periods, weekdays, closures,
   and time zone.
3. Preview a valid definition and explain the result in their own words.
4. Resolve one instructional date, one closure, one ordinary weekday off, one date in a gap, and
   one date outside the year.
5. Create an overlapping-period error, find the explanation, and recover without losing their
   understanding of the previous valid preview.
6. Explain the intended future distinction between `save draft`, `preview publication`,
   `publish`, and the committed published revision.
7. Explain what they would expect after session expiry, access denial, an inactive module, a stale
   version, an interrupted request, and a successful publication.
8. Complete the task at a narrow layout and using keyboard-only navigation. Where the reviewer or
   participant uses assistive technology, record the actual technology and result.

### Product-experience/accessibility record

| Field | Recorded value |
| --- | --- |
| Accountable reviewer | Open |
| Role and accessibility/experience competence | Open |
| Review date and environment | Open |
| Representative operators observed | Open |
| Calendar patterns exercised | Open |
| Wide and narrow layouts exercised | Open |
| Keyboard-only result | Open |
| Assistive technology and result | Open; state `not used` with rationale rather than leaving blank |
| Tasks completed without interpretation | Open |
| Assistance required | Open |
| Confusing terms, states, focus behavior, or errors | Open |
| Required changes, owner, and evidence for closure | Open |
| Accepted residual risks | Open |
| Disposition | Open: `approve`, `approve with condition`, or `do not approve` |

Approval must explicitly confirm that a participant can distinguish draft, preview, published, and
not-saved states; identify the exact institution/calendar; understand that hierarchy or selection
does not grant authority; and recover from the listed failure states. Automated accessibility
checks support this record but do not replace it.

## E. C25-05 security and privacy

Review the proposed CF-3 boundary against TM-01, TM-02, TM-09 through TM-15, TM-17, and TM-19 in
the [threat model](../security/threat-model.md), plus ADR 0030's request/action contract.

The approved implementation candidate must:

- derive tenant, actor, membership, purpose, placement, module, capability, and field policy from
  the current trusted session and server-owned route contract;
- accept no browser-supplied tenant, repository, placement, capability, authority, or role;
- expose only exact named calendar actions and exact reads, never generic CRUD, arbitrary filters,
  export, or traversal;
- require the exact same origin and a session-bound CSRF proof for unsafe methods;
- bind idempotency to tenant, actor, action, aggregate, and canonical request, with no automatic
  client retry;
- use the writer for current authority and immediate read-after-write confirmation;
- return `no-store` responses and stable non-disclosing errors;
- keep labels and free text out of audit/outbox payloads unless explicitly classified and needed;
- show support mode without impersonation and recheck any grant for every action; and
- remain disabled by default until the reviewed runtime, identity connection, origin, keys, edge,
  rate, recovery, and operating controls are supplied.

### Security/privacy review record

| Field | Recorded value |
| --- | --- |
| Accountable reviewer | Open |
| Role and relevant competence | Open |
| Review date | Open |
| Threats and ADR sections reviewed | Open |
| Synthetic data classification accepted | Open |
| Session, origin, and CSRF treatment | Open |
| Tenant and authorization treatment | Open |
| Idempotency, conflict, audit, and outbox treatment | Open |
| Stable error and non-disclosure treatment | Open |
| Logging, telemetry, and evidence redaction treatment | Open |
| Required negative tests | Open |
| Conditions, owner, and closure evidence | Open |
| Accepted residual risks | Open |
| Disposition | Open: `approve`, `approve with condition`, or `do not approve` |

## F. Provider-neutral identity-connection record

This record selects what engineering may qualify; it does not contain connection secrets.

| Field | Recorded value |
| --- | --- |
| Connection owner | Open |
| Synthetic environment | Open |
| Protocol and provider | Open |
| Qualified issuer or metadata reference | Open; restricted reference is acceptable |
| Exact public origin | Open |
| Exact callback path | `/auth/callback` unless ADR 0030 is superseded |
| Synthetic actor and tenant-membership source | Open |
| Required assurance | Open |
| Connection activation and suspension owner | Open |
| Key/secret injection and rotation owner | Open |
| Edge/TLS, host, rate, and recovery owner | Open |
| Evidence location | Open |
| Disposition | Open: `ready for qualification`, `condition`, or `not ready` |

Do not paste a client secret, private key, token, cookie, authorization code, assertion, password,
or real user record into this table, chat, issue, test, log, or committed evidence.

## Consolidated entry decision

The Project Owner records this only after sections A–F are complete and every blocking condition is
resolved. `Approve with condition` is valid only when the condition does not need to be satisfied
before CF-3 and names an owner, later gate, and closure evidence.

| Field | Recorded value |
| --- | --- |
| Decision date | Open |
| Project Owner | François |
| C25-03-R representative disposition | Open |
| Two real calendar patterns accepted | Open |
| Educational-domain disposition | Open |
| Product-experience/accessibility disposition | Open |
| Security/privacy disposition | Open |
| Identity connection ready for qualification | Open |
| Blocking conditions and closure evidence | Open |
| Conditions retained after CF-3 entry | Open |
| CF-3 entry outcome | Open: `approve`, `approve with condition`, or `do not approve` |

An approved CF-3 entry authorizes only a reviewable, synthetic, disabled-by-default implementation
candidate and its tests. Enabling an endpoint or identity connection still requires its exact
runtime configuration and qualification record. Real data, a pilot, deployment, and production
remain prohibited until their own gates close.

## Submission completeness check

- [ ] Five C25-03-R context records are complete and attributable.
- [ ] Seven common and three context-specific questions are answered for each context.
- [ ] Two materially different real calendar-pattern records are complete.
- [ ] The educational-domain owner has consolidated the findings.
- [ ] Representative operators completed the C25-05 tasks.
- [ ] The accountable product-experience/accessibility record is complete.
- [ ] The accountable security/privacy record is complete.
- [ ] The provider-neutral identity-connection record identifies an exact synthetic environment.
- [ ] Every blocking condition has closure evidence.
- [ ] The Project Owner recorded the consolidated entry decision.

If any required box is open, CF-3 remains blocked and eligible private synthetic work may continue
without creating or enabling a connected browser write.
