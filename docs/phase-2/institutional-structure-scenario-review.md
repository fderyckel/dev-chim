# Institutional-structure scenario and vocabulary review

- Status: Engineering walkthrough complete; accountable G1 review remains open
- Date: 2026-09-27
- Gate: ADR 0025 G1
- Scope: Logical contract only; no persistence, production route, module, or real data
- Accountable reviewers still required: Product owner, named institutional-structure domain owner,
  and platform engineering

## Outcome

The eight required synthetic contexts can be represented by ADR 0025 without weakening tenant
isolation, stable identity, single-parent canonical containment, or the separation of hierarchy
from authority. The walkthrough narrows two previously open vocabulary questions:

- the initial code-owned structural classifications are `institution` and
  `organizational_unit`; tenant-controlled localized labels such as university, faculty, school,
  college, department, kindergarten, or division describe the unit without creating permissions
  or allowed-parent rules; and
- an optional current code is unique only among current siblings under the same canonical parent,
  with root codes scoped to the tenant's root set. A code is never identity or a tenant-wide lookup
  key. Historical and imported aliases retain source system, source identifier, snapshot, and
  mapping revision.

These are proposed G1 dispositions until the accountable reviewers named above record approval.
An objection that changes tenant ownership, UUID identity, canonical parentage, or hierarchy's
non-authority rule returns ADR 0025 to design work.

## Fixed synthetic identity and language fixture

The aliases below are stable within this review package. They are synthetic and must never be
copied into a real tenant. Every relationship uses the exact tenant-qualified UUID, never the
alias, name, code, label, or rendered path.

| Alias | Synthetic UUID | Meaning |
| --- | --- | --- |
| `T-A` | `a0000000-0000-4000-8000-000000000001` | Tenant containing the reviewed scenarios |
| `T-B` | `b0000000-0000-4000-8000-000000000001` | Foreign tenant used only for denial tests |
| `U-EARLY` | `11000000-0000-4000-8000-000000000001` | Independent early-childhood institution |
| `U-COMBINED` | `12000000-0000-4000-8000-000000000001` | Combined-school root |
| `U-KG` | `12000000-0000-4000-8000-000000000011` | Kindergarten division |
| `U-MIDDLE` | `12000000-0000-4000-8000-000000000012` | Middle-school division |
| `U-HIGH` | `12000000-0000-4000-8000-000000000013` | High-school division |
| `U-UNIV` | `13000000-0000-4000-8000-000000000001` | University root |
| `U-LS` | `13000000-0000-4000-8000-000000000011` | School of Learning Sciences |
| `U-CE` | `13000000-0000-4000-8000-000000000012` | School of Community Education |
| `U-IE` | `13000000-0000-4000-8000-000000000111` | Department of Inclusive Education |
| `U-COLLEGE-A` | `14000000-0000-4000-8000-000000000001` | First community-college root |
| `U-COLLEGE-B` | `14000000-0000-4000-8000-000000000002` | Second community-college root |
| `SITE-RIVER` | `51000000-0000-4000-8000-000000000001` | Independent early-learning site |
| `SITE-CENTRAL` | `52000000-0000-4000-8000-000000000001` | Combined-school shared site |
| `SITE-CITY` | `54000000-0000-4000-8000-000000000001` | Site shared by college roots |
| `AFF-01` | `61000000-0000-4000-8000-000000000001` | Shared-service affiliation |
| `AFF-JOINT` | `62000000-0000-4000-8000-000000000001` | Joint-programme affiliation candidate |

The fixture includes tenant-controlled localized presentation values `en: School` and
`fr: École` for one `organizational_unit`. Both renderings resolve the same UUID and code-owned
classification. Translation never creates another unit, hierarchy edge, capability, or allowed
parent rule.

## Scenario walkthrough

| Scenario | Fixed synthetic shape | Expected outcome | Security, history, and migration disposition |
| --- | --- | --- | --- |
| S1 — independent early-childhood institution | Tenant `T-A`; root `U-EARLY`; site `SITE-RIVER`; local label “Early Learning Centre” | `U-EARLY` is an `institution` root with no fabricated global parent. The site is linked separately. | Existing creates no authority or module activation. Source type and site evidence remain separate migration fields. |
| S2 — combined school | Root `U-COMBINED`; child units `U-KG`, `U-MIDDLE`, and `U-HIGH`; shared site `SITE-CENTRAL` | All divisions are `organizational_unit` records under one root. A rename keeps the UUID; a move is a governed parentage change. | Branding, reporting, calendars, access, and site use require explicit owning contracts. No value follows parentage implicitly. |
| S3 — university | Root `U-UNIV`; schools `U-LS` and `U-CE`; nested department `U-IE` | Arbitrary reviewed depth and local labels are represented without a fixed type ladder. Repeated codes are valid under different parents. | Moving `U-IE` preflights every registered consumer. Multiple calendars remain explicit adoptions, not inherited structure. |
| S4 — college/community-college group | Roots `U-COLLEGE-A` and `U-COLLEGE-B`; shared site `SITE-CITY`; shared-service affiliation `AFF-01` | Several roots coexist without an `All Organizations` node. The site is many-to-many and the service is a typed affiliation. | Neither link creates a second canonical parent, access scope, reporting roll-up, or tenant placement. |
| S5 — identity and history | Unit `U-IE` renamed, recoded, moved, reassociated, then closed | The unit UUID never changes. Profile, parentage, site association, and closure are distinct durable meanings with exact current and historical reads. | Planned succession differs from correction. Unknown source dates are imported as a baseline observation and never backfilled as invented history. |
| S6 — matrix relationship | Joint programme `AFF-JOINT` connects `U-IE` and `U-COLLEGE-A` | A code-owned `joint_programme` affiliation connects exact endpoints without adding a parent. | The edge has its own direction, lifecycle, authorization, and cycle rules. It grants no access or enrolment meaning. |
| S7 — invalid structure | Cross-tenant parent, self-parent, indirect cycle, and two racing reciprocal moves | Every write path rejects the same invalid outcome without disclosing the foreign unit. | Compound tenant constraints and writer-side tenant-scoped serialization are mandatory L1 proof; application validation alone is insufficient. |
| S8 — no implicit effects | Create or move `U-IE` below a visible or privileged parent | The preview classifies authorization, reporting, configuration/calendar, module/placement, and unknown consumers independently. | No implicit effect is allowed. `unknown` blocks the move; explicit descendant scopes are revalidated on the writer before commit. |

## Action, read, and navigation outcomes

| Scenario | Proposed actions | Expected current and historical reads | User-navigation outcome | Engineering disposition |
| --- | --- | --- | --- | --- |
| S1 | Register `U-EARLY`; associate `SITE-RIVER` | Current unit and site association resolve independently; the unit has no parentage history beyond its root observation | Shows one root without presenting tenant or site as its parent | Representable; early-childhood review open |
| S2 | Register three divisions; rename and preview moving `U-MIDDLE` | Current read shows revised profile and active parent; exact profile revision and effective parentage reads preserve earlier meaning | Nested units and the shared site remain visibly separate | Representable; combined-school review open |
| S3 | Register schools and department; recode or move `U-IE` | Current read resolves by UUID; exact revision and effective parentage reads preserve the prior code and parent | Bounded university/school/department context shows arbitrary reviewed depth | Representable; university review open |
| S4 | Register two roots; associate `SITE-CITY`; establish `AFF-01` | Current root summary, site association, and affiliation are separate named reads; no fabricated parent history exists | Several roots appear without an `All Organizations` node | Representable; college/community-college review open |
| S5 | Rename, recode, move, reassociate, and close `U-IE` | Current read shows the final published state; exact profile revisions and effective relationship intervals preserve prior facts; recorded-time reconstruction is not promised | Closed status remains textual and exact history requires its own authorized task | Representable subject to temporal/records review |
| S6 | Preview and establish `AFF-JOINT`; later end it | Current and effective affiliation reads identify exact endpoints and lifecycle; containment reads are unchanged | Affiliation appears outside the canonical tree | Representable subject to affiliation-type domain review |
| S7 | Attempt cross-tenant parentage, direct/indirect cycles, and racing reciprocal moves | Rejected attempts create no parentage interval or successful outbox fact; authorized current reads remain unchanged | Denied/conflict states disclose no foreign or hidden unit | Fail-closed design specified; executable L1 proof required |
| S8 | Create or move beneath a visible parent while registered impacts are evaluated | Current access, report, adoption, lifecycle, placement, site, and records meanings remain unchanged unless their owner records explicit reconciliation | Move preview names `unchanged`, `requires reconciliation`, and `blocks move`; it exposes no commit control | Fail-closed design specified; executable consumer proof required |

## Cross-scenario vocabulary

The two initial structural classifications answer only how the unit participates in canonical
containment:

| Classification | Meaning | Explicit non-meaning |
| --- | --- | --- |
| `institution` | A governed learning institution that may be a root or, where the operating context requires it, a contained institution | Not a tenant, legal entity, site, module owner, reporting scope, or authority grant |
| `organizational_unit` | A structurally meaningful contained unit such as a faculty, school, department, or division | Not a programme, cohort, course, access scope, reporting group, or arbitrary tenant-defined entity type |

The code-owned set is deliberately small. A later need for behaviorally distinct classifications
requires evidence and an ADR update; adding a display label does not extend the set. Legal entities,
sites, programmes, cohorts, courses, reporting groups, and access scopes remain separate identities.

Current sibling-code uniqueness is a usability constraint, not an identity guarantee. Root codes
use the tenant's root set as their sibling scope. Closed or superseded codes and source aliases may
overlap; all external references use the UUID. A move that would create a current sibling collision
is refused until the operator chooses a new code or resolves the existing one through a named
action.

## IS-01 through IS-12 disposition

| Position | Engineering disposition | Evidence in this walkthrough | Approval state |
| --- | --- | --- | --- |
| IS-01 | Retain | S1 and S4 prove independent and multiple roots without a global node. | Awaiting accountable review |
| IS-02 | Retain | S5 separates immutable UUID from every mutable meaning. | Awaiting accountable review |
| IS-03 | Retain | S2, S3, and S7 cover arbitrary depth, same-tenant edges, single parent, and cycle refusal. | Awaiting accountable review and later L1 executable proof |
| IS-04 | Retain | S4 and S6 use typed affiliations instead of second parents. | Awaiting accountable review |
| IS-05 | Narrow | Use only `institution` and `organizational_unit`; local labels remain tenant-controlled presentation. | Awaiting representative vocabulary review |
| IS-06 | Retain | S1, S2, S4, and S5 keep sites separate and many-to-many. | Awaiting accountable review |
| IS-07 | Retain | Every scenario treats containment as non-authoritative; S8 makes the negative explicit. | Awaiting security/privacy review |
| IS-08 | Retain | The selected exact unit is context only; future exact/descendant grants remain separate. | Awaiting security and representative experience review |
| IS-09 | Retain | S3, S5, and S8 require classified move impacts and block unknown effects. | Awaiting accountable review and later L1 executable proof |
| IS-10 | Retain | S5 and the separate assurance/migration review classify profile, parentage, site, affiliation, closure, and evidence layers. | Awaiting domain and records review |
| IS-11 | Narrow | Current codes are sibling-scoped, mutable, non-identifying; source aliases are qualified and retained. | Awaiting accountable review |
| IS-12 | Retain | No storage optimization is selected at L0; PostgreSQL remains authoritative and projections disposable. | Awaiting platform review and later measurement |

## G1 disposition

The engineering walkthrough and recommended decisions are complete. G1 is **not passed** until the
product owner, a named institutional-structure domain owner, and platform engineering record their
review. Representative-context validation remains a separate G2 gate and may require this record
to change.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Decision evidence plan](institutional-structure-decision-evidence.md)
- [Security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Experience and representative-review evidence](institutional-structure-experience-evidence.md)
