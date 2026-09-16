# Testing conventions

## Test layers

- Repository tests validate documentation, ADR structure, links, and phase boundaries.
- Production core tests validate trusted actor/placement source separation, fail-closed execution context, tenant agreement, global Ash authorization and actor requirements, the resource-authoring contract, deterministic allowlisted descriptor derivation, and trusted invocation of public named reads.
- Unit tests cover deterministic logic without services.
- Integration tests use the local synthetic PostgreSQL database and exercise Ash/PostgreSQL behaviour.
- Security tests include negative authorization and cross-tenant cases alongside positive cases.
- Contract tests drift-check the OpenAPI-derived TypeScript declarations, compile invalid-call assertions, and exercise the thin client's request and retry behaviour without creating a production web workspace.
- Placement tests prove that authenticated tenant context, not request input, selects the database and every bounded non-HTTP target; stale or missing routing fails closed. Movement tests keep the source authoritative during copy, quiesce ordinary work, reconcile code-owned tenant snapshots, increment the route version only at cutover, reject every old interface envelope, and exercise rollback.
- Module-lifecycle tests keep release availability, entitlement, activation, and actor authorization independent and cover concurrent deactivation, drain, retained data, and reactivation.
- Migration-rehearsal tests use disposable databases to prove bounded lock failure, mixed-version compatibility, tenant-scoped batches, constraint validation, retained-data snapshots, and the explicit point after which rollback becomes destructive.
- Maintenance-contract tests inventory the disposable lab's non-atomic, raw-SQL, generated-interface, and migration choreography boundaries; they reject unowned additions, authorization bypasses, silent skips, and detached drift controls.
- Resource-authoring tests drift-check the allowlisted descriptor, validate tenant view/report definitions, re-authorize filtered reads, reject forbidden metadata, and exercise stable-reference rename/removal compatibility.
- Performance tests model synchronized bursts, batch distributions, write amplification, retries, corrections, permission revocation, mixed reports, pool pressure, and noisy neighbours rather than relying on average annual volume.
- Availability and consistency tests separate writer failover, replica lag/outage, point-in-time restore, and regional recovery; security-sensitive reads and immediate confirmation never silently use stale state.
- Later end-to-end, accessibility, full performance, recovery, and adversarial tests are added when their platform capability exists.

## Commands

```sh
make test-fast
make test
make lint
make docs-check
make check
```

### Fast development loop

`make test-fast` runs only the provisional production-core test suite. It is the default short loop for core resource, action, policy, execution-context, descriptor, and trusted read-invocation work. It does not run the disposable Ash lab, Python repository checks, generated-artifact drift checks, TypeScript contracts, lint, dependency audit, or static analysis.

Use a focused `mix test path/to/test.exs` command when one file is sufficient during diagnosis. Before sharing any change, run the relevant focused checks and the complete `make check` contract; a passing fast loop is never Phase 0 or architecture evidence by itself.

Focused commands:

```sh
mise exec -- uv run pytest tests/tools
mise exec -- uv run python tools/check_phase0.py
mise exec -- uv run python tools/check_ash_dependency_warnings.py
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/trusted_routing_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/synthetic_module_lifecycle_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/retained_data_migration_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/maintenance_contract_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/resource_authoring_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix phase0.descriptor.check
cd spikes/ash-foundation-lab && mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix openapi.spec.json --spec AshFoundationLab.JsonApiRouter --check --pretty=true --filename priv/openapi/phase0-v1.json
cd spikes/ash-foundation-lab && mise exec -- mix credo --strict
cd spikes/ash-foundation-lab && mise exec -- mix dialyzer
cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm run generate:check
cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm run typecheck
cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm test
mise exec -- env MIX_ENV=test mix test
./bin/core-check
```

## Rules

- Tests are deterministic, isolated, and safe to rerun.
- Use synthetic tenant IDs and records; never copy production data.
- Database tests use SQL Sandbox transactions where possible.
- Test names describe behaviour and expected denial, not implementation details.
- Every policy change needs a permitted case, a denied case, a cross-tenant case, and a missing-context case where applicable.
- Every core execution-context change needs complete, missing, raw-map, malformed, invalid-routing, and tenant-mismatch cases where applicable. Live routing integration must add stale-version cases against the authoritative registry.
- Every base-resource or domain-contract change needs valid tenant-owned and global-reference cases plus missing-contract, missing-policy, wrong-domain, unsafe-tenant, and generic-mutation denials where applicable.
- Every production descriptor change needs tenant-owned and global-reference cases plus invalid-resource, private or missing field/action, unsupported type/classification, malformed or duplicate reference, generic mutation, canonical ordering, and stable-evolution tests where applicable.
- Every trusted invocation change needs public named-read, actor denial, cross-tenant, global-reference, missing or invalid context, unregistered resource, private or wrong-type action, reserved-input, and no-write-surface cases where applicable.
- Every placement-routing change needs pooled and dedicated positive cases plus wrong-tenant, request-selected, stale-version, missing-placement, spawned-task, job-context, and relevant non-HTTP negative cases. Every movement change also needs authorization, current-version, destination-membership, quiescence, reconciliation-failure, cutover, stale-envelope, and rollback evidence.
- Every module gate change needs independent entitlement, activation, and authorization cases; no test may infer one from another.
- Every read-routing change needs writer-required, read-your-write, bounded-staleness, lagging-reader, unavailable-reader, and prohibited request-selected-repository cases where applicable.
- Every generated-client change must start from the checked-in OpenAPI artifact, reject contract drift, keep tenant placement out of caller input, and prove whether write retries are explicit or automatic.
- Every retained-data migration must separate expand, mixed-version operation, tenant-scoped bounded backfill, validation, contract, and rollback boundaries; destructive contract requires an explicit drain and recovery gate.
- Every new non-atomic action, raw-SQL source, generated-interface edge adapter, OpenAPI modifier, or platform-owned migration choreography path must be registered with an owner, cost, bounded remedy, closure gate, recheck trigger, source, and evidence.
- Every descriptor or experience-metadata change must preserve one-way derivation, stable allowlisted references, exact revision checks, trusted tenant/actor binding, sanitized query input, and domain-boundary re-authorization; add private, stale, cross-tenant, executable, authority, and removed-reference negatives.
- Every dependency or Elixir/OTP change must force the complete spike dependency compile and produce a reviewed zero-delta warning result. Both added and removed warning groups require an explicit baseline update; application code remains governed by warnings-as-errors.
- Every pool or application-node change must recalculate the per-placement connection budget, including writer, reader, Oban, administration, monitoring, replication, and failover reserve.
- A benchmark report states its data shape, time distribution, hardware, PostgreSQL settings, connections, repeated-run variance, and limitations. Row-count arithmetic alone is not benchmark evidence.
- Do not weaken an assertion to make an unsafe implementation pass.
- Record an intentionally skipped test with its owner and unblock condition.

`make check` is the required pre-push proof. A clean exit means the current Phase 0 working checks and provisional Phase 1 core checks passed; it does not close Phase 0, accept an ADR, or certify later foundation gates that have not been implemented.
