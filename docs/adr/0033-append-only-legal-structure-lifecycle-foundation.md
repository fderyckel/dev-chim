# ADR 0033: Append-only legal-structure lifecycle foundation

- Status: Conditionally Accepted
- Date: 2026-10-03
- Decider: François — Project Owner
- Owners: Corporate/legal structure and platform engineering
- Extends: ADR 0031 and ADR 0032 for synthetic L1 Slice 2.1-C2a only

## Context

ADR 0032 closes C25-02's logical contract under the Project Owner's authority. On 2026-10-03 the
Project Owner confirmed that consultants are reviewing C25-02, directed the project to treat it as
approved for now, and authorized the next slice. Consultant findings remain revision evidence;
they are not a reason to represent the current synthetic decision as professional assurance.

Slice 2.1-C1 can establish direct legal-entity relationships and register corporate units, but it
cannot yet end a direct relationship or revise a corporate-unit name. Those are the smallest
lifecycle transitions that preserve identity without changing structural parentage, legal-entity
membership, downstream scope, or accounting meaning.

Changing a management parent, moving or transferring a corporate unit, or closing a unit is more
consequential. TM-17 and AC-18 require registered-impact preview and writer-side revalidation for
those transitions. That impact registry does not yet exist.

## Decision drivers

- Preserve effective and revision history instead of overwriting C1 facts.
- Add useful lifecycle transitions without weakening tenant, capability, module, and writer gates.
- Keep names separate from parentage, membership, authority, reporting, and finance meaning.
- Keep relationship termination separate from correction or replacement.
- Fail closed on stale versions, invalid dates, duplicate endings, direct SQL mutation, and partial
  evidence writes.
- Avoid parent or membership changes until their impact-review contract is executable.

## Considered options

1. Proceed directly to Slice 2.1-D. Rejected because C25-03 and C25-04 still block educational
   structure and primary-operation persistence.
2. Implement every deferred C1 lifecycle action together. Rejected because moves, transfers,
   consolidation-parent changes, and closure require registered-impact controls.
3. Add only append-only relationship ending and corporate-unit profile revision. Selected as
   Slice 2.1-C2a.
4. Mutate C1 rows in place. Rejected because it would erase historical meaning and weaken
   alternate-write protection.

## Decision

Authorize private synthetic L1 Slice 2.1-C2a with two named actions and exact-read changes.

### End a direct legal-entity relationship

`end_legal_entity_relationship` appends one immutable termination record to an exact C1 direct
relationship. It requires the relationship-management capability, exact expected version,
exclusive `effective_until` date, bounded evidence reference, idempotency key, and causation ID.

The end date must be later than the relationship's `effective_from` date. One relationship can
have at most one termination. The original relationship fact, type, endpoints, percentage, basis,
and start date remain immutable. Ending does not correct history, establish a successor, infer a
replacement relationship, or change authority, operation, reporting, placement, or consolidation.

The exact relationship read returns `active` with no end date or `ended` with the exclusive end
date. No collection, timeline search, graph traversal, or effective-date inference is added.

### Revise a corporate-unit profile

`revise_corporate_unit_profile` appends the next immutable name-profile revision for one exact
active corporate unit. It requires the corporate-unit-management capability and exact expected
profile version. At least one normalized name must change.

The corporate-unit UUID, legal-entity membership, canonical parent, status, and all earlier
profiles remain unchanged. The exact current read resolves the highest consecutive profile
revision. A revision creates no cost centre, ledger segment, authority, educational meaning, or
reporting scope.

### Explicitly deferred

This ADR does not authorize relationship correction, reactivation, or replacement; consolidation
parent changes; corporate-unit moves, legal-entity transfers, closure, or reopening; impact
preview; migration; real records; public interfaces; or educational structure.

## Consequences

### Positive

- Synthetic data can demonstrate ordinary expiry and naming change without replacing identities.
- Both transitions preserve immutable history and exact replay.
- Consequential structural moves remain closed until their required safety boundary exists.

### Negative

- An ended relationship cannot yet be corrected or reactivated.
- Corporate-unit parentage and membership remain fixed after registration.
- Current exact reads expose only the latest profile and the one termination fact; separately
  authorized history reads remain later work.

## Security, privacy, operability, and migration effects

Both actions run on the current authoritative writer with trusted actor, tenant, and placement
context. Existing module and tenant-defined capability gates apply. Database constraints and
triggers enforce same-tenant references, one termination, date order, consecutive profile
revisions, and append-only history on alternate write paths.

Audit and events contain stable identifiers, status/version facts, changed-field names, and the
relationship end date where applicable. They exclude names, percentages, and evidence references.
The state, idempotency claim, audit event, and outbox event commit or roll back together.

No source migration or real document is admitted. Consultant evidence is maintained outside these
synthetic records and may require a superseding ADR before a later adoption.

## Validation evidence

Slice 2.1-C2a must prove positive transitions, exact reads, exact replay, changed replay, stale
version, denied capability, cross-tenant identifiers, invalid and duplicate end dates, unchanged
name refusal, concurrent profile revision, alternate SQL mutation/insertion protection, minimized
events, injected rollback, module-inactive denial, migration review, and repeatable demo data.

The complete repository gate remains required before declaring the slice complete. Passing tests
do not close C25-03 through C25-06 or the later real-adoption validation.

## Fallback and exit cost

If consultant review changes the catalogue or lifecycle meaning, keep later adoption closed and
supersede this ADR. Synthetic termination and profile-revision tables can be discarded with their
local database. No public contract, migration mapping, or real tenant data depends on C2a.

## Review triggers

- Consultant findings change a relationship type, evidence rule, date meaning, or approval rule.
- A relationship must be corrected, reactivated, superseded, or linked to a successor.
- A management parent or corporate unit must move, transfer, close, or reopen.
- A downstream consumer would interpret an end or name revision as authority or financial scope.
- A public, migration, connected, real-data, or L2 boundary is proposed.

## Related records

- [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0031](0031-bounded-cross-jurisdiction-legal-structure-foundation.md)
- [ADR 0032](0032-c25-02-delegated-contract-acceptance.md)
- [C25-02 corporate-governance and finance review](../phase-2/c25-02-corporate-governance-finance-review.md)
- [Slice 2.1-C1 evidence](../phase-2/legal-structure-foundation-evidence.md)
- [Institutional-structure security and migration review](../phase-2/institutional-structure-security-migration-review.md)
- [Threat model](../security/threat-model.md), especially TM-17
- [Security abuse cases](../security/abuse-cases.md), especially AC-18
