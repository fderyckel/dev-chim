# ADR 0025: Learning-institution operating system with separated corporate/legal and educational structure

- Status: Conditionally Accepted
- Date: 2026-09-26
- Product direction: Approved by François — Project Owner on 2026-09-26, refined through the
  linked-structure review, and conditionally accepted for bounded synthetic implementation on
  2026-09-27
- Next condition review: 2026-12-15, or before the first connected/public institutional-structure
  workflow, whichever is earlier
- Accountable owner: Product, corporate/legal-structure, and educational-structure domain ownership
- Deciders: Product owner, architecture review group, platform engineering, security/privacy,
  corporate governance/finance domain ownership, and representative learning-institution domain
  owners
- Supersedes: None
- Partially superseded by: [ADR 0032](0032-c25-02-delegated-contract-acceptance.md), which closes C25-02 through explicit delegated Project Owner review; the original decision below is retained as history and C25-03 through C25-06 remain binding

- Additional partial supersession: [ADR 0034](0034-c25-03-delegated-educational-structure-acceptance.md) closes C25-03 for synthetic L1 through delegated review; external representative validation remains C25-03-R and C25-04 through C25-06 remain binding

## Context

Current supersession notice: [ADR 0035](0035-c25-04-delegated-primary-operator-acceptance.md)
closes C25-04 for synthetic L1 and settles its operator controls and deadlines. The original
decision below is retained; C25-03-R, C25-05/C25-06 and existing external adoption gates remain.

Chimwemwe is an operating system for learning institutions. It is intended for kindergartens,
primary and secondary schools, combined schools, colleges, community colleges, universities, and
other governed learning environments. These are first-class product contexts, not later extensions
of a single-school or K-12 model.

The learner and the learner's changing learning context remain central regardless of age. A
learner may participate through several institutional units over time; `student`, `learner`,
`guardian`, `teacher`, `lecturer`, and similar terms describe contextual relationships or local
vocabulary, not permanent person types or production authorization roles.

Learning institutions are also structurally recursive. A university may contain schools,
faculties, colleges, and departments. A combined school may contain kindergarten, middle-school,
and high-school units. A tenant may operate several independent roots, and the word `school` may
describe a root institution or a nested unit. The Phase 2 candidate based on a flat `School`
aggregate plus optional relationships cannot represent those cases as a core invariant.

The product needs multi-entity operation comparable in purpose to established multi-company
systems, without importing source schemas, permission semantics, implicit defaults, or hierarchy
inheritance. The tenant remains the security, placement, lifecycle, and data boundary; accountable
legal operation belongs to an explicit legal entity. Both structures are tenant-owned domain data
inside that boundary.

The review identified a second independent structure. A tenant may contain several registered
legal entities and internal corporate units as well as educational institutions and units. Legal
ownership or control may be a graph, including joint ownership, while one optional consolidation
parent supplies a bounded reporting and navigation tree. Corporate units may nest but belong to an
exact legal entity. Educational institutions require an effective primary legal operator, yet
legal ownership, property ownership, employment, governance, funding, data-control responsibility,
and educational parentage can legitimately point to different entities. Collapsing those meanings
into the educational tree would make finance, accountability, reorganization, and authority
ambiguous.

This record captures the product direction and proposes the durable linked corporate/legal and
educational-structure boundary. It does not authorize a production resource, migration, module,
public interface, or real data.

## Decision drivers

- Support learning institutions across age ranges and institutional forms without a school-first
  hierarchy or fixed depth.
- Give every institution and nested unit a stable identity that survives renaming, movement, and
  reorganization.
- Represent canonical organizational containment without turning the hierarchy into a universal
  graph or a permission engine.
- Distinguish legal entities from internal corporate units and both from educational institutions
  and educational units.
- Preserve one effective primary legal operator per educational institution while allowing other
  typed legal relationships and non-tree ownership/control.
- Keep physical and virtual sites, academic affiliations, authorization scope, reporting scope,
  configuration adoption, and tenant placement distinct.
- Let future learning, enrolment, calendar, assessment, finance, and reporting modules reference
  exact institutional units rather than names or hierarchy paths.
- Preserve named actions, tenant isolation, explainable history, recovery, and reversible
  implementation slices.

## Considered options

1. Keep one flat `School` aggregate and add typed relationships only when needed. This preserves a
   small first schema but treats required containment as optional metadata and cannot provide a
   reliable nested scope to downstream modules.
2. Use separate tenant-owned corporate/legal and educational structures, connect them through
   explicit effective-dated legal-responsibility relationships, and retain separate typed
   relationships for sites, affiliations, authorization, reporting, and configuration. This is
   the proposed option.
3. Use one arbitrary many-parent organization graph for containment, campuses, programmes,
   reporting, configuration, and permissions. This is flexible but makes cycles, authority,
   inheritance, history, and user explanations unsafe and ambiguous.
4. Treat every nested school, department, or division as a separate tenant. This confuses the
   institutional model with security and deployment placement and prevents coherent shared
   operation inside one governed tenant.

## Decision

Propose option 2 for accountable review and later bounded implementation, with the corporate/legal
module preceding the educational-structure module.

### Product and learner boundary

The governing product definition is:

> Chimwemwe is an operating system for learning institutions.

The platform foundation supplies trusted identity and tenant context, authority, module lifecycle,
named actions, durable evidence, integration contracts, reporting boundaries, and shared human
experience contracts. Bounded modules supply institution and learning-domain behaviour.

No module may assume that a learner is a child, that a guardian relationship always exists, that a
school is the tenant root, or that a university is merely a larger school. Age, legal capacity,
safeguarding, guardianship, programme participation, and learning relationships require their own
explicit domain facts and policies when those modules enter scope.

### Tenant and corporate/legal structure

The tenant is the security, placement, lifecycle, and data boundary. It owns zero or more legal
entities and educational institutions but is not itself assumed to be a legal person, holding
company, school group, or educational root.

`LegalEntity` is the stable identity for a registered company, trust, foundation, public body, or
other legally accountable organization. A registration, jurisdiction, name, status, relationship,
or consolidation change does not replace its tenant-qualified opaque UUID. Legal ownership and
control use effective-dated, code-owned typed relationships. There is no generic
`ownership_or_control` relationship: each accepted type defines its endpoint kinds, cardinality,
attributes, evidence, cycle policy, and explicit non-effects. They may form a graph where joint or
multiple ownership is legitimate. There is no universal ownership-graph cycle rule and no
transitive ownership, control, authorization, or reporting inference; a relationship type may
allow a cycle only when its reviewed contract says so. One optional primary consolidation parent
may supply a bounded navigation and financial-reporting tree, but it remains a separate
single-parent acyclic meaning and does not erase other relationships, prove legal ownership,
grant authority, or become tenant placement.

`CorporateUnit` is a separately identified internal structure such as a regional office, finance
department, shared-service centre, or operating division. Corporate units may use canonical
same-tenant parentage only when parent and child belong to the same effective legal entity. Every
published corporate unit belongs to one exact legal entity and cannot be the primary legal
operator of an educational institution. Cross-legal-entity management, coordination, or shared
services use an explicitly reviewed typed relationship rather than corporate parentage. A change
of corporate parent or legal-entity membership preserves identity and history and requires
registered-impact review; a legal-entity transfer must reconcile any parentage that would cross
that boundary.

Every published educational institution has exactly one active primary legal operator at any
given institution-local effective date through an explicit relationship. The v1 interval uses the
institution's stored IANA time zone with an inclusive start and exclusive end date; the
authoritative writer records approval and commit time separately as UTC `recorded_at`. A source or
jurisdiction requiring legally significant time-of-day precision remains unresolved until an
instant-precision extension is reviewed rather than being rounded to a date. Additional typed
legal responsibilities, including governance, employment, property, funding, contracting, and
data-control responsibility, may coexist and may name different legal entities. An ordinary
educational unit is covered through its containing institution. If a contained school or college
has distinct legal accountability, it is an educational institution with its own operator
relationship rather than an educational unit with a misleading label. Draft or migration records
may be unresolved, but cannot be published or receive real operational records until legal
accountability resolves exactly.

Initial primary-operator assignment while an institution remains unpublished is a single named
action for one appropriately authorized actor. Changing the operator of a published institution
is instead a proposal followed by approval from a different appropriately authorized actor by
default. A tenant with only one qualified controller may use an explicit single-controller
exception, but the writer requires stronger actor assurance, a recorded reason and evidence
reference, a visible exception marker, and a mandatory retrospective review. The exception never
becomes an implicit downgrade of the ordinary two-person control. Assignment and transfer both
retain exact expected versions, idempotency, an impact preview, minimized audit evidence, and a
transactional outbox fact; a transfer does not rewrite downstream records.

The structure domain stores only the structured evidence metadata needed to establish and verify
operator accountability: evidence type, issuer or source, protected reference, applicable dates,
verification actor and time, and information classification. It does not become a duplicate legal
document store. Full documents remain in an approved records system or secure repository under
their own access, retention, legal-hold, export, and deletion rules. An unpublished draft may carry
pending evidence, but publication requires verified initial-operator evidence and a published
transfer cannot take effect until its evidence is verified. Audit and outbox records contain the
minimum reference and outcome facts, never embedded sensitive documents.

Approval of a future-effective operator transfer does not guarantee later activation. At the
effective boundary, the authoritative writer revalidates evidence under its type- and
jurisdiction-owned freshness policy, both legal entities' applicable status, the proposal and
approvals, the expected versions, and every registered impact. Missing, revoked, inaccessible, or
stale input blocks activation rather than relying on an arbitrary platform-wide expiry period. A
revocation discovered after a transfer took effect does not rewrite the historical interval; it
opens a high-priority reconciliation case for separately authorized resolution.

That reconciliation places the institution in a distinct **legal accountability under review**
condition; it does not silently treat the evidence as valid, replace the operator, or close or
unpublish the institution. The condition identifies the disputed evidence, alerts accountable
administrators, and uses explicit type- and jurisdiction-owned policy to block new actions that
depend on verified operator standing. Essential teaching, safeguarding, attendance, and learner
support may continue unless applicable policy requires suspension. Unknown action classification
fails closed. The policy also owns a resolution deadline and escalation; expiry never invents,
deletes, or substitutes an operator. This condition is separate from institution lifecycle,
module activation, actor authorization, and the historical operator relationship.

The under-review condition has no generic dismissal action. It resolves only by reverifying the
current operator, completing an approved transfer to a verified successor, correcting a factually
wrong historical record under ADR 0018 without erasing history, or applying a separately
authorized institution suspension or closure. A legally accountable interim organization uses
the ordinary time-bounded primary-operator relationship. An appointed natural person acting as an
administrator, trustee, or representative is recorded through the appropriate person and
authority contract and is not misclassified as a legal entity.

The corporate/legal module precedes the educational-structure module. Neither legal relationships,
corporate parentage, consolidation, nor an operator link grants a capability, selects tenant
placement, activates a module, exposes a report, or creates an educational parent.

### Educational hierarchy

The tenant owns zero or more root institutional units. It is not necessary to create a synthetic `All
Organizations` hierarchy node, and an institutional unit cannot cross tenants.

`InstitutionalUnit` is the stable recursive physical-model candidate for an educational
institution or a structurally meaningful educational unit within one. `institution` and
`organizational_unit` are code-owned classifications with distinct meaning, not merely display
labels. Representative institutions include universities, colleges, and schools. Representative
educational units include faculties, departments, kindergarten divisions, primary divisions,
middle-school divisions, and high-school divisions. Local terminology does not create a new class
or change legal accountability. A contained institution may have an educational parent while
retaining its own legal operator.

Each unit has an opaque immutable UUID. Names, codes, local type labels, status, default time zone,
and other profile meaning change through named and attributable actions without replacing that
identity. Downstream records reference the UUID, never a display name, code, materialized path, or
current ancestor.

Canonical organizational containment forms a tenant-local forest:

- a unit has zero or one active canonical parent at a time;
- a parent may contain any number of child units;
- there is no fixed maximum depth or required sequence of unit types;
- parent and child must belong to the same tenant;
- direct, indirect, and racing cycles are rejected on every write path; and
- closing, moving, or revising a unit preserves its identity and attributable history.

The domain contract should use an effective-dated, tenant-qualified parentage record when the
accepted scenarios require historical reorganization. The physical implementation may use an
adjacency list plus a disposable path or closure projection for efficient traversal. Any such
projection is rebuildable and cannot become an independent hierarchy authority.

An institutional unit may have only one canonical parent at a time. Legitimate matrix structures,
joint programmes, shared services, accreditation links, and other cross-cutting associations use
separately owned, typed `InstitutionalAffiliation` records. Adding those relationships does not
turn the canonical hierarchy into an arbitrary directed graph.

### Separate meanings that hierarchy cannot imply

Canonical parentage records organizational containment only. It does not by itself:

- grant a capability or record access;
- create or change a legal entity, corporate unit, primary legal operator, ownership, control,
  consolidation, employment, property, funding, contracting, or data-control responsibility;
- select an active tenant, database, cell, queue, cache, storage, or analytics placement;
- activate or entitle a module;
- make the parent or child a physical or virtual site;
- confer academic ownership, enrolment, employment, guardianship, or programme membership;
- aggregate reports or expose descendant data;
- copy branding, terminology, calendars, configuration, or policy; or
- make a parent responsible for a child's retained records or legal obligations.

Future access-scope grants must explicitly distinguish one exact unit from an allowed descendant
scope. Until that contract is accepted and implemented, hierarchy grants no access. If descendant
scope is later allowed, every reparenting action must calculate and expose its authorization
impact, re-evaluate current grants on the authoritative writer, and fail closed rather than
silently widening access.

Reporting roll-up is a separately authorized dataset contract. A selected parent can be an input
to a code-owned descendant expansion only after the actor is authorized for the resulting scope;
the tree itself is not report authority.

Configuration, terminology, branding, and calendar reuse use explicit, versioned adoption or a
separately accepted inheritance contract with visible provenance. A child never follows a live
parent change silently. Tenant selection and an active institutional-unit selector in a client are
context and usability controls only; the server validates them and they never grant authority.

### Sites and learning contexts

`Site` remains a separate stable identity for a physical or virtual place. A unit may operate at
several sites, and a site may serve several units through effective-dated associations. Neither a
site nor a site association is an institutional parent, academic scope, authorization scope, or
tenant placement.

Later person, learning, programme, enrolment, and delivery modules may need several distinct unit
references. For example, a learner may be admitted by a university, enrolled in a programme owned
by one school, take a module delivered by another department, and attend at a shared site. Those
modules must name the meaning of each reference instead of overloading one `school_scope_id`.

Finance, employment, property, contract, and regulatory modules similarly reference the exact
legal entity or corporate unit whose responsibility they mean. They do not infer that identity from
an educational ancestor. Educational reporting follows explicit educational ownership; legal or
financial consolidation follows explicit legal relationships and the applicable approved reporting
contract.

The stable cross-module structural reference is an `institutional_unit_id` or a more specific
domain-owned reference to an institutional unit. `school_scope_id` is not the general platform
contract.

### Named actions and lifecycle

The exact public vocabulary remains evidence-gated, but the structure boundary is expected to use
named outcomes equivalent to:

- register, revise, and close a legal entity;
- establish or end an approved legal-entity relationship and select an optional primary
  consolidation parent without erasing other relationships;
- register, revise, place, move, and close a corporate unit;
- assign an unpublished educational institution's initial primary legal operator;
- propose and separately approve a published institution's primary-operator transfer, or invoke
  the explicit reviewed single-controller exception; and
- manage other accepted typed legal responsibilities;
- register a root or child institutional unit;
- revise an institutional-unit profile;
- place a unit under an exact parent;
- preview and perform a governed unit move;
- close or supersede a unit without erasing retained references;
- associate or end association with a site; and
- establish or end an approved cross-cutting affiliation.

Moves, closure, and other durable structural changes require trusted actor and tenant context,
separate capabilities, exact expected versions, idempotency where replay is possible, cycle and
cross-tenant checks, minimized audit evidence, and a transactional outbox fact. They must surface
effects on explicit access scopes, configuration adoptions, report definitions, module data, and
downstream references before commit; an unclassified impact blocks the action.

## Consequences

### Positive

- The same product model supports a standalone kindergarten, a combined school, a college group,
  and a university with nested schools and departments.
- Separate legal and educational identities support groups, shared services, operator transfers,
  joint ownership, property separation, and financial consolidation without corrupting the
  educational hierarchy.
- Stable unit identities survive reorganizations and give later modules precise references.
- Sites and cross-cutting affiliations remain expressive without weakening the canonical tree.
- Authorization, reporting, and configuration behavior stay explicit and reviewable.
- Product language can adapt to local institutional terminology without hard-coded roles or fixed
  hierarchy levels.

### Negative

- Recursive containment, cycle prevention, moves, historical parentage, and bounded traversal add
  more design and test work than a flat school table.
- Two linked modules and several typed responsibility relationships require more explicit setup,
  migration reconciliation, and cross-module lifecycle handling than one universal organization
  tree.
- A strict single-parent canonical hierarchy cannot itself express every matrix organization;
  approved affiliations need a separate contract and user experience.
- Reorganization requires impact analysis across explicit scope grants, configuration adoptions,
  reports, integrations, and retained downstream records.
- Exact-unit and descendant-scope experiences need careful navigation and non-enumerating query
  contracts for sensitive records.

## Security, privacy, operability, and migration effects

Every legal entity, corporate unit, institutional unit, profile revision, parentage, legal
responsibility, affiliation, site association, action, event, job, cache key, projection, import
mapping, and telemetry record is tenant-qualified. Compound constraints reject cross-tenant
relationships. Database constraints and serialized writes prevent direct, indirect, and concurrent
cycles in every relationship type declared acyclic.

An actor's knowledge of a unit identifier, visibility of an ancestor, or permission on a parent
does not reveal a child or authorize descendant data. Errors remain non-disclosing. Reads expose
only the exact unit or bounded structure needed by the named task; a recursive endpoint cannot
become an undeclared bulk enumeration path.

Reparenting, consolidation changes, and primary-operator changes can alter the population relevant
to an explicitly authorized scope, report, workflow, finance process, or integration. The action
therefore uses the authoritative writer, evaluates registered impacts, records exact before-and-
after relationships, and blocks when a dependent contract cannot reconcile safely. Events carry
stable identifiers and minimal change facts, not complete trees, names, addresses, registrations,
ownership percentages, or translated labels.

Migration from any source system preserves source identifiers and relationship evidence
in a migration ledger. It reports duplicate or missing parents, cycles, cross-tenant links,
ambiguous roots, invalid types, path-dependent codes, sites represented as organizations,
implicit access inheritance, and unresolved matrix relationships. Migration never converts a
source company into both a legal entity and educational institution without explicit evidence,
converts a source parent link into an access grant, or invents history that the source cannot prove.

## Validation evidence

Current evidence includes the project owner's original and refined linked-structure direction, the
existing tenant and authority contracts, and the Phase 2 candidate review. The
[institutional-structure decision evidence plan](../phase-2/institutional-structure-decision-evidence.md)
defines the six approval gates. Its linked
[scenario and vocabulary walkthrough](../phase-2/institutional-structure-scenario-review.md),
[linked-structure scenario addendum](../phase-2/linked-structure-scenario-addendum.md),
[security/migration/temporal review](../phase-2/institutional-structure-security-migration-review.md),
[linked-structure security and migration addendum](../phase-2/linked-structure-security-migration-addendum.md),
and [read-only experience evidence](../phase-2/institutional-structure-experience-evidence.md)
prepare the complete technical G1, G3, and G4 evidence. The refreshed linked read-only prototype
supplies current-contract structure-navigation evidence, while the
[internal readiness challenge](../phase-2/institutional-structure-internal-readiness-review.md)
records the amended operator-governance and five-context findings and their technical closure.
All named accountable and representative reviews remain open; the
[review packet](../phase-2/institutional-structure-review-packet.md) is prepared.

Those artifacts do not approve themselves. The named accountable reviews are still open and no
representative-institution review is recorded for G2. On 2026-09-27, François, as Project Owner and
interim Security/Privacy Owner for synthetic work, nevertheless recorded the bounded G6 decision
to **Conditionally Accept ADR 0025**. The decision accepts the logical direction and the recorded
residual risks only within the fail-closed conditions below; it does not relabel an open review as
complete or claim that a physical model has passed its slice-specific evidence.

The separately authorized
[minimal Slice 2.1-B evidence](../phase-2/legal-entity-foundation-evidence.md) now supplies the
first physical proof under C25-01: a tenant-qualified stable `LegalEntity`, immutable name-profile
revisions, the two named actions, one exact read, and executable lifecycle, authority,
concurrency, idempotency, audit, outbox, rollback, and alternate-write checks. That proof does not
close any named review or authorize C25-02 through C25-06 work.

On 2026-09-28, François, as Project Owner, conditionally approved Phase 2.0 at its completed L1
foundation boundary and accepted Slice 2.0-E as a time-bounded deferred condition. The outstanding
expert/representative comprehension and accountable product-experience disposition must be
reviewed by 2026-12-15 or before the first connected/public institutional-structure workflow,
whichever is earlier. This decision closes Phase 2.0 for planning purposes; it does not satisfy
C25-05, authorize the connected workflow, or turn the absence of a review into approval. A missed
date requires an explicit condition review and renewal, amendment, or withdrawal.

Acceptance requires at least these synthetic scenarios:

1. one independent kindergarten at one site;
2. one standalone primary or early-years institution;
3. one standalone secondary institution;
4. one combined school containing kindergarten, middle-school, and high-school units;
5. one university containing several schools or faculties and nested departments;
6. one tenant operating several independent institutional roots with a shared site;
7. one unit renamed, moved, and later closed while stable references and history remain valid;
8. one cross-cutting programme or service represented without giving a unit two canonical parents;
9. invalid cross-tenant parentage plus direct, indirect, and concurrent cycle attempts;
10. proof that creating or moving a unit does not grant access, activate a module, change placement,
    widen a report, or apply parent configuration implicitly; and
11. nested legal entities, multiple ownership, an optional primary consolidation parent, nested
   corporate units, institutions sharing an operator, a contained institution with its own
   operator, distinct property/employment relationships, and an effective operator transfer.

The conditional review programme still includes representative domain owners from materially
different learning institutions, corporate governance/finance review, a browser linked-hierarchy
navigation prototype, bounded traversal and accessibility evidence, migration fixtures, and the
relevant threat-model negatives. These are now explicit slice and release conditions rather than
claims of completed review.

## Conditional acceptance disposition

The conditional acceptance settles the stable logical direction and makes only the separately
authorized, minimal Slice 2.1-B synthetic `LegalEntity` aggregate eligible for a recorded entry
decision. It does not authorize real institutional data, migration, a public interface, connected
identity, a pilot, deployment, or production release.

Phase 2.0 is conditionally approved at L1 with C25-05 carried as a dated residual condition through
2026-12-15 or the first affected connected/public gate, whichever is earlier. Conditional approval
does not waive any condition below.

The following conditions are binding:

1. **C25-01 — minimal reversible L1 start.** Slice 2.1-B is limited to the synthetic module
   declaration, stable tenant-qualified `LegalEntity` identity, smallest justified profile/history,
   the two named actions and exact read in the Phase 2 plan. It must pass its own migration,
   authorization, tenant-isolation, concurrency, idempotency, audit, outbox, rollback, lifecycle,
   and complete repository gates.
2. **C25-02 — legal relationships and corporate units.** Before Slice 2.1-C persists relationship
   types, consolidation parentage, or corporate units, a named corporate governance/finance
   disposition must settle each first-slice type's endpoints, cardinality, attributes, evidence,
   cycle policy, jurisdictional/accounting meaning, and non-inference rules.
3. **C25-03 — educational structures.** Before Slices 2.1-D or 2.1-E persist educational
   institutions, units, parentage, sites, terminology, or affiliations, the five representative
   operating perspectives and educational-structure domain disposition must be recorded. A finding
   that challenges tenant ownership, stable identity, one canonical educational parent, exact
   primary legal operation, or structure's non-authority rule requires this ADR to be revised or
   superseded before that slice expands.
4. **C25-04 — primary-operator workflow.** Before operator assignment or transfer is persistent,
   the applicable review must settle evidence types and freshness ownership, records boundary,
   normal approval and single-controller exception controls, effective-boundary activation,
   post-effect reconciliation ownership and response time, continuity policy, and resolution paths.
5. **C25-05 — experience and public boundary.** Before Slice 2.1-G or any connected public
   structure workflow, the refreshed prototype, bounded-read design, accessibility checks,
   representative comprehension, product-experience disposition, and applicable security/platform
   review must pass. A hierarchy view remains neither an authority surface nor a bulk-enumeration
   endpoint.
6. **C25-06 — real data and deployment.** Before migration or an L3 pilot, name the selected
   deployment, independent security/privacy reviewer, and learning-institution-side records owner;
   approve classification, retention, legal hold, export, correction, erasure, recovery, support,
   and operating policies; and close every lower-level gate.

The five representative perspectives may be covered by fewer than five people only when each
record names the reviewer's current or recent experience for every context covered. One qualified
person may also cover more than one specialist perspective, but product ownership or document
authorship alone is not evidence of that qualification. No reviewer or completed finding may be
invented.

## Fallback and exit cost

If a recursive unit model proves too broad, retain stable institutional-unit identities and limit
the first implementation to the unit types and parentage scenarios that passed review. If matrix
relationships need richer behavior, add typed affiliations through a later ADR rather than
weakening the canonical tree.

The logical contract does not require one hierarchy storage optimization. An adjacency list,
closure table, or materialized path may be replaced after measured query and move evidence, as
long as the canonical parentage, stable identifiers, history, tenant constraints, and named-action
contract remain unchanged.

Before production data, exit cost is documentation and prototypes. After adoption, changing
identity or parentage semantics requires expand-and-contract migration, path/projection rebuild,
downstream reference reconciliation, access/report impact review, and retained-history proof.

## Review triggers

- A representative institution requires several simultaneous canonical parents for one unit.
- A representative legal structure cannot express joint ownership, consolidation, corporate
  units, or a change of primary legal operator without changing a stable identity.
- A hierarchy move would silently change access, reporting, configuration, placement, or retained
  record ownership.
- A programme, cohort, course, site, legal entity, or external partner is proposed as an untyped
  institutional unit only to reuse the tree.
- The first migration cannot distinguish organizational units, physical sites, and access scopes.
- Recursive reads cannot meet bounded-query, non-enumeration, accessibility, or performance
  requirements.
- A proposed module assumes a fixed school root, fixed institutional depth, learner age, guardian
  relationship, or one universal academic calendar.

## Related records

- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [Institutional-structure decision evidence plan](../phase-2/institutional-structure-decision-evidence.md)
- [Institutional-structure scenario and vocabulary review](../phase-2/institutional-structure-scenario-review.md)
- [Linked-structure scenario addendum](../phase-2/linked-structure-scenario-addendum.md)
- [Institutional-structure security, migration, and temporal review](../phase-2/institutional-structure-security-migration-review.md)
- [Linked-structure security and migration addendum](../phase-2/linked-structure-security-migration-addendum.md)
- [Institutional-structure experience evidence](../phase-2/institutional-structure-experience-evidence.md)
- [Internal readiness challenge](../phase-2/institutional-structure-internal-readiness-review.md)
- [Representative and accountable review packet](../phase-2/institutional-structure-review-packet.md)
- [Slice 2.1-B minimal legal-entity foundation evidence](../phase-2/legal-entity-foundation-evidence.md)
- [System context](../architecture/system-context.md)
- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0024](0024-assurance-proportionality-and-module-evolution.md)
- [Threat model](../security/threat-model.md)
