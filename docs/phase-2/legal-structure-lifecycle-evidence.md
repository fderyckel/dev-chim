# Slice 2.1-C2a append-only legal-structure lifecycle evidence

- Status: Bounded implementation complete; complete repository gate pending
- Date: 2026-10-03
- Governing decisions: Conditionally Accepted ADRs 0025, 0031, and 0033; Accepted ADR 0032
- Module: `organization.legal` version `1.2.0`
- Boundary: private production-core candidate using synthetic local data only

## Accountable entry disposition

On 2026-10-03 the Project Owner confirmed that C25-02 is approved while consultants continue
their review and directed the project to proceed to the next slice. ADR 0033 records the resulting
bounded choice: extend Slice 2.1-C inside L1 rather than cross the still-open C25-03/C25-04 gates
into educational structures or legal-operation persistence.

Consultant findings remain a review trigger and may require a superseding ADR. This implementation
does not claim legal, tax, audit, accounting, or jurisdiction-specific assurance.

## Implemented boundary

Slice 2.1-C2a adds two named lifecycle actions:

- `end_legal_entity_relationship` appends one immutable exclusive end date to one exact direct
  relationship; and
- `revise_corporate_unit_profile` appends the next immutable full official/display-name profile
  for one exact active corporate unit.

The relationship read now resolves `active` version 1 or `ended` version 2 with the recorded end
date. The corporate-unit read resolves the highest consecutive profile revision. Both actions use
trusted context, the current writer, current module activation, tenant-defined capability checks,
exact expected versions, deterministic request binding, exact replay, minimized audit, and a
transactional outbox.

The original relationship row and corporate-unit identity, legal-entity membership, canonical
parent, status, and earlier profiles remain unchanged. No collection, graph traversal, inferred
control, finance scope, authority, educational meaning, public route, or real record is added.

## Migration review

AshPostgres generated the termination resource table and snapshot. Manual review adds and checks:

- a compound same-tenant relationship reference and one-termination uniqueness;
- an exclusive end date later than the relationship start;
- immutable termination and profile-history rows;
- tenant-and-aggregate advisory serialization for alternate inserts;
- strictly consecutive corporate-unit profile revisions;
- database-stamped recording time; and
- rollback refusal once lifecycle state, audit, or outbox evidence exists.

Constraint names were shortened explicitly so PostgreSQL stores the reviewed names without silent
identifier truncation. An empty temporary database migrated from the first repository migration
through Slice 2.1-C2a without warnings from the new migration.

## Executable evidence

The focused suite proves:

- relationship ending, exact current read, exact replay, and changed-request conflict;
- stale expected version, invalid interval, second-ending refusal, denied capability, and
  non-disclosing cross-tenant identifier handling;
- immutable termination history and database-level invalid-date refusal;
- corporate-unit name revision, preserved identity/membership/parentage, exact replay, minimized
  event payload, and full two-version history;
- unchanged-name refusal, stale expected version, denied capability, cross-tenant non-disclosure,
  skipped-revision refusal, and immutable prior profiles;
- concurrent corporate-unit revisions with exactly one version-2 winner;
- late-failure rollback of termination, audit, outbox, and idempotency claim;
- module-inactive denial while earlier state remains retained; and
- complete Ash domain inventory including the new denied-generic-action resource.

Verification on 2026-10-03:

| Check | Result |
| --- | --- |
| Compile with warnings as errors | Passed |
| Ash migration/snapshot drift check | Passed |
| Empty temporary database migration | Passed from the first migration through 2.1-C2a; temporary database removed afterward |
| Focused lifecycle and domain-inventory suites on the clean temporary database | Passed: 24 tests |
| `make legal-demo`, repeated against the same database | Passed: stable six entities, four relationships with one ended, three management parentages, six corporate units, and one profile revision |
| Production-core `make check-core` | Passed: formatting, warnings-as-errors compile, API and migration drift, strict lint, dependency audit, type analysis, 190 tests, and whitespace |
| Complete repository `make check` | Pending |

## Demonstration data

The development-only demo retains all Slice 2.1-C1 scenarios and adds:

- an exclusive 2027-06-30 end to the synthetic governing-body appointment from `LE-GROUP` to
  `LE-PROPERTY`; and
- a version-2 name profile changing `CU-GROUP-SHARED` to “Mphamvu Group Shared Services” with the
  display name “Group Shared Services”.

Fixed idempotency and causation identifiers make reruns exact replays. The demo remains synthetic,
local, non-destructive, and disconnected from any browser or public workflow.

## Deferred boundary

Slice 2.1-C2a does not implement relationship correction, reactivation, replacement, or successor
links; consolidation-parent changes; corporate-unit moves, legal-entity transfers, closure, or
reopening; registered-impact preview; educational structures; legal-operation responsibility;
migration; real data; or a connected/public surface.

The structural transitions stay deferred because TM-17 and AC-18 require a registered consumer
impact inventory, preview, and writer-side revalidation that do not yet exist. C25-03 and C25-04
continue to block Slice 2.1-D.

## References

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0031](../adr/0031-bounded-cross-jurisdiction-legal-structure-foundation.md)
- [ADR 0032](../adr/0032-c25-02-delegated-contract-acceptance.md)
- [ADR 0033](../adr/0033-append-only-legal-structure-lifecycle-foundation.md)
- [C25-02 completed review](c25-02-corporate-governance-finance-review.md)
- [Slice 2.1-C1 evidence](legal-structure-foundation-evidence.md)
- [Institutional-structure security and migration review](institutional-structure-security-migration-review.md)
- [Threat model](../security/threat-model.md)
- [Security abuse cases](../security/abuse-cases.md)
