# ADR 0009: Cache taxonomy, invalidation, and Valkey trigger

- Status: Accepted
- Date: 2026-09-13
- Decision date: 2026-09-16
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

Adopt explicit cache classes, ownership, tenant-aware/versioned keys, TTL, invalidation event, bypass, and observability. Placement and module-lifecycle versions participate in keys or namespaces where movement or deactivation could otherwise serve stale data. Begin with public/browser caching where safe and ETS behind an adapter. Do not deploy Valkey until cross-node reuse or coordination has a measured requirement.

## Plain-English summary

### What this means

A cache is a short-lived copy used to make a screen or service faster. Chimwemwe may use those
copies only under written rules that keep one school's information separate, respect changed
permissions, and allow the product to fall back safely to the authoritative record.

### What was agreed

- Every cache needs an owner, a data classification, a safe time limit, a way to clear it, and
  monitoring.
- Cache keys must keep organisations separate and account for changes such as a tenant move or a
  module being switched off.
- Restricted information is not placed in a shared cache by default.
- If the cache is unavailable, the product reads the authoritative source instead; it must not
  weaken permission checks to remain fast.
- The product starts with safe browser caching and a simple in-application cache. A shared cache
  service such as Valkey is deferred until measurements show it is needed.

### Context

Temporary copies can make frequently used information appear quickly, but an old or wrongly shared
copy could expose restricted learner information or continue to show access after it has been
removed. The decision treats correctness and privacy as more important than a speed improvement.

### Examples

- A public, non-sensitive page could be stored briefly so it opens faster for many visitors.
- If a staff member's access is revoked, a protected view must not keep showing a previously
  cached result as though the permission still existed.
- If a school moves to another approved technical placement, affected temporary copies are cleared
  or separated so an old location cannot serve stale information.

## Consequences

### Positive

- Modules cannot invent incompatible cache policy.
- Shared infrastructure is deferred until justified.

### Negative

- Cache declarations and negative tests add design work.
- Some restricted views may remain uncached.

## Security, privacy, operability, and migration effects

Restricted data is prohibited from shared cache by default. Authorization and module gates are re-evaluated where required, invalidation is durable, and cache failure must degrade to authoritative reads without weakening policy. A tenant move or module deactivation invalidates affected namespaces; unknown placement state cannot fall back to a shared cache.

## Validation evidence

See cache abuse cases in the [threat model](../security/threat-model.md). Full stampede and stale-event tests belong to Phase 5.

## Fallback and exit cost

Disable or bypass caching safely. Introduce Valkey only through an ADR update with capacity, consistency, and operational evidence.

## Review triggers

- Multi-node cache reuse becomes a measured bottleneck.
- A stale authorization or cross-tenant cache finding occurs.
- A tenant-movement or module-deactivation rehearsal serves stale data.

## Related records

- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
