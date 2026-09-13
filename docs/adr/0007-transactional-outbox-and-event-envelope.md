# ADR 0007: Transactional outbox and event envelope

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering
- Deciders: Architecture review group and operations owner
- Supersedes: None

## Context

Post-commit jobs, projections, cache invalidation, search, webhooks, and notifications must not be lost or emitted for rolled-back state.

## Decision drivers

- Atomic domain state and durable event facts.
- Idempotent, replayable, observable consumers.
- Minimal, versioned payloads.

## Considered options

1. PostgreSQL transactional outbox dispatched through Oban.
2. In-process publish after commit without durable storage.
3. Kafka or another broker from the start.

## Decision

Propose a transactional outbox written with domain state. A versioned envelope includes event ID, type, schema version, tenant, actor/service context, correlation, causation, occurrence time, classification, and a minimal payload. Consumers are registered, idempotent, replayable, and observable.

Each outbox belongs to a trusted database placement. Dispatchers validate the tenant and current routing version rather than treating an event-supplied destination as authority. Tenant movement must quiesce, drain, or reconcile outbox cursors explicitly so events are neither lost nor processed in two placements.

## Consequences

### Positive

- Durable side effects remain consistent with committed state.
- Replay and stuck-event operations are possible.

### Negative

- Consumers must tolerate at-least-once delivery.
- Schema evolution and retention need governance.

## Security, privacy, operability, and migration effects

Events carry the minimum necessary data, never become an authorization or placement source, and preserve tenant/classification context. Operations need per-placement lag, retries, dead-letter handling, replay controls, movement reconciliation, and redacted diagnostics. Module deactivation must preserve mandatory audit, retention, and outbox processing even when ordinary module consumers are drained or parked.

## Validation evidence

The [Ash pressure-test](../phase-0/evidence/ash-pressure-test.md#transactional-outbox-slice) proves a successful action writes state, audit reference, and one minimal event fact together, while an injected failure after the event insert rolls all three back. It also proves missing correlation and causation context prevents the transition. Full consumer dispatch, retry, replay, retention, and placement-movement reconciliation belong to later phases.

## Fallback and exit cost

Add a broker only when measured throughput, retention, or consumer isolation cannot be met by PostgreSQL/Oban. The outbox remains the commit boundary.

## Review triggers

- Measured outbox throughput or retention limit.
- A consumer requires incompatible delivery or isolation semantics.
- Tenant movement, database routing, or module-lifecycle semantics change.

## Related records

- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [Deferred choices](../architecture/deferred-choices.md)
