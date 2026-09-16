# Retained-data expand-and-contract migration rehearsal

- Status: Focused disposable-database evidence passes; production-scale acceptance remains open
- Date: 2026-09-15
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)
- Baseline revision: `61469c9` plus the documented working-tree slice

## Question

Can the current Ash/PostgreSQL foundation preserve tenant-owned retained data across a mixed-version additive schema change, bounded tenant backfill, constraint validation, rollback window, and explicitly gated destructive contract?

## Environment and artifacts

- PostgreSQL 18.6 on the local Apple-silicon development host.
- Existing executable migration chain through transactional action idempotency.
- Seven final synthetic `foundation_records` across two synthetic tenants; no real school or child data.
- Platform-owned batch runner: [`retained_data_migration.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/retained_data_migration.ex).
- Reviewable migration sequence: [`retained_data_migration_rehearsal/migrations`](../../../spikes/ash-foundation-lab/priv/retained_data_migration_rehearsal/migrations/).
- Focused tests: [`retained_data_migration_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/retained_data_migration_test.exs).

The sequence is deliberately separate from the executable application chain. It runs only against uniquely named disposable databases and proves migration choreography rather than changing the lab's current resource contract.

## Rehearsed sequence

1. **Expand:** add nullable `canonical_name` without a default or table rewrite, add a `NOT VALID` non-empty check, and impose a transaction-local `250ms` lock timeout.
2. **Mixed-version window:** legacy SQL continues to read and write `name`; the candidate reader uses `coalesce(canonical_name, name)` and the candidate writer updates both columns.
3. **Backfill:** a typed actor, tenant, and correlation context is required. Each transaction selects at most 100 rows for exactly one tenant in stable order with `FOR UPDATE SKIP LOCKED`, copies the legacy value, and returns the processed identifiers.
4. **Enforcement gate:** after legacy writers are drained, a write-blocking lock and explicit no-null precondition precede a reversible `NOT VALID` presence check. Any late legacy row aborts this migration without leaving its constraint or migration version behind.
5. **Validation:** non-empty and presence checks are validated in a separate migration before cleanup.
6. **Contract:** the validated column becomes `NOT NULL`, then the legacy column is dropped with `RESTRICT`. The migration refuses automatic down migration because the destructive step needs a backup restore or reviewed forward repair.

PostgreSQL documents that `NOT VALID` avoids the initial existing-row scan while enforcing the constraint for subsequent changes, and that `VALIDATE CONSTRAINT` uses a weaker `SHARE UPDATE EXCLUSIVE` lock. A valid check proving non-nullness can also avoid a second table scan when `SET NOT NULL` runs. See the [PostgreSQL 18 `ALTER TABLE` documentation](https://www.postgresql.org/docs/18/sql-altertable.html). The transaction-local timeout follows the [PostgreSQL `lock_timeout` contract](https://www.postgresql.org/docs/18/runtime-config-client.html#GUC-LOCK-TIMEOUT), avoiding a cluster-wide setting.

## Commands and results

```sh
cd spikes/ash-foundation-lab
mise exec -- mix format \
  lib/ash_foundation_lab/retained_data_migration.ex \
  test/ash_foundation_lab/retained_data_migration_test.exs \
  priv/retained_data_migration_rehearsal/migrations/*.exs
mise exec -- env MIX_ENV=test mix test \
  test/ash_foundation_lab/retained_data_migration_test.exs --trace
```

Result: 3 tests passed. A synthetic legacy reader held a conflicting table lock; expand returned PostgreSQL `lock_not_available` in 544ms including migrator overhead, below the asserted two-second outer bound, and left no `canonical_name` column. After release, expand applied and rolled back while retaining every legacy identifier and value.

The mixed-version path proved the old reader, old writer, fallback reader, and dual writer together. Tenant A was backfilled in batches of two then one while tenant B's two rows remained untouched. A late old-only write caused the enforcement migration to fail and roll back. After the final tenant-scoped batch, enforcement, validation, and contract succeeded; all seven identifiers, tenant keys, and canonical values matched the pre-contract snapshot. The old query then failed with PostgreSQL `undefined_column`, proving that destructive contract must remain behind the version-drain gate.

## Decision impact

The migration-readability and safety category advances from Partial pass to **Pass with bounded remediation**. The Ash generator remains useful for schema-drift and declared-constraint review, but it does not own deployment choreography, mixed-version application behaviour, tenant-by-tenant backfill, lock budgets, or destructive-contract authorization. Those remain platform-owned migrations, runbooks, and tests.

This result does not accept Ash or ADR 0002. It demonstrates that the required escape hatch can remain bounded and reviewable for one neutral retained-data change.

## Limits and falsifiers

- Seven local rows are compatibility evidence, not a production lock-duration, throughput, WAL, storage, or maintenance-window benchmark.
- The legacy and candidate versions are simulated with explicit SQL, not two independently deployed application releases.
- Trusted database placement is a caller precondition; this slice does not integrate the backfill runner with a production registry, tenant movement, or per-placement credentials.
- No heavy index, type rewrite, partitioned table, replica, HA failover, restore, or mixed-release node fleet is exercised.
- The `250ms` lock timeout and batch maximum of 100 are synthetic safety values, not approved production targets.
- Contract is intentionally irreversible in the migration API and runs only in a disposable database. Production use requires an approved backup/PITR point, drain proof, owner, window, and forward-repair or restore plan.
- The recommendation changes if production-shaped data shows unacceptable lock, validation, WAL, replica-lag, or backfill behaviour, or if framework-generated migrations cannot coexist predictably with the platform-owned sequence.
