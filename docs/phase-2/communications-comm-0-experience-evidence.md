# COMM-0 governed communications experience evidence

- Status: Technical paper walkthrough complete; Proposed ADR and all implementation/release gates
  remain open
- Date: 2026-10-09
- Scope: Five synthetic communication journeys plus common audience, interaction, receipt, metric,
  correction, accessibility, and failure-state contracts
- Authority: François's instruction to start COMM-0 authorizes this evidence work only
- Governing proposal: [ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md)
- Data: Fictional examples only; no production or real institutional data

## Outcome

The five walkthroughs support an announcement-first direction with immutable publication revisions,
frozen audience manifests, explicit interaction policy, distinct delivery/view/acknowledgement
evidence, and aggregate-first metrics. They do not prove usability, implementation, production
security, provider delivery, or representative institutional acceptance.

The paper evidence identifies three material prerequisites rather than hiding them:

1. `staff` and `student` are participation meanings, not roles or automatically reachable accounts;
2. the current academic year is not a grade-level or cohort, so a `Year 7` audience has no accepted
   source yet; and
3. guardian/family communication has no accepted relationship, responsibility, consent, contact,
   or account/endpoint contract and remains unavailable.

COMM-0 adds no module declaration, database resource, migration, capability, route, client screen,
job, consumer, notification, attachment, translation, analytics, or real data. The current
[classroom-first plan](../plans/classroom-first-six-week-plan.md) remains the implementation
priority.

## Product evidence used

The walkthrough uses current official product descriptions as comparative input:

- Workvivo describes targeted communications, spaces, multi-channel campaigns, analytics,
  translations, and a content calendar in its
  [communications overview](https://www.workvivo.com/communications/).
- SchoolFox describes one-to-one and group messages, optional replies, confirmation evidence,
  translation, and emergency delivery in its
  [communication overview](https://foxeducation.com/en/schoolfox/simple-school-communication/),
  plus surveys and event registrations in its
  [organisation overview](https://foxeducation.com/en/schoolfox/organisation-digital-assistant/).

The pages were accessed on 2026-10-09. They show useful market patterns; they do not validate
Chimwemwe's contract or supply school-user testimony.

## Common vocabulary

| Term | Meaning in COMM-0 |
| --- | --- |
| Communication | Stable identity for one durable communication and its correction chain |
| Draft | Mutable working state with no recipient or publication claim |
| Publication revision | Immutable published content, interaction policy, timing, and acknowledgement statement |
| Target | One code-owned audience rule selected by an authorized publisher |
| Audience manifest | Frozen, deduplicated intended subjects and resolution evidence accepted for publication |
| Reachable recipient | Intended subject with an eligible account or approved channel endpoint |
| Interaction mode | Closed, reactions only, moderated comments, or audience comments |
| Seen | Authorized content was opened by an authenticated actor under the declared view policy |
| Acknowledged | The actor explicitly completed the exact acknowledgement action |
| Responded | The actor completed a future typed response such as a poll or RSVP |
| Withdrawn | Ordinary visibility or pending delivery stopped without erasing required evidence |

`Seen` is deliberately used instead of `read`. The system cannot prove comprehension merely because
content opened. Acknowledgement proves only the exact action statement, not consent, agreement,
signature, or legal service.

## Common authoring experience

The authoring flow is the same semantic sequence on every device, while layout and density may
differ:

```text
Content -> Audience -> Interaction -> Delivery and timing -> Review and publish
```

### Content

The draft shows title, body, sender identity or approved publishing identity, classification, and
later any safe attachment or language-variant status. It does not accept raw HTML, arbitrary
scripts, caller-selected storage, or a provider template as authority.

### Audience

The publisher chooses only target kinds allowed by current scope. The preview names the meaning,
not just a label:

```text
Audience: Staff participating in Riverside Secondary on 9 October 2026
Intended: 84
Reachable in Chimwemwe: 79
No eligible account: 5
Overlapping target memberships removed: 7
Resolution basis changed: No
```

A target that cannot be resolved has no send-anyway fallback. A broad target shows whether it is
one exact institution, an explicit descendant expansion, or the whole tenant. `Everyone` is not
used when the actual meaning is ambiguous.

Applicants, offered-but-unenrolled learners, former applicants, referees, and external college
contacts have no accepted communication audience contract in this slice. They cannot enter
`Students`, `Whole tenant`, or `Named subjects` through an inferred relationship. A counsellor
with current staff participation may receive an ordinary staff notice; that does not authorize a
confidential reference, admissions decision, family disclosure, or external-college delivery.

### Interaction

The author chooses one mode and sees its consequence:

```text
(*) Closed
( ) Reactions only
( ) Moderated comments
( ) Audience comments

[x] Require explicit acknowledgement
Statement: "I acknowledge receipt of this notice."
```

Student audiences default to `Closed`. The UI cannot enable comments without an accepted policy,
moderator coverage, and the required capability.

This illustrative statement records receipt only. It does not attest to reading, comprehension,
agreement or consent; the exact statement and receipt fields still require COMM-1 disposition.

### Delivery and timing

COMM-0 presents the eventual product choices without claiming an adapter exists:

- in-product publication;
- schedule and institution-local time zone;
- expiry from ordinary active presentation;
- quiet-hours effect;
- later qualified channel adapters; and
- urgent override only through its separate action.

### Review and publish

The final review repeats content revision, exact audience meaning and counts, classification,
interaction mode, acknowledgement statement, schedule, expiry, and approval requirements. A stale
audience preparation blocks publication and offers `Refresh audience`; it does not update the
manifest invisibly.

## Common recipient experience

The recipient view presents:

1. sender and institutional context;
2. publication or correction status;
3. urgency in words and not colour alone;
4. title and content;
5. original and translated status where later applicable;
6. the exact required acknowledgement or structured response;
7. permitted reactions or comments; and
8. notification and moderation help appropriate to the journey.

Opening a push, email, or SMS deeplink does not display the content until current session, tenant,
module, classification, and communication access are re-authorized. An ended participation or
revoked account may remain in the historical audience manifest but cannot use that fact as current
access authority.

## Common publisher metrics

The aggregate dashboard displays both number and denominator:

```text
Intended                         84
Reachable                        79 of 84
Delivered in product             79 of 79 reachable
Seen                             61 of 79 reachable
Acknowledged                     55 of 79 reachable
Not yet seen                     18
No eligible account               5
Delivery failed                   0
```

The dashboard never merges unreachable people into `not yet seen`. It explains that delivery is
not viewing and viewing is not acknowledgement.

The recipient-level follow-up is a separate, audited action with a distinct capability and purpose.
It is bounded to this one audience manifest and returns only the fields needed to follow up:

```text
Status: Not yet seen | No eligible account | Delivery failed | Access ended
Subject: minimum approved display reference
Audience reason: Staff at Riverside Secondary
Last delivery state: minimum safe status
```

No arbitrary filtering, unrestricted sorting, empty search, reusable cursor, cross-communication
history, or tenant-wide export is available. A separately authorized reminder targets the selected
manifest statuses and records its own outcome; it does not reconstruct another audience.

## Journey 1: Exact-institution staff policy update

### User outcome

An authorized institutional publisher sends a policy update to current staff at one exact
institution, keeps discussion closed, requires acknowledgement, and follows up accurately without
accessing a general staff directory.

### Actors and sources

- Author: actor with draft capability.
- Approver/publisher: actor with exact-institution scoped publication capability; may be a separate
  actor under tenant policy.
- Recipients: current `staff` participation at the exact published institution and effective time,
  resolved to verified staff-account associations.
- Evidence viewer: actor with aggregate metric capability; recipient-level follow-up requires a
  separate capability and purpose.

No job title, email domain, role label, teaching assignment, ancestor unit, or external-provider
group selects the staff audience.

### Happy path

1. The author creates the draft and selects classification `Confidential`.
2. The author selects `Staff at Riverside Secondary`, not `all staff in tenant`.
3. Audience preparation resolves current staff participation, deduplicates people, and separates
   five staff without eligible accounts.
4. Interaction is `Closed`; acknowledgement is required with the exact statement shown.
5. The approver reviews the content, audience, unreachable count, schedule, expiry, and policy.
6. Publication freezes the revision and audience manifest, commits its evidence, and creates the
   minimal outbox fact.
7. Reachable staff open and explicitly acknowledge the communication.
8. The publisher first sees aggregates, then invokes the separately authorized bounded follow-up
   for `not yet seen` and `no eligible account`.

### Failure and denial cases

- Tenant-wide publication capability cannot substitute for an institution-scoped actor unless it
  is deliberately granted and invoked.
- A staff participation that ended before the manifest effective time is excluded.
- A staff account association revoked before publication is not reachable.
- A role named `Teacher` with no current staff participation does not enter the audience.
- A stale prepared audience blocks publication after a participation or association change.
- Changed idempotency-key reuse cannot produce a second publication.
- Retrying a delivery event cannot produce a second acknowledgement requirement.
- A recipient-level metrics actor cannot export or browse other staff records.

### Evidence disposition

This is the recommended COMM-1 candidate because its audience owner and staff-account association
already have bounded synthetic foundations. It still needs accepted classification/retention,
manifest limits, metric fields, public/session boundary, user research, and executable proof. No
COMM-1 implementation is authorized here.

## Journey 2: Year-level student notice

### User outcome

An authorized publisher sends a notice to all current students in `Year 7`, with comments closed
and no false claim that every intended student has an account.

### Actors and sources

- Publisher: actor with publication capability for the exact year-level scope.
- Intended subjects: current student participation plus accepted enrolment/membership in one exact
  year-level or cohort record at the effective time.
- Reachable recipients: intended students with a separately accepted student account or approved
  endpoint association.

The current academic year is a calendar period, not `Year 7`. A class code such as `7A`, label
prefix, age, curriculum text, or institutional hierarchy cannot manufacture the year-level
audience.

### Happy path after prerequisites exist

1. The publisher selects the exact institution and accepted `Year 7` cohort.
2. The preview shows intended, reachable, unreachable, and overlap counts without exposing the
   whole cohort as an ordinary directory.
3. Interaction defaults to `Closed`. Reactions or comments remain unavailable unless the accepted
   student policy allows them.
4. The publisher schedules the notice in the institution's time zone.
5. Publication freezes the exact cohort-membership basis.
6. Students with current access open the notice; aggregate metrics remain the default.
7. Unreachable students are reported as `No eligible account/endpoint`, not `Did not read`.

### Failure and denial cases

- A caller cannot enter `Year 7` as a free-text filter or submit student identifiers.
- The system cannot approximate the audience from academic year, age, class labels, or current
  hierarchy.
- A student who joins after publication does not silently change the denominator.
- A student who leaves after publication remains historical audience evidence but loses current
  content access according to policy.
- A publisher cannot infer a guardian recipient from a student's record.
- Named student engagement evidence requires the distinct capability and purpose; ordinary
  publication authority is insufficient.

### Evidence disposition

The journey is product-relevant but blocked. Chimwemwe has no accepted year-level/cohort owner and
no student account or endpoint contract. COMM-0 records the gap; it does not create either concept
inside communications.

## Journey 3: Exact-class educator notice

### User outcome

An educator responsible for one exact class sends a notice with comments and reactions closed.
The audience follows date-specific enrolment and placement without turning the class roster into
a tenant-wide student list. Moderated questions are a separate conditional variant, not the
ordinary student default. A daily register does not establish a subject teaching-group audience.

### Actors and sources

- Author/publisher: current verified staff account with accepted class communication capability and
  the required current teaching responsibility for that class.
- Intended subjects: exact class members resolved from the accepted enrolment and effective-dated
  placement contract for the declared audience date.
- Conditional moderated variant: explicitly authorized current moderators; teaching assignment
  alone is not moderation authority unless tenant policy grants the capability.

### Happy path after prerequisites exist

1. The educator starts from the exact assigned class context.
2. The server revalidates staff-account association, capability, teaching assignment, class,
   calendar, date, tenant, and module state.
3. Audience preparation resolves the naturally bounded class and shows placement-date provenance.
4. Interaction remains `Closed` for the ordinary notice.
5. Students with a separately accepted account/endpoint and current access open the notice.
6. A correction creates a successor publication revision and visually links it to the original.

In the separate moderated variant, the educator may select `Moderated comments` only when the
accepted student policy, current moderator coverage, escalation path and capability permit it.
Students may then submit attributable questions; an authorized moderator approves, hides or
escalates them through named actions. The variant remains unavailable while those prerequisites
or student endpoints are missing.

### Failure and denial cases

- Knowledge of a class ID or prior teaching assignment does not authorize publication.
- A teaching assignment that ended before the audience date is denied.
- Cross-class, cross-institution, cross-calendar, and cross-tenant placement references are denied.
- Roster pagination cannot escape the exact class or become an export.
- Comments cannot be enabled when the student policy, moderator coverage, or required capability is
  absent.
- Removed comment content cannot survive in notification previews, search, ordinary logs, or
  recipient caches.
- Correcting the notice cannot silently rewrite the first publication or its original manifest.

### Evidence disposition

The current classroom foundation provides synthetic class, enrolment, teaching-assignment, and
placement meanings, but explicitly exposes no roster or student login. The communication adapter,
student endpoint, policy, moderation, and connected experience remain future contracts.

## Journey 4: Dedicated student-group discussion

### User outcome

A student council receives a dedicated group communication with an allowlisted reaction set and
moderated comments, without treating the group as an access role or allowing unrestricted direct
messaging.

### Actors and sources

- Group owner: an education-domain or communications-community owner, depending on the accepted
  purpose.
- Publisher: separately authorized actor; ownership does not grant publication capability.
- Members: explicit, dated group membership under the owning domain.
- Moderators: current named moderators with reporting and escalation responsibility.

An instructional or administrative group must remain education-domain owned. A voluntary
communication-only club may later use a communications-owned community. The same display name
cannot hide different ownership or membership semantics.

### Happy path after prerequisites exist

1. The publisher opens the exact group context and sees its owner, purpose, visibility, membership
   source, moderators, and classification.
2. Audience preparation resolves current dated membership and deduplicates people who also match
   another selected reason.
3. The publisher selects `Reactions only` or `Moderated comments` from the allowed group policy.
4. Students react through an allowlisted set; a reaction remains neither acknowledgement nor vote.
5. Attributable comments may be reported. Moderators have an accessible review queue with reasons,
   deadlines, and escalation outcomes.
6. Archiving the group stops new ordinary posts but preserves retained publications and moderation
   evidence under policy.

### Failure and denial cases

- Group membership never grants a platform capability or access to another member's records.
- A student cannot invite arbitrary tenant users, enumerate non-members, or convert the group into
  a public space.
- Anonymous comments, custom emoji, unrestricted direct messaging, and external guests are absent.
- A group without active moderator coverage cannot enable student comments.
- Blocking, removal, or membership ending revokes current access and interaction without rewriting
  the historical publication manifest.
- Longitudinal engagement ranking, sentiment, and behavioural profiles are not produced.

### Evidence disposition

This journey demonstrates why group ownership must precede communication implementation. No
dedicated student-group or communication-community resource is authorized by COMM-0. Safeguarding
and representative student review are mandatory before connected use.

## Journey 5: Tenant-wide urgent closure alert

### User outcome

An authorized pair publishes an urgent closure alert across all eligible tenant institutions,
overrides quiet hours under policy, monitors channel failures, and avoids equating SMS or push
delivery with viewing.

This tenant-wide scenario applies only when the incident affects that declared scope. A one-site
closure must not inherit a whole-tenant audience: require an accepted authoritative target for the
exact affected scope and current publishing authority, or block targeting. Missing scope or an
emergency fallback owner is an explicit policy gap, not permission to broaden the broadcast.

### Actors and sources

- Author: actor with urgent-draft capability.
- Approver/publisher: different actor with tenant-wide urgent-publication capability under the
  normal policy.
- Recipients: explicit union of accepted tenant-wide subject types and endpoint policies. `Whole
  tenant` does not automatically include guardians, former participants, external partners, or
  people without the required communication relationship.
- Operations: capability-separated delivery observer and replay operator.

### Happy path after adapters are qualified

1. The author marks the draft `Urgent` and selects a code-owned reason such as site closure.
2. Audience preparation names every included subject type, excluded category, institution, and
   channel-eligibility policy; it deduplicates overlaps.
3. The preview shows the quiet-hours override, intended and reachable counts, approval requirement,
   classification, minimized channel preview, expiry, and escalation owner.
4. A second authorized actor approves and publishes.
5. The authoritative publication commits before bounded channel delivery begins.
6. In-product, push, email, and later SMS adapters record their own outcomes without changing
   publication truth.
7. The dashboard distinguishes delivered, failed, seen, acknowledged, and unreachable.
8. Authorized operations may replay only exact failed delivery items with idempotent provider
   handling and minimized evidence.

### Failure and denial cases

- A normal scoped publisher cannot set an urgent flag or bypass quiet hours.
- A missing approver cannot be replaced by a client checkbox. Any accepted single-controller
  exception is explicit, stronger-assurance, reasoned, visible, and retrospectively reviewed.
- A stale audience manifest blocks publication even under urgency unless a separately accepted
  emergency degradation policy defines a safe alternative.
- Provider groups, contact lists, and callbacks cannot add recipients or grant content access.
- A provider retry cannot create duplicate logical delivery, and a callback cannot mark content
  seen.
- Message content does not appear in a lock-screen, SMS, email subject, or provider log beyond the
  approved minimized preview.
- Channel outage is visible and escalated; it cannot be hidden by reporting only successful
  attempts.

### Evidence disposition

This journey is deliberately last. It requires selected providers, secrets and callback handling,
quiet-hour and emergency policy, operational ownership, mixed-load measurement, delivery and
recovery drills, representative review, and independent security/privacy review. COMM-0 authorizes
none of those adapters.

## Cross-journey correction and follow-up

All five journeys use the same correction rule:

1. the publisher opens the exact publication revision;
2. `correct_communication` requires a reason and expected current revision;
3. the successor retains the stable communication identity and names the corrected revision;
4. the original audience manifest remains preserved;
5. the correction declares whether it targets the original manifest, a newly prepared manifest,
   or both through an accepted policy;
6. recipients see an understandable corrected status and the current revision; and
7. downstream delivery and search projections reconcile without deleting the original evidence.

The exact correction-audience rule remains an open COMM-1 decision. COMM-0 rejects silent reuse or
silent recomputation because each choice changes who receives the correction and the metric
denominator.

An acknowledgement of the original statement is not a fresh acknowledgement of corrected
instructions. Before COMM-1, disposition exact receipt-to-statement/revision binding, whether a
material correction requires a new acknowledgement, and how that requirement is shown. Existing
receipts remain attributable to their original action; COMM-0 does not choose the renewal policy.

`nudge_non_viewers` is likewise a distinct action. It operates on an exact manifest and safe status
set, requires current authority and purpose, respects channel preference and quiet-hour policy,
deduplicates prior reminders, and records the result. It does not recreate the original audience
or imply non-compliance.

## Accessibility and device contract

### Phone recipient

- one communication and next action at a time;
- sender, institution, urgency, correction, and expiry visible without relying on colour;
- large acknowledgement and reaction targets;
- readable at supported text scaling and reflow;
- screen-reader order follows meaning rather than card layout;
- comments expose author, time, moderation state, and report action accessibly; and
- expired session or uncertain acknowledgement leads to authoritative reload, not a blind retry.

### Browser publisher

- keyboard-complete five-step composition;
- understandable audience preview and overlap explanation;
- no preselected broad audience;
- visible classification, interaction, approval, and quiet-hours consequences;
- aggregate dashboard before recipient-level follow-up;
- table alternatives and non-colour metric/failure states; and
- correction and withdrawal actions separated from draft editing.

The eventual prototype must check keyboard flow, visible focus, headings, labels, error association,
320-pixel reflow, text scaling, screen-reader semantics, reduced motion, target sizes, and
loading/empty/denied/stale/conflict/retryable/uncertain/success states. COMM-0 has not produced or
human-tested that prototype.

## Security and privacy walkthrough matrix

| Risk | Required COMM-0 response | Later executable proof |
| --- | --- | --- |
| Cross-tenant target or recipient | Compound tenant identity and non-disclosing denial | Direct, action, job, event, callback, cache, search, and API negatives |
| Publisher widens scope through hierarchy | Exact unit or explicit descendant target plus distinct capability | Move/source-version race and no-inference tests |
| Client supplies recipient identifiers | Reject; resolve code-owned targets on the server | OpenAPI/generated-client and alternate-write negatives |
| Overlapping groups duplicate delivery | One intended subject with retained audience reasons | Concurrent deduplication and idempotent fan-out tests |
| Manifest becomes stale before publication | Detect source change and require refresh or accepted policy | Writer race and changed-source tests |
| Notification leaks content after revocation | Minimized preview and re-authorization on open | Revocation, cache, deeplink, device, and provider tests |
| Seen inferred from delivery or feed presence | Separate evidence types and explicit view policy | Callback, background, preview, prefetch, and multi-device tests |
| Named metrics become a directory | Manifest-bounded named action with distinct capability and fields | Traversal, overlap, cursor, search, export, and cumulative-abuse tests |
| Student comments enable harm | Default closed, attributable comments, moderator coverage and escalation | Report, removal, cache/search purge, rate, and safeguarding tests |
| Rollback still sends a message | State/audit/idempotency/outbox atomicity | Injected post-outbox rollback test |
| Retry duplicates send or acknowledgement | Actor/request/event/provider-bound idempotency | Crash, replay, callback, dead-letter, and changed-request tests |
| Module deactivation loses required evidence | Controlled drain, mandatory retention and reconciliation | Both lock orders, parked work, replay and reactivation tests |

## COMM-0 decisions and open conditions

| Item | Disposition on 2026-10-09 |
| --- | --- |
| Announcement-first direction | Proposed and supported by the five paper walkthroughs |
| Immutable published revision | Proposed under ADR 0018 vocabulary |
| Frozen audience manifest | Proposed; physical representation and size limits open |
| Distinct intended/reachable/delivered/seen/acknowledged states | Proposed |
| Interaction modes | Proposed; student default is closed |
| Aggregate-first metrics | Proposed |
| Recipient-level non-viewer follow-up | Proposed with separate capability/purpose and manifest bound |
| Staff audience as COMM-1 candidate | Proposed; domain, retention, metric, and interface disposition open |
| Year-level student audience | Blocked on accepted cohort/year-level and student endpoint owners |
| Exact class audience | Proposed future typed classroom adapter; roster/public/student gates open |
| Dedicated student group | Blocked on owning domain and safeguarding contract |
| Guardian/family audience | Deferred; no inference allowed |
| Push, email, SMS, attachments, translation, search, analytics | Deferred to separately reviewed trust boundaries |
| Representative usability or safeguarding approval | Not gathered |
| Advisor review | Unavailable because the parent runtime could not be verified; no approval claimed |
| Implementation or release | Not authorized |

## COMM-1 entry questions

Before requesting COMM-1 implementation authority, settle:

1. Which exact-institution staff source versions or locks make a prepared manifest safe to publish?
2. What maximum staff-audience size, preparation duration, transaction budget, and mixed-load target
   apply to the first proof?
3. What fields may appear in aggregate and recipient-level metrics, and for how long?
4. What exact statement, receipt fields and revision binding define acknowledgement without
   implying consent, and what correction audience and renewed-acknowledgement policy applies?
5. What content, manifest, receipt, audit, idempotency, and outbox retention policy applies to the
   synthetic proof and later real staff data?
6. Does COMM-1 require a separate approver, and what explicit single-controller exception is
   acceptable for the synthetic proof?
7. Which routes and generated-client methods remain private, and how will adversarial enumeration
   be proven absent?
8. What recovery outcome applies when publication commits but audience preparation, delivery, view
   receipt, or acknowledgement confirmation is interrupted?

## Verification required for this paper slice

- documentation links and ADR index consistency;
- COMM-0 status remains Proposed and implementation claims remain absent;
- threat and abuse-case IDs remain unique and linked;
- no existing classroom, identity, people, or module status is upgraded by this document;
- unrelated web dependency work remains untouched; and
- repository-selected documentation checks are reported exactly.

## Related records

- [ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md)
- [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0036](../adr/0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0037](../adr/0037-class-register-enrolment-and-placement.md)
- [ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md)
- [Threat model](../security/threat-model.md)
- [Data classification](../security/data-classification.md)
- [Security abuse cases](../security/abuse-cases.md)
- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
