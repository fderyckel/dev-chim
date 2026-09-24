# Core-foundation Slice 1E trusted-persistence evidence

- Status: Focused and complete repository verification pass
- Owner: Platform engineering
- Date: 2026-09-23
- Source: revision `a30107f` plus the current Slice 1E working tree
- Governing records: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md) and [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)

## Question

Can the production core resolve a validated tenant context to an explicitly configured PostgreSQL repository, enforce node-local tenant and placement admission before checkout, and clean up process-local routing without adding a production resource or accepting request-selected infrastructure?

## Implemented boundary

Slice 1E adds `Chimwemwe.Repo`, an immutable `PlacementRegistry`, a supervised `PersistenceRuntime`, and `Persistence.with_writer/3`. The runtime owns its repository processes, complete route entries, and explicit admission limits. The operation API accepts only that runtime, an `ExecutionContext`, and a zero-argument synchronous callback.

Resolution compares the actor tenant and the complete trusted placement—including routing version, profile, and opaque placement reference—with the current startup-owned route. Only then does it resolve the repository child, acquire both admission limits, install the Ecto dynamic repository for the current process, and invoke the callback. The previous repository is restored in an `after` block. Spawned work receives no implicit route.

The route registry has no mutation function. Unknown, stale, and forged routes share one non-disclosing error. Unavailable runtime components share a retryable-dependency error. There is no default production database, placement, repository, or capacity setting and no application-supervisor wiring.

## Focused evidence

Focused command:

```sh
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/persistence_test.exs --trace
```

Result: 8 tests passed against the local synthetic PostgreSQL database.

The tests prove:

- a current pooled route selects its owned repository and executes a real `SELECT`;
- a dedicated route selects a different owned repository;
- callers have no repository-selector argument;
- raw maps, cross-tenant context, stale versions, forged placement references, and unknown tenants fail before the callback;
- the dynamic repository is restored after success and raised failure;
- a spawned task has no inherited dynamic repository;
- same-tenant saturation rejects before checkout while another tenant in the same placement can proceed;
- an unavailable runtime fails closed; and
- repositories, placements, and positive admission limits remain explicit startup requirements.

The empty production Ash domain also passes the AshPostgres migration generator in drift-check mode. The accompanying [migration discipline](../../development/migrations.md) retains expand, mixed-version, bounded tenant backfill, validate, and contract ownership outside the generator.

## Complete verification

`make check` passed on 2026-09-23 after the focused test. The result includes 23 repository-tool tests, 103 Phase 0 Elixir/PostgreSQL tests, 6 TypeScript contract tests, and 51 Phase 1 core tests. Python and Elixir formatting, Ruff, ShellCheck, repository/documentation validation, Phase 0 generated migration, OpenAPI and descriptor drift, Ash dependency-warning drift, the production-core empty migration/snapshot drift check, strict Credo, Hex and npm audits, unused-dependency checks, both Dialyzer suites with zero errors or skips, and Git whitespace checks also passed.

## Scope and limits

- The registry is immutable in-memory startup state, not a durable high-availability control plane or tenant-movement implementation.
- Repository tests use the local synthetic database. They do not qualify production credentials, selected hosting, failover, backup, restore, RLS, multi-node admission, or the accepted connection budget.
- The runtime is intentionally absent from the default application tree until a later deployment slice supplies trusted production configuration.
- Slice 1E itself introduced no production resource, table, migration, action, actor membership, role, capability, audit fact, idempotency claim, or outbox event.
- Slice 1F subsequently added the closed tenant-authority resources, compound tenant constraints, and negative authorization evidence. The first Slice 1G increment now proves those persistence guarantees for private role rename with idempotency, optimistic concurrency, audit, and a transactional outbox fact; other authority mutations remain deferred.
