# ADR 0025: Learning-institution operating system and recursive institutional structure

- Status: Proposed
- Date: 2026-09-26
- Product direction: Approved by François — Project Owner on 2026-09-26
- Accountable owner: Product and institutional-structure domain ownership
- Deciders: Product owner, architecture review group, platform engineering, security/privacy,
  and representative learning-institution domain owners
- Supersedes: None

## Context

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

The product needs multi-entity operation comparable in purpose to multi-company structures in
Odoo or Frappe, without importing their schemas, permission semantics, implicit defaults, or
hierarchy inheritance. The tenant remains the security, placement, and governed operator boundary;
the institutional hierarchy is tenant-owned domain structure inside that boundary.

This record captures the product direction and proposes the durable institutional-structure
boundary. It does not authorize a production resource, migration, module, public interface, or
real data.

## Decision drivers

- Support learning institutions across age ranges and institutional forms without a school-first
  hierarchy or fixed depth.
- Give every institution and nested unit a stable identity that survives renaming, movement, and
  reorganization.
- Represent canonical organizational containment without turning the hierarchy into a universal
  graph or a permission engine.
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
2. Use a tenant-owned recursive `InstitutionalUnit` hierarchy, with separate typed relationships
   for sites, affiliations, authorization, reporting, and configuration. This is the proposed
   option.
3. Use one arbitrary many-parent organization graph for containment, campuses, programmes,
   reporting, configuration, and permissions. This is flexible but makes cycles, authority,
   inheritance, history, and user explanations unsafe and ambiguous.
4. Treat every nested school, department, or division as a separate tenant. This confuses the
   institutional model with security and deployment placement and prevents coherent shared
   operation inside one governed tenant.

## Decision

Propose option 2 for accountable review and later bounded implementation.

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

### Tenant and institutional hierarchy

The tenant is the governed operator, security, placement, and lifecycle boundary. A tenant owns
zero or more root institutional units. It is not necessary to create a synthetic `All
Organizations` hierarchy node, and an institutional unit cannot cross tenants.

`InstitutionalUnit` is the stable recursive domain identity for a learning institution or a
structurally meaningful unit within one. Representative examples include a university, college,
school, faculty, department, kindergarten division, middle-school division, or high-school
division. Examples do not define a fixed type enumeration or permitted depth; Slice 2.1-A must
settle the smallest code-owned classification and tenant-controlled terminology needed by the
representative scenarios.

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

The stable cross-module structural reference is an `institutional_unit_id` or a more specific
domain-owned reference to an institutional unit. `school_scope_id` is not the general platform
contract.

### Named actions and lifecycle

The exact public vocabulary remains evidence-gated, but the structure boundary is expected to use
named outcomes equivalent to:

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
- Stable unit identities survive reorganizations and give later modules precise references.
- Sites and cross-cutting affiliations remain expressive without weakening the canonical tree.
- Authorization, reporting, and configuration behavior stay explicit and reviewable.
- Product language can adapt to local institutional terminology without hard-coded roles or fixed
  hierarchy levels.

### Negative

- Recursive containment, cycle prevention, moves, historical parentage, and bounded traversal add
  more design and test work than a flat school table.
- A strict single-parent canonical hierarchy cannot itself express every matrix organization;
  approved affiliations need a separate contract and user experience.
- Reorganization requires impact analysis across explicit scope grants, configuration adoptions,
  reports, integrations, and retained downstream records.
- Exact-unit and descendant-scope experiences need careful navigation and non-enumerating query
  contracts for sensitive records.

## Security, privacy, operability, and migration effects

Every unit, profile revision, parentage, affiliation, site association, action, event, job, cache
key, projection, import mapping, and telemetry record is tenant-qualified. Compound constraints
reject cross-tenant relationships. Database constraints and serialized writes prevent direct,
indirect, and concurrent hierarchy cycles.

An actor's knowledge of a unit identifier, visibility of an ancestor, or permission on a parent
does not reveal a child or authorize descendant data. Errors remain non-disclosing. Reads expose
only the exact unit or bounded structure needed by the named task; a recursive endpoint cannot
become an undeclared bulk enumeration path.

Reparenting can change the population reachable by an explicitly authorized descendant scope,
report, or integration. The action therefore uses the authoritative writer, evaluates registered
impacts, records the exact before-and-after parentage, and blocks when a dependent contract cannot
reconcile safely. Events carry stable identifiers and minimal change facts, not complete trees,
names, addresses, or translated labels.

Migration from Odoo, Frappe, or another source preserves source identifiers and hierarchy evidence
in a migration ledger. It reports duplicate or missing parents, cycles, cross-tenant links,
ambiguous roots, invalid types, path-dependent codes, sites represented as organizations,
implicit access inheritance, and unresolved matrix relationships. Migration never converts a
source parent link into an access grant or invents history that the source cannot prove.

## Validation evidence

Current evidence is the project owner's product direction, the existing tenant and authority
contracts, and the Phase 2 candidate review. It establishes the need to replace the flat school
boundary but does not prove a physical model or authorize persistence.

Acceptance requires at least these synthetic scenarios:

1. one independent kindergarten at one site;
2. one combined school containing kindergarten, middle-school, and high-school units;
3. one university containing several schools or faculties and nested departments;
4. one tenant operating several independent institutional roots with a shared site;
5. one unit renamed, moved, and later closed while stable references and history remain valid;
6. one cross-cutting programme or service represented without giving a unit two canonical parents;
7. invalid cross-tenant parentage plus direct, indirect, and concurrent cycle attempts; and
8. proof that creating or moving a unit does not grant access, activate a module, change placement,
   widen a report, or apply parent configuration implicitly.

The review must also include representative domain owners from materially different learning
institutions, a browser hierarchy-navigation prototype, bounded traversal and accessibility
evidence, migration fixtures, and the relevant threat-model negatives. Planned evidence does not
accept this ADR or authorize Slice 2.1-B.

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
