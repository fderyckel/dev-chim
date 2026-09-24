# Production-core migration discipline

- Status: Active from Phase 1 Slice 1E
- Owner: Platform engineering
- Governing records: [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), and [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)

Ash resource declarations and generated migrations provide reviewable schema intent. They do not own deployment choreography, production lock budgets, mixed-version compatibility, backfill, destructive approval, backup, restore, or forward repair.

## Required sequence

Every retained-data change is classified before implementation:

1. **Expand:** add compatible nullable fields, tables, indexes, or not-valid constraints under an explicit lock budget.
2. **Mixed-version operation:** prove old and new application versions can read and write safely for the declared deployment window.
3. **Backfill:** use bounded, restartable, tenant-qualified batches with current trusted placement and observable progress.
4. **Validate:** verify retained rows, tenant isolation, constraints, indexes, query plans, WAL, replica effect, and recovery assumptions separately from expansion.
5. **Contract:** drain old code, record backup or recovery evidence, obtain accountable approval, and prefer a forward repair when down migration would destroy data.

Generated artifacts are reviewed for non-null tenant keys, tenant-qualified unique constraints and foreign keys, index and lock impact, stable identifiers, rollback behaviour, and expand-and-contract safety. Partitioning remains evidence-driven and must account for compound uniqueness and foreign keys.

## Repository contract

- Production-core migrations belong under `apps/chimwemwe_core/priv/repo/migrations`.
- Ash resource snapshots belong under `apps/chimwemwe_core/priv/resource_snapshots`.
- `bin/core-check` runs the generator in drift-check mode.
- Slice 1E intentionally contains no migration or snapshot because the production Ash domain was still resource-empty.
- Slice 1F adds the first generated resource snapshots and reviewed migration. The generator's initial dependency ordering was invalid for the compound foreign keys, so the migration was manually reordered to create each tenant-qualified destination index before its dependants.
- The Slice 1F migration must apply, roll back, and reapply against synthetic PostgreSQL. Its down path drops the new empty-foundation tables and is development rollback evidence, not authorization to drop retained production authority data; once populated, forward repair and recovery evidence are required.
- The first Slice 1G migration adds authority-audit, outbox, and action-idempotency tables. Generator output again required dependency review: audit and outbox tenant-qualified indexes must exist before dependent compound foreign keys, optional idempotency references use `MATCH SIMPLE` so an in-transaction `started` claim remains valid, and rollback must remove idempotency before outbox before audit.
- Slice 1G migration rollback is synthetic empty-data evidence only. A committed role rename is authoritative state with retained audit/outbox/idempotency facts; it is never reversed by dropping tables or decrementing a version.

No migration may contain real school data, credentials, tenant-specific code, an implicit default placement, or an irreversible contract step without the documented owner, window, drain, recovery point, and repair or restore path.
