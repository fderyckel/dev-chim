# ADR 0005: Domain action and state-transition convention

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering
- Deciders: Architecture review group
- Supersedes: None

## Context

Generic CRUD cannot express actor requirements, invariants, audit, side effects, idempotency, and controlled publication safely.

## Decision drivers

- Intent is explicit and reviewable.
- Every interface invokes the same policy-preserving behaviour.
- Errors, concurrency, and events are stable contracts.

## Considered options

1. Named actions and controlled state transitions.
2. Generic updates with UI-enforced workflow.
3. A universal workflow language.

## Decision

Propose versioned named actions with typed inputs, actor and tenant requirements, validation, authorization, invariant checks, concurrency rules, transaction semantics, error taxonomy, emitted events, audit metadata, cache effects, and AI exposure policy.

Under the explicit provisional Phase 1 exception, slice 1C may implement a read-only production-core invocation seam that derives actor and tenant from the validated execution context, admits only public named Ash reads in a governed domain, and exposes no caller-controlled Ash options. This does not authorize a state-changing invocation API or accept this ADR. The first write path still requires resource-specific persistence, migration, authorization, concurrency, idempotency, outbox, and recovery evidence.

## Consequences

### Positive

- Domain intent and security are visible in code and generated interfaces.
- Alternate clients cannot bypass UI workflow.

### Negative

- More deliberate design than generic CRUD.
- Compatibility and deprecation require ownership.

## Security, privacy, operability, and migration effects

Protected state cannot change through a generic update. Critical invariants are mirrored in PostgreSQL constraints. Actions use stable validation, forbidden, conflict, not found, rate limited, retryable dependency, and internal error categories.

## Validation evidence

The [Ash pressure-test](../phase-0/evidence/ash-pressure-test.md) now proves one named transition, capability and tenant denial, invalid-state validation, a caller-supplied optimistic version and idempotency key, database constraints, concurrent exact-retry serialization, exact committed-result replay, changed-request conflict, tenant isolation, atomic state/audit/outbox/idempotency rollback, and preservation of that named action through the generated JSON:API adapter and typed client. Stable public mappings cover validation, forbidden, conflict, idempotency conflict, not found, missing tenant context, rate limited, retryable dependency, and internal failure without disclosing private implementation details. The synthetic transient and internal failures occur before the state transaction and leave no state, outbox fact, or idempotency claim. The provisional [slice 1C invocation evidence](../phase-1/evidence/action-invocation.md) additionally proves that the production core can revalidate trusted context and invoke only public named reads while preserving Ash policy and tenant behavior without exposing write invocation or caller-controlled authority options. This completes the proposed error-taxonomy and read-boundary evidence; accountable review is still required before the ADR can leave Proposed.

## Fallback and exit cost

The convention survives an Ash fallback through explicit Phoenix/Ecto action modules.

## Review triggers

- Repeated action boilerplate obscures rather than clarifies intent.
- A client requires a transition that the action contract cannot represent safely.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
