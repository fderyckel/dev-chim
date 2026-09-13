# ADR 0009: Cache taxonomy, invalidation, and Valkey trigger

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering
- Deciders: Architecture review group and security architecture
- Supersedes: None

## Context

Caching can improve latency but can also leak restricted data or preserve revoked access.

## Decision drivers

- Classification-aware eligibility.
- Tenant-safe keys and deterministic invalidation.
- Safe degradation when cache infrastructure fails.

## Considered options

1. Browser/public caching plus an application cache abstraction with ETS L1 and a measured Valkey trigger.
2. Valkey as a mandatory shared cache from the start.
3. Ad hoc caching inside modules.

## Decision

Propose explicit cache classes, ownership, tenant-aware/versioned keys, TTL, invalidation event, bypass, and observability. Begin with public/browser caching where safe and ETS behind an adapter. Do not deploy Valkey until cross-node reuse or coordination has a measured requirement.

## Consequences

### Positive

- Modules cannot invent incompatible cache policy.
- Shared infrastructure is deferred until justified.

### Negative

- Cache declarations and negative tests add design work.
- Some restricted views may remain uncached.

## Security, privacy, operability, and migration effects

Restricted data is prohibited from shared cache by default. Authorization is re-evaluated where required, invalidation is durable, and cache failure must degrade to authoritative reads without weakening policy.

## Validation evidence

See cache abuse cases in the [threat model](../security/threat-model.md). Full stampede and stale-event tests belong to Phase 5.

## Fallback and exit cost

Disable or bypass caching safely. Introduce Valkey only through an ADR update with capacity, consistency, and operational evidence.

## Review triggers

- Multi-node cache reuse becomes a measured bottleneck.
- A stale authorization or cross-tenant cache finding occurs.

## Related records

- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)

