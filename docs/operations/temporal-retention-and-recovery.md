# Temporal retention, migration, and recovery

- Status: Qualified for the local synthetic neutral proof; domain and deployment qualification remain required
- Owner: Platform engineering and operations, with the applicable records owner
- Governing record: [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)

## Boundary

This runbook operates the neutral temporal qualification proof. It does not define a school
retention schedule, lawful-erasure outcome, selected backup window, or production service target.
Before a domain adopts the pattern, its records owner must declare classification, retention start,
duration, legal-hold authority, export behavior, erasure outcome, backup expiry, and recovery owner.

All actions require trusted actor and placement context, the authoritative PostgreSQL writer, an
exact tenant-defined capability, a reason code, and—except projection rebuild—an idempotency and
causation identifier. Never derive tenant, module, repository, or placement from request input or
an outbox event.

## Retention and legal hold

1. Declare retention only for an existing exact aggregate and entitled module. Record a code-owned
   policy key, classification, start date, and end date; do not put policy prose or protected
   content in the row.
2. Place a legal hold with the exact control version and a SHA-256 reference digest. Store the
   underlying case or instruction only in its approved system, not in audit, outbox, or receipt
   payloads.
3. A hold blocks erasure. Release requires the exact active digest and next expected version.
   Racing transitions serialize; one wins and the other receives a stable conflict.
4. Deactivation closes ordinary module work but retains mandatory hold release and erasure paths
   while lifecycle state remains `retained`. Missing entitlement, stale route, or a non-retained
   inactive state fails closed.

The current control is a selector over immutable receipts. Direct deletion, identity changes,
version skipping, receipt mutation, and state changes without the matching receipt are rejected by
database constraints and triggers.

## Erasure and propagation

The synthetic action is eligible only after its declared retention end and only when no hold is
active. In one writer transaction it:

1. appends an immutable minimal erasure receipt;
2. changes the control to `erased` with the exact next version;
3. replaces segment payloads with `[redacted]` and fact quantities with zero while preserving
   stable chain, operation, and effective-time identifiers;
4. attaches the tenant-qualified receipt to every redacted row;
5. deletes the disposable current projection; and
6. commits minimized audit, outbox, and exact idempotency evidence with the state transition.

The action deliberately does not expose undelete or restore. Projection, cache, search, analytics,
export, and integration consumers remain domain-owned propagation work. A real domain must keep
ordinary authority closed until those named consumers acknowledge the erasure fact or their own
approved retention window expires.

Backups may retain pre-erasure bytes until the approved backup expiry. Restoring an older recovery
point must not make those bytes available to users: keep interfaces closed, restore the current
erasure-receipt ledger from the approved recovery chain, reapply redactions, rebuild projections,
and verify convergence before reopening. A receipt proves completion within its stated recovery
boundary; it is not a claim that every expired offline medium was rewritten immediately.

## Import and reconciliation

- Register a source current row only as a baseline. Keep SHA-256 source-snapshot and source-ID
  digests, mapping revision, platform import time, and exact target revision.
- A duplicate source tuple conflicts. Source modification time never becomes platform recorded
  history.
- Missing predecessors, overlapping meaning, or ambiguous targets create a
  `reconciliation_required` record with no invented aggregate or revision.
- Reconciliation requires the exact pending record and appends immutable version two. The original
  conflict stays visible, and alternate updates or deletes fail at the database boundary.

## Expand, validate, and contract

Use the repository [migration discipline](../development/migrations.md). For this slice the
compatible expansion creates projection, provenance, retention-control, and receipt tables; adds
nullable redaction references; installs tenant-qualified indexes and foreign keys as `NOT VALID`;
then validates them separately. Trigger replacements are split into individual statements.

Only the empty synthetic state may roll the expansion back and reapply it. Once control, receipt,
import, redaction, audit, outbox, or idempotency evidence exists, rollback refuses. Repair forward
or restore an approved complete recovery point; never drop retained evidence to make a migration
pass.

## Restore and projection convergence

For the local synthetic rehearsal:

1. create a fresh source database and apply every migration;
2. run the recovery-fixture test at its named test line;
3. take a PostgreSQL custom-format dump with owner and privileges excluded;
4. restore into a fresh empty database;
5. compare aggregate, revision, segment, fact, projection, control, receipt, and import counts;
6. set `CHIMWEMWE_TEST_DATABASE` to the restored database and run
   `mix run priv/recovery/verify_temporal_restore.exs` from `apps/chimwemwe_core`;
7. require zero broken predecessor, import-target, redaction, and projection-current invariants.

The verifier deletes one disposable projection after restore and rebuilds it through the governed
action. A successful row-count comparison alone is not convergence evidence.

For a selected deployment, replace the local dump with its approved backup/WAL/PITR mechanism and
record recovery-point objective, recovery-time objective, encryption, key access, backup expiry,
restore isolation, data-volume, WAL, lock, and operator results. Local evidence does not set those
targets.

## Escalation

Keep the affected module inactive and interfaces closed when a hold is missing or mismatched, an
erased payload reappears, a receipt cannot be joined tenant-safely, import provenance points to a
missing revision, a chain predecessor is missing, a projection disagrees with current authority,
rollback removes retained evidence, or restored counts/invariants diverge. Preserve safe IDs and
error codes; do not copy protected payloads into telemetry or incident records.
