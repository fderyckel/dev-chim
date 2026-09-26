# Slice 1H-B module-lifecycle drain and reactivation

- Status: Implemented; focused and complete repository verification passed on 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0001](../../adr/0001-modular-monolith-and-service-boundaries.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), and [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md)
- Scope: neutral deactivation, modeled drain, mandatory work, and compatible reactivation only

## Question

Can the production core close ordinary module authority atomically, serialize a racing ordinary
mutation, park queue-neutral ordinary work, preserve retained state and mandatory work, record a
consumer replay boundary, and reopen authority only after compatible rebuild and reconciliation,
without adding a scheduler, external consumer, public interface, or school module?

## Implemented boundary

`ModuleActivation` now remains as the durable lifecycle aggregate after deactivation. Its state is
either `active` or `inactive`; there is no half-authorized draining state. Deactivation takes the
tenant-and-module transaction lock, rejects an active dependent, checks the exact lifecycle
version, closes ordinary authority, records the current consumer cursor, marks the disposable
projection stale, requires reconciliation, and parks queued or running ordinary work in one
writer transaction.

`ModuleWorkItem` is a closed tenant-owned state contract, not a queue implementation. Ordinary
items may be queued, running, parked, or completed. Audit, outbox, retention, legal-hold, and
reconciliation items are mandatory and cannot be parked. The private
`complete_mandatory_work` action uses a capability separate from ordinary module use and lifecycle
management, remains available while the module is inactive, and commits its state, audit fact,
outbox fact, and exact result together.

`ModuleLifecycle.authorize_current_transaction/4` is the internal mutation-side gate. It refuses
to run outside an existing writer transaction, takes the same tenant-and-module transaction lock
as deactivation, and then re-evaluates release, entitlement, activation, dependencies, and actor
capability. If ordinary work owns the lock first, it commits before deactivation. If deactivation
owns the lock first, the waiting work observes inactive state and fails without mutation.

Reactivation requires the private `reactivate_module` action, the exact inactive lifecycle
version, current entitlement, active compatible dependencies, and a code-owned release
declaration that explicitly lists the installed version in `compatible_from`. It requeues parked
ordinary work from the retained replay cursor, increments the projection generation, records the
last reconciled cursor, clears the replay boundary, and opens ordinary authority only when the
whole transaction commits. A failure after the outbox insert rolls the requeue, projection,
reconciliation, activation, audit, outbox, and idempotency changes back together.

## Persistent model and migration review

The expansion migration preserves every valid Slice 1H-A activation. It adds non-negative
consumer, replay, and reconciled cursors; positive projection generation; explicit projection and
reconciliation state; retained-data ownership fixed to `retained`; and tenant-qualified work
items whose compound foreign key cannot reference another tenant's activation.

Database checks reject unknown lifecycle states, internally inconsistent active or inactive
state, negative cursors, non-positive projection generations, an attempt to release retained
data implicitly, unknown work kinds or states, negative work cursors, and parked mandatory work.
The down path preserves valid 1H-A activation rows but refuses to remove the 1H-B schema while any
modeled work, 1H-B transition evidence, inactive state, replay position, projection change, or
reactivation timestamp remains.

The reviewed rollback exercise deliberately inserted a retained work item and observed
`module lifecycle drain rollback requires empty 1H-B work and durable evidence state`. Removing
only that synthetic fixture allowed rollback and reapply to pass.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Dependency-safe deactivation | An active dependent rejects base-module deactivation; deactivating the dependent first permits the base drain |
| Deterministic mutation race | Both lock orders are forced on separate repository connections: ordinary-first commits then drains, while deactivation-first parks work and makes the waiting mutation fail inactive |
| Queued and in-flight state | Queued and running ordinary items become parked with the saved replay cursor; completed work remains completed |
| Mandatory work | Audit, outbox, and retention items complete while inactive through a separate capability and remain unparked |
| Retained ownership | Activation, entitlement, completed work, and lifecycle evidence remain; the database rejects changing retained ownership away from `retained` |
| Cursor and replay | Deactivation records consumer cursor 41; reactivation requeues from 41, clears the live replay boundary, and retains 41 as the reconciled cursor |
| Projection and reconciliation | Reactivation increments projection generation only in the same transaction that clears reconciliation-required state and reopens authority |
| Compatibility | A release that does not list the installed version fails inactive; an explicitly compatible release may reactivate and update the installed version |
| Exact replay and atomic evidence | Deactivation, mandatory completion, and reactivation return exact prior results; changed reuse conflicts; injected post-outbox failure leaves the inactive state and parked work unchanged and the same request can retry |
| Tenant and database defence | Missing capability/context, forged input, cross-tenant work references, parked mandatory work, negative cursors, and implicit retained-data release fail closed |

## Verification

The focused lifecycle suite passed with two deterministic seeds:

```sh
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/module_lifecycle_test.exs --seed 0

mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/module_lifecycle_test.exs --seed 799205
```

Both runs passed 11 tests. Compile with warnings as errors and generated migration/snapshot drift
also pass. Migration apply, retained-state rollback refusal, empty rollback, and reapply pass
against the synthetic PostgreSQL test database.

The complete repository gate then passed through `make check`: 25 Python tests, 106 Phase 0
Elixir/PostgreSQL tests, 107 production-core Elixir/PostgreSQL tests, 6 generated-client tests,
20 web unit tests, 12 synthetic UI browser tests, 6 connected local-bridge browser tests, and 1
unavailable-core recovery test. Both Elixir type analyses reported zero errors and zero skipped
warnings; formatting, lint, dependency audits, generated contracts, migration drift, production
build, accessibility checks, responsive checks, and Git whitespace checks also passed.

## Remaining production gates

This slice models queue, consumer cursor, projection, and reconciliation state transactionally;
it does not add Oban, an outbox dispatcher, an external event consumer, cache or search adapter,
webhook, analytics publication, or a real module-owned projection. Those adapters still require
their own production integration, failure, replay, placement-movement, and operational-owner
evidence before a real module ships.

Entitlement expiry, commercial contract management, tenant offboarding, retained-data read,
export, correction, legal-hold, deletion, and recovery actions remain separate workflows. Slice
1H-B adds no public mutation, provisioning surface, browser connection, business vocabulary, or
school module.
