# Institutional-structure security, migration, and temporal review

- Status: Engineering design evidence complete; accountable G3 and G4 reviews remain open
- Date: 2026-09-27
- Gates: ADR 0025 G3 and G4
- Scope: L0 control design and synthetic compare-only fixtures; no production migration or data
- Reviewers still required: Security/privacy, platform engineering, named institutional-structure
  domain owner, and records/migration review

## Security and privacy treatment matrix

This matrix turns TM-17 and AC-18 into explicit failure behavior and later executable obligations.
It may support an L0 decision review; it does not mark the threats mitigated in running software.

| Challenge | L0 control decision | Failure response | Mandatory executable proof and owner |
| --- | --- | --- | --- |
| Cross-tenant parentage, site, affiliation, history, or alias | Every identity and relationship carries the same non-null trusted tenant; compound references cannot cross it. | Stable non-disclosing denial before mutation; no foreign existence signal. | Slice 2.1-B/E database and action negatives — platform engineering |
| Direct or indirect cycle | Canonical parentage is a forest; the authoritative writer checks reachability while holding tenant-scoped serialization. Database enforcement or an equivalent serialized invariant is required. | Stable conflict; no partial parentage, audit, or outbox write. | Slice 2.1-C direct, indirect, alternate-write, rollback, and concurrency tests — platform engineering |
| Racing reciprocal moves | Moves serialize within the affected tenant and compare exact expected versions. Both racing writes cannot commit a cycle. | At most one safe commit; the other receives a stable conflict. | Slice 2.1-C real PostgreSQL race proof — platform engineering |
| Visible ancestor or selected unit treated as authority | Structure resolution and grant resolution are separate. The server derives actor, tenant, and allowed exact or descendant scope independently of the selector. | Deny without revealing hidden descendants or counts. | Slice 2.1-G direct-interface and browser tests — security/privacy and web engineering |
| Parent visibility used to enumerate descendants | Reads are named and task-scoped, with server-derived root/depth/result bounds and cumulative-exposure controls under ADR 0023. | Refuse generic traversal and return no hidden identifiers, totals, or existence differences. | Slice 2.1-C/G adversarial traversal and cumulative-exposure suite — security/privacy |
| Move widens an access scope, report, or integration | Every consumer registers an impact evaluator. The writer previews exact old/new parentage and revalidates affected explicit scopes before commit. | `unknown` or unsafe reconciliation blocks the move. | Slice 2.1-C/F move, reconciliation, and unknown-consumer negatives — domain and platform engineering |
| Parent configuration, terminology, branding, calendar, module, or placement applies implicitly | Each meaning uses a separate explicit versioned adoption or owning lifecycle contract. No resolver may fall back to parentage. | Missing explicit adoption returns not configured/not entitled; it never inherits. | Owning-module tests before the first adoption ships — owning module and platform engineering |
| Event, cache, report, or path projection becomes hierarchy authority | Events contain stable IDs and minimal change facts. Every consumer validates current tenant routing; projections are rebuildable and non-authoritative. | Stale/missing route or incompatible consumer stops delivery/reconciliation. | Slice 2.1-F replay, restore, stale-route, and convergence tests — platform engineering and operations |
| Close or move hides retained history | Current and historical reads are separate named capabilities; exact UUID references remain valid within the retention contract. | Current navigation may omit closed units, but authorized exact/history reads remain explicit and attributable. | Slice 2.1-F retention, hold, erasure, export, and restore tests — records owner and security/privacy |

### Negative-test specification

The later executable suite must include cross-tenant identifiers on every relationship, missing
tenant/actor/capability/purpose, guessed hidden units, selector tampering, direct and indirect
cycles, reciprocal concurrent moves, stale expected versions, exact replay and changed-request
idempotency, injected rollback across state/audit/outbox, unknown impact consumers, denied exact and
descendant scopes, traversal by changing roots/depth/search/sort, and alternate writers that bypass
the named action. A positive test does not close its corresponding negative.

## Synthetic migration fixtures

The following compare-only rows model two materially different source shapes. `snapshot` is source
evidence, not an effective date. No row authorizes a write.

### Fixture A — generic enterprise organization tree

| Source evidence | Proposed target | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| `erp-a@2026-09-01`, company `COMP-01`, no parent | `institution` root with new UUID; source alias retained | Company may also be a legal entity | Require explicit institutional-domain confirmation; do not infer legal-entity equivalence. |
| `erp-a@2026-09-01`, department `DEP-10`, parent `COMP-01`, code `LS` | `organizational_unit` below confirmed root | Ordinary contained academic unit | Map only after parent confirmation; code is current sibling-scoped. |
| `erp-a@2026-09-01`, branch `BR-2`, parent `COMP-01`, address present | Unresolved | Likely physical site represented as organization | Reconcile as `Site` plus association; do not create a unit to preserve the source tree. |
| `erp-a@2026-09-01`, department `DEP-20`, parents inferred from two default tables | Unresolved affiliation or bad source | Several candidate parents | Record both evidence paths; no last-write-wins and no canonical parent until reviewed. |
| `erp-a@2026-09-01`, user default `COMP-01` | No structural relationship | Implicit source access/default assumption | Never import as access, active context, or placement. |

### Fixture B — tertiary hierarchy

| Source evidence | Proposed target | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| `tertiary-b@2026-08-31`, institution `UNI-1`, no parent | `institution` root with new UUID; alias retained | Stable root observation only | Import as baseline if domain owner confirms; do not invent an earlier start date. |
| `tertiary-b@2026-08-31`, schools `SCH-A` and `SCH-B`, parent `UNI-1` | Two `organizational_unit` children | Valid canonical containment | Preserve exact source parent evidence and mapping revision. |
| `tertiary-b@2026-08-31`, departments `DEP-CS-A` and `DEP-CS-B`, code `CS`, different schools | Two `organizational_unit` children | Repeated code under different parents | Valid; lookup requires UUID or exact parent/root scope. |
| `tertiary-b@2026-08-31`, programme `PROG-J`, references both schools | Typed affiliation candidate, not a unit | Matrix academic relationship | Domain review must select an affiliation type and endpoints; never add two parents. |
| `tertiary-b@2026-08-31`, department `DEP-X`, parent `DEP-Y`; `DEP-Y`, parent `DEP-X` | No target relationship | Source cycle | Quarantine both parent edges and report the cycle; identities may be staged only after reconciliation. |
| `tertiary-b@2026-08-31`, faculty `FAC-Z`, missing parent `UNI-9` | Unresolved | Missing/foreign source parent | No fabricated root or guessed tenant; require an attributable reconciliation decision. |

Each future migration ledger row must preserve source system, snapshot, source identifier, raw
parent evidence or its digest, source type, site/default/access evidence, mapping revision, target
UUID when one is approved, disposition, reviewer, and decision time. Import time is not the source
effective time. Unverifiable prior organization is represented as one baseline observation.

## Temporal, correction, and retention disposition

| Meaning | ADR 0018 classification | L0 decision | Safe synthetic and real-data boundary |
| --- | --- | --- | --- |
| Unit identity | Stable aggregate identity | UUID is immutable and never replaced by profile, code, parent, site, or status change. | Synthetic IDs only at L0. |
| Unit profile | Revisioned durable state after first publication | Draft changes may be mutable; publication and correction create immutable successor revisions with writer-assigned UTC `recorded_at`. Current and exact-revision reads are required; recorded-time reads are deferred. | Real classification, retention duration, and correction reasons require the named domain/records owner. |
| Canonical parentage | Effective-dated durable relationship | Institution-local `Date` precision with stored IANA time zone; inclusive start/exclusive end; at most one active parent; a move closes one interval and opens another atomically. Corrections name the exact prior revision and never rewrite it. | Unknown source dates create a baseline at the observed snapshot, not historical intervals. |
| Unit/site association | Effective-dated relationship | Institution-local `Date` precision; many-to-many; any primary-site role is explicit and non-overlapping for the owning unit when used. | No site association creates a parent, access scope, or placement. |
| Affiliation | Effective-dated typed relationship | Direction, endpoint kinds, cardinality, cycle policy, and closure are code-owned per accepted affiliation type. | Unknown type or lifecycle remains unresolved rather than becoming a generic graph edge. |
| Closure | Named durable transition | Effective local date; preserves UUID and retained references. Reopening or supersession requires a later accepted action contract. | Closure is not erasure and does not silently remove history. |
| Audit, outbox, migration, projection | Separate evidence contracts | Minimized audit, minimal outbox facts, source-stamped provenance, and rebuildable projections never substitute for domain history. | No restricted payloads in fixtures, logs, events, or committed evidence. |

The L0 classification is **synthetic-only**. Before any real institutional data, the named domain
and records owners must set data classification, retention start, retention duration, legal-hold
behavior, export scope, and deletion/redaction outcome. Until then, real import is blocked and the
safest operational default is no production storage. Independent security/privacy review remains
mandatory before Restricted child data or an L3 pilot.

## G3 and G4 disposition

The control matrix, negative-test specification, two source-shape fixtures, ambiguity handling,
and temporal disposition are prepared. G3 and G4 are **not passed** until their named reviewers
record approval. All executable claims remain future slice obligations; no threat is marked
mitigated merely because its intended control is documented.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Decision evidence plan](institutional-structure-decision-evidence.md)
- [Scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
