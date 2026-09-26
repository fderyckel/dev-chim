# Slice 1H-A module-lifecycle initial activation

- Status: Implemented with focused, full production-core, and complete repository verification passing on 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0001](../../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), and [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md)
- Scope: neutral independent gates and safe initial activation only

## Question

Can the production core independently require release availability, tenant entitlement, compatible
tenant activation and dependencies, and current actor authorization while providing one safe,
private, auditable, retryable initial-activation action without creating a school module or a
generic lifecycle administration surface?

## Implemented boundary

`ReleaseManifest` is an opaque, immutable, code-owned value. Each declaration contains exactly a
stable module key, semantic version, accountable owner, and dependencies. Construction rejects an
empty manifest, duplicate keys, malformed keys or versions, missing dependencies, self-dependency,
and cycles. The manifest is placed in namespaced trusted action context; it is never action input.

`ModuleEntitlement` and `ModuleActivation` are tenant-owned persistent resources. Entitlement has
no action. Activation exposes one private `activate_module` action requiring the code-owned
`platform.modules.activate` capability. `ModuleLifecycle.activate/4` is the supported entry point:
it validates trusted context before exact input, selects the authoritative writer, derives release
version and dependencies, serializes by tenant and module, re-authorizes on the writer, and checks
the tenant's entitlement and dependency activations.

The initial transition accepts only module key, expected version zero, idempotency key, and
causation identifier. One transaction creates activation version 1, a minimized audit fact, a
versioned transactional outbox fact, and the completed exact-replay result. Replay is bound to
tenant, action, actor, module declaration, expected version, and causation. A changed request or
actor conflicts; tenant keys are isolated.

`ModuleLifecycle.authorize/5` is the ordinary use gate. It independently requires the module in
the trusted release, a tenant entitlement, an active row at the released version, every declared
dependency active at its released version, and the requested tenant-defined actor capability.
Activation does not grant that capability.

## Persistent model and migration review

AshPostgres generated the two resource snapshots and initial operations. Manual review reordered
the migration so `platform_module_entitlements` and its `(id, tenant_id)` destination index exist
before `platform_module_activations` creates the compound entitlement foreign key. The reviewed
artifact also enforces:

- non-null tenant keys on both tables;
- one entitlement per tenant and stable module key;
- one activation per tenant and entitlement;
- constrained module keys and semantic versions;
- active-only state and positive lifecycle version; and
- `MATCH FULL` tenant-qualified entitlement linkage with restricted deletion.

The down path first checks entitlement, activation, audit, outbox, and idempotency state. It refuses
rollback if any lifecycle fact remains. Empty synthetic rollback and reapply pass; a deliberately
inserted synthetic entitlement makes rollback fail with
`module lifecycle rollback requires empty activation, entitlement, and durable evidence state`.
The fixture was then removed by exact tenant and module key before the successful empty rollback.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Invalid trusted release fails closed | Duplicate, malformed, missing-dependency, and cyclic manifest tests |
| Gates remain independent | Missing release, entitlement, activation, dependency, and actor-capability tests plus complete positive path |
| Activation grants no authority | Successful activation remains forbidden until the separate use capability is granted |
| Trusted input only | Raw context and unknown action input fail; tenant, release version, dependency, actor, routing, repository, and Ash options are derived |
| Tenant isolation | Compound foreign-key rejection, tenant-qualified reads, and same-key independent tenant activations |
| Alternate writes fail closed | Database key, version, state, lifecycle-version, and cross-tenant constraints are exercised directly |
| Retry behavior | Exact replay, changed request, changed actor, concurrent exact retry, duplicate-active conflict, and tenant-isolated key tests |
| Atomic evidence | Activation, audit, outbox, and idempotency rows are read back together |
| Transaction rollback | Injected post-outbox failure leaves zero action facts and the same request succeeds after removal |
| No expanded product scope | No deactivation, drain, reactivation, public mutation, entitlement workflow, UI connection, provisioning resource, or school vocabulary exists |

## Verification

The focused contract suite passed twice with different deterministic seeds:

```sh
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/module_lifecycle_test.exs \
  apps/chimwemwe_core/test/chimwemwe/platform/authority_test.exs --seed 799205

mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/module_lifecycle_test.exs \
  apps/chimwemwe_core/test/chimwemwe/platform/authority_test.exs --seed 0
```

Both runs passed 12 tests. The production-core compile with warnings as errors and the checked
migration/snapshot drift command also passed:

```sh
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check \
  --migration-path priv/repo/migrations \
  --snapshot-path priv/resource_snapshots
```

Migration apply, empty rollback, reapply, and retained-state rollback refusal were exercised
against the synthetic PostgreSQL test database. `make test-fast` passes all 97 production-core
tests. Dependency audit, unused-dependency check, and whitespace check pass; Credo and Dialyzer
report no Slice 1H-A finding.

The required repository-wide `make check` passed after UI-1A and the Ash 3.33.11 security patch
were reconciled. The run passed 25 repository-tool tests, 106 Phase 0 tests, 97 production-core
tests, 20 browser unit tests, all 19 browser scenarios, both Hex audits, both Dialyzer analyses,
generated-contract drift, static analysis, and whitespace checks.

## Follow-up gate

Slice 1H-A proves initial activation only. The separately authorized
[Slice 1H-B](module-lifecycle-drain-reactivation.md) now defines and proves deactivation versus
ordinary work, dependency-safe drain, queued and in-flight behavior, mandatory
audit/retention/outbox work, retained-data ownership, cursor and replay handling, compatible
reactivation, projection rebuild, and reconciliation. Neither slice authorizes a school business
module.
