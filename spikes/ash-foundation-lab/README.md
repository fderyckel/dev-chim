# Ash Foundation Lab

This is a disposable Phase 0 pressure-test for Ash, PostgreSQL tenancy, named actions, generated interfaces, transactions, migrations, telemetry, and upgrade ergonomics. It is not a production application or a hidden school business module.

## Run

From the repository root:

```sh
make bootstrap
make test
make check
```

All records are synthetic. PostgreSQL database names begin with `ash_foundation_lab_` and may be overridden through standard `PGHOST`, `PGUSER`, and `PGDATABASE` variables.

## Implemented slice

The lab currently includes a tenant-owned actor/role/capability graph and a capability-protected `submit_for_review` action. That action writes its audit reference, completed idempotency claim, and a minimal outbox fact in the same transaction. Exact retries return the committed result without a second event; reused keys with a changed actor, aggregate, or request envelope fail with a stable conflict. A generated JSON:API router exposes only the named transition and consumes actor, tenant, and synthetic failure-probe data from trusted connection-private context. Its stable error boundary covers validation, authorization, conflict, idempotency conflict, not found, missing tenant, rate limited, dependency unavailable, and internal failure without exposing private reasons. Its dispatch telemetry uses an exact metadata allowlist with correlation and a one-way tenant reference, never request or record payloads. Focused tests cover allowed, denied, cross-tenant existence-shape, missing-context, generic-update-bypass, renamed/composed-role, invalid-state, stale-write, exact and conflicting retries, concurrent submission, atomic rollback, transient/internal failure rollback, minimal-envelope, telemetry redaction, and database-constraint paths.

The resource definitions also declare their tenant indexes, compound identities, restrictive foreign keys, and database check constraints. A generated baseline and resource snapshots live under [`priv/generated_migration_review`](priv/generated_migration_review/) as review evidence, separate from the executable handwritten migration chain. `make check` fails if those snapshots drift, and focused tests inspect the generated migration's safety primitives and additive `up` path.

The isolated [`typescript-client-review`](typescript-client-review/) harness generates immutable declarations from the checked-in OpenAPI document and exercises a thin typed client. It is Phase 0 contract evidence, not the Phase 1 web workspace or a production toolchain decision.

The completed [dependency upgrade exercise](../../docs/phase-0/evidence/ash-upgrade-exercise.md) compares the immediately preceding framework patches with the current lock in a disposable copy. It records package changes, compile warnings, security-audit results, migration output, and the same 21-test compatibility result without turning network-dependent freshness checks into the local verification contract.

The neutral [`TrustedRouting`](lib/ash_foundation_lab/trusted_routing.ex) slice resolves authenticated tenant context through a versioned registry into real pooled or dedicated test databases and tenant-qualified infrastructure namespaces. Requests cannot select placement, spawned tasks require explicit propagation, jobs re-resolve current placement from an allowlisted envelope, and every missing, stale, unavailable, or mismatched route fails before work begins. The [routing evidence](../../docs/phase-0/evidence/trusted-routing.md) records the limits of this disposable control-plane stand-in.

The neutral [`SyntheticModuleLifecycle`](lib/ash_foundation_lab/synthetic_module_lifecycle.ex) slice keeps release availability, tenant entitlement, activation state, and actor capability independent. Named lifecycle actions serialize ordinary mutations against deactivation, park ordinary work, preserve mandatory work and replay cursors, retain data, atomically record audit/outbox facts, and reopen only after compatible reactivation and reconciliation. The [module-lifecycle evidence](../../docs/phase-0/evidence/module-lifecycle.md) distinguishes this transactional contract proof from a production module registry or real queue/search integrations.

## Evidence rule

Passing smoke tests proves only the scenarios those tests name. Ash remains Proposed until every mandatory category in [the evidence scorecard](../../docs/phase-0/evidence/ash-pressure-test.md) has direct evidence and ADR 0002 is reviewed.
