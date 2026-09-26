# Slice 1J-B supervised internal consumption and exact replay

- Status: Implemented; focused, migration, production-core, and complete repository verification passing on 2026-09-26
- Owner: Platform engineering
- Governing records: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), [TM-10](../../security/threat-model.md), and [TM-13](../../security/threat-model.md)
- Scope: supervised database-local consumption, durable exact-delivery receipts, and capability-separated exact dead-letter replay only

## Question

Can the production core execute one trusted code-owned internal consumer and safely release one
exact dead letter without letting event, request, or replay data choose tenant, placement,
repository, handler, destination, payload, or subscription, and without installing a production
worker or claiming full operational readiness?

## Implemented consumption boundary

Each `ConsumerRegistry` declaration now pins a loaded module implementing the bounded `Consumer`
behaviour and a positive handler revision in addition to the exact event/schema and delivery
limits established by Slice 1J-A. Revalidation rejects a missing behaviour, unloaded module,
invalid revision, duplicate declaration, or widened/unknown key before event work.

`Outbox.consume/5` accepts the leased envelope only as an event-and-token locator. On the current
authoritative writer it requires `platform.outbox.dispatch`, locks the exact tenant/consumer/event
delivery, rereads the immutable event, and rechecks active database time, exact lease token,
current routing version, internal classification, subscription, and schema. The event actor remains
evidence; the validated service execution context remains authority.

The code-owned handler runs inside that writer transaction and may return only a small scalar map.
The core hashes its deterministic encoding and inserts one closed tenant-owned receipt in the same
transaction. The receipt pins event, consumer, event type, schema and routing versions, handler
revision, digest, and writer time. Compound foreign keys bind it to both the tenant event and the
exact tenant/consumer delivery. A handler exception, typed rejection, malformed result, insert
failure, or contract mismatch rolls back the transaction.

If the process fails after the receipt commits but before acknowledgement, the expired lease can
be reclaimed. Consumption finds the exact receipt and returns its digest without executing the
handler again. A changed handler revision or contract fails closed rather than silently treating
old work as compatible.

## Explicit supervision

`Outbox.Dispatcher` is a `GenServer` that can be placed under an explicit caller-owned supervisor.
Construction requires the persistence runtime, immutable registry, trusted execution context,
consumer key, and bounded poll interval. One poll claims the code-declared batch, consumes each
lease, then acknowledges it. Typed callback failures use the existing retry/dead-letter transition;
an acknowledgement dependency failure leaves the receipt-protected lease to expire safely.

The dispatcher is not a child of `Chimwemwe.Application`, chooses no production placement or
repository, and has no production interval or capacity default. Its status contains processed,
skipped, acknowledged, and failed counts plus the last-poll timestamp only.

## Governed exact replay

`Outbox.replay/5` requires `platform.outbox.replay`, independently of dispatch and observe. Its
typed input contains only the exact event UUID, expected dead-letter lock version, idempotency key,
causation UUID, and stable reason; the consumer still comes from the immutable registry.

Replay takes a transaction advisory lock for tenant/event/consumer, claims the existing
tenant/action idempotency manifest, and locks the tenant-qualified delivery plus immutable event.
Only an exact dead letter on the current route with the declared event/schema and internal
classification may proceed. The transition resets the attempt cycle to zero, increments replay and
lock versions, clears lease state, and keeps the prior failure code as retained operational
context. The next claim advances the attempt count to one.

The same transaction writes one minimized authority audit fact and completes the exact idempotency
result against the original event. Exact concurrent replay returns the one retained result;
changed reason, version, causation, event, consumer, handler revision, or actor conflicts. Replay cannot edit the
immutable payload, choose a handler or destination, or supply tenant, repository, or placement.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Registry governance | Loaded behaviour and positive revision are required; malformed module/revision and duplicate declarations fail closed |
| Authoritative execution | Consumption rereads the exact leased event and rechecks tenant, route, classification, subscription, schema, lease token, and database time |
| Crash-window idempotency | A reclaimed lease returns the durable receipt without a second handler execution |
| Revision safety | A receipt under handler revision 1 conflicts under revision 2 |
| Supervision | An explicitly supervised dispatcher consumes and acknowledges a bounded batch while exposing only count/time status |
| Failure containment | A raised handler exception is converted to the stable failure path and dead-letters at the declared limit |
| Result-contract safety | A malformed handler result returns `invalid_contract`, rolls back the receipt, and reaches dead letter only through the explicit failure transition |
| Authority separation | Dispatch-only cannot replay; replay-only cannot claim; missing trusted context fails before replay input parsing |
| Exact replay | Exact and concurrent replay produce one transition, one audit fact, one completed idempotency result, and the same returned result |
| Replay conflict | Changed input or actor conflicts; a stale route is rejected before mutation |
| Tenant isolation | Another tenant cannot consume, transition, or replay the event and receives no cross-tenant record details |
| Alternate writes | Compound references reject wrong-tenant/wrong-delivery receipts and digest checks reject malformed evidence |
| Availability | Missing persistence runtime fails closed without running the handler |

## Migration review

AshPostgres generated the receipt table, updated delivery snapshot, and replay counter. Review adds
the compound receipt-to-delivery `(event_id, tenant_id, consumer_key)` foreign key after the
referenced unique index from Slice 1J-A. Checks require stable keys, positive handler/schema/routing
versions, a 32-byte SHA-256 digest, and non-negative attempt/replay counts. Attempt zero is valid
only for the governed replay-to-next-claim interval; the delivery state constraint still requires
available state and a retained failure code.

The down path refuses destructive removal after any receipt, replay cycle, replay audit, or replay
idempotency evidence exists. This is development rollback protection, not production migration,
lock-budget, mixed-version, backup, restore, or forward-repair qualification.

## Verification

The focused outbox suite passes all 14 tests with deterministic seeds 0 and 799205. The reviewed
migration applies, rolls back while empty, reapplies, and refuses rollback with a retained receipt;
the test database was then restored to the fully migrated state. Migration and snapshot drift pass.

The production-core gate passes strict formatting and compilation, UI-1A OpenAPI drift, Credo over
138 source files and 1,461 modules/functions, dependency audit, Dialyzer with zero errors or skipped
warnings, all 134 core tests, and whitespace validation.

Complete `make check` also passes: 25 Python tests, 6 generated TypeScript contract tests, 106 Phase
0 Elixir/PostgreSQL tests, 134 production-core tests, 20 web unit tests, 12 UI-0 browser tests, 6
connected UI-1A browser tests, and 1 unavailable-core recovery browser test, together with the
formatting, lint, generated-contract, dependency, type, build, and documentation gates.

## Remaining Slice 1J gates

Slice 1J-B is not full operational readiness. It deliberately limits handler effects to the
authoritative database transaction and supplies no network/filesystem adapter, external publisher,
Oban job, production application child, replay range/cursor, payload repair, retention deletion,
module drain/reactivation integration, production telemetry/alerting, or operator console.

The actual selected environment must still prove multi-node admission, sustained and burst
capacity, lag and poison-event operations, module-aware drain/reconciliation, replay ranges and
cursors, migration rehearsal, placement movement, backup/restore and convergence, deployment
configuration, runbooks, and independent security/privacy review before restricted data or a
dependent school capability is allowed.
