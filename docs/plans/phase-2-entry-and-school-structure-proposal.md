# Phase 2 entry and school-structure implementation proposal

- Status: Proposed; this document authorizes no implementation slice
- Owner: Product and platform engineering, with school-domain and security/privacy review
- Decision scope: Phase 2.0 production-entry closure and Phase 2.1 school structure only
- Review trigger: acceptance of this proposal, authorization of any listed slice, a change to
  identity, support access, module lifecycle, temporal semantics, public interface, or the proposed
  school-structure boundary

## Purpose

Phase 2 should cross one deliberate threshold: Chimwemwe moves from a qualified platform core to
its first real school-domain module without weakening the tenant, authority, evidence, recovery, or
client contracts established in Phases 0 and 1.

The proposed sequence is:

1. **Phase 2.0 — close the entry gates.** Finish the operational, identity, support-access, temporal,
   and public-interface contracts required to run a school module safely.
2. **Phase 2.1 — introduce school structure.** Let a tenant describe the schools it operates, their
   sites, stable codes, operating time zones, local terminology, and explicit institutional
   relationships.

School structure is intentionally first. It gives later calendar, admissions, enrolment, classes,
attendance, communication, and reporting modules a stable `school_scope_id` without prematurely
introducing learner, guardian, staff, curriculum, or academic-year records.

This is not a proposal for a generic `setup` module. Provisioning, identity, authority, module
lifecycle, institutional structure, and later school workflows keep separate owners and contracts.

## Desired outcomes

### Phase 2.0 outcome

The platform can safely host its first school module. In practical terms:

- a released, entitled, activated, and authorized module can drain and reactivate against real
  queue/outbox consumers rather than only modeled work;
- an attributable correction can be dispatched, replayed, reconciled, restored, and inspected
  without silently changing a durable consumer's historical basis;
- a production candidate establishes real actor, tenant, session, assurance, purpose, placement,
  and correlation context without accepting those claims from browser input;
- support access requires an explicit tenant, approved purpose, sufficient assurance, bounded
  capability, expiry, and enhanced evidence;
- a checked public contract and generated client preserve named actions, stable errors, page and
  query bounds, idempotency, module gates, and tenant non-disclosure; and
- the selected deployment and independent reviews are explicit gates before real Restricted data,
  rather than being inferred from local synthetic evidence.

### Phase 2.1 outcome

An authorized tenant operator can establish and maintain one or more school scopes and the sites
at which they operate. A permitted staff member can inspect that structure through an intentional
browser workflow. Every structure remains tenant-qualified, historically explainable, and usable
as a stable reference by later modules.

Organizational hierarchy has **no authorization effect**. A parent, operator, cluster, or site
relationship never grants a capability, expands record scope, selects a database, activates a
module, or creates live configuration inheritance.

## Product and standards evidence

This proposal adopts patterns, not vendor schemas or screens.

| Evidence | Useful lesson | Chimwemwe interpretation |
| --- | --- | --- |
| [ManageBac school settings](https://help.managebac.com/hc/en-us/articles/360019112011-Configuring-School-General-Settings-Languages-Academics-Year-Levels-Terms) | School identity, address, time zone, language, terminology, and programme settings need a coherent administrative home. | Give school operators one clear structure workspace, but keep calendar, programmes, people, and identity in their owning modules. |
| [PowerSchool school information](https://ps.powerschool-docs.com/pssis-admin/latest/school-information) and [district setup](https://ps.powerschool-docs.com/pssis-admin/latest/academic-and-career-planner-district-setup) | Districts contain multiple schools and sites; institutional records have durable identity and operational status. | Use stable opaque identity, explicit school/site associations, and close/supersede actions instead of destructive deletion. |
| [Toddle for school groups](https://www.toddleapp.com/toddle-for-school-groups/) | A group needs cross-campus visibility and controlled sharing while schools retain local context. | Make the tenant the governed operator boundary; make school scopes explicit; require deliberate adoption instead of implicit hierarchy inheritance. |
| [Canva for Schools and Districts](https://www.canva.com/education/schools/) | Central provisioning, SSO, user-type controls, and institution-wide governance are distinct from everyday creation. | Keep identity and central controls in the platform boundary; school structure supplies scope but never credentials or authority. |
| [SchoolFox communication](https://foxeducation.com/en/schoolfox/simple-school-communication/) | School adoption benefits from simple setup, explicit audiences, multilingual terminology, and clear delivery status. | Keep structure setup concise and translatable; defer messages, recipients, confirmations, and emergency delivery to a later communications module. |
| [1EdTech OneRoster 1.2](https://www.1edtech.org/standards/oneroster) and the [Ed-Fi education-organization domain](https://docs.ed-fi.org/reference/data-exchange/data-standard/4/model-reference/education-organization-domain/overview/) | Interoperability expects stable organization identifiers and explicit organization types and relationships. | Preserve stable IDs and a mapping seam, but do not copy OneRoster's limited org types or Ed-Fi's fixed US hierarchy into the authoritative model. |

These products also show a common failure mode: school settings tend to accumulate identity,
academic, communications, branding, roster, and permission concerns. Chimwemwe should present a
coherent setup journey while keeping those concerns in distinct domain modules.

## Governing boundaries

The implementation remains governed by:

- [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md): small platform kernel and
  independently owned business modules;
- [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md): non-null tenant ownership,
  trusted placement, and data-defined roles;
- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md): named actions rather
  than generic CRUD;
- [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md): atomic state and minimal
  side-effect facts with registered, replayable consumers;
- [ADR 0014](../adr/0014-primary-api-and-generated-typescript-client.md): checked OpenAPI and a
  generated client over the authoritative named-action contract;
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md): explicit
  succession, correction, effective time, consumer basis, and evidence separation;
- [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md): code-owned domain
  authority and bounded presentation metadata;
- [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md): intentional
  browser and phone experiences, not generated CRUD screens;
- the [module lifecycle contract](../architecture/module-activation-and-lifecycle.md); and
- the [threat model](../security/threat-model.md), especially TM-01, TM-02, TM-03, TM-09, TM-10,
  TM-11, TM-13, TM-14, TM-15, and TM-16.

[ADR 0024](../adr/0024-assurance-proportionality-and-module-evolution.md) is still Proposed. Its
useful distinction is followed here without treating it as accepted authority: trust, identity,
tenant, durability, and recovery boundaries remain strict; terminology and bounded school
workflows may evolve through reversible module slices.

## The release ladder

Phase 2 must not use one vague word, "ready", for materially different risk levels.

| Gate | What it permits | What it still forbids |
| --- | --- | --- |
| **L0 — paper and prototype** | Domain scenarios, ADR work, low/high-fidelity flows, synthetic fixtures | Persistent production-core school resources |
| **L1 — synthetic module proof** | Persisted school-structure resources and named actions using synthetic local data | Connected production browser, real identity, public deployment, real school records |
| **L2 — connected synthetic workflow** | A production-candidate session and checked browser/API path using synthetic data | Real Restricted data or a school pilot |
| **L3 — controlled real-data pilot** | Named pilot with approved data classes, deployment, support, recovery, and reviewers | General availability or an unbounded rollout |
| **L4 — production release** | Accountably accepted operating envelope and release process | Automatic approval of another module or integration |

Discovery for Phase 2.1 may run while Phase 2.0 closes. Runtime authorization follows the ladder:
later code or real data never enters through a documentation shortcut.

## Phase 2.0 — entry closure

Phase 2.0 is a sequence of independently reviewable foundation slices. Completing local code is not
enough; each slice closes only when its named evidence and owner are recorded.

### Slice 2.0-A — entry decision register

**Outcome:** one accountable register states which existing conditional gates block L1, L2, L3,
or L4 and who may close each gate.

1. Reconcile the current Phase 0/1 condition registers against the first school-module candidate.
2. Record the selected deployment candidate and the difference between local synthetic evidence
   and deployment evidence.
3. Decide the production identity/session boundary, support-access boundary, and first public
   browser/API boundary through accepted or superseding ADRs.
4. Record the independent security/privacy reviewer and school records owner required before L3.
5. Keep every missing gate fail-closed; an owner and a future test are not completion evidence.

**Exit evidence:** reviewed gate matrix, accepted decision records for every new stable boundary,
and explicit authorization for the next foundation slice.

### Slice 2.0-B — operational outbox and module drain

**Outcome:** the existing durable outbox facts reach real registered consumers safely, including
through module drain, failure, replay, and reactivation.

1. Complete the bounded delivery lease/status work proposed as Slice 1J-A before building on it.
2. Add one supervised dispatcher using the code-owned consumer registry. Preserve current trusted
   tenant placement; event data never selects a destination or grants authority.
3. Prove bounded retry, dead-letter quarantine, operator-observable lag, and separately authorized
   replay from an exact event/range and consumer cursor.
4. Add idempotent consumer receipts and version/schema compatibility checks. At-least-once delivery
   must not duplicate the consumer's durable effect.
5. Integrate the real consumer with module drain: ordinary consumption parks after the recorded
   boundary, mandatory evidence work continues, and reactivation resumes from the exact cursor and
   reconciles before ordinary authority reopens.
6. Rehearse process crash, lease expiry, database outage, stale route, incompatible event version,
   poison event, dead-letter replay, and restore/convergence.

**Exit evidence:** dispatcher and consumer runbooks, lag/retry/dead-letter telemetry, deterministic
drain/reactivation evidence, restore/replay drill, negative tenant/routing tests, and `make check`.

**Not included:** Kafka, a second event authority, arbitrary operator payload editing, or a public
event browser.

### Slice 2.0-C — temporal completion and recovery

**Outcome:** ADR 0018's neutral proof is complete enough to govern the first domain adoption without
pretending that one generic temporal engine fits every module.

1. Close the remaining TR-06 retention, legal-hold, redaction/erasure-receipt, propagation, and
   deactivated-module access evidence with synthetic data.
2. Close TR-07 expand/backfill/validate/contract, import provenance, conflict reconciliation,
   correction-chain backup/restore, and projection convergence evidence.
3. Record performance and storage limits for the neutral proof and reject an unmeasured universal
   abstraction.
4. Complete accountable residual-risk review and update ADR 0018 status only if its stated Full
   Acceptance gate is actually satisfied.
5. For school structure, separately classify profile revisions, site associations, closures, and
   code changes; neutral qualification does not choose the domain model automatically.

**Exit evidence:** TR-01 through TR-07 disposition, retention/recovery runbooks, restore and
convergence artifacts, migration rehearsal, accountable review, and `make check`.

### Slice 2.0-D — production identity, session, and support access

**Outcome:** every public request and support action receives trusted context from a reviewed
identity and session chain.

1. Select an identity-provider and account-linking boundary without copying the local UI-1A token
   registry into production.
2. Define sign-in, callback, session creation, rotation, idle/absolute expiry, logout, revocation,
   credential recovery, tenant selection, step-up assurance, and service-identity behavior.
3. Resolve actor membership and tenant from trusted server-side state. A cookie, header, route,
   form field, or token claim never selects a repository or bypasses current membership.
4. Protect browser sessions with secure cookie, CSRF, origin, content-security, secret/key rotation,
   no-store, and safe error/logging controls appropriate to the selected deployment.
5. Implement TM-03 support grants as separately authorized, time-bounded records with tenant,
   purpose, ticket/approval reference, assurance, capabilities, expiry, revocation, and enhanced
   start/use/end evidence.
6. Show the acting support identity and selected tenant visibly throughout an elevated session;
   deny background, stale, expired, missing-purpose, or cross-tenant reuse.

**Exit evidence:** identity/session ADR and threat review; revoked, expired, forged, stale,
cross-tenant, fixation, CSRF, and recovery tests; support-access negative suite; key/incident
runbooks; and `make check`.

### Slice 2.0-E — production browser/API candidate

**Outcome:** one intentional staff workflow reaches the core through the production-candidate
session and public action contract.

1. Replace UI-1A's local bridge only after Slice 2.0-D is accepted. Keep the local qualification
   harness removable and impossible to enable in the production profile.
2. Expose only the named school-structure reads/actions required by the selected journey.
3. Check in OpenAPI, generate the TypeScript client, and fail drift. Enforce code-owned filters,
   page limits, sortable fields, idempotency headers, optimistic versions, and stable errors.
4. Keep server authorization, field filtering, module gates, and placement selection authoritative.
   Client state and route visibility remain usability aids only.
5. Prove keyboard, screen-reader, visible-focus, error recovery, narrow reflow, degraded network,
   conflict, expiry, revocation, and inactive-module behavior.
6. Qualify rate limits, observability, TLS/edge behavior, secrets, backups, restore, and rollback in
   the selected deployment before L3.

**Exit evidence:** accepted public-boundary decision, checked API/client artifacts, end-to-end
negative tests, representative user review, accessibility evidence, deployment rehearsal, and
`make check`.

## Phase 2.1 — school structure

### Proposed module declaration

| Property | Proposal |
| --- | --- |
| Stable module key | `school.structure` |
| Owner | School operations domain owner with product and platform engineering |
| Initial version | `1.0.0`, declared in the immutable release manifest |
| Declared module dependencies | None in v1; lifecycle, authority, trusted persistence, temporal/evidence contracts, and outbox are kernel prerequisites rather than business-module dependencies |
| Entitlement | Independent tenant entitlement; commercial policy remains outside authorization |
| Activation | Explicit, typed prerequisites; activation grants no actor capability |
| Deactivation | Close ordinary writes, retain structure and required reads/history, drain consumers, retain cursors and ownership, and support compatible reactivation |
| Data class | Confidential by default for real school-operating data; purely synthetic metadata may remain Internal, and any personal contact field requires separate minimization review |
| Downstream contract | Stable tenant-qualified `school_scope_id` and exact, versioned reads; no raw-table or hierarchy authority |

The exact module key and declaration become stable only through the school-structure ADR. The module
must not be placed in the mandatory kernel merely because most tenants will use it.

### Candidate authoritative model

The first ADR should pressure-test this bounded candidate rather than starting from a universal
organization graph:

- **`School`** — the stable school-scope aggregate. It owns an opaque UUID, current code, official
  and display names, operating status, default IANA time zone, terminology-profile reference, and
  optimistic version. Later modules reference its UUID, not its name or hierarchy path.
- **`SchoolProfileRevision`** — attributable, immutable revisions of durable school meaning where
  history matters. A code or name change does not replace the school identity. Current-only mutable
  fields must be justified explicitly rather than assumed.
- **`Site`** — a physical or virtual place with its own stable identity and bounded location data.
  It is not automatically a school, academic scope, authorization scope, or tenant placement.
- **`SchoolSiteAssociation`** — an effective-dated association so one school may use several sites
  and a shared site need not be duplicated. A named primary-site designation is explicit and
  historically bounded.
- **`SchoolRelationship`** — an effective-dated, typed edge between same-tenant schools when a
  reviewed scenario requires it. Each relationship type declares direction, allowed endpoint
  kinds, cardinality, and cycle behavior. The first release includes only types proven by the
  representative scenarios; there is no arbitrary relationship scripting.
- **`TerminologyProfileRevision`** — localized labels for an allowlisted set of code-owned concepts.
  Labels may change what people see, never resource identity, action names, capability keys, event
  types, API fields, or policy behavior.

The tenant itself is the operating boundary, so a synthetic global "all organizations" root is
unnecessary. If real scenarios later need governing bodies, networks, departments, or external
institutions as first-class records, their meaning and ownership require a later authorized slice;
they must not be smuggled in as untyped tree nodes.

The school time zone is a default for presenting and preparing local work. A later published
academic calendar records its own explicit IANA zone and never follows a school-profile change
silently.

### Initial capability vocabulary

The ADR should confirm a small code-owned vocabulary, expected to be equivalent to:

- `school.structure.read` — read current permitted structure;
- `school.structure.history.read` — read bounded revisions and ended associations;
- `school.structure.schools.manage` — register and revise schools;
- `school.structure.sites.manage` — register sites and manage school/site associations;
- `school.structure.relationships.manage` — create or end allowed relationships; and
- `school.structure.publish` — move a reviewed draft structure into ordinary downstream use.

These keys are assigned through tenant-defined, renameable roles. No administrator, head, teacher,
learner, guardian, or support role constant appears in production policy.

### Named action vocabulary

The initial public/domain surface should contain named outcomes, expected to be equivalent to:

- `register_school`, `revise_school_profile`, `publish_school`, and `close_school`;
- `register_site`, `revise_site`, `associate_site`, and `end_site_association`;
- `establish_school_relationship` and `end_school_relationship` for accepted types;
- `publish_terminology_profile_revision`; and
- exact reads for one school scope, its active sites, its permitted relationships, and bounded
  history.

There is no caller-selected tenant, repository, placement, policy option, generic update action,
unbounded organization listing, or recursive authority lookup.

### School-structure invariants

1. Every row, action, query, relationship, event, job, cache key, projection, import mapping, and
   telemetry record is tenant-qualified.
2. Compound database constraints reject cross-tenant profile, site, association, relationship,
   activation, and evidence references even through alternate writes.
3. School identity is an immutable UUID. Human codes are normalized and unique within the tenant;
   a code change is named, versioned, collision-checked, and preserves mapping history.
4. Time zones are valid IANA identifiers. The server never substitutes its own zone or accepts a
   request-supplied zone as authority for an already published downstream record.
5. Effective associations do not overlap where their declared cardinality forbids it. Directional
   relationship types enforce their declared cycle rules.
6. Hierarchy, site membership, shared branding, terminology, reporting roll-up, configuration
   inheritance, and authorization scope are separate semantics. None is inferred from another.
7. Closing or deactivating a school does not erase its stable identity, history, mappings, audit,
   outbox facts, or references from later retained records.
8. Events contain stable identifiers and minimal change facts, not names, addresses, relationship
   graphs, or translated labels unless a specific classified consumer contract requires them.

## Phase 2.1 implementation sequence

### Slice 2.1-A — scenarios, vocabulary, and ADR

**Release level:** L0.

Use at least three representative structures:

1. one independent school operating at one site;
2. one tenant operating several schools, including a shared site; and
3. one school changing code, name, time zone, or site relationship without changing identity.

Test official/local names, multilingual labels, a closed school, an invalid cross-tenant link, a
relationship cycle, and a migration from one current source. Compare the candidate model with
OneRoster and Ed-Fi only as external mappings, not as internal authority.

**Exit evidence:** accepted school-structure ADR; agreed terms, relationship types, correction and
retention disposition; journey prototype; domain-owner review; and explicit Slice 2.1-B
authorization.

### Slice 2.1-B — first vertical school aggregate

**Release level:** L1 after the required Phase 2.0 foundation gates are named as satisfied.

Implement the module declaration, `School`, the smallest justified profile/history representation,
one `register_school` action, one `revise_school_profile` action, and one exact current read. Route
all operations through trusted context, current writer admission, module gates, capability checks,
optimistic concurrency, exact idempotency, minimized audit, and transactional outbox.

**Exit evidence:** generated migration/snapshot review; positive, denied, missing-context,
cross-tenant, alternate-write, stale/concurrent, exact-replay, changed-replay, rollback, and
deactivated-module tests; checked descriptor evidence if exposed; and `make check`.

### Slice 2.1-C — sites and associations

Add `Site` and `SchoolSiteAssociation` with the accepted cardinality and effective-time rules.
Prove multiple sites, a shared site if the ADR accepts it, primary-site succession, overlap
rejection, closure behavior, history access, and deterministic current resolution.

Do not add buildings, rooms, facilities maintenance, transport, geofencing, maps, or attendance
location rules.

### Slice 2.1-D — terminology and institutional relationships

Add the bounded terminology profile and only the relationship types accepted by Slice 2.1-A.
Prove locale fallback, label/version compatibility, allowed endpoints, cardinality, cycle rules,
and the absence of authority or implicit configuration effects.

A new relationship type is code-reviewed schema/behavior, not arbitrary tenant executable logic.

### Slice 2.1-E — lifecycle, consumers, correction, and recovery

Exercise the real module through entitlement, activation, ordinary use, controlled drain,
mandatory work, compatible reactivation, outbox dispatch, consumer replay, and reconciliation.
Rehearse backup/restore and rebuild any disposable structure projection. Apply the domain-specific
retention and correction rules accepted in Slice 2.1-A.

This is the point at which Phase 2.0's neutral contracts prove that they work for a real business
module; failures reopen the applicable entry gate rather than being waived for the module.

### Slice 2.1-F — staff browser workflow

**Release level:** L2, only after the production identity/session and public-interface gates pass.

Create a browser structure workspace optimized for school operations:

- an overview of school scopes and status;
- an exact school detail with sites, time zone, codes, terminology, and relationships;
- guided named-action forms with review, conflict, retry, and recovery states; and
- written lifecycle and connection status in addition to colour.

The first phone experience may be a deliberately small read-only detail if research demonstrates a
real need; a compressed desktop editor is not an acceptance criterion. A generic resource browser
or JSON editor is prohibited.

### Slice 2.1-G — migration and controlled pilot

**Release level:** L3, only after deployment, reviewer, support, recovery, and data-class gates pass.

Build a source-specific shadow importer behind a migration ledger. It reports counts, stable-ID and
code mappings, duplicate codes, invalid time zones, unresolved sites, relationship cycles, source
hierarchy/default assumptions, and conflicts. It never resolves conflicts by last-write-wins or
turns a source parent relation into an access grant.

Run compare-only, then repeatable import, then authoritative read-back and reconciliation. A pilot
names its tenant, data classes, support model, rollback point, success measures, expiry, and
decision owner. General availability requires a later explicit decision.

## Cross-slice acceptance evidence

Before Phase 2.1 is called complete, the evidence set includes:

- one accepted school-structure ADR and module declaration;
- domain-owner approval of the school/site/relationship meanings and user journey;
- tenant/capability negatives for every action and read, including non-disclosing cross-tenant and
  cross-school cases;
- database-enforced tenant, identity, code, time-zone, association, relationship, and lifecycle
  invariants;
- concurrency, idempotency, state/audit/outbox atomicity, dispatch, retry, replay, drain,
  reactivation, restore, and reconciliation proof;
- migration provenance and unresolved-conflict reporting;
- checked OpenAPI and generated-client drift evidence for every public action;
- keyboard, assistive-technology, narrow-screen, degraded-network, conflict, expiry, and recovery
  evidence for the browser workflow;
- deployment-specific security, capacity, backup, restore, and rollback evidence before L3;
- independent security/privacy review and school-records review before real Restricted data; and
- a passing `make check` for every authorized implementation slice, with skipped checks stated.

## Explicit non-goals

This proposal does not authorize or include:

- learner, guardian, staff, household, identity-account, or employment records;
- admissions, applications, enrolment, promotion, withdrawal, or roster workflows;
- academic years, periods, calendars, curriculum, courses, classes, timetables, attendance,
  assessment, grading, portfolios, behavior, safeguarding, health, fees, or payroll;
- messaging, announcements, recipients, read confirmations, translation services, notifications,
  emergency SMS, or family applications;
- buildings, rooms, assets, facilities, transport, or geospatial tracking;
- a universal organization graph, arbitrary custom entity types, executable tenant rules, live
  hierarchy inheritance, or fixed school-role constants;
- a generic setup wizard that owns unrelated state;
- generic CRUD, GraphQL, Kafka, a new search/vector store, or a second policy engine; or
- production data, a pilot, deployment, or general availability without the matching ladder gate.

## Recommended implementation order after this proposal

1. Accept or amend this proposal.
2. Authorize Slice 2.0-A only and produce the entry decision register.
3. Close 2.0-B and 2.0-C while 2.1-A runs as research and decision work.
4. Accept the school-structure ADR and authorize 2.1-B as the first persisted module slice.
5. Add 2.1-C and 2.1-D only after each prior slice is green and reviewed.
6. Qualify 2.1-E against the real operational lifecycle.
7. Complete 2.0-D and 2.0-E before connecting 2.1-F.
8. Permit 2.1-G only after the L3 deployment, review, support, recovery, and data-class gates pass.

The next likely module after school structure is academic calendar because ADR 0021 already records
a bounded candidate and later domains need stable school and period references. That sequencing is
informative only: this proposal neither accepts ADR 0021 nor authorizes a calendar implementation.
