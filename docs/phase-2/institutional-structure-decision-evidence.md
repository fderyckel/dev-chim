# Institutional-structure decision evidence plan

- Status: L0 evidence package in review; G2, accountable reviews, and G6 remain open
- Date: 2026-09-27
- Accountable owner: Product and institutional-structure domain ownership
- Decision record: [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- Gate: Slice 2.1-A; Slice 2.1-B persistence remains closed

## Purpose and current disposition

This plan defines the evidence and review required to move ADR 0025 from **Proposed** to
**Accepted**. It converts the ADR's acceptance paragraph into a reviewable decision package
without treating planned scenarios, a prototype, or an owner role as completed evidence.

The decision under review is the logical institutional-structure contract: stable tenant-owned
institutional units, tenant-local canonical parentage, separate sites and affiliations, explicit
history, and strict separation of hierarchy from authority, reporting, configuration, module
lifecycle, and placement. Acceptance would make the first synthetic persistence slice eligible
for its separately recorded entry decision. It would not prove or authorize that implementation.

**Current disposition: partially prepared, not approved.** The product direction is approved. The
[scenario and vocabulary walkthrough](institutional-structure-scenario-review.md),
[security/migration/temporal review](institutional-structure-security-migration-review.md), and
[read-only experience evidence](institutional-structure-experience-evidence.md) now prepare the
engineering evidence for G1, G3, G4, and the technical portion of G5. Their accountable reviews
remain open. No named representative-institution review is recorded for G2, and G6 cannot occur
before those reviews. ADR 0025 therefore remains Proposed and Slice 2.1-B remains blocked.

## Decision question

Is the logical contract sufficiently precise, safe, and representative to govern a bounded
synthetic implementation, while leaving storage optimization and executable database proof to
Slices 2.1-B through 2.1-F?

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

## Approval gates

| Gate | Required artifact or review | Pass condition | Accountable reviewers | Current status |
| --- | --- | --- | --- | --- |
| G1 — scenarios and vocabulary | Completed eight-scenario walkthrough and decision disposition for IS-01 through IS-12 | Every context is representable without weakening tenant, identity, parentage, or separation invariants | Product owner, institutional-structure domain owner, platform engineering | Engineering walkthrough prepared; accountable review open |
| G2 — representative institutions | Recorded review across materially different learning environments | No unresolved rejection; local terminology maps without becoming fixed roles or arbitrary schema | Representative learning-institution domain owners and product owner | Open; all three named-reviewer records are empty |
| G3 — security and privacy | TM-17/AC-18 treatment matrix and negative-test specification | Cross-tenant links, cycles, enumeration, selector misuse, and implicit widening all fail closed by design | Security/privacy and platform engineering | Design matrix prepared; accountable review and later executable proofs open |
| G4 — migration and correction | Source-to-target mapping fixtures, ambiguity report, temporal classification, correction/retention disposition | The mapping preserves source evidence, invents no history, creates no access, and has governed unresolved outcomes | Domain ownership, platform engineering, records/migration review | Two compare-only fixtures and temporal disposition prepared; accountable review open |
| G5 — experience and accessibility | Read-only synthetic hierarchy-navigation and move-preview prototype | Users can distinguish tenant, unit, site, affiliation, and access scope; traversal is bounded and accessible | Product experience and representative institution reviewers | Technical prototype and complete repository gate passed; accountable product-experience and representative review open |
| G6 — accountable decision | Signed decision record with evidence links, residual risks, and implementation conditions | Every blocking issue is closed or narrowed through an explicit fail-closed condition; the product owner records the outcome | Named ADR deciders | Blocked by open G1–G5 reviews |

## Required scenario pack

Each scenario must record fixed synthetic identities, structure, sites, classifications, local
labels, proposed actions, expected current and historical reads, security challenges, migration
questions, user-navigation outcome, and final disposition. Scenario completion means reviewed
outcomes, not merely creating fixture names.

| Scenario | Minimum structure and questions | Required challenges |
| --- | --- | --- |
| S1 — independent early-childhood institution | One kindergarten root, one site, local terminology, no parent | Prove a root is not a tenant or site and receives no authority by existing |
| S2 — combined school | One root containing kindergarten, middle-school, and high-school units | Rename and move a division; distinguish shared site, shared branding, reporting, and access from containment |
| S3 — university | University root with several schools or faculties and nested departments | Mixed local labels, repeated department labels/codes, deep navigation, department move, and multiple academic calendars as separately owned future meaning |
| S4 — college/community-college group | Several institutional roots, one shared site, and one shared service | Multi-root navigation, site many-to-many, shared service affiliation, and no fabricated global root |
| S5 — identity and history | One unit renamed, recoded, reparented, reassociated with a site, and closed | Stable UUID references, exact prior meaning, current resolution, correction versus planned succession, and closure with retained downstream references |
| S6 — matrix relationship | Joint programme or shared service spans units without two canonical parents | Typed affiliation direction, endpoints, cardinality, lifecycle, cycles, and proof that the edge grants no access |
| S7 — invalid structure | Cross-tenant parent plus direct, indirect, and racing cycle attempts | Same non-disclosing outcome across named actions and alternate writes; concurrency serialization design |
| S8 — no implicit effects | Create and move a unit beneath a visible or privileged parent | Prove no capability, descendant record access, report widening, configuration/calendar adoption, module activation, site meaning, tenant placement, or retained-record ownership changes |

The pack must additionally exercise multilingual labels, a closed unit, multiple roots at different
depths, a shared site, duplicate source codes, an ambiguous source parent, one source cycle, and the
distinction between institutional units, legal entities, sites, programmes, cohorts, courses,
reporting groups, and access scopes.

## Representative institution review

The review requires at least three materially different operating perspectives rather than one
generic "school" representative:

1. early-childhood or combined primary/secondary operations;
2. college or community-college operations; and
3. university operations with schools or faculties and departments.

Each reviewer receives the same scenario pack and prototype. Their record must identify the
context they represent, scenarios reviewed, accepted terminology mappings, missing structures,
objections, required changes, residual risks, date, and disposition. A role title without a named
review and recorded findings does not satisfy G2. Product-owner approval cannot be relabelled as
representative institutional review.

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
| Direct, indirect, or concurrent cycle | Database-enforced invariant plus tenant-scoped serialization; application validation is not sufficient | Slice 2.1-C alternate-write and race tests |
| Visible ancestor or active selector used as authority | Explicit grant resolution independent from structure; client context never grants authority | Slice 2.1-G direct-interface and browser tests |
| Move widens a descendant scope or report | Registered-impact preview and authoritative writer revalidation; unknown effect blocks | Slice 2.1-C/F move and reconciliation tests |
| Parent configuration, calendar, branding, terminology, module, or placement silently applies | Explicit versioned adoption in the owning contract; no live hierarchy fallback | Owning-module tests before each adoption contract ships |
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

When G1 through G5 are complete, the named deciders record one outcome:

- **Accept ADR 0025** when the logical contract is settled and remaining conditions are explicitly
  implementation proof for authorized later slices;
- **Conditionally Accept ADR 0025** only when the accepted platform direction is usable but a
  clearly named non-identity, non-tenant, non-authority condition remains; or
- **Keep Proposed or reject** when a core decision or representative context remains unresolved.

The record must include:

| Field | Required value |
| --- | --- |
| Decision date | Open |
| Accountable approver | Open |
| Institutional-structure domain owner | Open |
| Representative reviewers and contexts | Open |
| Platform engineering reviewer | Open |
| Security/privacy reviewer | Open |
| Product-experience reviewer | Open |
| Scenario review | Open |
| Migration/correction review | Open |
| Experience/accessibility review | Open |
| TM-17/AC-18 disposition | Open |
| Residual risks and implementation conditions | Open |
| Final outcome | Open |

No placeholder or blank field counts as approval. Independent security/privacy review and a
learning-institution-side records owner remain mandatory before real Restricted data or an L3
pilot; they are not prerequisites for an L0 logical-model decision unless the decision review
introduces a real-data or external trust boundary.

### Prepared G6 review agenda

The following candidate residual risks and implementation conditions are prepared for challenge;
they are not accepted until the named reviewers amend or approve them:

1. the two proposed structural classifications may omit a distinction needed by one of the three
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
   ownership remain unset, so real import and an L3 pilot stay prohibited.

If ADR 0025 is later accepted, Slice 2.1-B must remain synthetic and must not treat acceptance as
proof of a database constraint, concurrency behavior, authorization path, public interface,
module activation, migration, or production readiness. Any unresolved G2 objection affecting
tenant ownership, UUID identity, parentage, or hierarchy's non-authority rule blocks acceptance
rather than becoming a later implementation condition.

## Entry and exit effect

This approval plan is complete as a planning artifact when it is linked from ADR 0025, the ADR
index, threat model, Phase 2 proposal, and entry register and repository documentation checks pass.
That does not close any approval gate above.

ADR 0025 may change status only after G1 through G6 have recorded evidence. After acceptance, the
Phase 2 entry register must separately record whether all Slice 2.1-B entry conditions are
satisfied. The first persistence slice then supplies generated migration review, executable
tenant/authorization/concurrency/idempotency/outbox evidence, and a complete `make check`; ADR
acceptance is not permission to skip those implementation gates.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Experience and representative-review evidence](institutional-structure-experience-evidence.md)
- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [ADR 0018 temporal records contract](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020 human-interface boundary](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023 sensitive-collection boundary](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
