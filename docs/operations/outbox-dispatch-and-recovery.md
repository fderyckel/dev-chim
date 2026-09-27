# Outbox dispatch, drain, replay, and recovery

- Status: Qualified for the local synthetic core; deployment qualification remains required
- Owner: Platform engineering and operations
- Governing records: [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md) and
  [ADR 0026](../adr/0026-module-aware-outbox-cursors-and-reconciliation.md)

## Observe

Read `Outbox.status/4` with trusted tenant context and `platform.outbox.observe`. Investigate a
non-zero dead-letter or stale-route count immediately. Investigate oldest-pending age against the
selected environment's later service threshold. Dispatcher telemetry is
`[:chimwemwe, :outbox, :dispatch]`; it contains tenant, routing version, consumer key, mode,
outcome, duration, and cumulative counts only.

Never copy payloads, actor identifiers, lease tokens, or unredacted errors into logs, tickets, or
telemetry. Never derive tenant placement from an event.

## Retry and poison events

Retry is bounded by the code-owned declaration. A handler failure records a stable code and either
delays availability or quarantines the delivery as dead letter. For an ordinary module consumer,
the earliest dead letter blocks later delivery so the cursor cannot skip a poison event.

Do not edit an event or receipt. Repair the consumer forward, deploy a compatible handler revision,
then use separately authorized replay.

## Exact and range replay

1. Confirm tenant, consumer, current routing version, handler revision, reason, and recovery owner.
2. Page dead letters with `Outbox.replay_page/5` using an exact `(after_cursor, through_cursor]`
   window and a limit no greater than 100.
3. Convert each returned event ID and expected lock version into its own `ReplayInput`, with unique
   idempotency and causation IDs and one stable reason code.
4. Submit at most 100 inputs through `Outbox.replay_range/5`. Repeating the identical inputs returns
   the retained exact results. Changed input or actor conflicts.
5. Dispatch and confirm dead-letter count, pending age, receipt, audit, and cursor convergence.

Replay never changes payload, schema version, classification, route, subscription, or authority.

## Module drain and reactivation

Ordinary consumers use `work_kind: :ordinary`, one-item batches, and exactly one ordinary consumer
per module. Deactivation records the acknowledged cursor and normal dispatch parks. Mandatory
consumers use `work_kind: :mandatory` and may continue while inactive.

Run `Dispatcher.reconcile_now/1` while inactive until it returns no further acknowledged work and
status shows no pending or dead-letter item for the frozen cursor window. Use the registry-aware
`ModuleLifecycle.reactivate/5`; it rechecks the backlog on the authoritative writer and refuses to
open authority while reconciliation is incomplete.

## Recovery drills

- **Process crash after consumer commit:** restart the supervised dispatcher. The durable receipt
  returns `already_processed`; acknowledge without running the handler twice.
- **Lease expiry:** wait for database time to expire the lease; the next claim uses a new exact
  token. A stale token conflicts.
- **Database outage:** leave work durable and restart/poll after writer admission recovers. Do not
  acknowledge success from memory.
- **Stale route:** stop dispatch, restore trusted current placement, and reconcile. Never rewrite
  the event route from request data.
- **Incompatible schema:** deploy a code-reviewed compatible declaration/handler or forward
  translator. Do not widen the registry from event input.
- **Poison event:** allow bounded attempts to dead-letter, repair forward, exact replay, then resume.
- **Restore:** restore state, audit, outbox, delivery, receipt, idempotency, and sequence together;
  compare counts and maximum stream positions per tenant/consumer before resuming.

Escalate when authoritative state and outbox facts differ, a receipt lacks its delivery, a cursor
exceeds the maximum retained stream position, routing is stale, or restored counts diverge. Keep the
module inactive and the dispatcher stopped until reconciliation is proven.
