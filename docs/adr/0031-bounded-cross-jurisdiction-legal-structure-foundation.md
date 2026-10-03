# ADR 0031: Bounded cross-jurisdiction legal-structure foundation

- Status: Conditionally Accepted
- Date: 2026-10-03
- Decider: François — Project Owner
- Owners: Corporate/legal structure and platform engineering
- Supersedes: ADR 0025 condition C25-02 only for the synthetic L1 Slice 2.1-C1 boundary defined here
- Partially superseded by: [ADR 0032](0032-c25-02-delegated-contract-acceptance.md) for C25-02 review route, completed contract disposition, and explicit first-slice qualifications; synthetic implementation and later-adoption gates remain binding

## Context

ADR 0025 separated legal entities, corporate units, educational structure, primary operation,
ownership or control, and financial consolidation. Its C25-02 condition originally prohibited
persisting any legal relationship, consolidation parentage, or corporate unit before a named
corporate-governance and finance disposition.

On 2026-10-03 the Project Owner directed the project to continue using an explicitly documented
cross-country education and finance judgement rather than wait until December. This is an
accountable product decision to accept a narrow synthetic implementation risk. It is not a claim
that an AI-assisted analysis is professional legal, tax, audit, accounting, charity-regulation, or
jurisdiction-specific advice, and it does not invent a qualified reviewer.

The cross-country evidence rejects one generic ownership/control/consolidation edge:

- IFRS 10 makes control, not a stated ownership percentage alone, the basis for consolidation and
  requires judgement about power, variable returns, and the ability to affect those returns.
- IPSAS 35 assesses public-sector control through power and the ability to influence benefits.
- US governmental reporting can include legally separate component units and distinguishes
  blended from discretely presented units.
- England's academy-trust model can place several academies inside one legal academy trust, while
  the trust board remains accountable for the trust's finances.
- South African public-school law places school funds and governance responsibilities at the
  public-school and governing-body boundary without making every governance relationship an
  ownership relationship.
- Australian charities and non-government schools can use several legal forms and can have group
  reporting arrangements that do not by themselves redefine each legal entity.

These examples are mapping evidence. They do not make one country's rule the platform's universal
authority.

## Decision drivers

- Preserve legal-entity identity separately from internal corporate and educational structures.
- Represent materially different legal bases explicitly instead of hiding them behind one generic
  ownership or control edge.
- Support common private, public, trust, charity, and multi-entity education structures without
  claiming universal jurisdictional semantics.
- Keep accounting consolidation a reviewed finance conclusion rather than an inference from an
  equity percentage or organizational hierarchy.
- Preserve tenant isolation, named actions, exact replay, minimized durable evidence, and the
  existing Phase 2 release gates.
- Make the synthetic implementation reversible if the December external review changes the model.

## Considered options

- **Wait until December:** lowest semantic risk, rejected by the Project Owner for the synthetic
  implementation schedule.
- **One generic ownership/control edge:** rejected because legal ownership, governance power,
  public authority, and accounting consolidation differ across structures and reporting bases.
- **Infer consolidation from equity percentage:** rejected because official accounting standards
  require a broader control assessment and professional judgement.
- **Put schools and departments directly in the legal graph:** rejected because one legal entity
  may operate several educational institutions and internal units are not automatically legal
  persons.
- **Use a closed direct catalogue plus separate management navigation:** selected for the bounded
  synthetic foundation.

## Decision

Authorize a synthetic, private L1 Slice 2.1-C1 with the following closed semantics.

### Direct legal-entity relationships

There is no generic `owns`, `controls`, or `related_to` type. The initial code-owned catalogue is:

1. `equity_interest` — a direct equity interest from holder to investee. A percentage in basis
   points is mandatory. It does not imply voting power, governance control, primary operation, or
   consolidation.
2. `governing_body_appointment` — a direct right to appoint or remove members of a governing body,
   grounded in a governing instrument. It does not imply equity ownership or consolidation.
3. `statutory_control` — direct power grounded in legislation or a regulator's formal act. It does
   not imply equity ownership.
4. `contractual_control` — direct power grounded in a contract. It does not imply ownership or
   accounting consolidation.

Every relationship is directional, tenant-qualified, effective-dated, supported by a bounded
non-sensitive evidence reference, and explicit about its basis. Cycles and reciprocal edges are
permitted because cross-holdings and reciprocal arrangements can be real; no transitive control or
aggregate percentage is inferred by the platform. A later action may end or correct a relationship
without rewriting its identity or evidence history.

### Primary consolidation parentage

The first `primary_consolidation_parent` is only a tenant's explicit **management-reporting
navigation choice**. It is not an IFRS, IPSAS, US GAAP/GASB, tax, statutory, or regulator-approved
consolidation conclusion. One child has at most one active primary parent, roots are allowed, and
same-tenant compound references plus serialized direct, indirect, and concurrent cycle checks are
mandatory. This parentage never creates ownership, control, authority, module activation,
placement, access, configuration inheritance, or legal responsibility.

If statutory or framework-specific reporting later needs several simultaneous consolidation
scopes, it must receive a separate accounting-owned model rather than overloading this default.

### Corporate units

A `CorporateUnit` is a stable internal organizational identity belonging to exactly one legal
entity. Its name is revisioned separately from its UUID. It may have zero or one canonical parent
inside the same legal entity, allowing several roots and arbitrary reviewed depth. A corporate
unit is not a legal entity, educational institution, site, cost centre, authority scope, or ledger
segment merely because it is visible in the structure.

Slice 2.1-C1 starts with registration and exact reads. End, move, correction, import, and public
workflow actions remain later bounded work.

### Required controls

- All state, evidence, queries, and events are tenant-qualified and use trusted placement.
- Named actions, exact idempotency, current module gates, tenant-defined capabilities, audit, and
  transactional outbox remain mandatory.
- Compound foreign keys reject cross-tenant endpoints and cross-legal-entity corporate parents.
- Relationship evidence references contain no documents, secrets, names, registration numbers,
  learner data, or financial amounts.
- Events contain stable identifiers and minimal type/state facts, never names, percentages,
  evidence references, or a relationship graph.
- Exact reads do not authorize collection or recursive enumeration.

## Consequences

This decision supports common group, charity, public-sector, trust, and multi-school structures
without claiming that one ownership percentage determines control or consolidation. It creates
more explicit records and requires downstream finance features to select an approved reporting
basis rather than infer one.

The model is intentionally incomplete. It does not yet represent beneficial ownership,
partnership interests, guarantees, agency, property holding, employment responsibility, funding,
contracting, data-control responsibility, joint arrangements, minority protections, or
jurisdiction-specific company and charity registers.

## Security, privacy, operability, and migration effects

Relationship, parentage, unit, audit, outbox, and idempotency state remains tenant-qualified and
writer-owned. Compound foreign keys reject cross-tenant endpoints; corporate-unit parents must
also belong to the same legal entity. Exact reads disclose no collection, descendant count, or
cross-tenant existence signal. Events exclude names, percentages, and evidence references.

Management-reporting parentage is serialized per tenant before cycle evaluation. Database checks
and immutable-fact triggers defend alternate write paths as well as the application boundary.
Generated migrations and snapshots remain reviewable, and rollback refuses to erase committed
state or durable evidence. No real-data import or legacy mapping is authorized by this ADR.

## Conditions

1. This authorization is synthetic L1 only: no real records, migration, public route, pilot, or
   deployment.
2. The focused slice must prove positive, denied, missing-context, cross-tenant, alternate-write,
   exact-replay, changed-replay, rollback, lifecycle, and consolidation-cycle cases.
3. The December 2026 corporate-governance/finance review becomes a validation and revision gate.
   It remains mandatory before L2, real data, migration, external reporting, or any claim of
   jurisdictional/accounting correctness.
4. A finding that changes relationship meaning, consolidation semantics, or corporate-unit
   identity requires this ADR to be superseded before the affected expansion.

ADR 0025 C25-03 through C25-06 remain unchanged.

## Validation evidence

The [Slice 2.1-C1 evidence](../phase-2/legal-structure-foundation-evidence.md) records migration
review, relationship and parentage semantics, tenant and capability denials, alternate-write
protection, exact replay, rollback, lifecycle denial, concurrent cycle checks, and repeatable demo
data. Complete repository verification remains an exit condition rather than evidence supplied by
this decision alone.

- [IFRS 10 overview](https://www.ifrs.org/issued-standards/list-of-standards/ifrs-10-consolidated-financial-statements/)
- [IPSAS 35 overview](https://www.ipsasb.org/publications/ipsas-35-consolidated-financial-statements-1)
- [GASB Codification sections 1100–3100](https://storage.gasb.org/Sections_1100-3100.pdf)
- [England Academy Trust Handbook 2026](https://www.gov.uk/government/publications/academy-trust-handbook/academy-trust-handbook-2026-effective-from-1-october-2026)
- [South African Schools Act compilation](https://www.education.gov.za/LinkClick.aspx?fileticket=zdcANx8EF8Q%3D&forcedownload=true&mid=1828&portalid=0&tabid=185)
- [Australian Charities and Not-for-profits Commission legal structures](https://www.acnc.gov.au/for-charities/start-charity/you-start-charity/legal-structure)
- [ACNC group-reporting policy](https://www.acnc.gov.au/about/corporate-information/corporate-policies/commissioners-policy-statement-group-reporting-joint-and-collective)

## Fallback and exit cost

If external review changes a relationship meaning, keep the affected action closed and supersede
this ADR before migration or real use. The synthetic rows can be discarded with the local test or
demo database. No production consumer, public contract, import mapping, or real record depends on
the model, so the current exit cost is limited to code, generated migration/snapshot artifacts,
tests, and synthetic fixtures.

## Review triggers

- A real jurisdiction requires a relationship not expressible without a generic edge.
- A professional review finds that a type label overstates legal or accounting meaning.
- A reporting basis needs more than one simultaneous consolidation scope.
- Corporate-unit parentage must cross legal-entity boundaries.
- A proposed relationship would change access, reporting, placement, configuration, or module
  lifecycle implicitly.

## Related records

- [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [Institutional-structure decision evidence](../phase-2/institutional-structure-decision-evidence.md)
- [Slice 2.1-B evidence](../phase-2/legal-entity-foundation-evidence.md)
- [Slice 2.1-C1 evidence](../phase-2/legal-structure-foundation-evidence.md)
- [Threat model](../security/threat-model.md)
