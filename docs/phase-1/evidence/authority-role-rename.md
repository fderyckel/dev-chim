# Core-foundation Slice 1G role-rename evidence

- Status: Focused action, migration lifecycle, production-core, and complete repository verification pass
- Date: 2026-09-24
- Last verified: 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md), and [threat model TM-01/TM-02/TM-09/TM-10/TM-14/TM-15](../../security/threat-model.md)
- Source basis: completed Phase 0 named-action evidence, implemented Slices 1A through 1F, and the explicitly authorized first Slice 1G increment

## Question

Can the production core perform one real tenant-authority change through a named,
capability-protected action with optimistic concurrency, exact idempotent replay, immutable
audit evidence, a transactional outbox fact, stable failure categories, and no generic or public
write surface?

## Implemented boundary

`Role.rename_role` is a private Ash generic action. `Authority.rename_role/3` is its only
supported invocation boundary. It validates `ExecutionContext` before action input, accepts only
the five ordinary fields `role_id`, `name`, `expected_version`, `idempotency_key`, and
`causation_id`, and derives actor, tenant, writer, route, correlation, domain, authorization, and
Ash options from trusted platform state.

The Ash policy requires the code-owned `platform.authority.roles.rename` capability. The action
then takes a tenant-qualified transaction advisory lock and rechecks the same capability on the
current writer before it reads or changes the role. The lock is the serialization contract for
later authority-write actions; request input cannot select or bypass it.

The action binds the idempotency key to tenant, action name, actor, role, and a deterministic
hash of normalized name, expected version, and causation identifier. A first execution locks the
tenant-qualified role, verifies its expected positive version, renames it, and increments the
version. An exact retry returns the stored `RenameRoleResult`; changed input or a different
authorized actor receives `:idempotency_conflict`. Correlation identifiers may differ across
transport retries without changing the original committed result or event.

One PostgreSQL transaction contains:

1. the role label and version update;
2. one immutable `Authority.AuditEvent` with actor, action, aggregate, versions, causation,
   correlation, idempotency key, and the label change summary;
3. one `OutboxEvent` using the ADR 0007 envelope and a minimal payload containing only the
   resulting lock version; and
4. one completed `Authority.ActionIdempotency` result with opaque audit and event references.

Audit, outbox, and idempotency resources are private tenant-owned manifests with no actions.
This increment added no dispatcher, consumer, HTTP route, generated client,
application-supervisor runtime, assignment, capability grant, role inclusion, revoke,
provisioning, or school module. The separately authorized Slice 1G-B role-assignment increment
was integrated later and does not change the role-rename boundary recorded here.

## Failure and recovery contract

Raw or missing context fails before action discovery. Malformed or authority-shaped input fails
before persistence. Missing capability is forbidden; another tenant's role is indistinguishable
from a missing role; stale version and duplicate tenant role name are conflicts; changed request
or actor is an idempotency conflict; and unavailable database work is a retryable dependency.
The stable errors contain no role, actor, tenant, placement, repository, SQL, or policy details.

The fault-injection test installs a temporary PostgreSQL trigger that fails idempotency completion
after the action has updated state and inserted audit and outbox facts. Ash rolls the complete
writer transaction back, leaving the original role version and zero action facts. Removing the
fault and retrying the same request then commits exactly once. This proves the recovery behavior
for an uncertain action attempt without replaying a partially committed transition.

## Migration review

AshPostgres generated snapshots for the three new resources and the initial migration operations.
Manual review found the same dependency-order risk previously found in Slice 1F: generated
compound foreign keys appeared before destination tenant columns and unique indexes. It also
showed that nullable in-transaction idempotency references require `MATCH SIMPLE`; `MATCH FULL`
would reject a `started` claim because its tenant is present while result references are null.

The checked-in migration therefore creates complete audit and outbox destinations and their
tenant-qualified indexes before the idempotency table. Its reverse dependency order removes
idempotency before outbox before audit. This down path is synthetic empty-data evidence only;
retained role changes and action facts require forward repair or an approved recovery point.

## Focused evidence

Commands:

```sh
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/platform/authority_role_rename_test.exs
cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
```

Results:

- **6 role-rename tests passed**;
- migration and resource-snapshot drift check passed; and
- warnings-as-errors compilation passed before migration generation.

The Slice 1G migration also applied, rolled back completely, reapplied, and passed drift after
reapply against the synthetic PostgreSQL 18 test database.

The focused tests prove atomic success and exact replay, capability denial, stale version,
duplicate name, cross-tenant non-disclosure, malformed input and context, canonical-request and
actor binding, concurrent exact-retry serialization, tenant-isolated idempotency keys, injected
post-outbox rollback, and safe retry.

## Complete verification

`./bin/core-check` first passed this increment with strict formatting, warnings-as-errors
compilation, migration and snapshot drift, Credo, Hex audit, unused-dependency check, Dialyzer,
**63 production-core tests**, and Git whitespace validation.

The final required `make check` passed on 2026-09-25 after the existing local UI development
process was temporarily restarted to release its fixed test port. The complete run passed 24
repository Python tests, 103 Phase 0 Elixir/PostgreSQL tests, six generated TypeScript client tests, 75
production-core tests after the separately authorized role-assignment and temporal-qualification increments were integrated,
seven UI-0 unit tests, and 12 Playwright tests across wide, medium, and narrow viewports. It also
passed dependency and warning drift, audits, both Dialyzer suites, generated artifacts,
documentation conventions, formatting, lint, types, the production browser build, keyboard and
reflow checks, automated accessibility checks, and Git whitespace validation.

An earlier complete run reached the same final Playwright step but could not bind
`127.0.0.1:3000` while the development server was active. No code or test-server workaround was
retained; the required command itself passed with its fresh production test server, after which
the development server was restored on the same address.

## Scope and limits

- This increment proves one label change; it does not complete Slice 1G.
- Role identity and effective authority do not change when the label changes.
- Role assignment is implemented by the separately authorized Slice 1G-B increment. Capability
  grants, role inclusion, revoke, and authority-cache invalidation remain unimplemented.
- Outbox dispatch, consumer deduplication, retention deletion, operational replay, and
  placement-movement reconciliation remain later gates.
- The persistence runtime remains test-started with synthetic configuration and is not installed
  under `Chimwemwe.Application`.
- No production identity, tenant, school, child, employee, or restricted data is present.
- Independent security/privacy review remains mandatory before real restricted data or
  school-side identity ownership.
