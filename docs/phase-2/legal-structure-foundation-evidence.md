# Slice 2.1-C1 bounded legal-structure foundation evidence

- Status: Bounded implementation and production-core gate passing; complete repository gate
  blocked by stale clean-checkout evidence for the changed Makefile
- Date: 2026-10-03
- Governing decisions: Conditionally Accepted ADRs 0025/0031; Accepted ADR 0032 for the completed C25-02 contract
- Module: `organization.legal` version `1.1.0`
- Boundary: private production-core candidate using synthetic local data only

## Accountable entry disposition

On 2026-10-03 the Project Owner directed the project to continue with a best-judgement,
cross-country education-governance and finance model. ADR 0031 records that direction without
inventing a qualified reviewer or representing the analysis as legal, tax, audit, accounting, or
jurisdiction-specific certification.

ADR 0031 originally superseded ADR 0025 C25-02 only for this synthetic L1 Slice 2.1-C1.
[ADR 0032](../adr/0032-c25-02-delegated-contract-acceptance.md) and the
[completed corporate/finance review](c25-02-corporate-governance-finance-review.md) now close
C25-02 under explicit delegated Project Owner authority. That review excludes the current code
and migration as domain acceptance evidence; implementation conformity and exit verification
remain separate obligations. External
corporate-governance and finance validation remains due by 2026-12-15 and is mandatory before L2,
real records, migration, external financial reporting, pilot, deployment, or a claim of
jurisdictional/accounting correctness. ADR 0025 C25-03 through C25-06 remain unchanged.

## Cross-country decision

Official accounting and education-governance evidence shows that legal ownership, governance
power, public authority, school operation, and financial consolidation cannot safely be collapsed
into one relationship:

- IFRS 10 makes control the basis for consolidation and requires judgement about power, variable
  returns, and the ability to affect those returns.
- IPSAS 35 assesses public-sector control through power and the ability to influence benefits.
- US governmental reporting can include legally separate component units and distinguishes
  blended from discretely presented units.
- England can operate several academies within one legal academy trust.
- South African public schools have statutory school-fund and governing-body responsibilities
  that are not ordinary equity ownership.
- Australian charities and schools may use several legal forms and separate group-reporting
  arrangements.

The first code-owned direct relationship catalogue is therefore limited to:

| Type | Meaning | Required basis/attribute | Explicit non-inference |
| --- | --- | --- | --- |
| `equity_interest` | Direct legal equity interest from holder to investee | `registered_equity`; 1–10,000 basis points | No voting control, operation, or consolidation |
| `governing_body_appointment` | Direct appointment/removal right grounded in a governing instrument | `governing_instrument`; no percentage | No equity ownership or consolidation |
| `statutory_control` | Direct power grounded in legislation or a formal regulatory act | `statute`; no percentage | No equity ownership |
| `contractual_control` | Direct power grounded in a contract | `contract`; no percentage | No ownership or accounting consolidation |

Reciprocal relationships and graph cycles are allowed because cross-holdings and reciprocal
arrangements may exist. The platform performs no transitive ownership/control inference and no
percentage aggregation.

The optional primary consolidation parent is separately represented and fixed to
`management_reporting`. It is a navigation and management-reporting input only, not an IFRS,
IPSAS, US GAAP/GASB, tax, statutory, or regulator-approved conclusion. One active parent per child,
several roots, same-tenant endpoints, and serialized direct/indirect/concurrent cycle prevention
are enforced.

A corporate unit belongs to exactly one legal entity and may have one canonical parent inside that
same entity. Its UUID survives naming changes. It is not automatically a legal person,
educational institution, site, cost centre, ledger segment, authority scope, reporting scope,
configuration scope, module scope, or placement scope.

## Implemented boundary

The domain adds four tenant-owned Ash resources with denied generic resource actions:

- `LegalEntityRelationship`;
- `LegalEntityConsolidationParentage`;
- `CorporateUnit`; and
- `CorporateUnitProfileRevision`.

The private domain boundary adds three named writes:

- `establish_legal_entity_relationship`;
- `set_primary_consolidation_parent`; and
- `register_corporate_unit`.

It also provides exact reads for one relationship, one child's management-reporting parentage,
and one corporate unit. There is no collection, graph, descendant, or recursive public read.

The actions use trusted actor/tenant/placement context, the current writer, module release,
entitlement and activation, tenant-defined `organization.legal.relationships.manage`,
`organization.legal.corporate_units.manage`, and exact-read capabilities, deterministic request
binding, exact replay, minimized audit, and transactional outbox evidence.

## Migration review

AshPostgres generated the tables, indexes, checks, compound endpoint references, and snapshots.
Manual review corrected the generated corporate-unit self-reference order: the compound
`(id, legal_entity_id, tenant_id)` destination index is created before the optional parent foreign
key. `MATCH SIMPLE` permits roots while still requiring a non-null parent to match the same tenant
and legal entity.

Database controls include:

- non-null tenant keys and compound same-tenant legal-entity endpoints;
- closed relationship type/basis/percentage consistency checks;
- distinct relationship and consolidation endpoints;
- one management-reporting parent per child;
- corporate parentage constrained to the unit's exact legal entity;
- immutable Slice 2.1-C1 facts and profile history; and
- rollback refusal after state or durable evidence exists.

## Executable evidence

The focused suite proves:

- all four relationship meanings with exact replay and exact reads;
- percentage absence from non-equity types;
- changed-request idempotency conflict and minimized events without percentage/evidence content;
- denied capability and non-disclosing cross-tenant endpoints;
- one management-reporting parent, several roots, exact replay, and direct/indirect cycle denial;
- tenant-serialized concurrent opposite-parent attempts with exactly one winner;
- root and nested corporate units with stable IDs and exact reads;
- cross-legal-entity and cross-tenant parent rejection at action and database boundaries;
- immutable alternate-write rejection;
- late-failure rollback of relationship, audit, outbox, and idempotency claim; and
- module-inactive denial while committed state remains retained.

Focused verification on 2026-10-03:

| Check | Result |
| --- | --- |
| Test-environment migration | Passed |
| Empty temporary database migration | Passed from the first migration through 2.1-C1; temporary database removed afterward |
| Ash migration/snapshot drift check | Passed |
| Focused `organization_legal` suite | Passed: 14 tests |
| Production-core `make check-core` | Passed: formatting, compile, API and migration drift, strict lint, dependency audit, type analysis, 186 tests, and whitespace |
| `make legal-demo`, repeated against the same database | Passed: stable 6 entities, 4 direct relationships, 3 management-reporting parentages, and 6 corporate units |
| Complete repository `make check` | Failed in its first documentation step: at execution, concurrent untracked ADR 0032 referenced a missing review and was absent from the ADR index. A subsequent C25-02 documentation check resolves those missing-review/index issues. The latest `make check` still stops at stale clean-checkout evidence for the changed Makefile; later repository suites were not run by either command |

## Demonstration data

`make legal-demo` now retains the six original legal entities and adds:

- 100% direct equity from `LE-GROUP` to `LE-OPS`;
- two separate 50% interests from `LE-GROUP` and `LE-JOINT` to `LE-NEW-OPS`, proving joint
  interests are a graph rather than a tree;
- one governing-body appointment relationship to `LE-PROPERTY`;
- management-reporting parentage for `LE-OPS`, `LE-PROPERTY`, and `LE-NEW-OPS` under `LE-GROUP`;
  and
- six corporate units, including nested finance and governance units under shared services.

Fixed action, idempotency, and causation identifiers make reruns exact replays. Names,
percentages, and evidence references remain absent from outbox events. The demo contains no real
records, educational structure, primary-operator workflow, public route, migration, pilot, or
deployment.

## Deferred boundary

Slice 2.1-C1 did not implement ending/correcting a relationship, moving/revising/closing a
corporate unit, changing management-reporting parentage, framework-specific consolidation scopes,
beneficial ownership, partnership interests, guarantees, property/employment/funding/contracting
responsibility, data-control responsibility, joint arrangements, registry integration, or
financial calculations.

[ADR 0033](../adr/0033-append-only-legal-structure-lifecycle-foundation.md) and the
[Slice 2.1-C2a evidence](legal-structure-lifecycle-evidence.md) now add only append-only direct
relationship ending and corporate-unit name-profile revision. Every other C1 deferral remains.

## References

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0031](../adr/0031-bounded-cross-jurisdiction-legal-structure-foundation.md)
- [ADR 0033](../adr/0033-append-only-legal-structure-lifecycle-foundation.md)
- [Phase 2 entry register](entry-decision-register.md)
- [Slice 2.1-B evidence](legal-entity-foundation-evidence.md)
- [IFRS 10 overview](https://www.ifrs.org/issued-standards/list-of-standards/ifrs-10-consolidated-financial-statements/)
- [IPSAS 35 overview](https://www.ipsasb.org/publications/ipsas-35-consolidated-financial-statements-1)
- [GASB Codification sections 1100–3100](https://storage.gasb.org/Sections_1100-3100.pdf)
- [England Academy Trust Handbook 2026](https://www.gov.uk/government/publications/academy-trust-handbook/academy-trust-handbook-2026-effective-from-1-october-2026)
- [South African Schools Act compilation](https://www.education.gov.za/LinkClick.aspx?fileticket=zdcANx8EF8Q%3D&forcedownload=true&mid=1828&portalid=0&tabid=185)
- [Australian charity legal structures](https://www.acnc.gov.au/for-charities/start-charity/you-start-charity/legal-structure)
- [ACNC group-reporting policy](https://www.acnc.gov.au/about/corporate-information/corporate-policies/commissioners-policy-statement-group-reporting-joint-and-collective)
