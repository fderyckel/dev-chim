# Core-foundation Slice 1G-B role-assignment evidence

- Status: Focused action, migration lifecycle, production-core, and complete repository verification pass
- Date: 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md), and [threat model TM-01/TM-02/TM-09/TM-10/TM-14/TM-15](../../security/threat-model.md)
- Source basis: completed Phase 0 evidence, implemented Slices 1A through 1G-A, and the explicitly authorized next bounded slice

## Question

Can the production core add one tenant-qualified authority edge through a private named action
while preserving writer-side authorization, cross-tenant non-disclosure, exact replay, immutable
evidence, atomic rollback, and the absence of a generic administration surface?

## Implemented boundary

`ActorRoleAssignment.assign_role` is a private Ash generic action.
`Authority.assign_role/3` is its only supported invocation boundary. It accepts exactly
`membership_id`, `role_id`, `idempotency_key`, and `causation_id`; actor, tenant, placement,
routing, correlation, writer selection, authorization, and Ash options come only from validated
platform context.

The action requires `platform.authority.assignments.create`, takes the tenant authority-write
transaction lock, and rechecks the capability on the current writer. It locks both referenced
records with tenant-qualified predicates before inserting the edge. Missing and cross-tenant
references have the same not-found shape, while compound PostgreSQL foreign keys remain the
final defence for alternate writers.

The new assignment is an immutable UUID aggregate at lock version 1. One writer transaction
contains the assignment, an authority-audit fact for version `0 -> 1`, a minimal outbox fact,
and a completed action-idempotency result. The outbox carries assignment, membership, role, and
version identifiers but no tenant-defined role label and no placement authority.

## Idempotency and compatibility

The idempotency key is bound to tenant, action, actor, canonical membership/role request, and
causation identifier. Exact and concurrent retries return the originally committed assignment
and evidence references. Changed input or actor returns `:idempotency_conflict`; the same key is
independent in another tenant. A different key for an already existing membership-role pair
returns `:conflict` and leaves no second claim or evidence fact.

The action-idempotency table is expanded with an optional JSON result payload. Its compatibility
constraint permits either the existing role-rename name/version result pair or the new JSON
payload, never both. Existing rename claims remain valid and the older rename write path remains
compatible during the mixed-version window. No column is dropped or reinterpreted.

## Failure and recovery contract

Raw context and authority-shaped input fail before persistence. Missing capability is forbidden;
cross-tenant references are not found; duplicate assignment is a conflict; malformed input is
invalid; and unavailable writer work remains a retryable dependency. Stable errors disclose no
tenant, actor, membership, role, repository, placement, SQL, or policy detail.

A fault-injection trigger fails idempotency completion after assignment, audit, and outbox writes.
The writer transaction rolls all four records back, after which the same request succeeds exactly
once. Direct SQL tests also prove the compound membership foreign key rejects a cross-tenant edge
and the new assignment-version constraint rejects version zero.

## Migration review

AshPostgres generated one migration and three resource snapshots. Manual review confirmed:

- `lock_version` is non-null with a positive check on the assignment row;
- `result_payload` is a JSON object when present and remains optional for rename compatibility;
- completion requires exactly one result representation plus audit, outbox, and completion time;
- audit versions now permit creation evidence `0 -> 1` while preserving consecutive versions;
- no tenant key, compound foreign key, unique index, or existing result column is removed; and
- down migration is empty-data evidence only and fails closed when assignment action facts remain.

The migration applied, rolled back after synthetic action data was cleared, reapplied, and passed
resource-snapshot drift checking.

## Focused evidence

Commands:

```sh
make test-fast
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/authority_role_assignment_test.exs \
  apps/chimwemwe_core/test/chimwemwe/platform/authority_role_rename_test.exs
cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check \
  --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
```

Results:

- **6 role-assignment tests passed** and the **6 role-rename regression tests passed**;
- the complete fast production-core suite passed with **75 tests** after ADR 0018 T1-A was integrated;
- warnings-as-errors compilation passed;
- migration apply, rollback, reapply, and drift checks passed; and
- direct browser, API, worker, dispatcher, and external-service scope remained absent.

## Complete verification

The required complete `make check` passed on 2026-09-25 after the temporal-qualification
migration separated trigger functions and triggers into valid prepared DDL statements. The run
passed 24 repository Python tests, 103 Phase 0 Elixir/PostgreSQL tests, six generated TypeScript
client tests, 75 production-core tests, seven UI-0 unit tests, and 12 Playwright tests. It also
passed formatting, lint, generated artifacts and migration drift, dependency and warning audits,
both Dialyzer suites, documentation conventions, types, the production browser build, keyboard
and reflow checks, automated accessibility checks, and Git whitespace validation.

## Scope and limits

- This increment assigns existing records; it cannot create a membership, role, or capability.
- Capability grants, role inclusion, revoke, membership lifecycle, and cache invalidation remain
  unimplemented.
- Outbox dispatch, consumer deduplication, retention deletion, operational replay, and placement
  movement reconciliation remain later gates.
- The persistence runtime remains test-started with synthetic configuration and is not installed
  under `Chimwemwe.Application`.
- UI-0 remains synthetic and disconnected from the production core.
- No production identity, tenant, school, child, employee, or restricted data is present.
