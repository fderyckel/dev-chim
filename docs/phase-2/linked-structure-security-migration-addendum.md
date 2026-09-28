# Linked-structure security and migration addendum

- Status: Technical G3/G4 evidence prepared; named accountable reviews remain open
- Date: 2026-09-27
- Gates: ADR 0025 G3 and G4
- Scope: Control design, negative-test contract, compare-only mapping, and temporal disposition;
  no running mitigation, migration execution, persistent resource, or real data
- Accountable reviewers still required: Security/privacy, platform engineering, corporate
  governance/finance, educational-structure, and records/migration

## Purpose

This addendum completes the technical treatment for the linked scenarios in
[LS-01 through LS-10](linked-structure-scenario-addendum.md). It extends TM-17 and AC-18 without
claiming that a written control is an implemented mitigation.

The design uses relationship-specific rules. It does not apply one universal graph algorithm to
ownership, consolidation, corporate containment, educational containment, sites, authority,
reporting, or workflow.

## Relationship-policy matrix

| Relationship family | Endpoint and cardinality rule | Cycle rule | Temporal rule | Explicit non-effect |
| --- | --- | --- | --- | --- |
| Primary legal operation | One educational institution to one legal entity at an institution-local effective date; exactly one active interval before publication | Cycles do not apply because endpoints have different meanings | Inclusive start/exclusive end `Date` in the institution's stored IANA time zone; UTC `recorded_at`; predecessor closes and successor opens atomically | Does not grant access, rewrite downstream records, or create educational parentage; exact-time sources remain unresolved |
| Other legal responsibility | Exact code-owned endpoint kinds and cardinality per type; never a generic unvalidated responsibility edge | Defined per accepted type | Effective-dated when responsibility changes | Does not imply primary operation or another responsibility type |
| Legal ownership/control | Several code-owned typed edges may coexist; there is no generic ownership/control edge and type-specific attributes require domain review | Defined per relationship type; no universal rejection, allowance, or transitive inference | Effective-dated with attributable evidence | Does not imply consolidation, accounting control, operator status, authority, or another relationship type |
| Primary consolidation parent | Zero or one active parent per legal entity | Direct, indirect, and concurrent cycles rejected | Effective-dated; change preserves earlier intervals | Navigation/reporting input only; not legal ownership or report authorization |
| Corporate-unit membership | Exactly one active legal entity per published corporate unit | Cycles do not apply across the differently typed endpoints | Effective-dated; transfer preserves unit identity | Does not make the unit a legal person or operator |
| Corporate parentage | Zero or one active corporate parent within the same tenant and same effective legal entity | Direct, indirect, and concurrent cycles rejected | Effective-dated; move is atomic; legal-entity transfer reconciles incompatible parentage | Does not imply finance access, employment, workflow, educational parentage, or cross-entity management |
| Educational parentage | Zero or one active educational parent in the same tenant | Direct, indirect, and concurrent cycles rejected | Effective-dated; move is atomic | Does not imply legal accountability, access, reporting, calendar, site, or placement |
| Site association | Many-to-many between exact site and approved owning concept | No containment traversal or cycle meaning | Effective-dated; primary-site role, if used, is explicit | Does not create a structural parent, operator, or authority scope |
| Affiliation | Exact code-owned endpoint kinds and cardinality per type | Defined per accepted type | Effective-dated | Does not create a second canonical parent or programme/enrolment authority |

An implementation cannot introduce an untyped `relationship` row whose runtime label supplies
endpoint, cardinality, cycle, authority, or temporal meaning. Source evidence with unknown meaning
stays unresolved.

## TM-17 and AC-18 treatment matrix

| Challenge | Preventive design | Fail-closed result | Later executable proof |
| --- | --- | --- | --- |
| Cross-tenant endpoint, parent, operator, owner, site, or membership | Every row and foreign relation carries the tenant key; writer derives tenant from trusted context; compound constraints cover every permitted endpoint shape | Stable non-disclosing denial; no relationship, successful audit outcome, or outbox success fact | One positive plus foreign-tenant, missing-context, guessed-ID, and alternate-writer negatives for every relationship family |
| Missing or two active primary operators | Publication and operator-change action resolve the effective timeline on the writer; database/exclusion strategy prevents overlap | Draft or reconciliation may remain unresolved; publication and real operational attachment are refused | Gap, overlap, boundary-date, concurrent-transfer, rollback, and direct-write tests |
| Published operator transfer is self-approved or bypasses review | Transfer is a proposal followed by a different authorized approver by default; the explicit single-controller exception requires stronger actor assurance, reason, evidence, visible marking, and retrospective review | No interval change, successful audit outcome, or outbox success fact unless the ordinary or exception workflow resolves exactly | Same-actor denial, stale proposal, missing evidence, assurance failure, exception-marking, and retrospective-review tests |
| Operator evidence is missing, unverified, inaccessible, or copied into an unsafe channel | Structure stores classified metadata and a protected reference; publication and transfer effectiveness require current verification; documents remain under the approved records boundary | Draft may remain pending, but publication or transfer is refused; audit, event, log, and error content exposes no document or sensitive reference | Pending-verification, revoked-reference, unauthorized-read, stale-verification, log/event minimization, and alternate-writer tests |
| Future-effective transfer activates from stale approval or evidence | Effective-boundary writer revalidates type/jurisdiction freshness, legal-entity status, proposal and approvals, versions, and registered impacts | Activation is blocked with no interval, audit-success, or outbox-success write; post-effect revocation opens reconciliation without rewriting history | Evidence revoked before/after effect, entity closure, approver loss, stale version, changed impact, retry, and concurrent-activation tests |
| Post-effect operator invalidation is ignored or causes unsafe blanket shutdown | A separate accountability-under-review condition uses code-owned type/jurisdiction policy to classify actions, alert accountable administrators, and set escalation deadlines | Operator-dependent and unknown actions fail closed; policy-permitted essential teaching, safeguarding, attendance, and learner support remain available unless suspension is required; no implicit closure, transfer, or authority change | Policy matrix, unknown-action denial, essential-operation continuity, required-suspension, notification, deadline, and alternate-writer tests |
| Accountability review is dismissed without resolving the legal fact | No generic clear action exists; only reverify, approved transfer, ADR 0018 correction, or separate suspension/closure may resolve the condition | Warning and restrictions remain; no success audit or resolution event | Direct-dismissal, incomplete-outcome, stale-evidence, unauthorized-correction, and alternate-writer tests |
| Corporate unit assigned to two legal entities | Membership timeline permits one active legal entity | Conflict; no partial membership or parentage change | Concurrent transfer, stale version, retained child, and alternate-write tests |
| Consolidation mistaken for ownership | Separate relationship stores, action names, read contracts, labels, and events | No ownership claim or ownership-based action can use consolidation evidence | Contract/descriptor tests and user-comprehension review |
| Ownership graph used as transitive control or authorization | Relationship type never computes authority; any control or accounting interpretation belongs to an explicitly reviewed downstream contract | Unknown interpretation remains unavailable; no inherited capability or report | Selector misuse, transitive traversal, report, and capability-negative tests |
| Parentage or consolidation cycle | Authoritative writer serializes relevant structure and checks the proposed edge; database-backed invariant or equivalent prevents alternate paths | Stable conflict with no partial interval | Direct, indirect, long-chain, and reciprocal concurrent-cycle tests |
| Structural move silently widens access, report, workflow, configuration, module, placement, records, or finance scope | Code-owned impact registry evaluates every registered consumer against exact before/after structure on the writer | Unknown, unavailable, stale, or unsafe consumer blocks the change | One negative per consumer class, unknown-consumer denial, changed-preview/version conflict, and rollback tests |
| Active-node selector treated as authority | Selector is presentation context only; every read/action re-authorizes exact task and server-derived scope | Denied without revealing hidden relatives or alternate structures | Selector tampering and direct identifier guessing across legal, corporate, and educational nodes |
| Tree endpoint becomes bulk enumeration | Reads require exact root and code-owned depth/result bound; no caller-defined recursive query, arbitrary filter, or unrestricted cursor | Request is refused or returns only the already authorized bounded context | Depth, breadth, cursor, search, repeated-root, and parallel traversal abuse tests |
| Event, cache, path, or report projection becomes authoritative | Events contain stable IDs and minimal change facts; projections carry source revision and are rebuildable; writer revalidates current state | Stale/missing route or revision cannot decide authority or commit structure | Replay, out-of-order delivery, stale route, projection rebuild, and post-restore convergence tests |
| Corporate or educational transfer rewrites retained history | Stable identities and closed effective intervals remain authoritative; correction creates a successor record | Prior interval remains queryable through separately authorized exact/history read | Current/effective/exact-revision, correction, hold, erasure, export, and restore tests |
| Generic action bypasses relationship-specific policy | Only allowlisted named actions own writes; migration/import stages unresolved evidence rather than calling generic CRUD | Unsupported type/action is rejected | Domain inventory, private-action, alternate adapter, import, and direct SQL guard tests |

## Minimum executable negative-test catalogue

The following IDs are reserved for the later L1 evidence so that implementation cannot claim a
control with only a positive test.

| ID | Required negative |
| --- | --- |
| `LS-N01` | Missing actor, tenant, purpose, capability, module gate, or current route fails before any structure read or write |
| `LS-N02` | Every relationship family rejects a foreign-tenant endpoint without revealing whether it exists |
| `LS-N03` | A published educational institution cannot have zero or overlapping primary operators |
| `LS-N04` | A corporate unit cannot have two active legal-entity memberships, use a corporate unit as its legal entity, or retain canonical parentage across legal-entity boundaries |
| `LS-N05` | Direct, indirect, long-chain, and reciprocal concurrent cycles fail for consolidation, corporate parentage, and educational parentage |
| `LS-N06` | An ownership/control edge is not copied into consolidation, converted to another type, followed for transitive control, or used to grant operator, report, workflow, or access meaning |
| `LS-N07` | A consolidation parent, operator, corporate ancestor, educational ancestor, site, or active selector grants no capability or descendant visibility |
| `LS-N08` | Unknown, failed, stale, or newly registered impact evaluation blocks a move or operator transfer |
| `LS-N09` | A stale expected version and a changed idempotency request return stable conflict without a second state or outbox write |
| `LS-N10` | Injected failure after state, history, audit, or outbox preparation rolls the entire action back |
| `LS-N11` | Alternate Ash, repository, import, generated-interface, job, and support paths cannot bypass the named writer |
| `LS-N12` | Caller-controlled root, depth, cursor, filter, sort, search, or repeated queries cannot enumerate an unauthorized structure or sensitive collection |
| `LS-N13` | Stale cache, projection, event, or rendered path cannot authorize or resolve the current relationship |
| `LS-N14` | Closing, correcting, transferring, or moving a record does not erase protected history or resurrect redacted content after restore |
| `LS-N15` | An unresolved migration record cannot be published, selected as operator, attached to real operational data, or treated as access/placement context |
| `LS-N16` | A published primary-operator transfer cannot be self-approved or bypass the proposal workflow; the single-controller exception fails without stronger assurance, reason, evidence, visible marking, and a mandatory retrospective-review obligation |
| `LS-N17` | An institution cannot publish and an operator transfer cannot take effect with missing, failed, stale, foreign-tenant, or unauthorized evidence verification; documents and unredacted references cannot enter audit, outbox, logs, or errors |
| `LS-N18` | Future-effective transfer cannot activate from prior approval alone when evidence, entity status, approval authority, versions, or registered impacts no longer revalidate; post-effect revocation cannot rewrite its historical interval |
| `LS-N19` | Accountability under review cannot be hidden, treated as verified, used to perform a blocked or unclassified operator-dependent action, or cause an automatic operator substitution, institution closure, module change, or authority change |
| `LS-N20` | Accountability under review cannot be dismissed except through successful reverification, approved transfer, ADR 0018 correction, or separately authorized suspension/closure; an appointed person cannot be misclassified as the operator legal entity |

Every negative must assert the absence of partial domain state, successful audit outcome, outbox
success fact, idempotency completion, and cross-tenant existence disclosure where applicable.

## Compare-only migration sources

The mappings below are synthetic snapshots. A source `parent`, `company`, `school`, or `group`
column is evidence to interpret, not an instruction to reproduce the source tree.

### Source C — education group with separate operator and property owner

| Source evidence | Candidate target meaning | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| Company `C-100`, registration and jurisdiction present | `LegalEntity` candidate `LE-OPS` | Legal identity evidence only | Stage legal identity; do not create an institution or operator relationship yet |
| Company `C-200`, owns campus address | `LegalEntity` candidate `LE-PROPERTY` plus unresolved property evidence | Address and ownership note do not prove a `Site` or title | Stage separately; require site and property-domain reconciliation |
| School `S-10`, `company=C-100` | Educational institution candidate plus primary-operator candidate | Source company field may mean operator, billing company, or default | Require domain confirmation before publication; preserve source field and snapshot |
| Division `D-11`, `parent_school=S-10` | Educational-unit candidate | Containment is plausible | Map only after `S-10` resolves as an institution |
| Campus `P-1`, used by `S-10` and `S-20` | `Site` candidate plus two associations | Shared physical place, not a parent | Never create a corporate or educational unit from the campus row |

### Source D — joint ownership and consolidation mismatch

| Source evidence | Candidate target meaning | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| Entity `E-1`, parent company `E-HOLD` | Legal entity plus consolidation-parent candidate | Source parent may represent ownership, control, or reporting only | Keep candidate relation unresolved until its source semantics are confirmed |
| Ownership table: `E-HOLD` 60% of `E-1` | Typed ownership candidate | Percentage has explicit source evidence | Preserve value and unit as source evidence; do not infer accounting control or access |
| Ownership table: `E-JOINT` 40% of `E-1` | Second typed ownership candidate | Multiple owners are legitimate | Do not collapse into one legal parent or omit the minority relationship |
| Consolidation table includes `E-1` under `E-HOLD` | Primary consolidation candidate | Separate reporting evidence exists | May resolve consolidation independently after finance review |
| User defaults include `E-HOLD` | No target structural or authority relation | Source convenience setting | Never import as active tenant, access, placement, or report authority |

### Source E — separately operated institution inside an educational group

| Source evidence | Candidate target meaning | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| Institution `I-GROUP` contains establishment `I-A` | Educational parentage candidate | Educational containment evidence | Preserve source edge, subject to same-tenant and cycle review |
| `I-A` has separate registration and operator `E-A` | `I-A` is an educational institution, not merely an educational unit | Distinct accountability changes classification | Require exact operator mapping; retain contained institution and parentage separately |
| Department `D-A1` belongs to `I-A` | Educational-unit candidate | Legal accountability resolves through `I-A` | Do not assign a separate operator without new evidence |
| Finance roll-up maps `I-A` to `E-HOLD` | Reporting or consolidation input only | Does not prove operator or educational parent | Preserve as unresolved reporting evidence for its owning module |

### Source F — operator transfer with incomplete history

| Source evidence | Candidate target meaning | Finding | Fail-closed disposition |
| --- | --- | --- | --- |
| Current institution row names operator `E-NEW` | Current primary-operator candidate | No trustworthy prior interval | Record a baseline observation at the source snapshot; do not invent a transfer date |
| Archived document names `E-OLD` but has no effective end | Proven prior evidence with uncertain interval | Insufficient for contiguous timeline | Retain evidence in reconciliation; do not publish overlapping or fabricated dates |
| Import timestamp differs from source snapshot | Migration provenance only | Import time is not business effective time | Store both separately; never use import time as operator start without review |
| User role rows reference `E-OLD` | No authority migration from structure | Source authorization semantics are separate | Migrate through the authority workstream or leave unresolved; never infer access from operator history |

## Migration ledger and reconciliation contract

Every staged observation records:

- tenant, source system, source snapshot, source record type, and source identifier;
- immutable raw-evidence digest and separately protected source reference where permitted;
- proposed target concept and target UUID only after one is approved;
- relationship type, endpoints, date precision, and source interval evidence when present;
- mapping revision, confidence/disposition code, reviewer, decision time, and reason reference;
- ambiguity flags for dual-purpose organization rows, missing operators, duplicate registrations,
  several parents, cycle candidates, inferred defaults, and inconsistent effective dates; and
- whether publication, attachment of operational records, or later processing is blocked.

The ledger does not grant authority and is not a second domain store. Correcting a mapping creates
an attributable successor mapping decision; it does not rewrite the original source observation.

Allowed dispositions are:

- `mapped` — the reviewed evidence supports one exact target meaning;
- `split` — one source row legitimately maps to several separately identified meanings with an
  explicit reason;
- `merged_alias` — several source identities refer to one target, with every alias preserved;
- `unresolved` — plausible meanings remain ambiguous;
- `rejected` — source evidence is invalid, unsafe, foreign-tenant, cyclic where prohibited, or
  outside the accepted contract; and
- `deferred_owner` — the meaning belongs to another domain such as property, employment, finance,
  access, calendar, programme, or site management.

There is no silent last-write-wins or default `mapped` disposition.

## Temporal and correction decisions

| Meaning | L0 temporal classification | Correction rule | Required later owner decision |
| --- | --- | --- | --- |
| Legal-entity identity | Stable aggregate with revisioned published profile | Correct the exact published revision; never replace identity | Jurisdiction-specific registration, uniqueness, evidence, retention, and closure policy |
| Legal ownership/control | Effective-dated typed relationship | Correct exact relationship evidence or interval through a successor record | Initial type catalogue, attributes, cycle policy, and legal/accounting interpretation |
| Consolidation parent | Effective-dated single-parent relationship | Atomic close/open; no ownership rewrite | Financial reporting purpose, cycle boundary, and review authority |
| Corporate-unit identity | Stable aggregate with revisioned profile | Profile correction is separate from parent or legal-membership change | Classification, retention, closure, and transfer policy |
| Corporate membership/parentage | Effective-dated durable relationships | Atomic move/transfer with exact predecessor and impact review | Descendant treatment and downstream finance/employment reconciliation |
| Educational identity/parentage | ADR 0025 and existing educational disposition | Separate profile, parentage, and closure corrections | Domain records policy and downstream module reconciliation |
| Primary legal operator | Institution-local Date-effective durable relationship with separate UTC recording time | Single-step initial assignment while unpublished; verified evidence before publication; atomic inclusive-start/exclusive-end predecessor/successor only after effective-boundary revalidation of the verified proposal and approval; governed single-controller exception; post-effect revocation preserves history and opens a separate accountability-under-review condition with policy-classified restrictions and essential-operation continuity; no overlap for published institution; exact-time source remains unresolved | Approved records-system integration, evidence-type/jurisdiction freshness and action-classification policy, reconciliation ownership and deadline, and retrospective-review owner; later instant-precision extension only with demonstrated need |
| Other legal responsibility | Type-owned effective relationship | Type-specific correction; never edit into another type | Owning domain, endpoint/cardinality, evidence, retention, and consequences |

Real registration, ownership, control, property, employment, contracting, governance, and
beneficial-owner data remain blocked until classification, minimization, access, export, retention,
legal hold, correction, and erasure policies have named owners. The safest default is no production
storage.

## G3/G4 technical disposition

The relationship-policy matrix, TM-17/AC-18 treatment, reserved negative tests, four linked source
fixtures, reconciliation contract, and temporal decisions complete the **technical addendum**.
They do not pass G3 or G4. Those gates require the named reviewers to confirm that the controls and
mappings are sufficient, identify missing jurisdictional or institutional meaning, and record any
implementation condition in the
[representative and accountable review packet](institutional-structure-review-packet.md).

Executable enforcement remains an exit condition of the authorized L1 slices. A future passing
test cannot retroactively approve an ambiguous domain meaning; a domain review cannot substitute
for the required negative tests.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Linked-structure scenario addendum](linked-structure-scenario-addendum.md)
- [Institutional-structure security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0023](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
