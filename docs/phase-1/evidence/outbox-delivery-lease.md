# Slice 1J-A internal outbox delivery lease

- Status: Implemented; focused, production-core, migration, and complete repository verification passing on 2026-09-26
- Owner: Platform engineering
- Governing records: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), and [TM-10](../../security/threat-model.md)
- Scope: durable internal claim, exact lease transitions, retry/dead-letter state, and sanitized status only

## Question

Can the production core make committed outbox facts available to one declared internal consumer
without allowing request or event data to select a consumer, tenant, placement, subscription,
limit, authority, or destination, and without yet installing a worker or claiming production
readiness?

## Implemented boundary

`ConsumerRegistry` accepts only immutable code-owned declarations with one stable consumer key,
exact event-type/schema-version pairs, and bounded batch, lease, attempt, and retry limits. The
public `Outbox` facade revalidates the opaque registry and trusted `ExecutionContext` on every
operation. No request map or retained event can invent or widen a consumer declaration.

`Outbox.claim/4` enters the current authoritative writer and requires
`platform.outbox.dispatch`. Its tenant-qualified query accepts only subscribed internal events at
the current trusted routing version, orders them by occurrence and event ID, and claims no more
than the code-owned batch limit. PostgreSQL event-row locks with `SKIP LOCKED` give competing
claimers one active lease. An expired lease may be reclaimed with a new token and incremented
attempt; an active lease may not.

The closed `Outbox.Delivery` resource stores only operational state. Its event relationship uses
a compound `(event_id, tenant_id)` foreign key and its unique event/tenant/consumer key prevents
duplicate delivery state. Database checks constrain stable consumer keys, known states and failure
codes, positive attempts and versions, and mutually consistent lease, completion, retry, and
dead-letter fields.

`Outbox.acknowledge/6` and `fail/7` require the exact consumer, event, active lease token, current
route, subscription, schema, and internal classification. PostgreSQL time—not application time—
decides whether the lease is active. Exact completed acknowledgement and exact recorded failure
replay return the retained result; another token or failure code conflicts. Retry delay and the
dead-letter threshold come only from the declaration.

`Outbox.status/4` requires the independent `platform.outbox.observe` capability. It returns only
consumer-scoped counts plus the oldest pending timestamp, including stale-route and expired-lease
counts. It returns no tenant, actor, event, aggregate, payload, audit, repository, placement,
routing, lease, or capability identifier.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Declaration governance | Duplicate, widened, malformed, and over-limit consumer declarations fail closed |
| Tenant and route safety | Claims include only the current tenant, current routing version, internal classification, exact type, and exact schema |
| Bounded concurrency | A two-event batch limit is enforced; two competing claimers produce one lease and one empty result |
| Lease safety | Active leases cannot be reclaimed, expired leases receive a new token, and expired or replaced tokens cannot transition state |
| Exact outcomes | Same-token acknowledgement and failure are idempotent; another token or failure code conflicts |
| Retry and dead letter | A failed delivery waits for the declared retry time and dead-letters at the declared attempt limit |
| Authority separation | Dispatch-only and observe-only actors cannot cross capabilities; capability failure occurs before event lookup |
| Non-disclosure | Another tenant cannot claim or transition the event, and status exposes no record or infrastructure identifiers |
| Alternate writes | The compound foreign key rejects a cross-tenant event reference and state checks reject an inconsistent completed lease |
| Availability | An unavailable persistence runtime fails closed through the existing retryable-dependency contract |

## Migration review

The reviewed migration creates the delivery table after the immutable outbox-event destination,
uses a compound tenant-qualified foreign key, and adds unique identity plus dispatch-path indexes.
Its down path permits only the explicitly empty synthetic rollback and raises once any delivery
attempt is retained. That guard does not substitute for a production lock budget, mixed-version
deployment proof, backup, restore, or forward-repair plan.

## Verification

The focused outbox suite passes all 7 tests with deterministic seeds 0 and 799205. The combined
production-core fast suite passes all 127 tests. Strict compilation, Credo over 128 source files
and 1,358 modules/functions, Dialyzer with zero errors or skipped warnings, empty migration
rollback/reapply, retained-state rollback refusal, and generated migration/snapshot drift all pass.

Complete `make check` verification also passes: 25 Python tests, 6 generated TypeScript contract
tests, 106 Phase 0 Elixir/PostgreSQL tests, 127 production-core tests, 20 web unit tests, 12 UI-0
browser tests, 6 connected UI-1A browser tests, and 1 unavailable-core recovery browser test,
together with formatting, lint, dependency, type, generated-contract, build, and whitespace gates.

## Remaining Slice 1J gates

Slice 1J-A is not an operational-readiness completion claim. It executes no consumer, schedules no
work, publishes nothing externally, and offers no dead-letter replay or administration. A later
bounded increment must define and prove real adapter idempotency, replay authorization and audit,
module drain/reconciliation integration, retention, redacted metrics and alert thresholds, and
operator runbooks.

The actual selected environment must still pass multi-node admission, sustained and burst
capacity, outbox lag and recovery, placement movement, migration rehearsal, backup/restore,
deployment qualification, and independent security/privacy review before restricted data or a
dependent school capability is allowed.
