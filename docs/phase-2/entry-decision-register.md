# Phase 2 entry decision register

- Status: Phase 2.0 conditionally approved and closed at L1; Slices 2.0-B, 2.0-C, internal D.2a
  through D.2c, the bounded D.3 public-session adapter, and the minimal Slice 2.1-B legal-entity
  proof have synthetic evidence; 2.0-E is deferred under dated C25-05 and L2 remains gated
- Prepared on: 2026-09-26
- Last reviewed: 2026-09-28
- Accountable owner: François — Project Owner and interim Security/Privacy Owner
- Delivery owners: Product and platform engineering
- Review trigger: any gate closure, owner assignment, accepted or superseding ADR, deployment
  selection, or entry into a later Phase 2 slice

## Decision effect

This register conditionally approves and closes Phase 2.0 at the L1 synthetic-entry boundary. It
reconciles the current Phase 0 and Phase 1 conditions against the first
learning-institution-module candidate and makes every later blocking effect explicit. Phase 2.0-E
is a dated deferred condition; selected-deployment qualification, real data, pilot, and production
release remain later L2 through L4 gates. This closure does not claim that they are complete.

`Satisfied` means the cited evidence closes the gate for the exact candidate and level named.
`Partial` means useful evidence exists but a binding condition remains. `Open` means the dependent
release level is prohibited. A planned test, owner role, local synthetic result, or future ADR is
not completion evidence.

The 2026-09-26 project-owner direction authorizes the bounded sequence in the Phase 2 proposal.
Authorization is therefore not an open gate. Each slice may start when the sequence permits and
its stated entry conditions are satisfied. ADR 0025's 2026-09-27 conditional acceptance makes only
the minimal synthetic Slice 2.1-B corporate/legal aggregate eligible for a separately recorded
entry disposition. That disposition is now recorded and the bounded proof passes; no
educational-structure persistence or Slice 2.1-C work is authorized yet.

The Project Owner's 2026-09-28 decision conditionally approves Phase 2.0 for planning and carries
2.0-E as a residual condition through 2026-12-15 or the first connected/public
institutional-structure gate, whichever is earlier. The condition requires expert/representative
comprehension and accountable product-experience disposition. It does not authorize implementation
or release of the connected workflow. If the review is not complete by the deadline, the condition
must be explicitly renewed, amended, or withdrawn.

## Release gate matrix

| Gate | Current evidence | Disposition | First level blocked | Accountable closure |
| --- | --- | --- | --- | --- |
| Bounded production-core baseline | Phase 1 is complete at Slices 1A through 1J-B, including neutral lifecycle drain/reactivation, internal delivery leases, supervised database-local consumption, durable receipts, and exact dead-letter replay. | Satisfied for starting L0 only. Phase 1 closure does not satisfy any later release-level gate; every later candidate must pass its own complete gate. | None for L0 | Platform engineering |
| Operational outbox, real consumer, replay, and module drain | Slice 2.0-B connects immutable stream positions, cursor paging/range replay, supervised module-aware consumers, atomic cursor advancement, inactive reconciliation, fail-closed reactivation, sanitized telemetry, recovery drills, and runbooks. | Satisfied for the provider-neutral local synthetic L1 foundation. Selected-deployment thresholds, restore, external effects, movement, and real-data review remain L3 gates. | None for L1 foundation | Platform engineering and operations, with security architecture |
| Temporal retention, erasure, migration, and recovery | ADR 0018 T1-A/T1-B/T1-C plus Slice 2.0-C provide executable TR-01 through TR-07 evidence, explicit local limits, retained-data migration refusal, PostgreSQL dump/restore, and governed projection convergence. On 2026-09-27, the accountable approver reviewed and approved all six residual risks after the complete repository gate had passed. | Satisfied for the neutral local synthetic L1 foundation; ADR 0018 is Accepted. Domain policy, selected-deployment qualification, independent review, downstream propagation, and TR-08 remain later or candidate-specific gates. | None for L1 foundation | Platform engineering, domain records owners, and the accountable approver |
| Linked corporate/legal and educational structure meaning and module boundary | Conditionally Accepted ADR 0025 records separate corporate/legal and educational structures, exact primary legal operation, the learning-institution operating-system direction, technical scenario/control/migration evidence, and the bounded G6 disposition. | C25-01 is satisfied for the completed minimal synthetic Slice 2.1-B proof. C25-02 blocks legal relationships/corporate units; C25-03/C25-04 block educational/operator persistence; C25-05 blocks connected/public structure experience; C25-06 blocks migration, real data, and L3. Open named reviews remain visible and are not treated as complete. | None for minimal 2.1-B; conditions block 2.1-C and later | Product Owner for the bounded decision; named corporate/finance, learning-institution, platform, product-experience, records, and security owners at their stated conditions |
| First learning-institution state-transition qualification | The minimal `organization.legal` release declaration, stable `LegalEntity`, immutable profile revisions, two named actions, and one exact read preserve tenant routing, lifecycle and capability gates, optimistic concurrency, exact idempotency, minimized audit, transactional outbox, rollback, and non-disclosure. | Satisfied for L1 by the Slice 2.1-B evidence. This does not qualify a public interface, relationship model, educational structure, migration, real data, or L2 release. | None for L1 | Platform engineering under the bounded Product Owner disposition; named corporate/finance ownership remains required before 2.1-C |
| Production identity and session chain | Accepted [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md) and its [decision review](identity-session-and-support-access-decision-review.md) establish a provider-neutral OIDC/gateway seam, protocol-qualified external-identity links, application-owned opaque sessions, writer-resolved tenant selection, bounded assurance, separate service identities, and optional separately gated SCIM provisioning. Accepted [ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md) and the [implementation evidence](identity-session-and-support-access-implementation-evidence.md) add the bounded provider-neutral callback/cookie adapter, current placement/session revalidation, origin/CSRF controls, logout, and checked contract. | Satisfied through bounded D.3 synthetic engineering. No real provider callback, provider credential, directory sync, enabled endpoint, selected-connection/deployment qualification, or L2 release exists. | L2 | Security architecture and platform engineering |
| Bounded support access | TM-03 and accepted ADRs 0029/0030 retain a non-impersonating, independently approved, one-tenant, purpose/ticket-bound, strongly assured, allowlisted grant lasting at most 60 minutes. The resource/action suite proves per-use recheck, revocation, minimized evidence, concurrency, rollback, and negatives; D.3 carries only one encrypted grant reference and returns safe real-actor/purpose/expiry/scope presentation state after writer validation. | Bounded D.3 adapter evidence is satisfied. The complete visible tenant-labelled accessible browser experience and deployment qualification remain 2.0-E/L2 gates. | L2 | Security architecture with product and platform engineering |
| Public browser/API contract | ADRs 0014, 0020, 0022, and 0023 remain conditional around their exact scopes. Accepted ADR 0030 selects one same-origin Next.js/Phoenix candidate, a host-only encrypted application cookie, server-owned context, thin REST/OpenAPI fallback, exact reads/named actions, and no public collection by default. The public session OpenAPI and generated TypeScript declarations are checked. | Public-session decision and bounded adapter contract satisfied. The first linked-structure action/read contract, accessible browser journey, module gates, conflict/degraded states, and any collection-specific ADR 0023 review remain open in 2.0-E. | L2 | Platform and web engineering, product experience, and security architecture |
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
| Page-limit edge adapter | Before the first public collection read in Slice 2.0-E/2.1-G | ADR 0023's policy is conditionally accepted. Classify the exact collection/task and prove enforced bounds, adversarial traversal resistance, cumulative-exposure controls, contract drift, and separate export denial before enabling the route. |
| Failure-header edge adapter | Before the production public error contract ships | Prove status, body, cache/retry headers, correlation, and non-disclosure against the production candidate. |
| OpenAPI contract modifier | Before generating the production client | Regenerate and review the byte-stable OpenAPI artifact and TypeScript client; use an explicit interface layer if the modifier is no longer bounded. |
| Retained-data migration choreography | Before the first retained-data contraction or cutover | Rehearse expand/backfill/validate/contract, locks, drain, monitoring, backup/restore, repair, and retained-history verification in the selected environment. |
| Resource descriptor and metadata validator | Before a production descriptor consumer, definition, or renderer | Re-run descriptor evolution, incompatible/stale/private/cross-tenant negatives, execution re-authorization, and security review for the institutional-structure consumer. |
| Tenant movement and non-HTTP routing | Before a real outbox consumer, durable routing registry, or movement operation | Prove authenticated transport identity, durable registry behavior, movement, reconciliation, rollback, stale/forged/missing context, recovery, and real adapters. Static placement is the fail-closed fallback. |

## Required decision records

| Boundary | Current governing position | Slice 2.0-A disposition |
| --- | --- | --- |
| Production identity, session, and support access | Accepted ADR 0029 supersedes ADR 0027's provider selection and defines provider-neutral qualified OIDC/gateway connections, application-owned sessions, explicit external-identity links, writer-resolved tenant context, separate service identities, separately gated provisioning, and non-impersonating support grants. Accepted ADR 0030 owns the public callback/cookie seam; ADR 0022 remains local qualification only. | D.2a through D.2c and bounded D.3 synthetic implementation are satisfied. Per-connection contractual/privacy, selected deployment, independent review, real data, and L2 release gates remain closed. |
| First public browser/API boundary | Accepted ADR 0030 selects the same-origin Next.js/Phoenix production candidate and keeps ADR 0023 non-enumeration binding. UI-1A remains local-only. | Decision complete. The checked session contract is implemented; the first business action/read contract and complete accessible browser evidence remain 2.0-E work after its linked-structure dependency passes. |
| Linked corporate/legal and educational structure | ADR 0025 is Conditionally Accepted for the stable logical direction. Technical scenario, control, migration, refreshed prototype, and focused G5 evidence plus the bounded G6 decision are recorded; named reviews remain explicit conditions. | Slice 2.1-A is conditionally closed and the minimal synthetic Slice 2.1-B passes C25-01. C25-02 through C25-06 block the first later slice or release that depends on each open review. |
| Deployment candidate | ADRs 0003 and 0017 define provider-neutral placement, availability, recovery, and routing contracts. | Unselected. Local PostgreSQL and browser evidence must not be relabelled as a deployment candidate. |

## Deployment and reviewer record

| Required record | Current value | Consequence |
| --- | --- | --- |
| Deployment candidate | Unselected | No L3 qualification, real data, pilot, or production claim |
| Independent security/privacy reviewer | Unassigned | No real Restricted data or pilot |
| Learning-institution-side records/governance owner | Unassigned | No real-data migration, records-policy acceptance, or pilot |
| Interim security/privacy owner | François, through the existing Phase 0 residual-risk boundary | May govern synthetic design and implementation evidence; does not provide independent review |
| Operational owner for dispatcher, replay, backup, and recovery | Unassigned for the selected environment | No operational outbox completion or deployment acceptance |

## Slice 2.0-A L1 exit disposition

Slice 2.0-A is closed for the L1 synthetic-entry boundary. Accepted ADRs 0029 and 0030 settle the
identity/session/support and public-boundary direction; Conditionally Accepted ADR 0025 settles the
first business-module direction with C25-01 through C25-06. The gate matrix records the exact level
at which each remaining item blocks.

The deployment candidate, independent security/privacy reviewer, institution-side records owner,
and complete 2.0-E deployment/browser evidence remain mandatory before L3 or at their earlier
stated gate. They are not being reported as complete, but they no longer prevent the minimal local
synthetic 2.1-B proof, whose entry and L1 exit disposition are now recorded.

Slices **2.0-D.2a through D.2c and the bounded D.3 public-session adapter are implemented with
synthetic evidence**. D.3 is not released at L2 and the endpoint is not enabled. Phase 2.0 is
conditionally approved at L1; Slice 2.0-E is its dated deferred condition. Its minimal persistence
dependency is complete, but C25-05 still prohibits the connected/public workflow until the named
expert/representative-comprehension and accountable product-experience dispositions are recorded,
no later than 2026-12-15 or the first affected gate. This does not reopen the L1 foundation closure
or weaken the completed identity and session foundation.

## Slice 2.1-B L1 entry and exit disposition

Entry and implementation are accepted only for the minimal synthetic boundary in C25-01. The
checked proof adds the `organization.legal` release declaration, stable tenant-qualified
`LegalEntity`, immutable official/display-name profile revisions, `register_legal_entity`,
`revise_legal_entity_profile`, and one exact current read. It adds no registration/jurisdiction
policy, relationship, corporate unit, educational structure, collection, public route, migration,
or real data.

The generated-and-reviewed migration, trusted writer/module/capability gates, optimistic
concurrency, exact replay, minimized audit/outbox, injected rollback, lifecycle denial,
cross-tenant and alternate-write negatives, and complete repository gate are recorded in the
[Slice 2.1-B evidence](legal-entity-foundation-evidence.md). C25-01 is satisfied. C25-02 through
C25-06 remain binding and no later Phase 2.1 slice starts through this disposition.

## Evidence references

- [Phase 0 binding later gates](../phase-0/README.md#binding-later-gates)
- [Phase 0 review record](../phase-0/review-record.md)
- [Ash bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md)
- [Phase 1 status](../phase-1/README.md)
- [Slice 1H-B lifecycle evidence](../phase-1/evidence/module-lifecycle-drain-reactivation.md)
- [Slice 1J-A outbox delivery evidence](../phase-1/evidence/outbox-delivery-lease.md)
- [Slice 1J-B supervised consumption and replay evidence](../phase-1/evidence/outbox-supervised-consumption-and-replay.md)
- [Slice 2.0-B operational outbox and module-drain evidence](operational-outbox-and-module-drain-evidence.md)
- [Slice 2.0-C temporal completion and recovery evidence](temporal-completion-and-recovery-evidence.md)
- [Temporal retention and recovery runbook](../operations/temporal-retention-and-recovery.md)
- [ADR 0026](../adr/0026-module-aware-outbox-cursors-and-reconciliation.md)
- [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md)
- [Superseded ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- [Identity, session, and support-access decision evidence plan](identity-session-and-support-access-decision-evidence.md)
- [Identity, session, and support-access decision review](identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access implementation evidence](identity-session-and-support-access-implementation-evidence.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Institutional-structure decision evidence plan](institutional-structure-decision-evidence.md)
- [Institutional-structure scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Institutional-structure security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Institutional-structure experience evidence](institutional-structure-experience-evidence.md)
- [Slice 2.1-B minimal legal-entity foundation evidence](legal-entity-foundation-evidence.md)
- [Temporal decision review](../architecture/temporal-records-decision-review.md)
- [UI-1A local bridge evidence](../phase-1/evidence/local-browser-core-bridge.md)
- [Threat model](../security/threat-model.md)
- [Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
