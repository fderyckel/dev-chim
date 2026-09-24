# Core-foundation Slice 1F tenant-authority evidence

- Status: Focused, complete repository, and isolated clean-checkout verification pass
- Date: 2026-09-24
- Owner: Platform engineering
- Governing records: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md), and [threat model TM-01/TM-02/TM-14](../../security/threat-model.md)
- Source basis: completed Phase 0 evidence, implemented Slices 1A through 1E, and the current Slice 1F working tree

This record is the point-in-time acceptance evidence for Slice 1F. The later
[Slice 1G role-rename evidence](authority-role-rename.md) adds one private named action and
three closed evidence resources; it does not retroactively change what Slice 1F proved.

## Question

Can the production core persist and resolve tenant-defined authority without role-name constants, request-selected grants, cross-tenant relationships, graph cycles, a public mutation surface, or a second authorization engine?

## Implemented boundary

`Chimwemwe.Platform` now registers six tenant-owned AshPostgres resources:

1. `Membership` binds an authenticated actor UUID to one tenant.
2. `Role` stores a renameable label behind an immutable UUID and positive lock version.
3. `Capability` stores a tenant-owned stable dotted key.
4. `ActorRoleAssignment` assigns a membership to a role.
5. `RoleCapabilityGrant` grants a capability to a role.
6. `RoleInclusion` composes one role from another role recursively.

Every resource has a private, non-null tenant key and no global fallback. Each authority edge has a compound foreign key over its local `tenant_id` and the destination `(id, tenant_id)`. PostgreSQL therefore rejects a cross-tenant assignment, grant, or role inclusion independently of Ash policy or caller behavior.

Role inclusion uses a database trigger backed by a tenant-qualified transaction advisory lock and a recursive graph query. It rejects direct and indirect cycles on every write path. The same lock is the database half of the future Slice 1G composition action; application-level concurrency and stable public error mapping remain deferred with that action.

`Authority.authorize/3` accepts only an explicitly configured persistence runtime, a validated `ExecutionContext`, and one stable capability key chosen by platform code. It enters `Persistence.with_writer/3`, then resolves direct and inherited grants from the current writer. It accepts no role identifier, assignment, graph, actor replacement, tenant, route, placement, repository, or Ash option.

Capability keys are ordinary tenant data, but data alone cannot create authority: no action is authorized unless source-controlled platform code requires the exact key. Missing membership and missing grant both return `:forbidden`. Invalid keys and unavailable dependencies return stable non-disclosing errors.

The six resources deliberately expose no Ash actions. Their policies deny every action, and `Authority` exports no assign, revoke, grant, or include function. Direct SQL appears only in the synthetic test fixture to prove constraints and resolver semantics. Slice 1G owns the first real writes and must add capability checks, optimistic concurrency, idempotency, audit evidence, transactional outbox facts, exact retry, and negative tests.

## Migration review

AshPostgres generated the six resource snapshots and the initial migration operations. Manual review found that the generated migration ordered compound foreign keys before the referenced tenant columns and unique indexes existed, and its generated rollback removed a referenced column too early. The checked-in migration retains the generated schema intent but explicitly orders:

1. membership, role, and capability destinations and their tenant-qualified indexes;
2. assignment, grant, and inclusion edge tables with compound foreign keys; and
3. the role-cycle function followed by its trigger.

The migration was applied, rolled back completely, and reapplied against the synthetic PostgreSQL 18 test database. This proves the empty-foundation transition only. Once retained authority rows exist, table-dropping rollback is prohibited; forward repair or an approved restore point is required by the [migration discipline](../../development/migrations.md).

## Focused evidence

Focused command:

```sh
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/platform/authority_test.exs
```

Focused result: **6 tests passed**.

The suite proves:

- direct and transitive grants resolve from the current writer;
- renaming a role does not change its capabilities;
- the Ash policy adapter resolves the same authority inside the writer boundary;
- missing membership, missing grants, invalid capability input, raw context, tenant mismatch, stale routing, and unavailable runtime fail closed;
- policy resolution outside the selected writer fails closed;
- compound foreign keys reject cross-tenant assignment, grant, and inclusion;
- PostgreSQL rejects direct and indirect graph cycles without adding another edge; and
- all six resources satisfy the core resource contract, are tenant-owned, expose no actions, and have no graph-mutation API.

Migration commands:

```sh
mise exec -- env MIX_ENV=test mix ecto.migrate
mise exec -- env MIX_ENV=test mix ecto.rollback --step 1
mise exec -- env MIX_ENV=test mix ecto.migrate
```

Migration result: apply, complete rollback, and reapply passed.

## Complete verification

`make check` passed on 2026-09-24 after the focused and migration-lifecycle tests. It includes Python and Elixir formatting; Ruff and ShellCheck; repository/documentation validation; Phase 0 generated migration, OpenAPI, descriptor, and dependency-warning drift; both strict Credo and Dialyzer suites; Hex and npm audits; unused-dependency checks; the generated TypeScript client contract; the production-core migration/snapshot drift check; all database-backed tests; and Git whitespace checks.

The isolated clean-checkout rehearsal also passed after copying the complete candidate into a temporary clone, bootstrapping only from declared inputs, and running the same `make check`. It recorded 23 repository-tool tests, 103 Phase 0 Elixir/PostgreSQL tests, 6 TypeScript contract tests, and 57 Phase 1 core tests, with the candidate clean after bootstrap and verification. The machine-readable result is retained in `spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json`.

Verification found and corrected two issues before acceptance. Manual migration review caught generator ordering that would have created tenant-qualified foreign keys before their destination columns and indexes. Dialyzer then caught a resolver access that broke the opaque `TrustedActor` boundary; authority lookup now uses the type's internal accessor. The final migration drift check, strict lint, type analysis, and complete test suites pass after both corrections.

## Scope and limits

- The repository contains only synthetic authority records used by tests; no real identity or school data is present.
- The persistence runtime still requires explicit startup routes, credentials, pool sizes, and admission limits and is not installed in the application supervisor.
- This slice resolves actor authorization only. Release availability, entitlement, and module activation remain separate later gates.
- No role administration, support grant, break-glass access, role removal, revocation cache, public API, generated client, UI, job, event, audit row, outbox fact, or module is implemented.
- The resolver is writer-only. Replica routing for authorization remains prohibited by ADR 0017 and threat TM-14.
- Multi-node graph-mutation serialization is not claimed. The database lock protects the graph in one authoritative database; Slice 1G must prove concurrent named writes and stable outcomes.
- Independent security/privacy review remains mandatory before real restricted data or school-side identity ownership.
