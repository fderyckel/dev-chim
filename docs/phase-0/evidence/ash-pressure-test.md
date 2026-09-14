# Ash pressure-test evidence

- Status: All 14 planned scenarios have focused evidence; adoption scorecard incomplete
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)

## Environment proof

- Date: 2026-09-14
- Host: Apple silicon macOS 26.6.2
- Project runtimes: Erlang/OTP 29.0.5, Elixir 1.20.3, Python 3.14.5, uv 0.12.13
- Services: PostgreSQL 18.6 over the local Unix socket
- Framework packages: Ash 3.33.3, AshPostgres 2.13.1, AshJsonApi 1.7.1, OpenApiSpex 3.22.4, Phoenix 1.8.13
- Commands: `make bootstrap`, `make format`, `make check`, and `mix dialyzer`
- Results: 4 repository-tool tests passed; 43 Ash/PostgreSQL/JSON:API/migration-review/routing/lifecycle tests passed; Ruff, ShellCheck, documentation validation, generated-migration drift detection, Credo, dependency audit, Dialyzer, formatting, migrations, and Git whitespace checks passed.

The tests currently prove attribute-based tenant filtering, cross-tenant denial without an existence signal, actor and tenant fail-closed behaviour, capability denial, tenant-defined role composition and rename independence, a named `submit_for_review` transition, invalid-state validation, optimistic-lock conflicts, compound tenant foreign keys, atomic state/audit/outbox rollback, required correlation and causation context, minimal event payloads, database constraints against alternate unsafe writes, generated JSON:API preservation of the action and policy boundary, allowlisted correlated telemetry without raw tenant, actor, record, or payload data, trusted pooled/dedicated database routing across requests, tasks, and job envelopes, and independent module gates with serialized deactivation, drain, retained data, mandatory work, and compatible reactivation.

Dependency compilation emitted warnings inside current third-party Ash/Phoenix/OpenApiSpex code under Elixir 1.20/OTP 29. None originated in the spike modules, and the required checks pass, but the warning volume is evidence to consider under upgrade and maintenance ergonomics rather than suppressing or ignoring it.

## Named-action and tenant-role slice

- Date: 2026-09-13
- Code: [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), [`access_control.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/access_control.ex), and [`policy/`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/policy/)
- Database artifact: [`20260913010000_add_access_model_and_record_workflow.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913010000_add_access_model_and_record_workflow.exs)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 10 tests passed.
- Migration commands: `mise exec -- env MIX_ENV=test mix ecto.rollback --step 1` and `mise exec -- env MIX_ENV=test mix ecto.migrate`
- Migration result: the new access/workflow migration rolled back and reapplied successfully against the synthetic test database.

The access model stores tenant-owned actors, roles, capabilities, actor-role assignments, role-capability assignments, and recursive role inclusions. Role names are data: a test renames a composed role and retains the same capability without a code change. Compound foreign keys reject cross-tenant assignments.

The named update uses Ash validation plus optimistic locking inside the data-layer transaction. Ash 3.33.3/AshPostgres 2.13.1 could not compile the custom validation error into a fully atomic SQL expression, so the spike explicitly uses `require_atomic? false`. Concurrency still fails closed through the lock-version predicate, but the atomic-expression limitation remains framework-fit evidence for the final scorecard.

## Transactional outbox slice

- Date: 2026-09-13
- Code: [`record_outbox.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/change/record_outbox.ex), [`outbox_event.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/outbox_event.ex), and the extended [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex)
- Database artifact: [`20260913020000_add_transactional_outbox.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913020000_add_transactional_outbox.exs)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 12 tests passed.
- Migration commands: `mise exec -- env MIX_ENV=test mix ecto.rollback --step 1` and `mise exec -- env MIX_ENV=test mix ecto.migrate`
- Migration result: the transactional-outbox migration rolled back and reapplied successfully against the synthetic test database.

The `submit_for_review` action now requires typed correlation and causation IDs, writes a record audit reference, and inserts one immutable tenant-owned outbox fact from an Ash `after_action` hook inside the same database transaction. The event records actor, tenant, aggregate, type, schema version, correlation, causation, classification, occurrence time, and only the minimal state-transition payload; it does not copy the synthetic record name.

The negative test injects an error after the outbox insert. Ash rolls back the record status, lock-version increment, audit reference, and outbox row together. A separate negative test proves missing correlation and causation inputs prevent the transition before any state or event write.

## Generated JSON:API policy slice

- Date: 2026-09-13
- Code: [`json_api_router.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/json_api_router.ex), the extended [`foundation.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation.ex), and the extended [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 18 tests passed.

The generated router exposes one `PATCH /foundation-records/:id/submit-for-review` route and no generic create, read, update, or delete route. It receives the actor and tenant through Ash's connection-private context; request payloads do not select a tenant or placement. The successful HTTP test proves that the adapter invokes the same capability-protected action, preserves typed correlation and causation IDs into the outbox fact, and excludes the private tenant key from serialized output.

Negative HTTP tests prove capability denial, actor and tenant fail-closed behaviour, and absence of a generic update bypass. A tenant-B actor receives the same normalized not-found error shape for an existing tenant-A identifier and a random identifier, so the response does not disclose cross-tenant existence. Every denied path leaves the record and outbox unchanged.

AshJsonApi 1.7.1 calls its optional OpenAPI module while deriving the request-validation schema for this update route, even without serving an OpenAPI endpoint. The first request attempt therefore failed until the documented compatible `open_api_spex` dependency was installed; this coupling is retained as framework-fit evidence. A missing-tenant request is rejected safely, but AshJsonApi logs that `Ash.Error.Invalid.TenantRequired` has no specific JSON:API error implementation. Stable error mapping remains an acceptance gap.

## Telemetry and redaction slice

- Date: 2026-09-13
- Code: [`telemetry.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/telemetry.ex) and the instrumented [`json_api_router.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/json_api_router.ex)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 19 tests passed.

The JSON:API dispatch hook emits one versioned `[:ash_foundation_lab, :json_api, :dispatch]` event from an explicit metadata allowlist. It carries the trusted correlation ID, action, transport, classification, count, and a stable 96-bit hexadecimal reference derived one-way from the tenant context. It does not emit the connection, actor, raw tenant key, route parameters, request body, record identifier, or record contents.

The capture test observes both an allowed request and a policy-denied request. It requires the exact measurement and metadata key sets, proves the tenant reference is stable across the two requests, and asserts that raw actor and tenant identifiers, record identifiers, and a synthetic restricted-content marker are absent. This proves the pre-dispatch event's safety; response outcome/duration instrumentation and third-party logger redaction remain separate work.

## Generated migration review slice

- Date: 2026-09-13
- Resource declarations: [`tenant.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/tenant.ex), [`actor.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/actor.ex), [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), and [`outbox_event.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/outbox_event.ex)
- Generated artifact: [`20260913205401_phase0_generated_baseline_review.exs`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/migrations/20260913205401_phase0_generated_baseline_review.exs) and its [`resource snapshots`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/resource_snapshots/)
- Inspection tests: [`generated_migration_review_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/generated_migration_review_test.exs)
- Generation command: `mise exec -- mix ash_postgres.generate_migrations --name phase0_generated_baseline_review --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots`
- Drift command: `mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots`
- Focused result: 2 migration-inspection tests passed and the drift check passed.
- Disposable-database result: the generated baseline applied, rolled back completely, and reapplied successfully in `ash_foundation_lab_generated_review_20260913_2054`; PostgreSQL catalog inspection confirmed all three tenant-owned tables have non-null tenant keys, the five declared foreign keys exist with restrictive deletion, both cross-resource references match actor or aggregate ID together with tenant ID, and all declared indexes and check constraints exist. The disposable database was dropped after verification.

An initial dry run omitted tenant indexes, compound identities, foreign keys, and database checks because those invariants were present only in the handwritten migration. The resource DSL now declares them explicitly. Regeneration then produced the required non-null tenant columns, tenant lookup indexes, unique `(id, tenant_id)` identities, `MATCH FULL` compound outbox foreign keys, restrictive tenant foreign keys, partial audit uniqueness, and state/envelope checks. This is important framework-fit evidence: the generator preserves declared database safety, but does not infer repository conventions that the resources omit.

The generated `up` path is additive: it creates tables, indexes, foreign keys, and constraints and contains no drop or remove operation. Its explicit `down` path removes constraints before their tables and completed successfully. The generator still prints a destructive-operation warning because rolling back this initial baseline drops its tables; that is expected only for the empty disposable review database and is not approval for destructive production rollouts.

This artifact is isolated from the executable handwritten migration chain. It is evidence for generator readability and baseline reversibility, not a replacement migration. It also exposes a type difference: Ash emits PostgreSQL `bigint` for the integer resource attributes that the handwritten spike migration currently defines as `integer`. Upgrade, data backfill, locking, and live expand-and-contract behaviour therefore remain unproven and are the next separate migration concerns.

## Dependency upgrade slice

- Date: 2026-09-13
- Detailed report: [Ash dependency upgrade exercise](ash-upgrade-exercise.md)
- Previous patch set: Ash 3.33.2, AshPostgres 2.13.0, AshJsonApi 1.7.0
- Candidate/current set: Ash 3.33.3, AshPostgres 2.13.1, AshJsonApi 1.7.1
- Result: both sets compiled and passed 21 tests; the candidate required no application changes, changed only three direct lock entries, passed the dependency audit, and produced a byte-for-byte identical generated baseline migration.

The exercise used a disposable copy because the repository was already at every latest compatible release. It upgraded the preceding patch set onto the same synthetic database schema, then removed the database and temporary copy. Third-party compile warnings and the missing-tenant AshJsonApi warning remained, so upgrade ergonomics pass only with the warning and error-mapping remediation bounded in the detailed report.

## Trusted tenant-placement routing slice

- Date: 2026-09-13
- Code: [`trusted_routing.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/trusted_routing.ex)
- Tests: [`trusted_routing_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/trusted_routing_test.exs)
- Detailed report: [Trusted tenant-placement routing evidence](trusted-routing.md)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/trusted_routing_test.exs`
- Focused result: 7 tests passed against separate pooled and dedicated disposable PostgreSQL databases; both databases were removed after the run.

The trusted registry selects the live repository, database profile, cell, and tenant-qualified queue, storage, cache, and projection namespaces from authenticated tenant context and a matching routing version. Request placement fields cannot influence the selection. Missing, unknown, stale, unavailable, and wrong-repository inputs fail before the operation runs and never fall back to the default database.

Dynamic repository selection is process-local. A plain spawned task therefore has no route, while the explicit task wrapper resolves context in the child. Serialized job arguments carry an allowlist without repository data and re-resolve the current registry at execution, causing stale jobs to fail closed. Normal and exceptional execution both restore prior process state.

## Module lifecycle slice

- Date: 2026-09-14
- Code: [`synthetic_module_lifecycle.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/synthetic_module_lifecycle.ex) and the dynamic-repository-safe capability query in [`access_control.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/access_control.ex)
- Database artifact: [`20260913030000_add_synthetic_module_lifecycle.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913030000_add_synthetic_module_lifecycle.exs)
- Tests: [`synthetic_module_lifecycle_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/synthetic_module_lifecycle_test.exs)
- Detailed report: [Module-lifecycle evidence](module-lifecycle.md)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/synthetic_module_lifecycle_test.exs`
- Focused result: 15 tests passed against a disposable PostgreSQL database; concurrency cases used two independent repository pools.
- Migration result: the executable lifecycle migration applied, rolled back completely, and reapplied successfully.

The neutral module boundary gets release availability only from a validated trusted manifest, stores entitlement and activation independently, and resolves actor authority from tenant-defined capability data. Request-selected gate and tenant values are ignored. Separate capabilities govern ordinary use, lifecycle management, and mandatory work after deactivation.

An optimistic lifecycle version and `FOR UPDATE` lock serialize an ordinary mutation against deactivation. Tests force both lock orders: the first transition commits its entire record/lifecycle/audit/outbox change, while the stale or newly inactive competitor fails without a partial write. Deactivation rejects active dependents, parks ordinary work, preserves the replay cursor and retained record, invalidates the disposable projection, and leaves narrower mandatory work available. Reactivation remains inactive after incompatibility or an injected reconciliation failure and opens ordinary work only after the compatible rebuild/replay/reconcile transaction commits.

## Scorecard

| Category | Required result | Current result | Evidence |
| --- | --- | --- | --- |
| Action and policy expressiveness | Mandatory pass | Partial pass | [Named create/read/transition policies](#named-action-and-tenant-role-slice) and [generated action preservation](#generated-jsonapi-policy-slice); relationship and field-policy scenarios still pending |
| Tenant scoping and missing-context failure | Mandatory pass | Partial pass | [Actor/tenant denial, cross-tenant invisibility, and compound foreign-key tests](#named-action-and-tenant-role-slice), plus [pooled/dedicated request, task, and job routing](#trusted-tenant-placement-routing-slice); other interfaces and movement remain pending |
| Tenant-defined hierarchical capability resolution | Mandatory pass | Partial pass | [Recursive composition, rename independence, denial, and cross-tenant assignment tests](#named-action-and-tenant-role-slice); cycle rejection still pending |
| Independent module gates and safe drain | Mandatory pass | Mandatory pass | [Release/entitlement/activation/authorization matrix, dependency denial, both concurrency lock orders, drain, retained data, mandatory work, and reactivation](#module-lifecycle-slice) |
| State transitions, concurrency, and errors | Mandatory pass | Partial pass | [Named transition, invalid-state, and optimistic-lock tests](#named-action-and-tenant-role-slice); stable transport error mapping still pending |
| Transaction and rollback ergonomics | Mandatory pass | Mandatory pass | [Successful atomic state/audit/event write and injected rollback](#transactional-outbox-slice) |
| Migration readability and safety | Mandatory pass | Partial pass | [Generated baseline inspection, drift detection, catalog proof, and rollback/reapply](#generated-migration-review-slice); live upgrade, backfill, lock, and expand-and-contract evidence still pending |
| Generated API policy preservation | Mandatory pass | Partial pass | [Single named route, allowed/denied, cross-tenant existence-shape, missing-context, serialization, and generic-update-bypass tests](#generated-jsonapi-policy-slice); stable errors, pagination, versioning, idempotency, contract export, and client generation still pending |
| Telemetry and redaction | Mandatory pass | Mandatory pass | [Captured allowlist assertions on allowed and denied generated-interface requests](#telemetry-and-redaction-slice) |
| Test and maintenance ergonomics | Pass or bounded remediation | Not evaluated | Review notes |
| Upgrade effort and dependency health | Pass or bounded remediation | Pass with bounded remediation | [Three-package patch update with zero application or migration diff and 21 passing tests](ash-upgrade-exercise.md) |

The environment smoke test must not be used to accept Ash. Every mandatory category needs direct evidence.

## Limits

- Role-composition cycle rejection and administration policies are not implemented yet.
- Outbox dispatch, retry, deduplication, retention, and placement-movement reconciliation remain later-phase work; lifecycle replay is modeled only as transactional cursor and work-item state.
- The trusted routing registry and job runner are pressure-test components; production control-plane availability, movement, Oban integration, and external namespace enforcement remain unimplemented.
- The lifecycle release manifest, registry rows, work items, projections, replay, and reconciliation are synthetic contract models rather than production services or live external integrations.
- Lifecycle idempotency-key retries are not exercised and remain an ADR 0001 acceptance gap.
- Stable JSON:API errors, pagination, versioning, idempotency, contract export, and generated TypeScript client behaviour are not implemented yet.
- Response outcome/duration telemetry and third-party logger-redaction assertions remain outside this pre-dispatch telemetry proof.
- The generated migration proof covers a fresh disposable baseline, not a live upgrade with retained data, backfill, lock, or mixed-version compatibility.
- The JSON:API request validator currently requires the optional OpenApiSpex dependency, and missing-tenant rejection emits an unmapped-error warning in third-party code.
- The named action is not fully atomic because the locked framework pair cannot translate the custom validation error; the current fallback path is transaction-backed with optimistic locking.
- A patch upgrade passes, but a non-patch framework upgrade and a machine-normalized warning-delta gate remain untested.
- No clean-machine or CI-host rehearsal has been completed.
