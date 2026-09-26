# Phase 2 entry decision register

- Status: In progress under authorized Slice 2.0-A
- Prepared on: 2026-09-26
- Accountable owner: François — Project Owner and interim Security/Privacy Owner
- Delivery owners: Product and platform engineering
- Review trigger: any gate closure, owner assignment, accepted or superseding ADR, deployment
  selection, or entry into a later Phase 2 slice

## Decision effect

This register starts Phase 2 at release level L0. It reconciles the current Phase 0 and Phase 1
conditions against the first learning-institution-module candidate and makes their blocking effect
explicit.

`Satisfied` means the cited evidence closes the gate for the exact candidate and level named.
`Partial` means useful evidence exists but a binding condition remains. `Open` means the dependent
release level is prohibited. A planned test, owner role, local synthetic result, or future ADR is
not completion evidence.

The 2026-09-26 project-owner direction authorizes the bounded sequence in the Phase 2 proposal.
Authorization is therefore not an open gate. Each slice may start when the sequence permits and
its stated entry conditions are satisfied. At the current evidence level, no persistent
`institution.structure` resource or module declaration may be added yet.

## Release gate matrix

| Gate | Current evidence | Disposition | First level blocked | Accountable closure |
| --- | --- | --- | --- | --- |
| Bounded production-core baseline | Phase 1 implements Slices 1A through 1J-B, including neutral lifecycle drain/reactivation, internal delivery leases, supervised database-local consumption, durable receipts, and exact dead-letter replay. | Satisfied for starting L0 only. Every later candidate must pass its own complete gate. | None for L0 | Platform engineering |
| Operational outbox, real consumer, replay, and module drain | Slice 1J-B adds an explicitly supervised database-local consumer and exact replay, while Slice 1H-B models drain and cursors. Replay ranges/cursors, real module drain/reactivation integration, selected-environment recovery/convergence, production telemetry, and runbooks remain open. | Partial; close the remaining contract through Slice 2.0-B under the authorized sequence. | L1 | Platform engineering and operations, with security architecture |
| Temporal retention, erasure, migration, and recovery | ADR 0018 T1-A/T1-B/T1-C provide neutral physical, action, fact, and reconciliation evidence. TR-06, TR-07, performance/migration/recovery limits, and final accountable review remain open. | Open; close through Slice 2.0-C under the authorized sequence. | L1 | Platform engineering, domain records owners, and the accountable approver |
| Institutional-structure meaning and module boundary | ADR 0025 records the learning-institution operating-system direction and proposes recursive institutional units, canonical parentage, sites, and affiliations. It is still Proposed; no cross-context scenario review, correction/retention disposition, hierarchy-navigation evidence, threat-model proof, or representative domain-owner approval exists. | Open; Slice 2.1-A may proceed as L0 decision work, but ADR 0025 must be accepted before any Slice 2.1-B persistence. | L1 | Learning-institution operations domain owner, product engineering, platform engineering, and security/privacy review |
| First learning-institution state-transition qualification | Accepted ADRs require the first real named actions to preserve tenant routing, authorization, constraints, optimistic concurrency, exact idempotency, audit, outbox, rollback, and non-disclosure. Neutral proofs do not close the production-candidate gate automatically. | Open until Slice 2.1-B's foundation and ADR entry conditions are satisfied and its exact action/resource evidence passes. | L1 | Platform engineering and learning-institution operations domain owner |
| Production identity and session chain | `ExecutionContext` and UI-1A prove only trusted internal context and a local synthetic token. No identity provider, account linking, session lifecycle, tenant selection, assurance, credential recovery, key rotation, or service identity is selected. | Open; UI-1A must not be promoted. Decide through an accepted identity/session ADR in Slice 2.0-D. | L2 | Security architecture and platform engineering |
| Bounded support access | TM-03 defines explicit tenant, assurance, purpose, expiry, least privilege, and enhanced audit. No support-grant resource, action, visible elevated-session experience, revocation path, or negative suite exists. | Open; decide and prove with the production identity/session boundary in Slice 2.0-D. | L2 | Security architecture with product and platform engineering |
| Public browser/API contract | ADRs 0014 and 0020 are conditionally accepted. UI-1A is loopback-only, read-only, synthetic, and governed by proposed ADR 0022. ADR 0023's collection/export boundary is still Proposed. | Open; accept or supersede the applicable public-boundary records and prove a checked production-candidate contract in Slice 2.0-E. | L2 | Platform and web engineering, product experience, and security architecture |
| Selected deployment and operational qualification | No hosting or deployment environment is selected. Existing capacity, admission, movement, failover, and restore evidence is local and provider-neutral; it is not deployment qualification. | Open. Selection must name topology, region/residency, identities, secrets, edge/TLS, database, queues, storage, observability, backup, restore, rollback, and operating owners. | L3 | Project owner, platform engineering, operations, and security architecture |
| Independent security/privacy review | The Phase 0 threat model is an accepted engineering baseline. François remains the interim owner; no independent reviewer is named. | Open; real Restricted data and a pilot remain prohibited. | L3 | Project owner must name the independent reviewer; the reviewer owns the recorded challenge and residual-risk disposition |
| Learning-institution records ownership | Phase 0 requires an institution-side records/governance owner before a pilot. None is named in the repository. | Open; real-data migration, retention, correction, and pilot decisions remain prohibited. | L3 | Project owner must name the learning-institution-side records owner |
| General-availability operating envelope | No production release review, support model, service envelope, rollout decision, or general-availability evidence exists. | Open; L3 completion never implies L4. | L4 | Project owner with product, platform, operations, security/privacy, and learning-institution records owners |

## Phase 0 condition reconciliation

All eight Ash conditions remain candidate-specific. A neutral or local proof does not silently
qualify the first learning-institution module or its public client.

| Existing condition | Phase 2 closure point | Current treatment |
| --- | --- | --- |
| Transaction-backed non-atomic action | Before the first Slice 2.1-B state transition uses the pattern | Re-run positive, invalid, stale, concurrent, and injected-rollback evidence for each production candidate action; use the recorded Phoenix/Ecto domain-service fallback if the properties cannot be preserved. |
| Dynamic-repository SQL | Before any learning-institution-module adapter is promoted | Keep SQL inventoried and internal to the trusted writer seam; prove tenant routing, authorization, rollback, concurrency, and source inventory. |
| Page-limit edge adapter | Before the first public collection read in Slice 2.0-E/2.1-G | Resolve the ADR 0023 boundary for the exact classification and task; prove enforced and documented bounds plus cumulative-exposure controls. |
| Failure-header edge adapter | Before the production public error contract ships | Prove status, body, cache/retry headers, correlation, and non-disclosure against the production candidate. |
| OpenAPI contract modifier | Before generating the production client | Regenerate and review the byte-stable OpenAPI artifact and TypeScript client; use an explicit interface layer if the modifier is no longer bounded. |
| Retained-data migration choreography | Before the first retained-data contraction or cutover | Rehearse expand/backfill/validate/contract, locks, drain, monitoring, backup/restore, repair, and retained-history verification in the selected environment. |
| Resource descriptor and metadata validator | Before a production descriptor consumer, definition, or renderer | Re-run descriptor evolution, incompatible/stale/private/cross-tenant negatives, execution re-authorization, and security review for the institutional-structure consumer. |
| Tenant movement and non-HTTP routing | Before a real outbox consumer, durable routing registry, or movement operation | Prove authenticated transport identity, durable registry behavior, movement, reconciliation, rollback, stale/forged/missing context, recovery, and real adapters. Static placement is the fail-closed fallback. |

## Required decision records

| Boundary | Current governing position | Slice 2.0-A disposition |
| --- | --- | --- |
| Production identity, session, and support access | Trusted-context contracts and TM-03 exist, but no production identity/session decision exists. Proposed ADR 0022 explicitly limits its token to local qualification. | Missing. A new ADR or explicit superseding set is required before Slice 2.0-D implementation. No provider is selected by this register. |
| First public browser/API boundary | ADRs 0014 and 0020 are conditional; ADRs 0022 and 0023 are Proposed and do not authorize a production route. | Missing production-candidate acceptance. The later decision must keep page/query bounds, named actions, stable errors, idempotency, field policy, module gates, and tenant non-disclosure explicit. |
| Recursive institutional structure | ADR 0025 records the approved product direction but remains a Proposed data-model and domain-boundary decision. | Missing acceptance evidence. Slice 2.1-A must obtain accountable acceptance for ADR 0025 before persistence. |
| Deployment candidate | ADRs 0003 and 0017 define provider-neutral placement, availability, recovery, and routing contracts. | Unselected. Local PostgreSQL and browser evidence must not be relabelled as a deployment candidate. |

## Deployment and reviewer record

| Required record | Current value | Consequence |
| --- | --- | --- |
| Deployment candidate | Unselected | No L3 qualification, real data, pilot, or production claim |
| Independent security/privacy reviewer | Unassigned | No real Restricted data or pilot |
| Learning-institution-side records/governance owner | Unassigned | No real-data migration, records-policy acceptance, or pilot |
| Interim security/privacy owner | François, through the existing Phase 0 residual-risk boundary | May govern synthetic design and implementation evidence; does not provide independent review |
| Operational owner for dispatcher, replay, backup, and recovery | Unassigned for the selected environment | No operational outbox completion or deployment acceptance |

## Slice 2.0-A remaining exit work

Slice 2.0-A is started, not complete. Its exit remains blocked until:

1. the production identity/session and support-access decision is accepted or an explicit
   fail-closed alternative is recorded;
2. the production public browser/API decision is accepted or superseded for the first journey;
3. a deployment candidate and the distinction between local and deployment evidence are recorded;
4. the independent security/privacy reviewer and learning-institution-side records owner required
   before L3 are named with their review points;
5. the gate matrix is reviewed by its accountable owners; and
6. the entry conditions for the next slice are recorded as satisfied before that slice crosses its
   release-level boundary.

Authorization is complete. While these exit items remain open, the accepted sequence permits the
Phase 2.0 foundation work and Slice 2.1-A L0 scenario/decision work described by the proposal, but
not Slice 2.1-B persistence or any higher release level.

## Evidence references

- [Phase 0 binding later gates](../phase-0/README.md#binding-later-gates)
- [Phase 0 review record](../phase-0/review-record.md)
- [Ash bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md)
- [Phase 1 status](../phase-1/README.md)
- [Slice 1H-B lifecycle evidence](../phase-1/evidence/module-lifecycle-drain-reactivation.md)
- [Slice 1J-A outbox delivery evidence](../phase-1/evidence/outbox-delivery-lease.md)
- [Slice 1J-B supervised consumption and replay evidence](../phase-1/evidence/outbox-supervised-consumption-and-replay.md)
- [Temporal decision review](../architecture/temporal-records-decision-review.md)
- [UI-1A local bridge evidence](../phase-1/evidence/local-browser-core-bridge.md)
- [Threat model](../security/threat-model.md)
- [Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
