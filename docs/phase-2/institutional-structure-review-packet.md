# ADR 0025 representative and accountable review packet

- Status: ADR 0025 conditionally accepted for bounded synthetic implementation; named reviews
  remain open as slice/release conditions
- Date: 2026-09-27
- Condition review due: 2026-12-15, or before the first connected/public
  institutional-structure workflow, whichever is earlier
- Gates: ADR 0025 G1 through G6
- Boundary: Review of the logical linked-structure contract only; approval does not authorize
  persistence, real data, a public interface, module activation, or production release

## How to use this packet

The review is deliberately short for each participant. A reviewer does not need to approve every
part of ADR 0025.

1. Read the common summary below.
2. Review only the scenarios assigned to your perspective.
3. Answer the seven common questions and any role-specific questions.
4. Record one disposition and every blocking concern.
5. Open the detailed evidence only when a question is unclear or the answer is `condition` or
   `do not approve`.

Expected review time is 20–30 minutes for a representative institution perspective and 30–45
minutes for an accountable specialist perspective. Time is guidance, not a pass condition.

No one should approve a structure they do not understand. `Unclear` is useful evidence and must
not be silently converted to approval.

## Common summary

Chimwemwe proposes two linked but independent structures inside a tenant:

- a corporate/legal structure containing legal entities, typed legal relationships, optional
  consolidation parentage, and nested internal corporate units; and
- an educational structure containing educational institutions and educational units under one
  canonical educational parent at a time.

Every published educational institution has one primary legal operator at an effective date. A
contained establishment with its own legal operator is still an institution; an ordinary
educational unit obtains legal accountability through its containing institution. Sites,
programmes, courses, affiliations, access scopes, reports, workflows, configuration, module
activation, and tenant placement remain separate.

The structure stores classified operator-evidence metadata and a protected reference, not full
legal documents. Draft evidence may remain pending, but initial evidence must be verified before
publication and transfer evidence before the transfer takes effect.

A future-effective transfer revalidates evidence, entity status, approvals, versions, and impacts
at activation. Revocation before effect blocks activation; revocation discovered afterward
preserves history and opens high-priority reconciliation.

During reconciliation, legal accountability is visibly under review. Explicit policy blocks
operator-dependent and unknown actions, while essential teaching, safeguarding, attendance, and
learner support continue unless suspension is required. This condition does not silently verify or
replace the operator, close the institution, alter module activation, or grant or revoke access.

There is no generic dismissal. Reverification, approved transfer, ADR 0018 correction, or a
separately authorized suspension/closure resolves the condition. An interim organization may be a
time-bounded operator; an appointed individual remains a representative rather than being
misclassified as a legal entity.

Neither a parent, operator, owner, consolidation link, visible tree node, nor selected node grants
authority. Consequential changes require a preview and fail closed when a downstream effect is
unknown or unsafe.

## Evidence map

| Review need | Evidence |
| --- | --- |
| Complete educational scenarios and shared vocabulary | [Institutional-structure scenario walkthrough](institutional-structure-scenario-review.md) |
| Corporate/legal and linked educational cases | [Linked-structure scenario addendum](linked-structure-scenario-addendum.md) |
| Security, migration, correction, and negative tests | [Linked-structure security and migration addendum](linked-structure-security-migration-addendum.md) |
| Current linked legal/corporate and educational prototype | [Experience evidence](institutional-structure-experience-evidence.md) |
| Decision positions and gate definitions | [Decision evidence plan](institutional-structure-decision-evidence.md) |
| Governing proposal | [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md) |

## Common questions

Record `yes`, `condition`, `no`, or `unclear` for each question.

| ID | Question | Answer | Finding or condition |
| --- | --- | --- | --- |
| Q1 | Can you identify the tenant, legal entity, corporate unit, educational institution, educational unit, and site without relying only on their labels? | Open | Open |
| Q2 | Is the primary legal operator clear, including when an institution has an educational parent or shares an operator with another institution? | Open | Open |
| Q3 | Is it clear that ownership/control, consolidation, primary operation, property, employment, funding, governance, and data-control responsibility may differ? | Open | Open |
| Q4 | Can your real structure be represented with corporate parentage limited to one legal entity and one canonical educational parent, using explicit typed relationships for cross-entity or cross-cutting meanings? | Open | Open |
| Q5 | Is it clear that no structure or selected node grants access, report authority, workflow/configuration inheritance, module activation, or tenant placement? | Open | Open |
| Q6 | Do rename, move, closure, operator transfer, and correction preserve enough identity and history for your work? | Open | Open |
| Q7 | What required concept is missing, misleading, too complex, or unsafe? | Open | Open |

## Representative-institution reviews — G2

Each row requires a real named person with current or recent operating knowledge of that context.
One person may cover more than one context only when the record explains their relevant experience
for each. Product ownership or document authorship alone does not satisfy representative review.

### Primary or early-years operations

- Minimum scenarios: S1, S1P, S5, S7, S8, LS-04, LS-06, and LS-10.
- Additional questions:
  - Do early-years and primary divisions remain understandable without fixed structural types?
  - Can the institution keep its own curriculum, calendar, terminology, and workflows even when
    it shares an operator or adopts a group template?
  - Does the model avoid assuming that every learner has the same guardian or legal-capacity
    context?

### Secondary operations

- Minimum scenarios: S2S, S2, S5, S7, S8, LS-04, LS-06, and LS-10.
- Additional questions:
  - Are subject departments distinguishable from courses, programmes, sections, and timetables?
  - Can different school divisions use different calendars, teaching days, periods, and cycles
    without inheriting them from educational parentage?
  - Can shared programmes and services cross divisions without creating a second parent?

### Combined formal education

- Minimum scenarios: S2, S5, S7, S8, LS-04, LS-05, LS-08, and LS-10.
- Additional questions:
  - Can early-years, primary, and secondary structures coexist under one institution without a
    fixed depth?
  - Is the difference between a division and a separately operated contained institution clear?
  - Are cross-level academic, sports, and support programmes kept outside the containment tree?

### College or community-college operations

- Minimum scenarios: S4, S5, S6, S7, S8, LS-04, LS-07, and LS-10.
- Additional questions:
  - Can several campuses or institutions share sites, services, programmes, and operators without
    being merged?
  - Does the model support independent and centrally coordinated operations without assuming one
    calendar or reporting scope?
  - Is operator transfer understandable without changing learner, programme, or course identity?

### University operations

- Minimum scenarios: S3, S5, S6, S7, S8, LS-05, LS-06, LS-08, and LS-10.
- Additional questions:
  - Can faculties, schools, departments, institutes, and separately incorporated institutions be
    represented without a fixed type ladder?
  - Can shared courses, programmes, research/support units, and sports activities cross structures
    without acquiring two canonical parents?
  - Can different calendars and academic responsibilities remain explicit at the applicable unit
    or programme scope?

## Corporate governance and finance review

- Minimum scenarios: LS-01 through LS-10 and migration Sources C through F.
- Required questions:
  1. Does the contract distinguish ownership/control from consolidation and primary operation?
  2. Which code-owned legal relationship types and attributes are essential for the first
     relationship slice, given that a generic ownership/control edge is prohibited?
  3. Are any cycles legitimate in a specific ownership/control type, and how must they be surfaced
     without transitive inference?
  4. Is one optional primary consolidation parent sufficient for bounded navigation and reporting
     input while preserving other relationships?
  5. Are registration, jurisdiction, closure, transfer, correction, and evidence requirements
     sufficiently deferred to owned policies rather than guessed by the platform?
  6. Which operator, property, employment, funding, contracting, governance, or data-control
     changes require approval or downstream reconciliation before they take effect?
  7. Does institution-local Date precision accurately represent primary-operator changes in the
     reviewed context, and can exact-time source evidence remain unresolved safely?
  8. Is single-step initial assignment practical while unpublished, and is distinct proposal and
     approval proportionate for a published transfer? For a single-controller exception, who owns
     retrospective review, by when, and what evidence and stronger assurance are required?
  9. Which evidence types, verification freshness, revocation events, and approved records
     boundary are required without copying sensitive documents into structure, audit, or events?
  10. Who owns type- and jurisdiction-specific freshness rules and post-effect reconciliation,
      and what response time is proportionate when operator evidence is revoked?
  11. Which actions require verified operator standing, which learner-facing operations must
      continue, and which applicable rules require suspension during accountability review?
  12. Are reverification, approved transfer, ADR 0018 correction, and separate
      suspension/closure the complete resolution set, including interim-operator cases?
  13. Does the proposed first-slice sequence avoid claiming a complete finance or company-registry
      model?

## Accountable specialist reviews — G1, G3, G4, and G5

### Educational-structure domain owner

Confirm that institution versus educational-unit classification, primary-operator resolution,
canonical parentage, affiliations, sites, terminology, and change history are usable across the
five contexts. Record every case that would require two canonical parents or hidden inheritance.

### Platform engineering

Confirm that the contract can be enforced with tenant-qualified identities and constraints,
serialized cycle-safe writes, expected versions, idempotency, atomic history/audit/outbox,
registered-impact evaluation, bounded reads, and disposable projections. Do not accept a design
whose correctness depends only on the browser or application prechecks.

### Security/privacy

Review TM-17, AC-18, the relationship-policy matrix, and `LS-N01` through `LS-N20`. Confirm that
cross-tenant links, ambiguous operators, selector misuse, hierarchy-derived authority, traversal,
alternate writers, and unknown impacts fail closed without revealing foreign or hidden records.

### Records/migration

Review Sources C through F, mapping dispositions, effective-time precision, correction, retention,
legal hold, export, erasure, and restore implications. Confirm that a current snapshot cannot be
presented as historical proof and that unresolved evidence cannot publish.

### Product experience and accessibility

Use the linked prototype when available. Confirm that a participant can distinguish every
structure and relationship using keyboard and assistive technology at wide and narrow layouts;
understand current versus historical meaning; and explain why selection, ownership,
consolidation, operation, and parentage grant no authority. Repository tests do not replace this
review.

## Review record

Copy this section once for each reviewer. Do not combine several unnamed opinions into one record.

| Field | Recorded value |
| --- | --- |
| Reviewer name | Open |
| Current role or relevant experience | Open |
| Perspective reviewed | Open |
| Organization/context represented | Open; use a generic descriptor if the name must remain private |
| Review date | Open |
| Evidence and scenarios reviewed | Open |
| Common-question answers | Open |
| Missing or confusing structures | Open |
| Security, privacy, migration, records, or usability concerns | Open |
| Required changes or implementation conditions | Open |
| Accepted residual risks | Open |
| Disposition | Open: `approve`, `approve with condition`, or `do not approve` |

A valid `approve with condition` record names the condition, owner, gate, and evidence needed to
close it. A condition that changes tenant ownership, stable identity, primary legal operation,
canonical parentage, or hierarchy/non-authority semantics blocks G6 until the ADR and evidence are
revised.

## Consolidated gate record

| Gate | Evidence complete? | Required named reviews complete? | Blocking findings | Disposition |
| --- | --- | --- | --- | --- |
| G1 — scenarios and vocabulary | Technical educational and linked scenario packs prepared | Specialist findings open | No current technical rejection; C25-02/C25-03 block the affected later slices | Accepted as bounded decision evidence |
| G2 — five representative contexts | Review instructions prepared | Five perspective records open | Educational persistence blocked by C25-03 | Deferred to first affected slice |
| G3 — security/privacy | Technical control and negative-test contract prepared | Named and executable per-slice review open | C25-01/C25-05/C25-06 remain binding | Accepted as bounded design evidence |
| G4 — migration/correction | Synthetic mappings and temporal contract prepared | Named records/migration review open | Migration and real data blocked by C25-06 | Accepted as synthetic design evidence |
| G5 — experience/accessibility | Current-contract prototype and focused checks pass | Accountable/representative comprehension review open | Connected/public structure workflow remains prohibited by C25-05 | Technical evidence ready; condition review due 2026-12-15 or the first affected gate |
| G6 — accountable decision | Product-owner decision and conditions recorded | François recorded; specialist/representative findings remain conditions | C25-01 through C25-06 | **Conditionally accepted 2026-09-27** |

## G6 decision form

The Project Owner completed this bounded form on 2026-09-27. Open review rows are not reported as
complete; each is attached to a fail-closed condition before the first slice that depends on it.

| Field | Recorded value |
| --- | --- |
| Decision date | 2026-09-27 |
| Named deciders | François — Project Owner and interim Security/Privacy Owner for synthetic work |
| G1–G5 evidence links | Scenario, linked-structure, security/migration, internal-readiness, and experience records linked above |
| Remaining implementation conditions | ADR 0025 C25-01 through C25-06 |
| Accepted residual risks and owners | Product Owner accepts the recorded residual risks only within C25-01 through C25-06; named specialist and representative owners remain to be recorded before their affected slices |
| Outcome | **Conditionally accept ADR 0025** |
| Effect on Slice 2.1 persistence | Minimal synthetic Slice 2.1-B may seek its separate entry disposition; later slices remain gated by C25-02 through C25-06 |

Conditional acceptance settles the logical direction only. It makes the separately authorized
minimal first synthetic corporate/legal persistence slice eligible; it does not approve a
migration, public interface, deployment, real data, pilot, relationship catalogue, corporate-unit
model, operator workflow, or educational-structure persistence.

## Phase 2.0 conditional-approval addendum

On 2026-09-28, François, as Project Owner, conditionally approved Phase 2.0 at its completed L1
foundation boundary. The uncompleted G5 expert/representative comprehension and accountable
product-experience finding is carried as a dated residual condition until 2026-12-15 or the first
connected/public institutional-structure gate, whichever is earlier.

This addendum closes Phase 2.0 for planning purposes only. It does not complete a blank review row,
satisfy C25-05, authorize Slice 2.0-E's connected workflow, or approve L2. If no valid review is
recorded by the deadline, the Project Owner must explicitly renew, amend, or withdraw the
conditional disposition; expiry never converts the condition into approval.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Institutional-structure decision evidence plan](institutional-structure-decision-evidence.md)
- [Institutional-structure experience evidence](institutional-structure-experience-evidence.md)
- [Internal readiness challenge](institutional-structure-internal-readiness-review.md)
- [Linked-structure scenario addendum](linked-structure-scenario-addendum.md)
- [Linked-structure security and migration addendum](linked-structure-security-migration-addendum.md)
