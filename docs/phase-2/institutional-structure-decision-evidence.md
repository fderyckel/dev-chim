# Institutional-structure decision evidence plan

- Status: ADR 0025 conditionally accepted for bounded synthetic implementation; technical G5 is
  ready and named reviews remain binding slice/release conditions
- Date: 2026-09-27
- Accountable owner: Product, corporate governance/finance, and educational-structure domain
  ownership
- Decision record: [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- Gate: Slice 2.1-A conditionally closed; minimal Slice 2.1-B entry and L1 proof complete under
  C25-01

## Purpose and current disposition

This plan records the evidence and review programme that moved ADR 0025 from **Proposed** to
**Conditionally Accepted**. It converts the ADR's acceptance paragraph into a reviewable decision
package without treating planned scenarios, a prototype, an owner role, or an open review as
completed evidence.

The decision under review is the linked logical structure contract: stable tenant-owned legal
entities, corporate units, educational institutions and educational units; explicit primary legal
operation; separate legal/corporate and educational relationships; separate sites and affiliations;
explicit history; and strict separation of every hierarchy or relationship from authority,
reporting, configuration, module lifecycle, and placement. Conditional acceptance makes only the
minimal first corporate/legal synthetic persistence slice eligible for its separately recorded
entry decision. It does not prove or authorize that implementation.

**Current disposition: conditionally accepted for bounded synthetic entry.** The product direction
and the linked corporate/legal and educational refinement are approved by the Product Owner. The
[scenario and vocabulary walkthrough](institutional-structure-scenario-review.md),
[linked scenario addendum](linked-structure-scenario-addendum.md),
[security/migration/temporal review](institutional-structure-security-migration-review.md), and
[linked security and migration addendum](linked-structure-security-migration-addendum.md) prepare
the complete technical G1, G3, and G4 package. The
[read-only experience evidence](institutional-structure-experience-evidence.md) supplies linked
legal/corporate and educational prototype evidence. The later
[internal readiness challenge](institutional-structure-internal-readiness-review.md) records the
original wide/narrow findings and their closure through the current-contract, five-context
prototype refresh. The
[review packet](institutional-structure-review-packet.md) is ready, but no required named review is
recorded. The Product Owner's bounded G6 disposition conditionally accepts the logical direction
without closing those reviews. The entry register and
[Slice 2.1-B evidence](legal-entity-foundation-evidence.md) now record the complete minimal
synthetic proof under C25-01; C25-02 through C25-06 block the later work that depends on the open
evidence.

## Decision question

Is the linked corporate/legal and educational contract sufficiently precise, safe, and
representative to govern bounded synthetic implementation, while leaving storage optimization and
executable database proof to Slices 2.1-B through 2.1-F?

The review must not create a circular gate by demanding the prohibited persistence implementation
as evidence for accepting the decision that authorizes that implementation. At L0, every invariant
must have a credible enforcement design and a concrete negative-test specification. Executable
constraints, actions, migration rehearsals, and concurrency tests remain exit evidence for their
authorized L1 slices.

## Proposed decision positions to confirm

The accountable reviewers must accept, amend, or reject each position. An unresolved item that
changes identity, canonical parentage, tenant isolation, historical meaning, or the separation of
hierarchy from authority blocks acceptance.

| ID | Proposed position | Evidence needed for closure |
| --- | --- | --- |
| IS-01 | A tenant may own several root institutional units; no synthetic global root is required. | Multi-root and shared-site scenario plus navigation prototype |
| IS-02 | Each unit has one immutable tenant-qualified UUID. Names, codes, labels, profile meaning, status, site associations, and canonical parentage may change without replacing it. | Rename, move, closure, correction, and migration walkthroughs |
| IS-03 | Canonical containment is a tenant-local forest with zero or one active parent per unit, no fixed depth, same-tenant edges, and direct, indirect, and racing cycle rejection. | Combined-school, university, invalid-parentage, and concurrency test design |
| IS-04 | Cross-cutting structures use code-owned typed affiliations and never supply a second canonical parent. | Joint programme or shared-service scenario with endpoint, cardinality, and cycle disposition |
| IS-05 | The smallest initial structural classification is code-owned; institutions control localized display labels. Classification cannot create arbitrary entity types, authority, or allowed-parent rules by itself. | Cross-context vocabulary review and migration mapping |
| IS-06 | `Site` is a separate identity. Unit/site associations may be many-to-many and effective-dated; any primary-site meaning is explicit rather than inherited from parentage. | Independent, shared-site, multi-site, move, and closure scenarios |
| IS-07 | Canonical parentage has no implicit authorization, reporting, configuration, branding, calendar, module, placement, site, academic-ownership, or retained-record effect. | TM-17/AC-18 matrix and no-inheritance scenario |
| IS-08 | Exact-unit and descendant access are future explicit grant semantics. A unit selector or visible ancestor is never authority. | Security review and bounded-navigation prototype |
| IS-09 | Reparenting is a governed action with before/after parentage, effective meaning, registered-impact preview, writer revalidation, and fail-closed handling of unclassified effects. | Move scenario, impact registry, and negative-test specification |
| IS-10 | Unit profile publication/correction, parentage, sites, affiliations, closure, audit, outbox, migration provenance, and retention remain distinct evidence layers. | Domain-specific ADR 0018 classification and retention/correction disposition |
| IS-11 | Canonical codes are mutable human identifiers, never identity. The review must choose and document their uniqueness scope and preserve source aliases when migration evidence is ambiguous. | Duplicate-code fixtures across roots, siblings, and moved units |
| IS-12 | The logical decision does not select adjacency list, closure table, or materialized path. PostgreSQL remains authoritative and any traversal projection is disposable and rebuildable. | Query/move design review with explicit future measurement gate |
| IS-13 | Legal entities, internal corporate units, educational institutions, and educational units are distinct meanings. They may share presentation patterns but never one universal organization type or hierarchy. | Linked-structure scenarios and terminology review |
| IS-14 | Every published educational institution has exactly one effective primary legal operator. Ordinary educational units resolve through their containing institution; distinct legal accountability makes a contained establishment an educational institution. | Operator sharing, contained institution, transfer, and unresolved-publication scenarios |
| IS-15 | Legal ownership/control uses code-owned relationship types rather than one generic edge and may express multiple ownership. Each type owns its endpoint, cardinality, attribute, evidence, cycle, and non-inference rules; no transitive control is inferred. One optional primary consolidation parent supplies a separate single-parent acyclic navigation/reporting meaning. Corporate units may nest only within one effective legal entity and each belongs to one exact legal entity. Cross-entity coordination uses explicit typed relationships. | Joint-ownership, consolidation, corporate-unit, finance, and migration scenarios |
| IS-16 | Legal relationships, corporate parentage, consolidation, operator responsibility, and educational parentage grant no implicit access, report, workflow, configuration, module, or placement effect. Every consequential change is effective-dated and impact-checked. | Extended TM-17/AC-18 matrix and linked move/operator-change preview |
| IS-17 | Initial primary-operator assignment is single-step while the institution is unpublished. A published transfer requires proposal and distinct approval by default. The explicit single-controller exception requires stronger assurance, reason, evidence, visible marking, and mandatory retrospective review. | Assignment, proposal, approval, exception, stale-version, and bypass scenarios plus later negative tests |
| IS-18 | Structure stores classified operator-evidence metadata and a protected reference, not full legal documents. Draft evidence may remain pending, but publication requires verified initial evidence and a published transfer cannot take effect until evidence is verified. | Pending/verified/revoked evidence scenarios, records-boundary review, and later minimization and authorization tests |
| IS-19 | A future-effective operator transfer revalidates evidence freshness, entity status, proposal and approvals, expected versions, and registered impacts at activation. Pre-effect revocation blocks activation; post-effect revocation preserves history and opens high-priority reconciliation. | Future-effect, stale-input, revocation, concurrency, and reconciliation scenarios plus later negative tests |
| IS-20 | Post-effect operator invalidation creates a separate legal-accountability-under-review condition, not automatic institution closure or silent continuation. Policy blocks operator-dependent and unknown actions while permitting essential learner-facing operations unless suspension is required; history remains unchanged and resolution is deadline-bound. | Action-classification, learner-continuity, suspension, notification, escalation, and no-substitution scenarios plus later negative tests |
| IS-21 | Accountability under review has no generic dismissal. It resolves only through reverification, approved successor transfer, ADR 0018 correction, or separate suspension/closure. A legally accountable interim organization is a time-bounded operator; an appointed individual is a representative, not a legal entity. | Resolution-action, history, interim-operator, representative, and dismissal-negative scenarios plus later tests |

## Recorded Product Owner review

On 2026-09-27, François, as Product Owner, approved IS-01 through IS-12 and the refinements now
recorded as IS-13 through IS-21 through a stepwise review. The review additionally requires:

- separate corporate/legal and educational modules, with corporate/legal structure first;
- separate legal entities and internal corporate units;
- canonical corporate parentage only between units of the same effective legal entity, with
  cross-entity coordination represented by an explicit typed relationship;
- one effective primary legal operator per educational institution plus additional typed legal
  relationships;
- institution-local Date precision for primary-operator intervals using the institution's stored
  IANA time zone, with separate UTC recording time and no approximation of exact-time sources;
- single-step initial operator assignment while unpublished, but proposal and distinct approval
  for a published transfer by default, with only an explicit assured and reviewable
  single-controller exception;
- structured and classified operator-evidence metadata with a protected document reference,
  verified before publication or transfer effectiveness, while full documents remain in their
  separately governed records boundary;
- effective-boundary revalidation for future transfers using evidence-type and jurisdiction-owned
  freshness rules, with pre-effect revocation blocking activation and post-effect revocation
  preserving history while opening high-priority reconciliation;
- a visible, deadline-bound legal-accountability-under-review condition whose explicit policy
  blocks operator-dependent and unknown actions without automatically closing the institution or
  interrupting essential learner-facing operations unless suspension is required;
- named resolution only through reverification, approved transfer, ADR 0018 correction, or
  separate suspension/closure, with interim organizations modeled as time-bounded operators and
  appointed individuals modeled as representatives rather than legal entities;
- non-tree legal ownership with an optional consolidation parent;
- code-owned ownership/control relationship types with type-specific cycle rules, no generic edge,
  and no automatic transitive control or authority inference;
- separate educational institutions and educational units with one canonical educational parent;
- separate sites, programmes, reporting, finance, workflow, and authority meanings; and
- a reusable bounded tree-view pattern for every approved nested structure.

This record completes only the Product Owner portion of accountable review. It cannot substitute
for named corporate governance/finance, institutional-domain, platform, security/privacy,
records/migration, product-experience, or representative-institution reviewers.

## Approval gates

| Gate | Required artifact or review | Pass condition | Accountable reviewers | Current status |
| --- | --- | --- | --- | --- |
| G1 — scenarios and vocabulary | Completed linked scenario walkthrough and decision disposition for IS-01 through IS-21 | Every context is representable without weakening tenant, legal responsibility, identity, parentage, or separation invariants | Product owner, corporate governance/finance domain owner, institutional-structure domain owner, platform engineering | Product-owner disposition and technical packs accepted for bounded 2.1-B entry; named specialist findings remain C25-02/C25-03 conditions |
| G2 — representative institutions | Recorded review across the five approved learning environments | No unresolved rejection; local terminology maps without becoming fixed roles or arbitrary schema | Representative learning-institution domain owners and product owner | Five perspective records remain open and block educational persistence under C25-03, not minimal 2.1-B legal-entity proof |
| G3 — security and privacy | Extended TM-17/AC-18 treatment matrix and negative-test specification | Cross-tenant links, cycles, enumeration, selector misuse, legal-responsibility ambiguity, and implicit widening all fail closed by design | Security/privacy and platform engineering | Technical design accepted for bounded entry; executable per-slice proof and named review remain mandatory under C25-01/C25-05/C25-06 |
| G4 — migration and correction | Source-to-target mapping fixtures, ambiguity report, temporal classification, correction/retention disposition | The mapping preserves legal and educational source evidence separately, invents no history, creates no access, and has governed unresolved outcomes | Corporate/legal and educational domain ownership, platform engineering, records/migration review | Synthetic design accepted; no migration or real-data use is authorized, and C25-04/C25-06 remain binding |
| G5 — experience and accessibility | Read-only synthetic linked-structure navigation and change-preview prototype | Users can distinguish tenant, legal entity, corporate unit, educational institution/unit, site, affiliation, access scope, and the approved operator-governance states; traversal is bounded and accessible across five contexts | Product experience and representative institution reviewers | Current-contract prototype and focused checks pass; accountable/representative review remains C25-05 before connected/public structure workflow |
| G6 — accountable decision | Signed decision record with evidence links, residual risks, and implementation conditions | Every issue is closed or narrowed through an explicit fail-closed condition owned by a later slice/release gate | Named ADR deciders | Conditionally accepted by François on 2026-09-27 with C25-01 through C25-06 |

## Required scenario pack

Each scenario must record fixed synthetic identities, structure, sites, classifications, local
labels, proposed actions, expected current and historical reads, security challenges, migration
questions, user-navigation outcome, and final disposition. Scenario completion means reviewed
outcomes, not merely creating fixture names.

| Scenario | Minimum structure and questions | Required challenges |
| --- | --- | --- |
| S1 — independent early-childhood institution | One kindergarten root, one site, local terminology, no parent | Prove a root is not a tenant or site and receives no authority by existing |
| S1P — standalone primary/early-years institution | One primary institution with early-years and primary educational units, age-phase terminology, and one operator | Prove the model does not require a combined-school parent or a secondary division |
| S2S — standalone secondary institution | One secondary institution with departments, examination context, and one operator | Prove the model does not require a primary division and departments remain educational units rather than programmes or courses |
| S2 — combined school | One root containing kindergarten, middle-school, and high-school units | Rename and move a division; distinguish shared site, shared branding, reporting, and access from containment |
| S3 — university | University root with several schools or faculties and nested departments | Mixed local labels, repeated department labels/codes, deep navigation, department move, and multiple academic calendars as separately owned future meaning |
| S4 — college/community-college group | Several institutional roots, one shared site, and one shared service | Multi-root navigation, site many-to-many, shared service affiliation, and no fabricated global root |
| S5 — identity and history | One unit renamed, recoded, reparented, reassociated with a site, and closed | Stable UUID references, exact prior meaning, current resolution, correction versus planned succession, and closure with retained downstream references |
| S6 — matrix relationship | Joint programme or shared service spans units without two canonical parents | Typed affiliation direction, endpoints, cardinality, lifecycle, cycles, and proof that the edge grants no access |
| S7 — invalid structure | Cross-tenant parent plus direct, indirect, and racing cycle attempts | Same non-disclosing outcome across named actions and alternate writes; concurrency serialization design |
| S8 — no implicit effects | Create and move a unit beneath a visible or privileged parent | Prove no capability, descendant record access, report widening, configuration/calendar adoption, module activation, site meaning, tenant placement, or retained-record ownership changes |
| S9 — linked corporate/legal and educational structures | Nested legal entities with joint ownership and one consolidation parent; nested corporate units; two institutions sharing one operator; one contained institution with its own operator; separate property/employment responsibility; effective operator transfer | Prove stable identities, exact operator resolution, unresolved-publication refusal, graph/tree distinction, historical continuity, and no implicit authority, finance, workflow, reporting, or placement effect |

The pack must additionally exercise multilingual labels, closed legal and educational identities,
multiple roots at different depths, a shared site, duplicate source codes or registrations, an
ambiguous source parent or operator, one source cycle, and the distinction between legal entities,
corporate units, educational institutions, educational units, sites, programmes, cohorts, courses,
reporting groups, and access scopes.

## Representative institution review

The review requires five materially different operating perspectives rather than one generic
"school" representative:

1. primary or early-years operations;
2. secondary operations;
3. combined formal education spanning multiple levels;
4. college or community-college operations; and
5. university operations with schools or faculties and departments.

Each reviewer receives the same scenario pack and prototype. Their record must identify the
context they represent, scenarios reviewed, accepted terminology mappings, missing structures,
objections, required changes, residual risks, date, and disposition. A role title without a named
review and recorded findings does not satisfy G2. Product-owner approval cannot be relabelled as
representative institutional review.

A named corporate governance or finance reviewer must additionally review S9's legal-entity,
corporate-unit, ownership/control, consolidation, primary-operator, and financial-reporting
meanings. That review may be performed by one of the representative-institution reviewers only
when the record explicitly establishes that person's relevant operating context; a title or
assumption is insufficient.

Valid dispositions are:

- **approve** — the contract represents the reviewed context without weakening the invariants;
- **approve with implementation condition** — the logical decision is sound and a named L1
  implementation check remains; or
- **do not approve** — a concrete context cannot be represented or introduces unacceptable
  governance, usability, privacy, or security behavior.

## Security and privacy review design

The G3 record must trace every challenge below to a proposed control, future executable negative
test, owner, failure response, and slice where proof becomes mandatory.

| Challenge | Required decision-level treatment | Later executable proof |
| --- | --- | --- |
| Cross-tenant parentage, site association, affiliation, or history link | Compound tenant-qualified relationships and non-disclosing named-action errors | Slice 2.1-B through 2.1-E database and action negatives |
| Cross-tenant or ambiguous legal operator, ownership, corporate-unit membership, or consolidation | Compound tenant-qualified relationships, one effective primary operator for published institutions, and non-disclosing named-action errors | Slice 2.1-B through 2.1-E relationship, overlap, ambiguity, and alternate-write negatives |
| Direct, indirect, or concurrent cycle | Database-enforced invariant plus tenant-scoped serialization; application validation is not sufficient | Slice 2.1-C alternate-write and race tests |
| Visible ancestor or active selector used as authority | Explicit grant resolution independent from structure; client context never grants authority | Slice 2.1-G direct-interface and browser tests |
| Move widens a descendant scope or report | Registered-impact preview and authoritative writer revalidation; unknown effect blocks | Slice 2.1-C/F move and reconciliation tests |
| Parent configuration, calendar, branding, terminology, module, or placement silently applies | Explicit versioned adoption in the owning contract; no live hierarchy fallback | Owning-module tests before each adoption contract ships |
| Legal relationship, consolidation parent, operator, or corporate ancestor treated as authority | Legal and authorization resolution remain independent; changes use registered-impact preview and writer revalidation | Slice 2.1-C through 2.1-G legal-change and selector-misuse negatives |
| Recursive read becomes enumeration | Exact task-scoped, bounded navigation; no generic tenant-wide structure dump or caller-controlled traversal | Slice 2.1-C/G adversarial traversal and cumulative-exposure tests |
| Event or projection becomes hierarchy authority | Minimal events, stable IDs, tenant/current-route validation, rebuildable projections | Slice 2.1-F dispatch, replay, restore, and convergence tests |
| Close or move hides retained history | Separately authorized bounded history with closure and retention semantics | Slice 2.1-F retention, legal-hold, erasure, and restore tests |

This review may close the ADR's design gate with credible enforceable mechanisms and precise test
obligations. It must not mark the threats mitigated at L1 until those tests pass.

## Migration review design

Use synthetic source fixtures patterned after at least two materially different inputs: a generic
enterprise organization tree and a tertiary hierarchy. Preserve source system, snapshot,
identifier, parent evidence, source type, site evidence, access/default assumptions, and mapping
revision in a migration ledger.

The compare-only report must identify:

- duplicate and path-dependent codes;
- missing, ambiguous, cross-tenant, or cyclic parents;
- several source parents for one node;
- sites, legal entities, programmes, reporting groups, and access scopes represented as
  organizations;
- one source company represented simultaneously as legal entity, corporate unit, and educational
  institution without evidence, or an educational institution with no unambiguous legal operator;
- multiple legal owners collapsed into one parent or a consolidation parent misrepresented as
  legal ownership;
- implicit ancestor defaults, permissions, reports, calendars, or configuration;
- roots created only for source-system convenience;
- unknown effective dates and unverifiable reorganization history; and
- unresolved classifications, affiliations, closures, and retained references.

No mapping may invent historical parentage, turn a source relationship into an access grant, or
resolve ambiguity through last-write-wins. Every unresolved item receives a fail-closed
reconciliation disposition. Repeatable import and authoritative read-back remain Slice 2.1-H
evidence, not prerequisites for the L0 architecture decision.

## Experience and accessibility review design

The G5 prototype remains synthetic and read-only. It must demonstrate:

- several roots and arbitrary reviewed depth without a fabricated global root;
- search or direct lookup that returns only the permitted bounded context;
- clear distinction between institutional containment, sites, and affiliations;
- exact current-unit context without suggesting that selection grants authority;
- current and closed status, local labels, codes, and time zone;
- a move preview showing old and proposed parentage plus every registered impact as `unchanged`,
  `requires reconciliation`, or `blocks move`;
- keyboard navigation, visible focus, hierarchical assistive-technology semantics, text scaling,
  narrow reflow, non-colour status, loading, empty, denied, conflict, and unexpected-error states;
  and
- language that works for kindergarten, school, college, community-college, and university
  contexts without hard-coding one of them as the universal root.

The prototype is experience evidence only. It cannot authorize data access, validate a move,
select placement, or become the production client.

## Temporal, lifecycle, and retention disposition

Before G4 closes, the institutional-structure domain owner must classify at least:

| Meaning | Proposed ADR 0018 class to review | Minimum decision |
| --- | --- | --- |
| Unit identity | Stable aggregate identity | Never replaced by name, code, label, parent, site, or status change |
| Legal-entity identity | Stable aggregate identity | Never replaced by registration, name, owner, control relationship, consolidation parent, or status change |
| Corporate-unit identity | Stable aggregate identity | Never replaced by name, parent, legal-entity membership, or status change |
| Primary legal operator | Effective-dated durable relationship | Exactly one active relationship for each published educational institution; transfer preserves both identities and prior intervals; initial assignment and published-transfer approval use distinct lifecycle contracts |
| Legal ownership/control and consolidation | Effective-dated typed relationships | Direction, endpoints, cardinality, percentage or evidence meaning, cycles, and history are explicit per accepted type; consolidation never substitutes for ownership evidence |
| Published unit profile | Revisioned durable state | Decide draft/publication boundary, correction reasons, current/exact reads, and whether recorded-time reads are promised |
| Canonical parentage | Effective-dated durable relationship or revision-owned snapshot | Decide effective precision, move/supersession behavior, non-overlap, historical read, and consumer pin/reconciliation |
| Unit/site association | Effective-dated relationship | Decide primary-site succession, overlap, closure, and history |
| Affiliation | Effective-dated typed relationship | Decide direction, endpoints, cardinality, cycles, closure, and history per accepted type |
| Closure | Named durable transition | Preserve identity and retained references; decide reopening/supersession and downstream reconciliation |
| Audit, outbox, migration, retention | Separate evidence contracts | Never reconstruct domain history from logs/events or invent source history |

The record must name classification, retention start, retention duration or policy owner, legal-hold
behavior, export scope, deletion/redaction outcome, and accountable owner for any content that may
be retained. It may explicitly defer real-data values to L3 records ownership, but it must state
the safe synthetic behavior and block real data until those values exist.

## Accountable decision record

The normal path records a final outcome when G1 through G5 are complete:

- **Accept ADR 0025** when the logical contract is settled and remaining conditions are explicitly
  implementation proof for authorized later slices;
- **Conditionally Accept ADR 0025** when the current evidence supports the identity, tenant, and
  non-authority invariants, every open review has a fail-closed owner and first affected slice, and
  a later contrary finding must revise or supersede the ADR before that slice proceeds; or
- **Keep Proposed or reject** when a core decision or representative context remains unresolved.

On 2026-09-27, the Project Owner chose the bounded conditional path: unresolved reviews are not
treated as complete, but each one now blocks the first slice whose correctness depends on it. This
permits only minimal synthetic 2.1-B work and requires revision or supersession if a later finding
challenges a core invariant.

The record must include:

| Field | Required value |
| --- | --- |
| Decision date | 2026-09-27 |
| Accountable approver | François — Project Owner and interim Security/Privacy Owner for synthetic work |
| Corporate governance/finance domain owner | Open; C25-02 blocks Slice 2.1-C |
| Institutional-structure domain owner | Open; C25-03 blocks Slices 2.1-D/2.1-E |
| Representative reviewers and contexts | Five perspectives open; C25-03 blocks educational persistence |
| Platform engineering reviewer | C25-01 executable proof recorded for minimal 2.1-B; C25-05 review remains required for the connected/public workflow |
| Security/privacy reviewer | Interim synthetic ownership recorded; independent review remains mandatory before L3 under C25-06 |
| Product-experience reviewer | Open; C25-05 blocks connected/public structure workflow |
| Scenario review | Product Owner disposition and technical linked addendum accepted as bounded decision evidence; named findings remain conditions |
| Migration/correction review | Synthetic mappings and temporal disposition accepted as design evidence; migration and real data prohibited by C25-06 |
| Experience/accessibility review | Internal wide/narrow audit recorded; refreshed technical and named review remains C25-05 |
| TM-17/AC-18 disposition | Technical treatment accepted for bounded synthetic entry; each implementation slice must supply its executable negatives |
| Residual risks and implementation conditions | Recorded risks accepted only within ADR 0025 C25-01 through C25-06 |
| Final outcome | **Conditionally Accept ADR 0025**; minimal Slice 2.1-B entered and passed its separate L1 disposition under C25-01 |

No placeholder or blank field counts as approval. Independent security/privacy review and a
learning-institution-side records owner remain mandatory before real Restricted data or an L3
pilot; they are not prerequisites for an L0 logical-model decision unless the decision review
introduces a real-data or external trust boundary.

### Prepared G6 review agenda

The following residual risks are accepted by the Project Owner only within C25-01 through C25-06.
Named reviewers may amend them; a finding that challenges a core invariant reopens the ADR before
the affected slice proceeds:

1. the two proposed educational classifications may omit a distinction needed by one of the five
   representative contexts;
2. sibling-scoped current-code uniqueness may not match a representative migration or lookup
   practice;
3. institution-local `Date` precision and its captured IANA time zone may not match every
   reorganization, site, or affiliation event;
4. `joint_programme` may belong to the later programme domain rather than the first
   structure-owned affiliation catalog;
5. reopening or superseding a closed unit is deliberately deferred to a separately accepted named
   action contract;
6. cycle serialization, bounded traversal, move-impact revalidation, and alternate-write denial
   are specified but remain unproved until their named L1 slices pass;
7. the read-only prototype has focused engineering evidence but no representative usability
   acceptance; and
8. real-data classification, retention, legal hold, export, redaction, deletion, and records
   ownership remain unset, so real import and an L3 pilot stay prohibited;
9. legal-entity relationship types, registration uniqueness, and corporate-unit membership require
   representative corporate governance/finance review before their first persistent slice;
10. the optional primary consolidation parent must not be presented as legal ownership or used as
    unreviewed financial-report authority; and
11. the linked read-only prototype has automated technical evidence but no accountable
    product-experience or representative comprehension acceptance;
12. the first persistent ownership/control catalogue still needs corporate governance/finance
    review of each type's exact name, endpoints, cardinality, attributes, evidence, cycle policy,
    and jurisdictional/accounting meaning; and
13. the approved primary-operator workflow still needs representative validation of the exact
    evidence types, records-system boundary, type/jurisdiction freshness policy, reconciliation
    owner and service level, under-review action classification and continuity policy,
    stronger-assurance mechanism, retrospective-review owner and deadline, and operational
    handling when no independent approver is available.

Slice 2.1-B remains synthetic and its executable proof does not imply a public interface,
migration, real-data use, or production readiness. Any unresolved G2 objection affecting
tenant ownership, UUID identity, parentage, or hierarchy's non-authority rule blocks acceptance
rather than becoming a later implementation condition. The same applies to an unresolved objection
about primary legal operation, legal/educational identity separation, or consolidation being
mistaken for ownership or authority.

## Entry and exit effect

This approval plan is complete as a planning artifact when it is linked from ADR 0025, the ADR
index, threat model, Phase 2 proposal, and entry register and repository documentation checks pass.
That does not close any approval gate above.

ADR 0025 is conditionally accepted at the logical boundary. The Phase 2 entry register and
[Slice 2.1-B evidence](legal-entity-foundation-evidence.md) separately record the satisfied entry
conditions, generated migration review, executable tenant/authorization/concurrency/idempotency/
outbox evidence, and complete repository gate. This bounded closure is not permission to cross
C25-02 through C25-06.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Linked-structure scenario addendum](linked-structure-scenario-addendum.md)
- [Security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Linked-structure security and migration addendum](linked-structure-security-migration-addendum.md)
- [Experience and representative-review evidence](institutional-structure-experience-evidence.md)
- [Internal readiness challenge](institutional-structure-internal-readiness-review.md)
- [Representative and accountable review packet](institutional-structure-review-packet.md)
- [Slice 2.1-B minimal legal-entity foundation evidence](legal-entity-foundation-evidence.md)
- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [ADR 0018 temporal records contract](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020 human-interface boundary](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023 sensitive-collection boundary](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
