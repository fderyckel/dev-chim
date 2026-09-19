# Module-lifecycle evidence

- Status: Accepted architecture contract; production integration gates remain
- Owner: Platform engineering with product and security architecture
- Date: 2026-09-14
- Source: revision `f1b846fad10b` plus the current uncommitted Phase 0 spike changes
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29, Elixir 1.20.3, PostgreSQL 18.6
- Decision boundary: [ADR 0001](../../adr/0001-modular-monolith-and-service-boundaries.md)

## Synthetic contract under test

The disposable [`SyntheticModuleLifecycle`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/synthetic_module_lifecycle.ex) boundary uses one neutral `synthetic.records` module. It is not a production registry, entitlement service, scheduler, or school business module.

Release availability comes from a validated immutable manifest supplied by trusted platform code. Entitlement, activation state, dependency readiness, lifecycle version, event-consumer cursor, projection state, retained records, and queued work are stored independently for each tenant. Actor authorization remains tenant-defined capability data resolved through the same `AccessControl` boundary used by the Ash policies.

The boundary exposes named activation, record-revision, deactivation, mandatory-work, and reactivation operations. Client request fields are deliberately ignored for tenant, release, entitlement, activation, and actor selection. Ordinary use, lifecycle management, and mandatory post-deactivation work require separate capabilities.

## Transaction and concurrency model

Every mutation locks the tenant's module-instance row in a PostgreSQL transaction and checks an expected lifecycle version. The ordinary mutation and deactivation therefore have two safe outcomes:

- if the mutation owns the lock first, its record update and audit/outbox pair commit and the stale deactivation receives `:lifecycle_conflict`; or
- if deactivation owns the lock first, it atomically closes ordinary authority and the waiting mutation receives `:module_inactive` without changing the retained record.

Deactivation parks queued or running ordinary work, leaves mandatory work runnable through its narrower capability, records the replay cursor, invalidates the disposable projection, retains module data, and writes distinct audit and outbox facts in the same transaction. Active dependents reject deactivation.

Reactivation checks release compatibility before rebuilding the projection, restoring parked ordinary work to the replay queue, clearing the saved replay boundary, reconciling state, and reopening ordinary actions. An injected reconciliation failure rolls the entire attempt back, leaving the module inactive.

## Database and test evidence

- Migration: [`20260913030000_add_synthetic_module_lifecycle.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913030000_add_synthetic_module_lifecycle.exs)
- Tests: [`synthetic_module_lifecycle_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/synthetic_module_lifecycle_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/synthetic_module_lifecycle_test.exs`
- Focused result: 15 tests passed against a disposable PostgreSQL database with two independent repository pools for real lock contention.
- Full test result: 43 tests passed.
- Migration commands: `mise exec -- env MIX_ENV=test mix ecto.migrate`, `mise exec -- env MIX_ENV=test mix ecto.rollback --step 1`, and `mise exec -- env MIX_ENV=test mix ecto.migrate`.
- Migration result: the lifecycle migration applied, rolled back completely, and reapplied without generated-name truncation warnings.

The migration gives every tenant-owned lifecycle table a non-null tenant key. Compound `MATCH FULL` foreign keys bind records, work items, events, actors, and module instances to the same tenant. Check constraints bound lifecycle states, work kinds, work states, versions, cursors, event channels, classification, and JSON object payloads. A negative test confirms that a cross-tenant retained-record reference is rejected by PostgreSQL.

## Required scenario results

| Scenario | Result | Evidence |
| --- | --- | --- |
| Module is absent from the release | Passed: `:module_not_released` is returned before the module-operation hook or database mutation | Release-absence test |
| Module is present but unentitled | Passed: forged request entitlement and activation fields are ignored | Client-field gate test |
| Module is entitled but inactive | Passed: an authorized ordinary actor receives `:module_inactive` | Inactive-module test |
| Module is active but actor is unauthorized | Passed: known and random record IDs both return `:actor_unauthorized` with no event or mutation | Record-existence-shape test |
| Module is present, entitled, active, and actor is authorized | Passed: only the named label revision is applied; forged tenant and gate fields are ignored | Four-gate positive test |
| Required dependency is absent or inactive | Passed: activation returns `:required_dependency_inactive` without a lifecycle event | Dependency-negative test |
| Active dependent exists during deactivation | Passed: deactivation returns `:active_dependents_present` and leaves the module active | Dependent-negative test |
| Mutation races deactivation | Passed: both lock orders are exercised on independent connections; one complete transition wins and the loser fails closed | Two concurrency tests |
| Jobs and event consumers are in flight | Passed: ordinary work is parked, mandatory work remains runnable, and cursor 41 becomes the replay boundary | Drain test |
| Audit, outbox, retention, or legal-hold work remains | Passed: mandatory work completes while ordinary authority stays closed and produces separate audit/outbox facts | Mandatory-work test |
| Module becomes inactive | Passed: projection readiness is cleared while the retained record and replay cursor remain | Drain and retained-data test |
| Module is reactivated after a release change | Passed: incompatible and injected-failure attempts stay inactive; compatible replay/rebuild/reconciliation reopens the named action | Reactivation test |

## What this does not prove

- The release manifest and module-instance rows are synthetic stand-ins, not production release, entitlement, configuration, or module-registry services.
- Queue parking, event cursors, projection rebuild, replay, and reconciliation are exercised as transactional state contracts; no Oban worker, external consumer, search index, cache, webhook, or analytics system is integrated.
- The proof rejects active dependents. It does not implement or approve cascade deactivation or dependency-graph administration.
- Lifecycle idempotency-key retry semantics are not exercised yet; this remains an ADR 0001 acceptance question even though optimistic conflicts have stable outcomes.
- Audit and outbox facts are retained atomically, but dispatch, retries, deduplication, retention, legal hold, and placement movement remain separate work.
- The lifecycle boundary uses explicit application-service and PostgreSQL transactions around the existing Ash-backed capability model. It is evidence for the architecture seam, not a reusable production API or a generated-interface result.
- The focused proof does not turn the synthetic boundary into a production API or approve an untested queue, projection, or external-consumer implementation.

## Review outcome

- Accountable decider: François — Project Owner
- Decision date: 2026-09-16
- Decision: Accepted as the ADR 0001 architecture contract. Release availability, entitlement, module activation, and actor authorization remain separate server-side gates; deactivation retains data and does not cascade by default.
- Conditions: before the first production module activation, François as interim Platform Owner must verify idempotent lifecycle requests, the real queue/outbox adapters, drain/replay/reconciliation, and a named operational owner. Review by 2026-12-15 or earlier at that production gate.

See [module activation and lifecycle](../../architecture/module-activation-and-lifecycle.md) and [ADR 0001](../../adr/0001-modular-monolith-and-service-boundaries.md).
