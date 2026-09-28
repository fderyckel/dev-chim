# Phase 2 entry and institutional-structure implementation proposal

- Status: Phase 2 implementation sequence authorized on 2026-09-26; Phase 2.0 conditionally
  approved and closed at L1 on 2026-09-28 with Slice 2.0-E carried as a dated residual condition;
  the former flat-school Phase 2.1 candidate is withdrawn and replaced by this recursive
  institutional-structure proposal
- Owner: Product and platform engineering, with learning-institution domain and security/privacy
  review
- Decision authority: François — Project Owner and interim Security/Privacy Owner
- Decision scope: Phase 2.0 production-entry closure and Phase 2.1 recursive institutional
  structure only
- Review trigger: entry into any listed slice, a failed entry or exit gate, or a change to identity,
  support access, module lifecycle, temporal semantics, public interface, or the proposed
  institutional-structure boundary

## Purpose

Phase 2 should cross one deliberate threshold: Chimwemwe moves from a qualified platform core to
its first linked corporate/legal and learning-institution domain modules without weakening the
tenant, authority, evidence, recovery, or client contracts established in Phases 0 and 1.

The proposed sequence is:

1. **Phase 2.0 — close the entry gates.** Finish the operational, identity, support-access, temporal,
   and public-interface contracts required to run a learning-institution module safely.
2. **Phase 2.1 — introduce separated corporate/legal and educational structure.** First let a
   tenant describe legal entities, corporate units, and their reviewed relationships; then add
   root learning institutions, nested educational units, exact primary legal operation, sites,
   stable codes, operating time zones, local terminology, and explicit affiliations.

Corporate/legal structure is intentionally the first business module, followed by educational
structure. Together they give later finance, calendar, admissions, enrolment, programmes, classes,
attendance, communication, and reporting modules stable, exact references without prematurely
introducing learner, guardian, staff, curriculum, or academic-calendar records.

This is not a proposal for a generic `setup` module. Provisioning, identity, authority, module
lifecycle, institutional structure, and later learning workflows keep separate owners and
contracts.

The 2026-09-26 project-owner authorization covers this bounded implementation sequence. The
sequence and its release ladder decide when each slice is eligible; no additional project-owner
authorization is pending for a listed slice. The same-day product clarification records Chimwemwe
as an operating system for learning institutions and requires recursive institutional units through
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md). It
does not accept that proposed data model, permit a slice to cross an unsatisfied entry gate, or turn
planned evidence into a satisfied gate. The current dispositions are recorded in the
[Phase 2 entry decision register](../phase-2/entry-decision-register.md).

## Desired outcomes

### Phase 2.0 outcome

The platform can safely host its first learning-institution module. In practical terms:

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

Authorized actors can establish and maintain legal entities, nested corporate units, one or more
root educational institutions, nested educational units at any reviewed depth, exact primary
legal-operation relationships, and the sites at which institutions operate. A permitted staff
member can inspect the linked structures through an intentional browser workflow. Every identity
remains tenant-qualified, historically explainable, and usable as a stable reference by later
modules.

Legal ownership/control, consolidation, legal responsibility, and corporate or educational
hierarchy have **no authorization effect**. They never grant a capability, expand record scope,
select a database, activate a module, turn a unit into a site, widen a report, or create live
configuration inheritance. Exact-identity and descendant authorization, reporting, finance, and
configuration semantics require separate explicit contracts.

## Reference-derived requirements

This proposal retains product-independent requirements identified through prior external research.
Commercial product names, links, schemas, and screens are intentionally excluded from the durable
architecture record.

| Observed pattern | Useful lesson | Chimwemwe interpretation |
| --- | --- | --- |
| Coherent institution settings | School identity, address, time zone, language, terminology, and programme settings need a coherent administrative home. | Give school operators one clear structure workspace, but keep calendar, programmes, people, and identity in their owning modules. |
| Multi-institution administration | Groups contain multiple schools and sites; institutional records need durable identity and operational status. | Use stable opaque identity, explicit institution/site associations, and close/supersede actions instead of destructive deletion. |
| Cross-campus operation | A group needs cross-campus visibility and controlled sharing while institutions retain local context. | Keep the tenant as the governed security boundary, make institutional scopes explicit, and require deliberate adoption instead of implicit hierarchy inheritance. |
| Central provisioning | Central identity and institution-wide governance are distinct from everyday learning operations. | Keep identity and central controls in the platform boundary; institutional structure supplies stable references but never credentials or authority. |
| Multilingual communication | Adoption benefits from simple setup, explicit audiences, multilingual terminology, and clear delivery status. | Keep structure setup concise and translatable; defer messages, recipients, confirmations, and emergency delivery to a later communications module. |
| Education interoperability | External exchanges expect stable organization identifiers and explicit organization types and relationships. | Preserve stable IDs and a mapping seam, but do not copy a source standard's limited organization types or jurisdiction-specific hierarchy into the authoritative model. |

These observations also show a common failure mode: institution settings tend to accumulate identity,
academic, communications, branding, roster, and permission concerns. Chimwemwe should present a
coherent setup journey while keeping those concerns in distinct domain modules. Product direction
on 2026-09-26 additionally requires a university-to-department hierarchy and a combined-school
hierarchy as first-class scenarios; the former flat `School` candidate is no longer sufficient.

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
- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md):
  product scope, recursive institutional units, and separation of hierarchy from other meanings;
- the [module lifecycle contract](../architecture/module-activation-and-lifecycle.md); and
- the [threat model](../security/threat-model.md), especially TM-01, TM-02, TM-03, TM-09, TM-10,
  TM-11, TM-13, TM-14, TM-15, TM-16, and TM-17.

[ADR 0024](../adr/0024-assurance-proportionality-and-module-evolution.md) is still Proposed. Its
useful distinction is followed here without treating it as accepted authority: trust, identity,
tenant, durability, and recovery boundaries remain strict; terminology and bounded
learning-institution workflows may evolve through reversible module slices.

## The release ladder

Phase 2 must not use one vague word, "ready", for materially different risk levels.

| Gate | What it permits | What it still forbids |
| --- | --- | --- |
| **L0 — paper and prototype** | Domain scenarios, ADR work, low/high-fidelity flows, synthetic fixtures | Persistent production-core institutional resources |
| **L1 — synthetic module proof** | Persisted institutional-structure resources and named actions using synthetic local data | Connected production browser, real identity, public deployment, real institutional records |
| **L2 — connected synthetic workflow** | A production-candidate session and checked browser/API path using synthetic data | Real Restricted data or a learning-institution pilot |
| **L3 — controlled real-data pilot** | Named learning-institution pilot with approved data classes, deployment, support, recovery, and reviewers | General availability or an unbounded rollout |
| **L4 — production release** | Accountably accepted operating envelope and release process | Automatic approval of another module or integration |

Discovery for Phase 2.1 may run while Phase 2.0 closes. Runtime authorization follows the ladder:
later code or real data never enters through a documentation shortcut.

## Phase 2.0 — entry closure

Phase 2.0 is a sequence of independently reviewable foundation slices. Completing local code is not
enough; each slice closes only when its named evidence and owner are recorded.

### Slice 2.0-A — entry decision register

**Outcome:** one accountable register states which existing conditional gates block L1, L2, L3,
or L4 and who may close each gate.

1. Reconcile the current Phase 0/1 condition registers against the first
   learning-institution-module candidate.
2. Record the selected deployment candidate and the difference between local synthetic evidence
   and deployment evidence.
3. Decide the production identity/session boundary, support-access boundary, and first public
   browser/API boundary through accepted or superseding ADRs.
4. Record the independent security/privacy reviewer and learning-institution records owner
   required before L3.
5. Keep every missing gate fail-closed; an owner and a future test are not completion evidence.

**Exit evidence:** reviewed gate matrix, accepted decision records for every new stable boundary,
and a recorded entry-gate disposition for the next foundation slice.

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

[Slice 2.0-B evidence](../phase-2/operational-outbox-and-module-drain-evidence.md) closes this
provider-neutral local L1 foundation contract with immutable stream positions, cursor paging and
bounded exact range replay, module-aware drain/reconciliation/reactivation, sanitized telemetry,
recovery drills, and runbooks. Selected-deployment thresholds and restore, external effects,
movement, retention, and real-data review remain later deployment gates rather than being
mislabelled as local completion evidence.

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
5. For institutional structure, separately classify profile revisions, parentage, site
   associations, affiliations, closures, moves, and code changes; neutral qualification does not
   choose the domain model automatically.

**Exit evidence:** TR-01 through TR-07 disposition, retention/recovery runbooks, restore and
convergence artifacts, migration rehearsal, accountable review, and `make check`.

[Slice 2.0-C evidence](../phase-2/temporal-completion-and-recovery-evidence.md) completes the
authorized neutral engineering: TR-01 through TR-07 are executable, the runbook and local
dump/restore/convergence artifacts are recorded, retained rollback fails closed, and local limits
are explicit. The accountable post-evidence residual-risk review remains the final ADR 0018
acceptance step; implementation authorization is not confused with that review. TR-08 continues to
reject a universal temporal persistence abstraction until two real domains justify one.

### Slice 2.0-D — production identity, session, and support access

**Outcome:** every public request and support action receives trusted context from a reviewed
identity and session chain.

Accepted [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
and its [decision review](../phase-2/identity-session-and-support-access-decision-review.md) close
the L0 decision gate with a provider-neutral qualified OIDC/gateway seam, application-owned
sessions, protocol-qualified external-identity links, writer-resolved tenant context, separately
gated directory provisioning, and non-impersonating support grants. Microsoft Entra ID,
hybrid/on-premises Active Directory, Google Workspace, generic OIDC, and qualified SAML gateway
paths are supported candidates. Bounded synthetic implementation may begin; no real connection,
public route, directory sync, or L2 claim exists yet.

1. Implement the provider-neutral identity-connection and account-linking boundary without copying
   the local UI-1A token registry or provider-specific authority into production.
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

**Current disposition:** Conditionally deferred under ADR 0025 C25-05. Expert/representative
comprehension and accountable product-experience review is due by 2026-12-15 or before this
connected/public workflow begins, whichever is earlier. Phase 2.0 is closed for planning at L1;
this deferral does not authorize the workflow or an L2 release.

**Outcome:** one intentional staff workflow reaches the core through the production-candidate
session and public action contract.

1. Replace UI-1A's local bridge only after Slice 2.0-D is accepted. Keep the local qualification
   harness removable and impossible to enable in the production profile.
2. Expose only the named institutional-structure reads/actions required by the selected journey.
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

## Phase 2.1 — separated corporate/legal and educational structure

### Proposed module declaration

| Property | Corporate/legal structure proposal | Educational-structure proposal |
| --- | --- | --- |
| Stable module key | Candidate `organization.legal`; the accepted ADR owns the final key | Candidate `institution.structure`; the accepted ADR owns the final key |
| Owner | Corporate governance and finance domain ownership with product and platform engineering | Learning-institution operations domain ownership with product and platform engineering |
| Initial version | `1.0.0`, declared in the immutable release manifest | `1.0.0`, declared in the immutable release manifest |
| Declared module dependencies | No business-module dependency; platform lifecycle, authority, trusted persistence, temporal/evidence contracts, and outbox remain kernel prerequisites | Depends on the compatible active corporate/legal module and the same kernel prerequisites |
| Entitlement | Independent tenant entitlement; commercial policy remains outside authorization | Independent tenant entitlement; legal-module entitlement or activation grants no institutional capability |
| Activation | Explicit typed prerequisites; activation grants no actor capability | Requires a compatible legal module and still grants no actor capability |
| Deactivation | Close ordinary writes, retain legal structure and required reads/history, drain consumers, retain cursors and ownership, and support compatible reactivation | Close ordinary writes, retain educational structure and required reads/history, drain consumers, retain cursors and ownership, and support compatible reactivation |
| Data class | Confidential by default for real registration, control, ownership, and operating data; contact or beneficial-owner data requires separate minimization and classification | Confidential by default for real institutional operating data; purely synthetic metadata may remain Internal, and any personal contact field requires separate minimization review |
| Downstream contract | Stable tenant-qualified legal-entity and corporate-unit identifiers plus exact versioned reads; no relationship-derived authority | Stable tenant-qualified institutional-unit identifier plus exact classification and versioned reads; no raw-table, hierarchy-derived authority, or path-based identity |

The exact module keys and declarations become stable only through acceptance of
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md).
Neither module belongs in the mandatory kernel merely because most tenants will use it.

### Candidate authoritative model

ADR 0025 should pressure-test two linked but independently governed structures rather than either
a flat school table or a universal organization graph.

The corporate/legal model contains:

- **`LegalEntity`** — the stable identity for a registered company, trust, foundation, public body,
  or other legally accountable organization. Registration, jurisdiction, status, and official
  profile change without replacing its UUID.
- **`LegalEntityRelationship`** — an effective-dated, code-owned typed relationship such as
  ownership, control, or consolidation. Legal ownership is not forced into one tree: joint or
  multiple ownership may coexist with one optional primary consolidation parent used for bounded
  navigation and financial reporting.
- **`CorporateUnit`** — an internal organizational structure, such as a regional office, finance
  department, shared-service centre, or operating division. Corporate units may nest, but every
  published corporate unit belongs to one exact legal entity and cannot be a legal operator.
- **`EducationalInstitutionLegalResponsibility`** — the effective-dated relationship assigning one
  exact primary accountable legal operator to an educational institution. Other typed legal
  relationships, including governance, employment, property, funding, contracting, and data-control
  responsibility, remain separate and may name different legal entities.

The educational-structure model contains:

- **`InstitutionalUnit`** — the stable physical-model candidate for either an educational
  institution or an educational unit. The code-owned classification is behaviorally meaningful:
  an educational institution is a recognized learning establishment with an effective primary
  legal operator; an educational unit is a contained division, faculty, school, or department
  covered through its containing institution. A contained establishment with distinct legal
  accountability is classified as an educational institution, not merely relabelled as a unit.
  The record owns an opaque UUID, current code, operating status, default IANA time zone,
  terminology-profile reference, and optimistic version. Later modules reference its UUID and
  exact classification, never its name or hierarchy path.
- **`InstitutionalUnitProfileRevision`** — attributable, immutable revisions of durable unit
  meaning where history matters, including official and display names and the accepted structural
  classification. A code, label, or type change does not replace the unit identity. Current-only
  mutable fields must be justified explicitly rather than assumed.
- **`InstitutionalUnitParentage`** — same-tenant canonical containment with zero or one active
  parent per unit, no fixed depth, effective history where accepted, and direct, indirect, and
  concurrent cycle prevention. A tenant may own several root units.
- **`Site`** — a physical or virtual place with its own stable identity and bounded location data.
  It is not automatically an institutional unit, academic scope, authorization scope, or tenant
  placement.
- **`InstitutionalUnitSiteAssociation`** — an effective-dated association so one unit may use
  several sites and a shared site need not be duplicated. A named primary-site designation is
  explicit and historically bounded.
- **`InstitutionalAffiliation`** — an effective-dated, typed same-tenant edge for a reviewed
  cross-cutting case such as a joint programme or shared service. It never supplies a second
  canonical parent. Each relationship type declares direction, allowed endpoint kinds,
  cardinality, and cycle behavior; there is no arbitrary relationship scripting.
- **`TerminologyProfileRevision`** — localized labels for an allowlisted set of code-owned concepts.
  Labels may change what people see, never resource identity, action names, capability keys, event
  types, API fields, or policy behavior.

The tenant is the security, placement, lifecycle, and data boundary; a legal entity is the
accountable operator. A synthetic global "all organizations" node is unnecessary in either
structure. Schools, colleges, faculties, departments, and age-phase divisions may be nested when
they are educationally meaningful. Programmes, cohorts, courses, sites, legal entities, corporate
units, external partners, reporting groups, and access scopes are never smuggled into the
educational tree as untyped nodes.

Every published educational institution has exactly one active primary legal operator for any
given date. An educational unit resolves legal accountability through its containing educational
institution. A move that might change that resolution must show the before-and-after operator and
block until every legal, records, workflow, finance, and safeguarding effect is classified. A
draft or migration candidate may remain unresolved, but it cannot be published or receive real
operational records. Changing legal operator, ownership, consolidation, corporate parentage, or
educational parentage never changes the affected stable identities or rewrites history.

The unit time zone is a default for presenting and preparing local work. A later published academic
calendar records its own explicit IANA zone and never follows a unit-profile or parent change
silently.

### Initial capability vocabulary

The ADR should confirm a small code-owned vocabulary, expected to be equivalent to:

- `organization.legal.entities.read` — read exact permitted legal-entity context;
- `organization.legal.entities.manage` — register and revise legal entities;
- `organization.legal.relationships.manage` — manage accepted ownership, control, and
  consolidation relationships;
- `organization.legal.corporate_units.manage` — manage internal corporate units and parentage;
- `organization.legal.responsibility.manage` — manage primary-operator and other accepted legal
  responsibility relationships;
- `institution.structure.read` — read current permitted structure;
- `institution.structure.history.read` — read bounded revisions and ended parentage or
  associations;
- `institution.structure.units.manage` — register and revise institutional units;
- `institution.structure.parentage.manage` — place or move units after impact validation;
- `institution.structure.sites.manage` — register sites and manage unit/site associations;
- `institution.structure.affiliations.manage` — create or end allowed affiliations; and
- `institution.structure.publish` — move a reviewed draft structure into ordinary downstream use.

These keys are assigned through tenant-defined, renameable roles. No administrator, head, teacher,
learner, guardian, or support role constant appears in production policy.

### Named action vocabulary

The initial public/domain surface should contain named outcomes, expected to be equivalent to:

- `register_legal_entity`, `revise_legal_entity_profile`, and `close_legal_entity`;
- `establish_legal_entity_relationship`, `end_legal_entity_relationship`, and
  `set_primary_consolidation_parent` for accepted types;
- `register_corporate_unit`, `revise_corporate_unit`, `place_corporate_unit`, and
  `move_corporate_unit`;
- `assign_primary_legal_operator`, `change_primary_legal_operator`, and named actions for other
  accepted legal responsibilities;
- `register_institutional_unit`, `revise_institutional_unit_profile`,
  `publish_institutional_unit`, and `close_institutional_unit`;
- `place_institutional_unit`, `preview_institutional_unit_move`, and
  `move_institutional_unit`;
- `register_site`, `revise_site`, `associate_institutional_unit_site`, and
  `end_institutional_unit_site_association`;
- `establish_institutional_affiliation` and `end_institutional_affiliation` for accepted types;
- `publish_terminology_profile_revision`; and
- exact reads for one unit, a bounded permitted ancestor or descendant view, its active sites, its
  permitted affiliations, and bounded history.

There is no caller-selected tenant, repository, placement, policy option, generic update action,
unbounded organization listing, or hierarchy-derived authority lookup.

### Institutional-structure invariants

1. Every row, action, query, relationship, event, job, cache key, projection, import mapping, and
   telemetry record is tenant-qualified.
2. Compound database constraints reject cross-tenant legal-entity, corporate-unit, legal
   relationship, legal-responsibility, institutional profile, parentage, site, association,
   affiliation, activation, and evidence references even through alternate writes.
3. Legal-entity, corporate-unit, and institutional-unit identities are immutable UUIDs. Human
   codes are normalized under their accepted scopes. A code or registration change is named,
   versioned, collision-checked, and preserves mapping history.
4. Every published corporate unit belongs to one exact legal entity. Every published educational
   institution has one active primary legal operator for its effective dates. An educational unit
   resolves through an exact containing institution; ambiguous or missing resolution fails closed.
5. Legal-entity ownership/control is a typed relationship graph. An optional primary consolidation
   parent is only a bounded navigation and reporting choice; it does not erase other relationships,
   create legal ownership, or grant authority. Corporate and educational canonical parentage remain
   separate acyclic structures.
6. Time zones are valid IANA identifiers. The server never substitutes its own zone or accepts a
   request-supplied zone as authority for an already published downstream record.
7. Canonical corporate and educational parentage each have at most one active parent, stay inside
   one tenant, have no fixed depth, and reject direct, indirect, and concurrent cycles. Effective
   associations do not overlap
   where their declared cardinality forbids it.
8. Legal, corporate, and educational hierarchy, legal responsibility, site membership, shared
   branding, terminology, reporting roll-up, configuration inheritance, and authorization scope
   are separate semantics. None is inferred from another.
9. A legal, corporate, or educational hierarchy move, legal-operator change, or consolidation
   change cannot silently widen exact-unit or descendant authorization, reporting, configuration,
   workflow, integration, finance, or retained-data scope. Every registered effect is previewed
   and reconciled or the change is blocked.
10. Closing or deactivating a legal entity, corporate unit, or educational unit does not erase its
   stable identity, history, mappings, audit, outbox facts, or references from retained records.
11. Events contain stable identifiers and minimal change facts, not names, addresses, relationship
   graphs, or translated labels unless a specific classified consumer contract requires them.

## Phase 2.1 implementation sequence

### Slice 2.1-A — linked-structure scenarios, vocabulary, and ADR

**Release level:** L0.

Use the educational scenarios required by ADR 0025 plus a corporate/legal scenario, including:

1. one independent kindergarten operating at one site;
2. one combined school containing kindergarten, middle-school, and high-school units;
3. one university containing several schools or faculties and nested departments;
4. one tenant operating several institutional roots, including a shared site;
5. one unit changing parent, code, name, time zone, or site relationship without changing identity;
6. one cross-cutting programme or service without a second canonical parent;
7. cross-tenant, direct-cycle, indirect-cycle, and concurrent-cycle attempts; and
8. proof that parentage and moves do not grant access, activate modules, change placement, widen
   reports, or apply configuration implicitly; and
9. nested legal entities, multiple ownership, an optional consolidation parent, nested corporate
   units, two institutions sharing one operator, a contained institution with its own operator,
   distinct property/employment relationships, and an effective operator transfer.

Test official and local names, multilingual labels, bounded tree navigation, closed entities and
units, migration from at least one current source, and the distinction between legal entities,
corporate units, educational institutions, educational units, sites, programmes, and access
scopes. Compare external interoperability profiles and source-system shapes only as mappings or
operational reference patterns, not as internal authority.

**Exit evidence:** accepted ADR 0025; agreed legal-entity, corporate-unit, educational-unit,
operator-responsibility, parentage, site, and affiliation meanings; correction and retention
disposition; linked-structure navigation prototype; representative domain-owner review;
threat-model evidence; and a recorded entry-gate disposition for Slice 2.1-B.

The [institutional-structure decision evidence plan](../phase-2/institutional-structure-decision-evidence.md)
defines the six approval gates, required scenario fields, representative contexts, TM-17/AC-18
review, migration and lifecycle disposition, experience checks, and accountable decision record.
Creating that plan does not satisfy its gates or accept ADR 0025.

### Slice 2.1-B — first vertical legal-entity aggregate

**Release level:** L1 after the required Phase 2.0 foundation gates are named as satisfied.

Implement the corporate/legal module declaration, `LegalEntity`, the smallest justified
profile/history representation, one `register_legal_entity` action, one
`revise_legal_entity_profile` action, and one exact current read. Route all operations through
trusted context, current writer admission, module gates, capability checks, optimistic
concurrency, exact idempotency, minimized audit, and transactional outbox.

**Exit evidence:** generated migration/snapshot review; positive, denied, missing-context,
cross-tenant, alternate-write, stale/concurrent, exact-replay, changed-replay, rollback, and
deactivated-module tests; checked descriptor evidence if exposed; and `make check`.

The [Slice 2.1-B evidence](../phase-2/legal-entity-foundation-evidence.md) records the bounded L1
entry and completed proof. It intentionally stops before Slice 2.1-C and before any connected
public workflow.

### Slice 2.1-C — legal relationships and corporate units

Add only the accepted `LegalEntityRelationship` types, the optional primary consolidation parent,
and `CorporateUnit` with its legal-entity membership and canonical parentage. Prove joint or
multiple ownership without pretending it is a tree, bounded consolidation navigation, several
roots, stable identities through reorganization, same-tenant relationships, direct/indirect/
concurrent cycle treatment where a relationship type requires acyclicity, and no implicit
authorization, reporting, configuration, module, or placement effect.

### Slice 2.1-D — educational institutions, units, and legal responsibility

Implement the educational-structure module declaration and the smallest accepted
`InstitutionalUnit` representation with distinct educational-institution and educational-unit
semantics. Add the exact effective primary-operator relationship for institutions and resolution
through the containing institution for units. Prove that publication fails closed without one
unambiguous operator, an operator transfer preserves both identities and history, and activation or
legal-module access grants no educational capability.

### Slice 2.1-E — educational parentage, sites, terminology, and affiliations

Add `InstitutionalUnitParentage`, `Site`, `InstitutionalUnitSiteAssociation`, the bounded
terminology profile, and only the affiliation types accepted by Slice 2.1-A. Prove several roots,
arbitrary reviewed depth, a contained institution, stable identity and legal-impact preview through
a move, one active canonical parent, same-tenant containment, cycle rejection, multiple and shared
sites, locale fallback, allowed affiliation endpoints, and the absence of implicit legal,
canonical-parent, authority, reporting, workflow, or configuration effects.

A new relationship type is code-reviewed schema/behavior, not arbitrary tenant executable logic.
Do not add buildings, rooms, facilities maintenance, transport, geofencing, maps, or attendance
location rules.

### Slice 2.1-F — lifecycle, consumers, correction, and recovery

Exercise both real modules through entitlement, dependency-aware activation, ordinary use,
controlled drain,
mandatory work, compatible reactivation, outbox dispatch, consumer replay, and reconciliation.
Rehearse backup/restore and rebuild every disposable structure projection. Apply the
domain-specific retention and correction rules accepted in Slice 2.1-A and prove that deactivating
either module neither erases history nor silently leaves the dependent module operational.

This is the point at which Phase 2.0's neutral contracts prove that they work for a real business
module; failures reopen the applicable entry gate rather than being waived for the module.

### Slice 2.1-G — staff browser workflow

**Release level:** L2, only after the production identity/session and public-interface gates pass.

Create a browser structure workspace optimized for learning-institution operations:

- separate but linked views of permitted legal entities, corporate units, educational
  institutions, educational units, and status;
- an exact legal or educational detail with bounded parent/child context and the applicable typed
  relationships, primary operator, sites, time zone, codes, terminology, and affiliations;
- safe hierarchy move preview with written downstream-impact and conflict status;
- safe legal-operator and consolidation-change previews that do not present either structure as
  authority;
- guided named-action forms with review, conflict, retry, and recovery states; and
- written lifecycle and connection status in addition to colour.

The first phone experience may be a deliberately small read-only detail if research demonstrates a
real need; a compressed desktop editor is not an acceptance criterion. A generic resource browser
or JSON editor is prohibited.

### Slice 2.1-H — migration and controlled pilot

**Release level:** L3, only after deployment, reviewer, support, recovery, and data-class gates pass.

Build a source-specific shadow importer behind a migration ledger. It reports counts, stable-ID and
code mappings, duplicate registrations or codes, invalid time zones, missing or ambiguous legal
operators and parents, roots, depth, unresolved sites, relationship cycles, source hierarchy/default
assumptions, and conflicts. It never resolves conflicts by last-write-wins, treats a source company
as both legal entity and educational institution without explicit evidence, turns a source parent
relation into an access grant, or treats a site, programme, or reporting group as an institutional
unit without an explicit mapping disposition.

Run compare-only, then repeatable import, then authoritative read-back and reconciliation. A pilot
names its tenant, data classes, support model, rollback point, success measures, expiry, and
decision owner. General availability requires a later explicit decision.

## Cross-slice acceptance evidence

Before Phase 2.1 is called complete, the evidence set includes:

- one accepted ADR 0025 and separate corporate/legal and educational-structure module declarations;
- representative domain-owner approval of legal-entity, corporate-unit, educational-unit,
  operator-responsibility, parentage, site, and affiliation meanings and the linked user journey
  across materially different learning institutions;
- tenant/capability negatives for every action and read, including non-disclosing cross-tenant and
  cross-unit cases;
- database-enforced tenant, identity, registration, code, time-zone, legal responsibility,
  parentage, cycle, association, affiliation, and lifecycle invariants;
- proof that legal relationships, consolidation, corporate or educational parentage, operator
  changes, and moves do not silently widen authorization, reporting, configuration, workflow,
  module, placement, site, finance, or retained-data meaning;
- concurrency, idempotency, state/audit/outbox atomicity, dispatch, retry, replay, drain,
  reactivation, restore, and reconciliation proof;
- migration provenance and unresolved-conflict reporting;
- checked OpenAPI and generated-client drift evidence for every public action;
- keyboard, assistive-technology, narrow-screen, degraded-network, conflict, expiry, and recovery
  evidence for the browser workflow;
- deployment-specific security, capacity, backup, restore, and rollback evidence before L3;
- independent security/privacy review and learning-institution records review before real
  Restricted data; and
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
  hierarchy inheritance, or fixed institutional-role constants;
- a generic setup wizard that owns unrelated state;
- generic CRUD, GraphQL, Kafka, a new search/vector store, or a second policy engine; or
- production data, a pilot, deployment, or general availability without the matching ladder gate.

## Future workflow propagation requirement

Later domain modules must support governed workflow coordination across approved corporate/legal
and educational structures without turning parentage into an automatic behavior engine.

- Downward reuse is explicit publication and adoption of a versioned workflow or policy, with
  visible provenance, local override rules, and deliberate update or withdrawal.
- Upward movement is an explicit escalation, approval, consolidation, or aggregation step, not
  reverse inheritance.
- Cross-branch coordination names the exact participating units and accountable owner rather than
  relying on a common ancestor.
- Reparenting never silently changes an active workflow. A move preview must classify affected
  adoptions, overrides, pending work, approvals, and reporting obligations and block unknown effects.
- Every workflow action retains tenant, actor, unit, effective-time, authorization, audit, and
  recovery evidence through its owning domain.

This requirement does not authorize a universal workflow language or executable tenant rules. Each
business module must define its own bounded states, actions, propagation directions, and acceptance
evidence when that workflow enters scope.

## Future programme and curriculum authority requirement

The 2026-09-27 product review approves a governed separation between external programme authority
and local curriculum ownership. An external awarding, curriculum, accreditation, or regulatory
body owns its authoritative specification. A named school or academic governing body owns the
local curriculum implementation. This is not blanket school sovereignty: the accountable local
owner may be a school, an explicitly authorized central academic body, or another reviewed
education authority, and its freedom remains bounded by applicable external, regulatory, and
governance obligations.

A later programme/curriculum module must preserve these meanings separately:

- an immutable reference to the exact external specification version and its typed obligations;
- a separately versioned local curriculum containing the institution's sequence, content,
  pedagogy, enrichment, and permitted local assessment choices;
- a versioned alignment map showing how local curriculum elements cover mandatory, constrained,
  recommended, and locally discretionary requirements; and
- an exact programme offering that binds the applicable external and local versions to its owning
  educational context.

The future model must distinguish frameworks, qualifications, subject or course specifications,
assessment regimes, and accreditation requirements rather than treating every external source as
one interchangeable framework. Mapping a local element to an external requirement supplies
traceability; it does not by itself certify compliance or permit an external obligation to be
edited locally.

External obligations cannot be downgraded, rewritten, or reclassified as local discretion by a
school. Where the external authority supplies a requirement classification, Chimwemwe preserves
that classification with the exact source version. A local curriculum authority may add its own
requirements or stricter expectations, but they remain visibly local and do not alter the external
source. When an external requirement is ambiguous, an authorized academic reviewer records a
separate attributable interpretation with its scope, rationale, evidence, and review state. An
unresolved interpretation does not prevent ordinary drafting, but the affected programme offering
cannot claim compliance until the ambiguity is resolved. The ordinary interface derives these
states from context and asks for human review only for exceptions, conflicts, and unresolved
interpretations.

One local curriculum may align with several external, national, regulatory, or group
specifications at the same time. Alignment is many-to-many: one local curriculum element may
address several external requirements, and one external requirement may be addressed through
several local elements. Each programme offering pins the exact applicable source versions and
marks each source as required or supplementary. Conflicting requirements have no implicit
precedence; an authorized academic reviewer records an explicit, attributable disposition.
Unresolved conflicts block the affected compliance claim, not ordinary drafting. Teachers
normally work from the resolved local curriculum, while curriculum leaders receive the detailed
mapping, conflict, gap, and exception views.

Every programme offering has one accountable academic owner, but it may involve several
participating educational units and sites. The accountable owner need not deliver every course or
component. Each participating unit has an explicit typed role, such as coordinator, contributor,
or delivery unit; participation never changes canonical institutional parentage and grants no
automatic access, reporting scope, configuration, or programme authority. Participation changes
are effective-dated so they do not reinterpret historical offerings. Cross-unit academic
programmes use this programme-owned participation model rather than becoming institutional-tree
nodes or arbitrary affiliations. Sports and extracurricular programmes remain in a separate
activity domain even when they later reuse the same accountable-owner and typed-participation
pattern.

Where a course-like structure applies, the future learning model separates five meanings:

1. a stable course identity, such as one enduring catalogued course;
2. an approved course-specification revision containing formal outcomes, credits, prerequisites,
   and alignment meaning;
3. a course-design edition containing the reusable teaching design, such as unit sequence,
   resources, assessments, and pacing;
4. a course offering that makes one course available in an exact academic period and educational
   context while pinning the applicable specification revision and design edition; and
5. a class or section that records the actual learner group, assigned staff, timetable, and
   delivery context.

Several offerings or sections may deliberately reuse one published course-design edition, and a
new edition is required only when the shared teaching design changes. Preparing a later offering
defaults to one simple rollover action: reuse the current design, copy it into a new editable
draft, or start a new design. Draft changes autosave as mutable working state; a durable edition is
created only through a meaningful publication transition. Internal revision identifiers and
lineage remain available for governance without becoming routine form fields.

A course offering may have several sections. Each section has its own effective-dated teaching
team and may assign one or more staff members with explicit instructional responsibilities, such
as teacher of record, co-teacher, assistant, specialist, or substitute. Two sections using the
same course offering may have entirely different teaching teams and section adaptations, and one
staff member may participate in several sections. Instructional assignment is not a fixed tenant
role and grants no implicit programme, institutional-unit, reporting, or cross-section authority;
the owning module must authorize the exact tasks and effective dates independently.

A published course-design edition is the shared baseline rather than a live document silently
modified by one section. Assigned teaching staff may collaboratively adapt lessons, resources,
pacing, and permitted assessments for their section. Section changes remain section-specific by
default and cannot remove locked programme obligations. A teaching-team member may propose an
adaptation for the next shared edition, where the accountable curriculum owner accepts, revises,
or rejects it. An urgent offering-wide amendment is a separate authorized action that identifies
every affected section. The ordinary interface defaults to `this section only` and asks about
wider reuse only when relevant.

Co-teachers work in one institution-owned section plan rather than maintaining competing official
plans. The system attributes material contributions and meaningful transitions to the responsible
staff member and preserves the shared plan's history. A staff member may keep private working notes,
but those notes are not part of the official section plan unless explicitly contributed through an
authorized action. Ending or changing a teaching assignment removes future access according to its
effective date without deleting or transferring authorship of earlier contributions. Concurrent
editing must preserve both collaborators' work or require an explicit conflict resolution; it must
not silently apply last-write-wins behaviour.

Teaching-team labels such as teacher, co-teacher, assistant, specialist, or substitute may provide
simple institution-configured responsibility presets, but the labels are not tenant roles and do
not themselves grant authority. Each effective-dated assignment records the permitted section
tasks, including shared-plan editing, attendance, assessment creation or marking, publication,
result finalization, and family communication where applicable. The ordinary interface presents a
concise preset and responsibility summary while retaining explicit adjustment and audit detail.
Sensitive or final actions must be authorized from the assignment's current responsibilities and
cannot be inferred from its display label or from another section assignment.

The future enrolment boundary must distinguish programme admission or enrolment, course
registration, and section placement. Course registration records the learner's approved
participation in an exact course offering; section placement assigns that registration to a
delivery group and teaching team. A section move therefore preserves the course registration and
the learner's attributable work, attendance, results, and prior delivery context. The ordinary
interface may perform registration and initial placement as one guided action without collapsing
their meanings.

Request initiation is separate from approval authority. Depending on age, institution policy, and
context, a learner, verified guardian, authorized staff member, or approved integration may request
registration or placement. The applicable workflow may approve an eligible request automatically
or require consent, review, or institutional approval. A guardian acts through an explicit current
relationship and delegated purpose rather than impersonating the learner, and neither learner nor
guardian initiation bypasses eligibility, capacity, financial, safeguarding, or academic controls.

Eligibility rules attach to the meaning they govern. Programme-entry requirements govern admission
or programme enrolment; prerequisites, prior-course results, entry or placement assessments, and
progression rules ordinarily govern course registration or level placement. Section-specific rules
govern constraints such as capacity, timetable conflicts, site or modality, linked teaching groups,
accommodations, and any explicitly required instructor approval. A course-wide requirement must not
be copied into every section merely to make the workflow function. Every consequential decision
must identify the evaluated rule version, outcome, explanation, evidence, and any authorized
override. The later enrolment module owns request, consent, waitlist, add/drop, transfer, and
approval workflows; this proposal does not authorize a universal workflow engine or enrolment
implementation.

The future calendar and scheduling boundary must not collapse a shared academic year into one
tenant-wide teaching schedule. It separates at least four meanings:

1. an academic calendar and its named periods, holidays, closures, and significant dates;
2. effective-dated operating-day classifications, including learner instructional days, teacher
   working or professional-development days, examination days, and other locally governed day
   meanings;
3. a timetable scheme defining the cycle and bell or teaching periods, such as an eight-period
   two-week rotation or a six-period three-day rotation; and
4. the actual section meeting pattern, room or site, assigned resources, and dated exceptions.

These records may be explicitly adopted at the relevant educational context or institutional unit.
A primary division and a secondary division may share academic-year and holiday boundaries while
using different learner days, teacher days, timetable cycles, and teaching periods. Parentage may
offer an authorized default or adoption opportunity, but it never silently imposes or changes a
calendar or timetable. Course offerings and sections pin the applicable calendar and scheduling
versions for their effective dates; later changes do not reinterpret historical attendance,
instruction, workload, or results. Cross-unit programmes coordinate explicitly across participating
calendars and surface conflicts rather than inventing one inherited schedule. The calendar module
owns date meaning, while a later timetabling module owns allocation and conflict resolution.

The future assessment boundary separates a reusable assessment definition from its delivery in an
exact course offering or section, each learner's submission or attempt, attributable evaluation and
feedback, and any published official result. An assessment may come from the shared course design
or be created for one section without silently changing the shared design or another section.
Teaching-team members may create, mark, moderate, or comment only through their current assignment
responsibilities, and every material contribution remains attributable to its real actor.

Official results are institution-owned learner records rather than property of an individual
teacher. Publication or finalization requires an explicitly accountable staff member or governed
workflow; collaboration does not make every contributor a final approver. Formative feedback and
working marks remain distinguishable from official grades, credits, and transcript outcomes.
Moving a learner between sections, ending a staff assignment, or replacing a teacher preserves
prior submissions, attempts, feedback, marks, decision state, and authorship while changing future
access according to the effective assignment. Detailed grading, moderation, correction, appeal,
transcript, and qualification rules remain decisions for their owning modules.

A course offering may span one or several academic periods according to its explicit effective
dates; a term boundary does not close it implicitly. At its planned end, an authorized lifecycle
action closes the offering and its sections without overwriting or deleting them. Preparing a later
occurrence creates new offering and section identities with explicit lineage. A guided rollover may
propose reuse of the applicable course specification and design and may suggest prior learners,
teaching assignments, rooms, or schedules, but none of those operational assignments carries
forward silently.

Learner transfers and section moves preserve the original delivery context and history. Late work,
appeals, result corrections, and other permitted post-closure activity use named authorized actions
that preserve the original state and attributable change evidence. Closed offerings are excluded
from ordinary current-work views by default while remaining available to authorized historical,
records, correction, and audit workflows. The later enrolment, assessment, calendar, timetabling,
and records modules define their exact closure responsibilities rather than relying on one generic
cascade.

This five-layer structure is not universal. Early-years, inquiry-based, project-based, or other
learning contexts may connect programme curriculum, units, and class delivery without inventing a
catalogued course. Interoperability models remain mappings at the boundary and cannot force their
course or class shapes into contexts where those meanings do not exist.

For a group operating several schools, an explicitly authorized central academic team may publish
a versioned curriculum template. Each school explicitly adopts or forks that template into its
locally owned curriculum version and may retain approved differences. Central updates produce a
comparison and selective adoption opportunity; they never overwrite a school's published or draft
curriculum. The system preserves which material was adopted unchanged, overridden, added, retired,
or left out of alignment, together with the local history.

Traceability must not make ordinary planning bureaucratic. The default lesson-planning path is:

1. derive the applicable programme offering, local curriculum, external specification, and
   effective versions from the selected class, course, institutional context, and lesson date;
2. let the teacher begin writing immediately, with relevant outcomes and standards suggested from
   that context rather than presented as a long mandatory checklist;
3. autosave mutable working drafts without creating a formal curriculum version for every edit;
4. create durable versions only at meaningful publication, submission, or explicit checkpoint
   transitions; and
5. keep alignment detail, provenance, comparison, and override controls available through
   progressive disclosure.

When context is ambiguous, Chimwemwe must not silently choose an official curriculum or external
version. The user may begin an `alignment pending` draft, but that draft cannot be published or
counted in official curriculum-coverage or compliance reporting until the ambiguity is resolved.
External or central updates appear as concise review notices; they never interrupt writing or
silently reinterpret an existing plan.

The governing experience principle is: capture governance from trusted context wherever possible
rather than demanding form-filling. Drafting starts immediately; formal publication and compliance
claims require resolved alignment. This section records future product requirements only. It does
not add curriculum, programme, course, lesson, assessment, compliance, or reporting scope to Phase
2.1.

**Consolidated product disposition — approved.** On 2026-09-27, François, as Project Owner,
approved the future programme, curriculum, course, offering, section, teaching-team, enrolment
boundary, calendar/scheduling, assessment-ownership, and closure/rollover direction recorded in
this section. The approval fixes the product meanings and usability principles for later module
design; it does not authorize those modules, accept their detailed workflows, expand Slice 2.1, or
substitute for ADR 0025's representative and accountable review gates. Each owning module must
still define and validate its named actions, authorization, temporal semantics, data policy,
interfaces, and executable evidence before implementation or production use.

## Recommended implementation order after this proposal

1. Record the project-owner authorization for this bounded sequence.
2. Produce the Slice 2.0-A entry decision register.
3. Close 2.0-B and 2.0-C while 2.1-A runs as research and decision work.
4. Accept ADR 0025 and record that 2.1-B's entry conditions are satisfied before the first
   persisted module slice begins.
5. Add 2.1-C, 2.1-D, and 2.1-E only after each prior slice is green and reviewed.
6. Qualify 2.1-F against the real operational lifecycle.
7. Complete 2.0-D and 2.0-E before connecting 2.1-G.
8. Permit 2.1-H only after the L3 deployment, review, support, recovery, and data-class gates pass.

The next likely module after institutional structure is academic calendar because later domains
need stable institutional and period references. ADR 0021 contains useful bounded calendar
evidence, but its former `school_scope_id` and single-school framing require revision against ADR
0025 before acceptance. This sequencing neither accepts ADR 0021 nor authorizes a calendar
implementation.
