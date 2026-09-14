# Ash pressure-test evidence

- Status: All 14 planned scenarios have focused evidence; adoption scorecard incomplete
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)

## Environment proof

- Date: 2026-09-14
- Host: Apple silicon macOS 26.6.2
- Project runtimes: Erlang/OTP 29.0.5, Elixir 1.20.3, Python 3.14.5, uv 0.12.13, Node.js 24.15.0
- Services: PostgreSQL 18.6 over the local Unix socket
- Framework packages: Ash 3.33.3, AshPostgres 2.13.1, AshJsonApi 1.7.1, OpenApiSpex 3.22.4, Phoenix 1.8.13, openapi-typescript 7.13.0, openapi-fetch 0.17.0, TypeScript 5.9.3, Vitest 5.0.0
- Commands: `make bootstrap`, `make format`, `make check`, and `mix dialyzer`
- Results: 4 repository-tool tests passed; 67 Ash/PostgreSQL/JSON:API/migration-review/routing/lifecycle/role-graph/idempotency tests passed; 3 TypeScript client behaviour tests passed; Ruff, ShellCheck, documentation validation, generated-migration, OpenAPI, and TypeScript-declaration drift detection, TypeScript compilation, Credo, dependency audits, Dialyzer, formatting, migrations, and Git whitespace checks passed.

The tests currently prove attribute-based tenant filtering, cross-tenant denial without an existence signal, actor and tenant fail-closed behaviour, capability denial, field and relationship policies, tenant-defined role composition and rename independence, direct/indirect/concurrent cycle rejection, governed role administration, named transitions, optimistic-lock conflicts, transactional exact-retry idempotency and changed-reuse conflict, compound tenant foreign keys, atomic state/audit/outbox/idempotency rollback, minimal event payloads, database constraints against alternate unsafe writes, generated JSON:API preservation of the action and policy boundary, versioned routes, bounded tenant-safe keyset pagination, stable core public errors, checked-in OpenAPI and generated-TypeScript drift detection, typed client calls without implicit write retries, tenant-safe telemetry, trusted pooled/dedicated routing, and independent module gates with serialized deactivation, drain, retained data, mandatory work, and compatible reactivation.

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

## Authorization graph integrity and policy-matrix slice

- Date: 2026-09-14
- Code: [`role_administration.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/role_administration.ex), the field policy in [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), and the relationship policy in [`outbox_event.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/outbox_event.ex)
- Database artifact: [`20260913040000_add_role_graph_integrity.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913040000_add_role_graph_integrity.exs)
- Tests: [`role_administration_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/role_administration_test.exs) and [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/role_administration_test.exs test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 31 tests passed against the standard synthetic test database and a separate role-graph database with two independent repository pools.
- Migration result: the role-graph migration applied, rolled back completely, and reapplied in the disposable database; catalog assertions confirmed the optimistic version, trigger, compound foreign keys, and constraints.

The spike exposes only two named role-administration actions: optimistic rename and inclusion. Both require trusted actor, tenant, and correlation context plus the tenant-defined `role.manage` capability. Authorization happens before role lookup, tenant mismatch fails closed, compound foreign keys reject cross-tenant links, and every successful action writes matching audit and outbox facts in the state transaction. An injected failure after event insertion rolls back the role change and both facts.

The trusted inclusion path takes a tenant-qualified transaction advisory lock before writing. A forced two-connection race proves opposing inclusions serialize: one edge commits and the other returns the stable `role_cycle` result. A recursive PostgreSQL trigger rejects direct and indirect cycles again for alternate writes. Role names remain mutable data, and a composed capability survives a rename without code changes.

The Ash policy matrix now has explicit field and relationship evidence. An actor with record-read authority but without the narrower audit-reference capability receives `%Ash.ForbiddenField{}` for that field. Loading the outbox relationship requires its own audit-trail capability; the same record remains readable while the forbidden relationship is masked, and direct missing-context or cross-tenant event reads fail closed.

This is pressure-test evidence, not a production role API. Role removal, assignment administration, idempotent retries, bulk graph changes, and user-facing transport contracts remain outside this slice.

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

- Date: 2026-09-14
- Public edge and contract: [`api_router.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/api_router.ex), [`json_api_contract.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/json_api_contract.ex), [`json_api_page_limit.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/json_api_page_limit.ex), and [`json_api_router.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/json_api_router.ex)
- Domain declarations: the extended [`foundation.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation.ex), [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), and [`idempotent_submission.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/change/idempotent_submission.ex)
- Contract artifact: [`phase0-v1.json`](../../../spikes/ash-foundation-lab/priv/openapi/phase0-v1.json)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 30 tests passed.
- Contract generation: `mise exec -- env MIX_ENV=test mix openapi.spec.json --spec AshFoundationLab.JsonApiRouter --pretty=true --filename priv/openapi/phase0-v1.json`
- Contract drift check: `mise exec -- env MIX_ENV=test mix openapi.spec.json --spec AshFoundationLab.JsonApiRouter --check --pretty=true --filename priv/openapi/phase0-v1.json`
- Contract result: generation and immediate drift verification passed.

The generated router exposes only `GET /api/v1/foundation-records` and `PATCH /api/v1/foundation-records/:id/submit-for-review`; the unversioned transition and generic create, update, and delete routes are unavailable. It receives the actor and tenant through Ash's connection-private context; request payloads do not select a tenant or placement. The successful HTTP test proves that the adapter invokes the same capability-protected action, preserves typed correlation and causation IDs into the outbox fact, and excludes the private tenant key from serialized output.

The transition requires the caller's `expected_version` and UUID `idempotency_key`. Tests map stale state to stable `409 conflict`, changed idempotency-key reuse to `409 idempotency_conflict`, invalid state to `422 validation_failed`, policy denial to `403 forbidden`, hidden or absent records to `404 not_found`, and missing trusted tenant context to `400 missing_tenant_context`. Public details and metadata are versioned and contain no framework module, actor identifier, or raw tenant identifier. A tenant-B actor receives the same normalized not-found shape for an existing tenant-A identifier and a random identifier, so the response does not disclose cross-tenant existence. Every denied path leaves the record and outbox unchanged.

The list action uses deterministic `(inserted_at, id)` keyset order with a default page size of two. Two-page assertions prove disjoint results and tenant isolation. Despite the resource's declared maximum, AshJsonApi 1.7.1 passed a requested `page[limit]=4` through and returned four records; its generated OpenAPI schema also omitted the maximum. The thin public edge therefore rejects non-integer, non-positive, and above-three limits before generated dispatch, while the supported OpenAPI modifier records `maximum: 3`. This bounded escape hatch is evidence against treating generation as a complete public boundary.

The checked-in OpenAPI document records the two versioned paths, the pagination maximum, and required correlation, causation, optimistic-version, and idempotency inputs. Its drift check is part of `make check` and is the only input to the generated TypeScript declaration reviewed below. AshJsonApi still calls the optional OpenAPI module while deriving request validation, so the compatible `open_api_spex` dependency remains a framework coupling. Explicit error implementations remove the prior missing-tenant mapping warning.

## Idempotency and generated TypeScript client slice

- Date: 2026-09-14
- Domain and error code: [`action_idempotency.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/action_idempotency.ex), [`idempotent_submission.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/change/idempotent_submission.ex), [`record_outbox.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/change/record_outbox.ex), and [`idempotency_conflict.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/error/idempotency_conflict.ex)
- Executable migration: [`20260914050000_add_action_idempotency.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260914050000_add_action_idempotency.exs)
- Generated review artifact: [`20260914200109_phase0_generated_idempotency_review.exs`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/migrations/20260914200109_phase0_generated_idempotency_review.exs) and its [`resource snapshot`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/resource_snapshots/repo/action_idempotency_keys/20260914200110.json)
- Server tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs), [`action_idempotency_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/action_idempotency_test.exs), and [`generated_migration_review_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/generated_migration_review_test.exs)
- TypeScript harness: [`typescript-client-review`](../../../spikes/ash-foundation-lab/typescript-client-review/), including the thin [`client.ts`](../../../spikes/ash-foundation-lab/typescript-client-review/src/client.ts), compile-time [`contract-check.ts`](../../../spikes/ash-foundation-lab/typescript-client-review/src/contract-check.ts), and runtime [`client.test.ts`](../../../spikes/ash-foundation-lab/typescript-client-review/test/client.test.ts)
- Focused server command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs test/ash_foundation_lab/action_idempotency_test.exs test/ash_foundation_lab/generated_migration_review_test.exs`
- Focused server result: 35 tests passed.
- Client command: `mise exec -- npm run check`
- Client result: generated declaration drift check and strict TypeScript compilation passed; 3 runtime tests passed.
- Migration commands: `mise exec -- env MIX_ENV=test mix ecto.rollback --step 1` and `mise exec -- env MIX_ENV=test mix ecto.migrate`
- Migration result: the executable idempotency migration rolled back and reapplied successfully against the synthetic test database.

The action requires a caller-supplied UUID key. PostgreSQL makes `(tenant_id, action_name, idempotency_key)` unique and binds the claim to the actor, aggregate, and SHA-256 hash of the canonical action envelope. The claim is inserted inside the same writer transaction as validation, state, audit, and outbox work. An exact completed retry returns the original committed lock version and audit reference without another transition or event; changed actor, aggregate, expected version, correlation, or causation under the same key returns the stable conflict. The same key remains independent across tenants.

A forced two-connection race pauses the winner after its claim. The second request blocks, then replays the completed result after the first commits; catalog counts prove one claim and one outbox fact. An injected post-outbox failure proves claim, state, audit, and outbox rollback together and that the same key can then succeed. Direct PostgreSQL negatives reject cross-tenant actor linkage and malformed request hashes.

The concurrency test exposed a placement-sensitive adapter hazard: calling `Ecto.Adapters.SQL.query!` with the repository module bypassed the Ecto dynamic repository selected by trusted routing. Both the idempotency and outbox paths now call the repository's dynamic query function, and the two independent connection pools prove that the custom SQL participates in the selected placement and Ash transaction. This is bounded but important adapter ownership for ADR 0014.

The isolated client harness generates immutable declarations only from the checked-in OpenAPI artifact. Compile-time assertions reject an unversioned action path and a missing idempotency key. The thin wrapper accepts no tenant or repository selector, preserves the caller's correlation, causation, optimistic version, and idempotency key, and performs one fetch per invocation. Runtime tests show that an exact caller retry sends the same envelope while a transport failure is not silently retried. The harness follows the `openapi-typescript`/`openapi-fetch` contract pattern but deliberately does not select the Phase 1 production web toolchain.

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
- Resource declarations: [`tenant.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/tenant.ex), [`actor.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/actor.ex), [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), [`outbox_event.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/outbox_event.ex), and [`action_idempotency.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/action_idempotency.ex)
- Generated artifacts: [`20260913205401_phase0_generated_baseline_review.exs`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/migrations/20260913205401_phase0_generated_baseline_review.exs), [`20260914200109_phase0_generated_idempotency_review.exs`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/migrations/20260914200109_phase0_generated_idempotency_review.exs), and their [`resource snapshots`](../../../spikes/ash-foundation-lab/priv/generated_migration_review/resource_snapshots/)
- Inspection tests: [`generated_migration_review_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/generated_migration_review_test.exs)
- Generation command: `mise exec -- mix ash_postgres.generate_migrations --name phase0_generated_baseline_review --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots`
- Drift command: `mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots`
- Focused result: 3 migration-inspection tests passed and the drift check passed.
- Disposable-database result: the generated baseline applied, rolled back completely, and reapplied successfully in `ash_foundation_lab_generated_review_20260913_2054`; PostgreSQL catalog inspection confirmed all three tenant-owned tables have non-null tenant keys, the five declared foreign keys exist with restrictive deletion, both cross-resource references match actor or aggregate ID together with tenant ID, and all declared indexes and check constraints exist. The disposable database was dropped after verification.

An initial dry run omitted tenant indexes, compound identities, foreign keys, and database checks because those invariants were present only in the handwritten migration. The resource DSL now declares them explicitly. Regeneration then produced the required non-null tenant columns, tenant lookup indexes, unique `(id, tenant_id)` identities, `MATCH FULL` compound outbox foreign keys, restrictive tenant foreign keys, partial audit uniqueness, and state/envelope checks. This is important framework-fit evidence: the generator preserves declared database safety, but does not infer repository conventions that the resources omit.

The generated `up` path is additive: it creates tables, indexes, foreign keys, and constraints and contains no drop or remove operation. Its explicit `down` path removes constraints before their tables and completed successfully. The generator still prints a destructive-operation warning because rolling back this initial baseline drops its tables; that is expected only for the empty disposable review database and is not approval for destructive production rollouts.

The later generated idempotency artifact is also additive in `up` and explicit in `down`. Static inspection requires its tenant/action/key uniqueness, lookup indexes, tenant-qualified actor and aggregate foreign keys, request-hash width, status/completion consistency, and positive result-version checks. The matching executable migration rolled back and reapplied against the synthetic test database; the generated incremental artifact remains review evidence rather than the executable chain.

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
| Action and policy expressiveness | Mandatory pass | Mandatory pass | [Named actions, field masking, and relationship-policy enforcement](#authorization-graph-integrity-and-policy-matrix-slice), plus [generated action preservation](#generated-jsonapi-policy-slice) |
| Tenant scoping and missing-context failure | Mandatory pass | Partial pass | [Actor/tenant denial, cross-tenant invisibility, and compound foreign-key tests](#named-action-and-tenant-role-slice), plus [pooled/dedicated request, task, and job routing](#trusted-tenant-placement-routing-slice); other interfaces and movement remain pending |
| Tenant-defined hierarchical capability resolution | Mandatory pass | Mandatory pass | [Recursive composition, rename independence, governed administration, cross-tenant denial, and direct/indirect/concurrent cycle rejection](#authorization-graph-integrity-and-policy-matrix-slice) |
| Independent module gates and safe drain | Mandatory pass | Mandatory pass | [Release/entitlement/activation/authorization matrix, dependency denial, both concurrency lock orders, drain, retained data, mandatory work, and reactivation](#module-lifecycle-slice) |
| State transitions, concurrency, and errors | Mandatory pass | Partial pass | [Named transition, optimistic request version, transactional exact-retry idempotency, and stable validation/forbidden/conflict/idempotency-conflict/not-found/missing-tenant mappings](#idempotency-and-generated-typescript-client-slice); rate-limited, retryable-dependency, and forced-internal paths remain pending |
| Transaction and rollback ergonomics | Mandatory pass | Mandatory pass | [Successful atomic state/audit/event write and injected rollback](#transactional-outbox-slice) |
| Migration readability and safety | Mandatory pass | Partial pass | [Generated baseline inspection, drift detection, catalog proof, and rollback/reapply](#generated-migration-review-slice); live upgrade, backfill, lock, and expand-and-contract evidence still pending |
| Generated API policy preservation | Mandatory pass | Mandatory pass | [Versioned named routes, stable core errors, tenant-safe keyset pagination, checked-in OpenAPI and generated-type drift checks, cross-tenant existence-shape, transactional idempotency, compile-time invalid-call assertions, exact request serialization, no implicit write retry, and generic-update-bypass tests](#idempotency-and-generated-typescript-client-slice) |
| Telemetry and redaction | Mandatory pass | Mandatory pass | [Captured allowlist assertions on allowed and denied generated-interface requests](#telemetry-and-redaction-slice) |
| Test and maintenance ergonomics | Pass or bounded remediation | Not evaluated | Review notes |
| Upgrade effort and dependency health | Pass or bounded remediation | Pass with bounded remediation | [Three-package patch update with zero application or migration diff and 21 passing tests](ash-upgrade-exercise.md) |

The environment smoke test must not be used to accept Ash. Every mandatory category needs direct evidence.

## Limits

- Role removal, assignment administration, idempotent role-action retries, bulk graph changes, and role-management transport contracts are not implemented; this slice proves only the bounded graph and policy matrix.
- Outbox dispatch, retry, deduplication, retention, and placement-movement reconciliation remain later-phase work; lifecycle replay is modeled only as transactional cursor and work-item state.
- The trusted routing registry and job runner are pressure-test components; production control-plane availability, movement, Oban integration, and external namespace enforcement remain unimplemented.
- The lifecycle release manifest, registry rows, work items, projections, replay, and reconciliation are synthetic contract models rather than production services or live external integrations.
- Lifecycle idempotency-key retries are not exercised and remain an ADR 0001 acceptance gap.
- Rate-limited, retryable-dependency, and forced-internal JSON:API paths remain untested.
- Idempotency-claim expiry, retention, cleanup, abuse limits, and failover-in-flight behaviour remain unproven; lifecycle and role-administration actions do not yet use this contract.
- AshJsonApi does not enforce or document the declared maximum page size at this generated interface in the tested version. The Phase 0 edge gate and OpenAPI modifier close the public contract locally but add adapter ownership and upgrade-drift risk.
- The TypeScript directory is an isolated contract harness, not the Phase 1 web workspace; production package ownership, publishing, authentication/session integration, compatibility release policy, and broader query serialization remain undecided.
- Response outcome/duration telemetry and third-party logger-redaction assertions remain outside this pre-dispatch telemetry proof.
- The generated migration proof covers a fresh disposable baseline, not a live upgrade with retained data, backfill, lock, or mixed-version compatibility.
- The JSON:API request validator requires the optional OpenApiSpex dependency; the prior missing-tenant mapping warning is closed by an explicit protocol implementation.
- The named action is not fully atomic because the locked framework pair cannot translate the custom validation error; the current fallback path is transaction-backed with optimistic locking.
- A patch upgrade passes, but a non-patch framework upgrade and a machine-normalized warning-delta gate remain untested.
- No clean-machine or CI-host rehearsal has been completed.
