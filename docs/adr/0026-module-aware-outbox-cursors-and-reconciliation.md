# ADR 0026: Module-aware outbox cursors and reconciliation

- Status: Conditionally Accepted
- Date: 2026-09-26
- Accountable owner: Platform engineering
- Deciders: Project owner, platform engineering, and security architecture
- Supersedes: None

## Context

ADR 0007 requires durable, tenant-qualified delivery, governed replay, and module-aware drain.
Slices 1H-B and 1J-B proved those concerns separately: lifecycle retained an integer consumer
cursor while the outbox ordered events by time and UUID, and exact dead-letter replay had no
bounded cursor/range workflow. Treating those proofs as integrated would allow ordinary work to
continue after deactivation or ordinary authority to reopen before backlog reconciliation.

## Decision drivers

- Preserve exact tenant isolation, ordering, idempotency, and current trusted placement.
- Connect lifecycle drain to executable consumer behavior without a second queue authority.
- Make poison events, lag, replay, and recovery observable without logging payloads.
- Keep old writers compatible and retained cursor evidence non-destructive.

## Considered options

1. Keep lifecycle and outbox cursors separate. Rejected because reactivation could assert
   convergence without consuming the durable stream.
2. Add the module-aware ordered cursor contract described below. Selected.
3. Introduce an external broker or job system. Rejected because 2.0-B does not justify another
   authority or service.

## Decision

Each outbox event receives an immutable database-assigned `stream_position`. Positions are global
and may contain gaps, but every read and mutation remains tenant-qualified; the value is ordering
evidence, never tenant, placement, or authorization evidence.

The code-owned consumer declaration classifies a consumer as platform, module-ordinary, or
module-mandatory. A module may declare at most one ordinary cursor-owning consumer. Ordinary
dispatch runs only while the module is active. Explicit reconciliation dispatch runs only while it
is inactive and reconciliation is required. Mandatory consumers may continue while inactive.

Acknowledging an ordinary module event advances its activation cursor in the same transaction.
Ordinary delivery is strictly ordered and stops behind an earlier dead letter. Deactivation records
the last acknowledged cursor. Reactivation fails closed until the declared ordinary consumer has
no unclaimed, available, leased, expired, or dead-letter item after that boundary; only then may it
record the reconciled cursor and reopen ordinary authority.

Operators page dead letters through a bounded cursor query and submit the returned exact event and
lock-version inputs to range replay. Each item retains the existing separate replay capability,
audit, optimistic conflict, and idempotency contract; range replay is a bounded ordered composition
of exact replays rather than a payload-editing or bulk-authority bypass.

Dispatcher telemetry contains the tenant identifier, consumer key, routing version, mode, counts,
and timing only. It contains no payload, event identifier, actor identifier, lease token, or error
text.

## Consequences

- Old writers remain compatible because PostgreSQL assigns the new stream position.
- A failed or poisoned ordinary event blocks later ordinary events until separately authorized
  replay or forward repair, making the operational blockage visible rather than silently skipping.
- Reconciliation is explicit and can take several bounded dispatch cycles before reactivation.
- This does not add Kafka, Oban, a public event browser, arbitrary payload editing, or an external
  consumer.

## Security, privacy, operability, and migration effects

Every cursor query, claim, acknowledgement, replay, lifecycle lookup, and telemetry record is
tenant-qualified. Capability checks remain separate for dispatch, observation, and replay. Events
cannot choose placement, handler, module, work kind, or replay scope. The additive migration keeps
old writers compatible through a database default, backfills deterministically, and refuses
destructive rollback after any event is retained.

## Validation evidence

Acceptance requires tenant and capability negatives, active/inactive/mandatory dispatch tests,
cursor advancement, poison-event ordering, exact cursor paging and replay, idempotent retries,
stale-route and schema rejection, crash/lease/database-outage recovery, telemetry redaction,
migration rollback/reapply, retained-evidence rollback refusal, and `make check`.

The implementation evidence is maintained in
[Slice 2.0-B operational outbox and module drain evidence](../phase-2/operational-outbox-and-module-drain-evidence.md).

## Fallback and exit cost

If ordered module reconciliation cannot preserve these properties, module consumers remain parked
and ordinary module authority remains closed. The fallback is forward repair or an approved restore
point, never skipping a cursor or editing an event payload.

## Review triggers

Review before multiple ordinary consumers per module, external effects, partitioned streams,
retention deletion, tenant movement across placements, a public operator interface, or a selected
production deployment.

## Related records

- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Outbox recovery runbook](../operations/outbox-dispatch-and-recovery.md)
