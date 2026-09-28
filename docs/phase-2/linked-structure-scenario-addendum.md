# Linked corporate/legal and educational-structure scenario addendum

- Status: Technical G1 evidence prepared; named accountable review remains open
- Date: 2026-09-27
- Gate: ADR 0025 G1
- Scope: Logical contract and synthetic review only; no persistence, public route, module
  activation, migration execution, or real data
- Accountable reviewers still required: Corporate governance/finance domain owner,
  educational-structure domain owner, and platform engineering

## Purpose

This addendum expands scenario S9 in the
[institutional-structure walkthrough](institutional-structure-scenario-review.md). It tests whether
the amended ADR 0025 contract can represent linked corporate/legal and educational structures
without creating one universal organization tree or allowing a structural relationship to become
authority.

The addendum is decision evidence, not approval. It deliberately leaves jurisdiction-specific
registration, ownership, accounting, regulatory, and records policies with named domain owners.
It uses no real organization, vendor, or source-system names.

## Invariants under review

Every scenario must retain all of these invariants:

1. The tenant is the security, placement, lifecycle, and data boundary; it is not assumed to be a
   legal person or educational root.
2. A legal entity, corporate unit, educational institution, educational unit, and site retain
   separate tenant-qualified stable identities.
3. A published educational institution has exactly one effective primary legal operator.
4. An educational unit obtains legal accountability through its containing institution. Distinct
   legal accountability makes the establishment an institution, not merely a relabelled unit.
5. Legal ownership or control may have several typed edges. An optional primary consolidation
   parent is a separate, single-parent, acyclic reporting/navigation meaning. There is no generic
   ownership/control edge or universal cycle rule; every type owns its endpoints, cardinality,
   attributes, evidence, cycle policy, and non-inference rules.
6. A published corporate unit belongs to exactly one legal entity. Corporate containment is
   single-parent, acyclic, and limited to units belonging to the same effective legal entity. A
   transfer preserves identity and history but must reconcile parentage that would cross the new
   legal-entity boundary. Cross-entity coordination uses an explicit typed relationship.
7. Educational containment is a separate tenant-local, single-parent, acyclic forest.
8. Legal, corporate, educational, and site relationships are effective-dated where their meaning
   changes over time. A change never rewrites the prior interval.
9. No relationship grants access, expands a report, activates a module, selects placement, adopts
   configuration or workflow, or changes finance responsibility implicitly.
10. Every consequential structural change previews registered downstream impacts. An unknown or
    unsafe impact blocks the change.

## Fixed synthetic fixture

The aliases below extend the fixed synthetic fixture in the main walkthrough. They are review
handles only. Implementations and downstream records use the exact tenant-qualified UUID.

| Alias | Synthetic UUID | Meaning |
| --- | --- | --- |
| `T-A` | `a0000000-0000-4000-8000-000000000001` | Tenant containing the reviewed structures |
| `T-B` | `b0000000-0000-4000-8000-000000000001` | Foreign tenant used only for denial cases |
| `LE-GROUP` | `71000000-0000-4000-8000-000000000001` | Optional consolidation parent |
| `LE-OPS` | `71000000-0000-4000-8000-000000000002` | Operator of several educational institutions |
| `LE-PROPERTY` | `71000000-0000-4000-8000-000000000003` | Property-owning legal entity |
| `LE-JOINT` | `71000000-0000-4000-8000-000000000004` | Additional owner or controller outside the consolidation tree |
| `LE-NEW-OPS` | `71000000-0000-4000-8000-000000000005` | Successor primary operator in a transfer scenario |
| `LE-INDEPENDENT` | `71000000-0000-4000-8000-000000000006` | Operator of a contained but separately accountable institution |
| `LE-FOREIGN` | `7b000000-0000-4000-8000-000000000001` | Foreign-tenant entity; never a valid endpoint for `T-A` |
| `CU-SHARED` | `72000000-0000-4000-8000-000000000001` | Shared-services unit belonging to `LE-OPS` |
| `CU-FINANCE` | `72000000-0000-4000-8000-000000000002` | Finance unit below `CU-SHARED` |
| `CU-SPORT` | `72000000-0000-4000-8000-000000000003` | Corporate coordination unit; not the sports programme itself |
| `U-COMBINED` | `12000000-0000-4000-8000-000000000001` | Combined educational institution |
| `U-HIGH` | `12000000-0000-4000-8000-000000000013` | High-school educational unit within `U-COMBINED` |
| `U-COLLEGE-A` | `14000000-0000-4000-8000-000000000001` | College institution sharing an operator |
| `U-ACADEMY` | `15000000-0000-4000-8000-000000000001` | Institution educationally contained by `U-COMBINED` but separately operated |
| `SITE-CENTRAL` | `52000000-0000-4000-8000-000000000001` | Site used by several educational units |

Formal names, registrations, addresses, ownership shares, and personal contacts are intentionally
absent. The review needs only the minimum synthetic meaning necessary to test the boundary.

## Linked scenarios

### LS-01 — several legal entities without a fabricated legal root

`T-A` contains `LE-OPS`, `LE-PROPERTY`, and `LE-INDEPENDENT`. They remain independent legal
identities even when no consolidation relationship exists.

Expected outcome:

- tenant membership does not create a legal parent;
- a legal-entity list is not itself a group ownership statement;
- absence of a consolidation parent is valid; and
- selecting one entity does not reveal or authorize another.

### LS-02 — multiple ownership and separate consolidation

`LE-OPS` has typed ownership or control relationships from `LE-GROUP` and `LE-JOINT`.
`LE-GROUP` is also the optional primary consolidation parent for `LE-OPS`. `LE-JOINT` is not in
that consolidation tree.

Expected outcome:

- several ownership/control edges may coexist;
- the consolidation parent is never presented as complete ownership evidence;
- ownership percentages, voting rights, beneficial ownership, and accounting control are not
  inferred when the relationship contract does not explicitly contain them; and
- cycles are evaluated under the exact relationship type rather than a universal graph rule, and
  no transitive control or authority is inferred from a path; and
- neither ownership nor consolidation grants access, reporting authority, or operator status.

The first implementation does not need a universal percentage model. A relationship type may add
validated type-specific attributes only after corporate governance/finance review.

### LS-03 — nested corporate units and legal-entity membership

`CU-SHARED` belongs to `LE-OPS`; `CU-FINANCE` and `CU-SPORT` are its corporate children. A later
transfer moves `CU-SHARED` and its reviewed descendants to `LE-NEW-OPS` without replacing their
stable identities.

Expected outcome:

- each published corporate unit resolves one exact legal entity at any effective date;
- corporate parentage and legal-entity membership remain separate relationships;
- moving a parent does not silently transfer children unless the named action explicitly includes
  them and previews every affected identity; and
- canonical parentage cannot remain across two legal entities after a membership transfer;
  cross-entity management or shared services require a separately reviewed typed relationship;
  and
- the corporate tree does not create finance access, employment, workflow, or programme ownership.

### LS-04 — one operator serving several institutions

`LE-OPS` is the primary legal operator for `U-COMBINED` and `U-COLLEGE-A`. The institutions are
separate educational roots with their own structures, calendars, programmes, terminology, and
site associations.

Expected outcome:

- a shared operator does not create an educational parent or merge the institutions;
- one institution's capability grants, reports, workflows, calendars, or configurations do not
  flow to the other; and
- operator-oriented finance or compliance work must use a separately authorized dataset rather
  than infer visibility from the operator link.

### LS-05 — contained institution with its own operator

`U-ACADEMY` is educationally contained by `U-COMBINED`, but `LE-INDEPENDENT` is its primary legal
operator. `U-HIGH`, by contrast, is an educational unit within `U-COMBINED` and resolves legal
accountability through `U-COMBINED`.

Expected outcome:

- `U-ACADEMY` is classified as an educational institution despite having an educational parent;
- `U-HIGH` remains an educational unit and cannot receive a conflicting operator link;
- the educational parent does not override the exact operator; and
- a user can understand the difference without relying on labels such as school or department.

### LS-06 — split legal responsibilities

`LE-OPS` is the primary operator for `U-COMBINED`; `LE-PROPERTY` owns `SITE-CENTRAL`; and a
separately typed relationship may identify an employment, funding, contracting, governance, or
data-control responsibility after its own domain review.

Expected outcome:

- primary operation, property ownership, employment, funding, contracting, governance, and data
  control are not aliases;
- each type has explicit endpoint, cardinality, effective-time, evidence, and lifecycle rules;
- an absent type is unknown, not inherited from the operator or property relationship; and
- no generic `responsible_for` edge is accepted as a shortcut.

### LS-07 — effective primary-operator transfer

On an institution-local effective date interpreted with the institution's stored IANA time zone,
`U-COLLEGE-A` transfers from `LE-OPS` to `LE-NEW-OPS`. The writer closes the prior interval and
opens the successor atomically. Approval and commit time are recorded separately in UTC.

Because the institution is already published, one authorized actor proposes the transfer and a
different authorized actor approves it by default. If the tenant has only one qualified
controller, that actor must invoke the explicit single-controller exception with stronger actor
assurance, a reason and evidence reference, a visible exception marker, and a mandatory
retrospective review. Initial operator assignment for an unpublished institution remains a
single-step named action.

The proposal records structured evidence metadata and a protected reference to the authoritative
document in an approved records system or secure repository. The structure domain does not copy
the document. The proposal may remain pending while verification is incomplete, but the transfer
cannot take effect until an authorized verifier records the evidence outcome.

If this is a future-effective transfer, activation revalidates the evidence under its type- and
jurisdiction-owned freshness policy, both entities' applicable status, proposal and approval
state, expected versions, and the registered-impact preview. Approval alone is not a scheduled
write guarantee. Revocation before activation blocks the transfer; revocation discovered after
activation preserves the historical interval and opens a high-priority reconciliation case.

During post-effect reconciliation, `U-COLLEGE-A` remains published and the recorded operator
history remains intact, but its legal accountability is visibly **under review**. Explicit
type- and jurisdiction-owned policy blocks new actions that depend on verified operator standing.
Essential teaching, safeguarding, attendance, and learner support continue unless that policy
requires suspension. Unknown action classification blocks the action. Accountable administrators
receive an alert and a policy-owned resolution deadline; no timeout silently closes the
institution or invents a successor.

The condition cannot be dismissed manually. It ends only when a named action reverifies the
current operator, transfers to a verified successor, corrects a factually wrong historical record
under ADR 0018, or separately suspends or closes the institution. A legally accountable interim
organization is a time-bounded primary operator. An appointed individual is an accountable
representative under the applicable person/authority contract, not a legal entity.

Expected outcome:

- the institution and both legal entities retain their stable identities;
- no published-time overlap or gap exists between operator intervals;
- current and exact historical reads return the correct operator for their date;
- a source requiring legally significant time-of-day precision remains unresolved rather than
  being rounded into the date-level contract;
- proposal and approval are attributable to distinct actors unless the recorded
  single-controller exception applies;
- evidence type, issuer or source, protected reference, applicable dates, verification actor and
  time, and information classification are attributable without exposing the full document;
- future activation cannot use stale approval, evidence, entity state, expected versions, or
  impact results;
- post-effect invalidation is visible and restricts policy-identified legal-accountability actions
  without automatically interrupting essential learner-facing operations;
- the transfer preview covers finance, contracts, employment, records, safeguarding, workflows,
  reports, integrations, access scopes, module data, and unknown consumers; and
- an unclassified, unsafe, stale-version, or concurrently changed impact blocks the transfer.

The operator relationship establishes accountable operation only. Downstream contracts decide
whether and how their own records change; the transfer does not rewrite them automatically.

### LS-08 — independent corporate and educational reorganizations

`CU-FINANCE` moves within the corporate tree while `U-HIGH` moves within the educational tree.
Neither change alters the other tree, any legal relationship, or the site's associations.

Expected outcome:

- each move has its own capability, expected version, idempotency claim, audit, outbox fact, and
  registered-impact preview;
- the interface never offers a generic move that can cross structure types;
- a corporate move cannot reparent an educational unit, and an educational move cannot change
  corporate membership; and
- cached paths and rendered trees are disposable projections, not alternate writers.

### LS-09 — invalid and ambiguous relationships

The review attempts:

- a relationship from a `T-A` record to `LE-FOREIGN` in `T-B`;
- two active primary operators for the same published institution;
- a published institution with no operator;
- two active legal-entity memberships for one corporate unit;
- direct, indirect, and reciprocal concurrent cycles in consolidation, corporate parentage, and
  educational parentage;
- a corporate unit used as a legal operator;
- a site or programme used as a structural parent; and
- an ownership edge silently copied into the consolidation tree.

Expected outcome:

- every invalid write fails without a partial state, audit-success record, outbox-success fact, or
  cross-tenant existence signal;
- relationship families apply their declared cycle policies independently rather than using one
  universal graph rule; and
- unresolved source evidence remains in reconciliation and cannot be published.

### LS-10 — no implicit effects and bounded navigation

An actor can view `LE-GROUP` in one bounded task and select `U-COMBINED` in another. The actor then
attempts to enumerate every descendant, obtain a consolidated report, start a workflow, adopt a
configuration, activate a module, or select tenant placement from those structures.

Expected outcome:

- structure visibility or selection grants none of those effects;
- the server derives the exact task and authorized scope independently;
- an ordinary linked-tree view exposes only the already authorized bounded context, not an
  unrestricted tenant-wide traversal API; and
- finance reconciliation uses an explicit authorized reporting contract, never the navigation
  tree alone.

## Candidate named-action boundary

The logical review expects separate action families. Names may be refined before implementation,
but a generic organization mutation is not acceptable.

| Intent | Minimum preconditions | Required outcome evidence |
| --- | --- | --- |
| Register or revise a legal entity | Trusted actor/tenant/purpose; capability; exact expected version for revision; jurisdiction-specific fields valid for the selected policy | Stable entity ID; exact revision/result; minimized audit; transactional outbox fact |
| Establish or end a legal relationship | Exact typed endpoints; same tenant; relationship-type cardinality and cycle policy; effective interval; evidence reference | Exact relationship interval; no derived authority; replay-safe result |
| Select or change consolidation parent | Same tenant; one active parent; acyclic writer check; registered-impact preview | Prior and successor intervals; no ownership rewrite; classified report/navigation impacts |
| Register, place, move, transfer, or close a corporate unit | One exact legal entity; valid corporate parent; expected versions; descendant and downstream impact preview | Stable unit ID and history; no partial descendant transfer; blocked unknown effects |
| Assign initial primary legal operator | Institution is unpublished; educational endpoint is an institution; legal endpoint is a legal entity; exact one-at-a-time interval; structured evidence metadata and protected reference exist | Attributable single-step assignment; stable institution/entity identities; publication remains blocked until evidence verification |
| Propose primary-operator transfer | Institution is published; current and successor operators are exact; effective date/time zone, reason, structured evidence metadata, protected reference, expected version, and impact preview resolve | Pending proposal only; no operator interval or downstream record changes |
| Approve primary-operator transfer | Pending proposal and evidence verification remain current; a different authorized actor approves by default, or the explicit single-controller exception satisfies stronger assurance, reason, evidence, visible marking, and retrospective-review requirements | Approved proposal awaits its effective boundary; no premature operator or downstream change |
| Activate future-effective primary-operator transfer | Evidence freshness policy, entity status, proposal, approvals, expected versions, and registered impacts all revalidate on the authoritative writer | Atomic predecessor/successor intervals and attributable activation; otherwise stable blocked outcome and no partial write |
| Reconcile operator accountability | Exact disputed evidence and current operator interval; type/jurisdiction policy; accountable owner and deadline; registered action impacts | Visible under-review condition; classified restrictions and alerts; history preserved; no invented operator, automatic transfer, or automatic closure |
| Resolve operator-accountability review | One exact named outcome: reverify current operator, approved successor transfer, ADR 0018 correction, or separate suspension/closure; all outcome-specific authority and evidence resolve | Review closes only from the successful named outcome; complete attribution and retained history; no generic dismissal |
| Manage another legal responsibility | Accepted code-owned type with explicit cardinality, effective time, evidence, and owning domain | Separate typed relationship and history; no operator or authority implication |

All actions remain subject to module availability, entitlement, compatible activation, and actor
authorization as independent server-side gates.

## Required read meanings

Acceptance of the logical contract requires distinct named reads, not one ambiguous organization
resolver:

- exact legal entity and exact revision;
- bounded current legal relationships for one exact entity and relationship purpose;
- current consolidation parent and bounded consolidation context;
- exact corporate unit, current legal-entity membership, and bounded corporate context;
- exact educational institution or unit and bounded educational context;
- primary legal operator for one exact institution and effective date;
- explicitly requested secondary legal responsibility for one exact institution and date; and
- registered-impact preview for one proposed structural change.

These reads do not authorize tenant-wide sensitive enumeration, finance reports, access-scope
expansion, or unrestricted recursive traversal.

## Review questions and disposition

The named reviewers must answer these questions with `yes`, `condition`, or `no`:

1. Can the scenarios represent the reviewed legal and educational operating structures without
   merging their identities?
2. Is one primary legal operator per published institution the correct accountability invariant?
3. Are ownership/control and consolidation sufficiently separate for navigation and finance work?
4. Can corporate units move without becoming legal persons or silently changing educational
   structure?
5. Are operator transfer and separate legal responsibilities historically and operationally
   understandable?
6. Does every relationship remain separate from access, reporting authority, workflow,
   configuration, modules, and placement?
7. Which relationship types or attributes are required before Slice 2.1-C, and which should remain
   deferred rather than hidden in a generic edge?

The technical walkthrough answers **representable** for LS-01 through LS-10. It does not answer
the domain-adequacy questions on behalf of the named reviewers. G1 remains open until the corporate
governance/finance, educational-structure, and platform reviewers record their dispositions in the
[representative and accountable review packet](institutional-structure-review-packet.md).

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Institutional-structure scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Linked-structure security and migration addendum](linked-structure-security-migration-addendum.md)
- [Institutional-structure decision evidence plan](institutional-structure-decision-evidence.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
