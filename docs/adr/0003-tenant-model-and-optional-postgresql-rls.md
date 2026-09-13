# ADR 0003: Tenant model and optional PostgreSQL RLS

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Security architecture
- Deciders: Architecture review group and privacy owner
- Supersedes: None

## Context

Child and school data must not cross tenant boundaries through requests, jobs, events, caches, files, search, realtime, exports, telemetry, or AI tools.

## Decision drivers

- Fail-closed tenant propagation.
- Relationship-aware, tenant-defined authorization.
- Database constraints that prevent accidental cross-tenant links.

## Considered options

1. Ash application policies and mandatory tenant keys, with RLS deferred as a backstop.
2. Ash policies plus PostgreSQL RLS immediately.
3. Separate database per tenant.

## Decision

Propose one PostgreSQL cluster/schema model where every tenant-owned row has a non-null tenant key and compound constraints prevent cross-tenant relationships. Ash policies remain the business authorization layer. Decide RLS only after the pressure-test and threat analysis prove connection, job, migration, and support-context safety.

Roles, scopes, and capabilities are tenant-defined hierarchical data. School job-title constants are prohibited as the production authorization model.

## Consequences

### Positive

- One operating model supports efficient transactions and migrations.
- Optional RLS remains available as defence in depth.

### Negative

- Every path must propagate tenant context correctly.
- RLS, if adopted, complicates pooling, maintenance, support, and migrations.

## Security, privacy, operability, and migration effects

Missing tenant context fails closed. Support access requires explicit tenant selection, strong assurance, reason, expiry, and enhanced audit. Global reference data must be clearly separate from tenant-owned data.

## Validation evidence

See [threat model](../security/threat-model.md) and the Ash tenancy tests.

## Fallback and exit cost

Adopt RLS as a backstop if application-only controls cannot meet the accepted threat model. Database-per-tenant requires a new ADR and operational evidence.

## Review triggers

- A cross-tenant control weakness or independent security finding.
- Connection-pool, support, or job architecture changes.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [Data classification](../security/data-classification.md)

