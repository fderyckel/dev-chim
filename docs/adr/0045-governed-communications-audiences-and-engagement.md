# ADR 0045: Governed communications, audiences, and engagement evidence

- Status: Proposed
- Date: 2026-10-09
- Accountable owner: Product experience, platform engineering, and security/privacy ownership
- Deciders: François — Project Owner, product experience, platform engineering, security/privacy,
  safeguarding ownership, and representative learning-institution users before connected use
- Implementation authority: The Project Owner's instruction to start COMM-0 authorizes this paper
  contract, five synthetic experience walkthroughs, and threat-model updates only. It does not
  authorize a module declaration, resource, migration, public route, delivery adapter, real data,
  or change to the classroom-first implementation priority.
- Supersedes: None

## Context

Learning institutions need one dependable place for broad announcements, staff communications,
student notices, class messages, year-level or cohort notices, dedicated-group communication, and
urgent alerts. Some communications should be one-way. Others may permit a small reaction set,
moderated comments, an explicit acknowledgement, or a structured response. Authorized publishers
also need to distinguish who was intended to receive a communication, who could actually receive
it, who opened it, and who explicitly acknowledged it.

That product need crosses several existing boundaries. Chimwemwe keeps person, participation,
account, membership, capability, institutional structure, enrolment, class placement, and teaching
assignment as separate meanings. Institutional hierarchy and teaching responsibility do not grant
communication authority. Students need not have accounts, guardians are not yet modeled, and the
current classroom contract has an academic year but no accepted grade-level or cohort resource.
The communications design must not hide those gaps behind labels, email addresses, inferred roles,
or caller-supplied recipient lists.

Publication also creates durable and privacy-sensitive evidence. A broad message can be sent to the
wrong population, duplicated across overlapping groups, exposed through a stale notification, or
used to construct a sensitive directory. Named non-viewer lists can become surveillance or pressure
tools. Comments can introduce safeguarding and moderation risk. Push, email, SMS, translation, and
attachment providers add external trust boundaries. A social feed or chat-first implementation
would therefore establish too many unresolved contracts at once.

Current comparable products provide useful product evidence rather than implementation authority.
Workvivo presents spaces, targeted and multi-channel campaigns, a content calendar, translation,
and communication analytics. SchoolFox presents class/group messaging, optional replies,
confirmations, translation, emergency delivery, surveys, and registrations. Chimwemwe adopts the
bounded product lessons while retaining its own tenant, authority, temporal, privacy, and release
contracts.

## Decision drivers

- Give institutions reliable, understandable communication without mixing it with authorization.
- Resolve recipients from authoritative domain records and preserve what the publisher actually
  targeted at publication time.
- Keep delivery, viewing, acknowledgement, reaction, comment, and structured response as distinct
  evidence.
- Allow comments or reactions to be disabled per publication and default safely for student
  audiences.
- Prevent communication and engagement views from becoming a general people, staff, student, or
  guardian enumeration interface.
- Preserve revision, correction, withdrawal, audit, outbox, retention, and recovery semantics.
- Start with a reversible announcement proof before chat, campaigns, emergency adapters, AI, or a
  general social intranet.
- Deliver intentional phone and browser experiences through the existing named-action boundary.

## Considered options

1. Add notification flags and read timestamps to existing domain records. This is small initially
   but provides no stable communication identity, audience evidence, correction chain, interaction
   policy, or cross-module ownership.
2. Build a chat or social-feed platform first. This is familiar to users but combines audience
   resolution, direct messaging, moderation, realtime, search, retention, device notification, and
   child-safeguarding risks before the durable announcement contract exists.
3. Add a bounded `communications.core` module direction centred on revisioned announcements,
   frozen audience manifests, explicit interaction policy, and classified engagement evidence.
   Later adapters may add channels, communities, structured responses, and campaigns. This is the
   proposed option.
4. Use email, SMS, or an external collaboration product as the authoritative communication store.
   This makes provider groups and delivery state an authorization and records boundary and cannot
   preserve Chimwemwe's tenant, correction, retention, and audience semantics.

## Decision

Propose option 3. COMM-0 fixes the logical contract and experience questions only. A separately
authorized COMM-1 slice may later test the smallest private synthetic implementation.

### Module and ownership boundary

The future bounded business module is `communications.core`. PostgreSQL remains authoritative for
communication state and evidence. The module may depend on platform context, authority, module
lifecycle, identity/session, institutional structure, and people participation. It consumes only
typed, owner-approved audience interfaces from classroom or future cohort/group domains.

The communications module does not own or infer:

- tenant membership, roles, capabilities, or account provisioning;
- people, staff, student, guardian, enrolment, class, cohort, programme, or hierarchy truth;
- a delivery provider's contact directory or external group membership;
- a general file store, translation service, analytics plane, or search authority; or
- a public, staff, student, or guardian directory.

Communication communities may later be owned by `communications.core` only when their purpose is
communication, such as a voluntary club discussion or staff interest group. An instructional,
administrative, programme, class, year-level, or cohort group remains owned by its education-domain
contract. Membership in either kind of group never grants a platform capability.

### Communication types and lifecycle

The first durable type is an **announcement**. Later types may include an urgent alert, community
post, poll, RSVP, checklist, or other structured request, but those do not enter COMM-1
automatically.

An unpublished draft is mutable working state. Publication creates an immutable
`CommunicationRevision` under one stable communication identity. A correction creates a successor
revision that names the prior revision and reason. Withdrawal is a separately authorized state
transition that stops ordinary presentation or pending delivery according to declared policy; it
does not erase the published revision, its audience evidence, or required audit. Expiry controls
ordinary prominence and delivery, not retention or lawful erasure.

Expected named actions include:

- `create_draft`, `revise_draft`, and `submit_for_approval`;
- `prepare_audience`, `approve_publication`, `schedule_publication`, and
  `publish_communication`;
- `correct_communication` and `withdraw_communication`;
- `acknowledge_communication`, `add_reaction`, and `add_comment` where enabled;
- `moderate_comment`; and
- a later separately authorized `nudge_non_viewers` action.

Generic create/update/delete routes are not an alternative. Publication, correction, withdrawal,
interaction, and metric access each re-evaluate current module gates, capability, scope, purpose,
tenant, placement, and session state on the authoritative path.

### Audience sources and frozen manifest

A publisher chooses only code-owned target kinds for which the current actor has a deliberate
publishing scope. The server resolves those selections from authoritative domain records. The
logical audience catalogue is:

| Target kind | Authoritative meaning | COMM-0 disposition |
| --- | --- | --- |
| Whole tenant | Every eligible subject inside the tenant boundary | Proposed; requires a distinct high-impact capability and preview |
| Exact institution or unit | One stable institutional unit | Proposed; descendant inclusion is a separate explicit target, never implied |
| Staff | Current `staff` participation at the selected institution and effective time | Eligible for a later bounded synthetic proof |
| Students | Current `student` participation | Proposed; participation alone does not make a reachable account |
| Exact class | Enrolment plus effective-dated class placement | Proposed typed classroom audience; no generic roster route |
| Year level or cohort | An explicit accepted cohort, programme-stage, or year-level record | Blocked until that owner exists; an academic year or class label is not a substitute |
| Dedicated educational group | An explicit domain-owned group and dated membership | Blocked until that domain contract exists |
| Communication community | An explicit communications-owned community and dated membership | Proposed for a later slice |
| Named subjects | Exact policy-authorized subject selection | Proposed only through a bounded task, never a directory escape hatch |
| Guardians or family contacts | An accepted relationship, responsibility, contact, consent, and account/endpoint contract | Deferred; no guardian inference is permitted |

Audience preparation produces an immutable logical `AudienceManifest` before publication. The
manifest records the target definitions, their source versions or equivalent resolution evidence,
the resolution time and purpose, deduplicated intended subject references, and deliverability
classification. It separates:

1. the target rules selected by the publisher;
2. intended subjects resolved from authoritative domain records; and
3. currently reachable recipient accounts or delivery endpoints.

Overlap across sources produces one intended subject, not duplicate communication authority or
multiple acknowledgements. A staff member who is also a student remains one person but may have
several explicit audience reasons. Those reasons are retained for explainability without sending
duplicate ordinary delivery.

Publication freezes the accepted manifest. A later enrolment, placement, participation, community,
account, or hierarchy change does not rewrite the historical audience or its denominator. Access
to content and recipient-level evidence is nevertheless re-authorized when read; a frozen manifest
does not preserve access after revocation. A rolling audience that automatically adds later members
is outside COMM-0 and requires a separate temporal and metric contract.

For large audiences, `prepare_audience` may be bounded asynchronous work with progress, fair
scheduling, idempotent items, cancellation, and reconciliation. `publish_communication` must detect
a stale preparation basis and require refresh or explicit reviewed policy; it cannot silently
publish against a changed authoritative population. The physical schema, batching threshold, and
snapshot representation remain implementation evidence, not decisions in this ADR.

### Authorization and approval

Code-owned capabilities distinguish at least:

- draft creation;
- scoped publication;
- tenant-wide publication;
- urgent publication;
- publication approval;
- comment moderation;
- aggregate metric access;
- recipient-level metric access; and
- later controlled reminder or export actions.

Tenant-defined, hierarchical, renameable, and composable roles grant those capabilities. No fixed
`teacher`, `principal`, `administrator`, `student`, or `communications officer` role enters the
production authorization model. Participation, teaching assignment, community ownership, group
membership, hierarchy, authorship, or visibility of a person does not grant publishing or metric
authority.

Tenant-wide and urgent publication candidates require a reviewable audience preview and may require
a second authorized approver under typed tenant policy. Any single-controller exception needs
stronger assurance, an attributable reason, a visible exception marker, and retrospective review;
it cannot be an implicit downgrade.

### Interaction policy and safeguarding

Every publication chooses one server-enforced interaction mode:

1. `closed`: no comments or reactions;
2. `reactions_only`: only an allowlisted, versioned reaction set;
3. `moderated_comments`: comments require or remain subject to active moderation; or
4. `audience_comments`: attributable comments are visible only to the currently authorized
   audience and moderators.

The exact reaction vocabulary is a product-owned allowlist. A reaction never counts as viewing,
acknowledgement, consent, or a structured response. Anonymous comments, caller-defined emoji,
public internet comments, and unrestricted direct messaging are outside COMM-0.

Student-audience publications default to `closed`. Enabling reactions or comments for a student
audience requires a separately authorized policy, current moderator coverage, reporting and
escalation paths, retention and removal rules, and representative safeguarding review. Removing a
comment may hide its ordinary content while preserving the minimum classified moderation evidence
or lawful tombstone. It must not erase an incident record or expose removed content through logs,
notifications, search, or caches.

### Delivery and notification semantics

The authorized in-product communication is the canonical recipient experience. Push, email, SMS,
digital signage, and other transports are later delivery adapters. Provider acceptance or device
delivery does not become domain truth and does not grant access to the communication.

Publication commits the immutable revision, accepted audience-manifest reference, required audit,
idempotency result, and minimal transactional outbox fact atomically. Post-commit consumers create
bounded, idempotent delivery work using the same tenant placement and classification. A rolled-back
publication creates no delivery. Duplicate events, provider callbacks, worker crashes, retries,
dead-letter replay, and tenant movement cannot duplicate the logical publication or acknowledgement.

Notification previews are minimized. Confidential or Restricted content is not exposed through an
email subject, SMS body, lock-screen notification, analytics event, or provider metadata unless a
separately reviewed channel policy permits the exact fields. A deeplink establishes no authority;
opening it revalidates the current session, tenant, module, purpose, and communication access.

Ordinary notification preferences and quiet hours are user-visible and time-zone aware. An urgent
quiet-hours override uses a distinct action and capability, records a reason, and requires a typed
institution policy. An `urgent` label is not a formatting choice.

### Engagement and acknowledgement evidence

The product uses the following separate terms:

| State | Meaning |
| --- | --- |
| Intended | The subject is present in the frozen audience manifest |
| Reachable | An eligible account or approved delivery endpoint existed for the attempted channel |
| Queued | Bounded delivery work was created |
| Delivered | The in-product or external adapter recorded its defined delivery outcome |
| Seen | The authenticated actor opened the authorized communication content under the declared view policy |
| Acknowledged | The actor performed the explicit acknowledgement action |
| Responded | The actor completed a future typed poll, RSVP, checklist, or other structured request |
| Failed | The declared delivery attempt failed or could not be completed |
| Expired unseen | The publication's active period ended without a recorded seen fact |

Push receipt, email provider acceptance, notification preview display, reaction, comment, or time in
a feed does not imply `seen`. `Seen` does not imply comprehension, consent, agreement, or compliance.
Acknowledgement confirms only the exact statement presented by the named action. A future digital
signature, consent, legal service, or policy acceptance requires its own domain contract.

Users are told when view and acknowledgement evidence is collected. The default publisher view is
aggregate and shows its denominator and exclusions. Recipient-level `seen` or `not yet seen`
evidence requires a distinct capability, purpose, and access audit and is bounded to one authorized
communication manifest. It distinguishes at least not yet seen, no eligible account, no approved
endpoint, delivery failed, and access ended. It must not label an unreachable person as
non-compliant or inattentive.

A recipient-level metric view is not a people directory or export. It returns only fields needed
for the communication follow-up task, exposes no arbitrary sort/filter/search or reusable cursor,
and cannot be traversed across communications to reconstruct a tenant-wide student, staff, or
guardian collection. Export, longitudinal engagement profiling, cohort comparison, sentiment,
ranking, and automated intervention require separately accepted contracts.

### Classification, retention, files, and translation

Communication content receives an accountable classification. Audience rules, manifests, delivery
attempts, interactions, comments, moderation facts, view receipts, acknowledgement facts,
notifications, search documents, exports, and telemetry inherit the highest applicable content,
audience, relationship, and source classification. Learner-targeted manifests and named learner
engagement evidence default to Restricted even when the message text itself is lower-classified.

The domain owner must settle retention start, duration, legal hold, correction, withdrawal,
moderation evidence, lawful erasure or redaction, export, restore convergence, and offboarding
before real data. Publication immutability does not promise permanent retention. Erasure or
redaction is a separately authorized action with a receipt under ADR 0018.

Attachments use ADR 0010's file ownership, quarantine, scanning, classification, signed-access,
retention, and reconciliation contract. An attachment is not approved because the surrounding
message is published. External links are presented as external destinations and do not inherit
Chimwemwe authorization.

Manually reviewed language variants may later belong to one publication revision. Machine
translation is not part of COMM-0. A future adapter must retain the original, label translated
content, protect Restricted text from an unqualified processor, record provider and version
provenance, and define correction and dispute behaviour.

### Product experience contract

The authoring experience follows five understandable steps:

1. content;
2. audience;
3. interaction;
4. delivery and timing; and
5. review and publish.

Before approval or publication, the user sees the exact target meanings, deduplicated intended
count, reachable count where known, unreachable categories, interaction mode, acknowledgement
requirement, schedule, expiry, classification, quiet-hours effect, and whether a second approval is
required. A broad or descendant audience is never summarized only as `Everyone` when its actual
scope is narrower, wider, or unresolved.

Phone recipient flows prioritize the communication, sender context, urgency, original/translated
status, acknowledgement or response, and safe recovery. Browser publisher flows prioritize
audience review, scheduling, approval, correction, moderation, and aggregate-first follow-up. Both
must provide keyboard and screen-reader semantics, visible focus, text scaling, non-colour status,
clear errors, and authoritative confirmation after uncertain responses.

### COMM-0 boundary and later sequence

COMM-0 contains only:

- this Proposed ADR;
- the five synthetic user-journey walkthroughs and common experience contract;
- the communication-specific threat and abuse-case additions; and
- navigation/status updates that distinguish proposed direction from implementation.

COMM-0 adds no module manifest entry, capability, database resource, migration, API/OpenAPI route,
generated client, browser page, mobile application, job, consumer, notification, file, translation,
search, analytics, external processor, real identity, or real data.

Potential later slices remain separately authorized:

- **COMM-1:** private synthetic exact-institution staff announcement, in-product only, comments
  closed or reactions only, optional acknowledgement, revision/manifest/outbox evidence;
- **COMM-2:** accepted class, cohort/year-level, dedicated educational-group, and student-account
  recipient contracts with no guardian inference;
- **COMM-3:** moderated comments, communication communities, attachments, reviewed translations,
  quiet hours, and qualified push/email adapters; and
- **COMM-4:** urgent multi-channel delivery, controlled SMS, structured responses, campaigns,
  content calendar, and privacy-preserving longitudinal analytics.

This sequence does not amend the active classroom-first implementation order. COMM-1 does not
become eligible merely because COMM-0 documents it.

## Plain-English summary

### What this means

Chimwemwe is preparing a reliable communication capability that can send one message to an exact
school audience, optionally permit reactions or comments, ask for acknowledgement, and show honest
delivery and viewing evidence.

### What was agreed

- The communication audience comes from trusted school records, not a browser-supplied list.
- A published message and its intended audience are frozen so later roster changes do not rewrite
  history.
- Delivered, seen, acknowledged, reacted, commented, and responded mean different things.
- Comments and reactions can be turned off and will default off for student audiences.
- Named non-viewer information is more restricted than aggregate statistics.
- This COMM-0 start writes the rules and experience walkthroughs only. It does not build or release
  the feature.

### Context

Schools need broad and targeted communication, but a message sent to the wrong class or a misleading
`read` metric can create real operational, privacy, and safeguarding harm. Chimwemwe therefore fixes
the audience and evidence meanings before implementing the feed or delivery channels.

### Examples

- A staff policy update may require an explicit acknowledgement while keeping comments closed.
- A class notice may permit moderated questions but cannot reveal the whole school roster.
- An urgent closure alert may later use several channels, but an SMS delivery receipt still does
  not prove that a student read or understood the notice.

## Consequences

### Positive

- Reliable publication and audience evidence precede social and multi-channel complexity.
- Overlapping groups do not create duplicate recipients or contradictory denominators.
- Institutions may choose one-way, reaction-only, or moderated interaction per communication.
- Metrics have clear meanings and recipient-level evidence receives stronger privacy controls.
- Domain-owned rosters, year levels, groups, guardians, accounts, and authority remain separate.

### Negative

- Audience preparation, deduplication, source-version checks, retention, and provider reconciliation
  add work beyond a simple send button.
- Year-level, dedicated student-group, guardian, and student delivery remain unavailable until their
  domain and account/endpoint contracts exist.
- Named non-viewer follow-up cannot reuse a generic directory or export and therefore needs a
  purpose-built bounded experience.
- Comment moderation and urgent multi-channel delivery require accountable operating owners before
  they can be enabled.

## Security, privacy, operability, and migration effects

Every communication, revision, target definition, audience entry, endpoint reference, delivery
attempt, receipt, acknowledgement, interaction, moderation action, event, job, cache key, search
document, export, and telemetry record is tenant-qualified and classified. Compound constraints
must reject cross-tenant links. Missing or stale tenant, actor, purpose, placement, module,
capability, audience source, or session context fails closed.

Publication and security-sensitive audience preparation use the authoritative writer. A replica,
cache, search result, provider group, external address book, notification token, or prior manifest
cannot authorize a publication or content read. Recipient access is re-authorized even when the
subject remains in the historical manifest. Provider credentials, message identifiers, callbacks,
and error text are minimized and cannot reveal recipient content or cross-tenant existence.

Audience resolution and delivery are potential burst workloads. A later implementation must define
bounded batches, per-tenant fairness, queue and connection budgets, backpressure, cancellation,
retry, dead-letter, reconciliation, retention, module drain, and tenant movement. It must measure
mixed classroom and communication load rather than relying on recipient count alone.

No migration is created by COMM-0. A later stored implementation uses additive tenant-qualified
tables, generated migration review, apply/rollback/reapply and drift checks, and forward repair once
published revisions or evidence exist. A source import cannot invent historical audiences, view
receipts, acknowledgement, or delivery evidence that the source cannot prove.

Relevant threats include TM-01 through TM-07, TM-09 through TM-15, TM-17 through TM-22, and abuse
cases AC-01, AC-02, AC-05 through AC-08, AC-10 through AC-21.

## Validation evidence

The [COMM-0 experience evidence](../phase-2/communications-comm-0-experience-evidence.md) walks
through five synthetic journeys: exact-institution staff policy, year-level student notice, class
notice, dedicated student-group discussion, and tenant-wide urgent alert. It records the common
authoring, audience, interaction, recipient, metric, correction, and failure-state contract and
identifies blockers rather than treating planned functions as implemented.

The walkthrough is informed by the official
[Workvivo communications overview](https://www.workvivo.com/communications/) and
[SchoolFox communication](https://foxeducation.com/en/schoolfox/simple-school-communication/) and
[organisation](https://foxeducation.com/en/schoolfox/organisation-digital-assistant/) feature
descriptions accessed on 2026-10-09. Those sources establish comparable product patterns only; they
do not prove Chimwemwe's usability, security, privacy, performance, or implementation.

Current platform evidence supports tenant context, named actions, revision vocabulary,
idempotency, transactional outbox, module lifecycle, and bounded read policy. It does not prove a
communication resource, audience resolver, recipient endpoint, Restricted consumer, realtime
channel, notification provider, comment moderator, attachment pipeline, translation processor,
search index, analytics dataset, public client, or production operating model.

Before COMM-1, accountable review must disposition the proposed staff audience and acknowledgement
semantics, the first classification/retention policy, precise source-version contract, manifest
size and preparation limits, aggregate and recipient-level metric fields, and COMM-1 negative-test
matrix. Before connected student use, representative students and staff plus safeguarding,
records, accessibility, and independent security/privacy reviewers must disposition the affected
journeys.

## Fallback and exit cost

If the broad communication direction is not accepted, retain the five journeys as research and add
no module. If a later audience resolver cannot produce an explainable frozen manifest safely, keep
the affected target kind unavailable rather than falling back to caller-supplied recipients,
provider groups, hierarchy inference, or live rolling membership.

If a generated public interface cannot preserve bounded audience and metric access, use a thin
purpose-built named adapter or keep the workflow private. If a delivery provider fails, retain the
authoritative in-product publication and reconcile provider attempts; do not migrate communication
authority to the provider.

Before real records, exit cost is documentation and disposable prototypes. After publication
evidence exists, changing stable communication identity, revision, audience denominator, or receipt
semantics requires expand-and-contract migration, dual compatibility, consumer reconciliation,
retention verification, and accountable review.

## Review triggers

- A different audience source, rolling membership, guardian/family targeting, public audience, or
  cross-tenant communication is proposed.
- The first year-level, programme, cohort, student-group, guardian, student-account, or recipient-
  endpoint contract enters scope.
- Comments, direct messages, anonymous interaction, user-generated media, or student-to-student
  conversation enters scope.
- Email, push, SMS, translation, attachments, search, realtime, digital signage, analytics, AI,
  sentiment, or another external processor enters scope.
- A view, acknowledgement, consent, signature, policy acceptance, or legal-service meaning is
  proposed beyond this bounded evidence vocabulary.
- Audience resolution, fan-out, receipt volume, or mixed workload misses its accepted target.
- A privacy, safeguarding, accessibility, or security review challenges recipient-level evidence,
  moderation, notification previews, retention, or the frozen-manifest model.

## Related records

- [COMM-0 experience evidence](../phase-2/communications-comm-0-experience-evidence.md)
- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0010](0010-file-ownership-storage-pipeline-and-external-drives.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0024](0024-assurance-proportionality-and-module-evolution.md)
- [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0037](0037-class-register-enrolment-and-placement.md)
- [ADR 0044](0044-administrator-provisioned-local-credentials.md)
- [Threat model](../security/threat-model.md)
- [Data classification](../security/data-classification.md)
- [Security abuse cases](../security/abuse-cases.md)
