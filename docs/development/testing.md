# Testing conventions

## Test layers

- Repository tests validate documentation, ADR structure, links, and phase boundaries.
- Production core tests validate trusted actor/placement source separation, fail-closed execution context, tenant agreement, and the global Ash authorization setting.
- Unit tests cover deterministic logic without services.
- Integration tests use the local synthetic PostgreSQL database and exercise Ash/PostgreSQL behaviour.
- Security tests include negative authorization and cross-tenant cases alongside positive cases.
- Contract tests drift-check the OpenAPI-derived TypeScript declarations, compile invalid-call assertions, and exercise the thin client's request and retry behaviour without creating a production web workspace.
- Placement tests prove that authenticated tenant context, not request input, selects database, queue, storage, cache, and projection namespaces; stale or missing routing fails closed.
- Module-lifecycle tests keep release availability, entitlement, activation, and actor authorization independent and cover concurrent deactivation, drain, retained data, and reactivation.
- Performance tests model synchronized bursts, batch distributions, write amplification, retries, corrections, permission revocation, mixed reports, pool pressure, and noisy neighbours rather than relying on average annual volume.
- Availability and consistency tests separate writer failover, replica lag/outage, point-in-time restore, and regional recovery; security-sensitive reads and immediate confirmation never silently use stale state.
- Later end-to-end, accessibility, full performance, recovery, and adversarial tests are added when their platform capability exists.

## Commands

```sh
make test
make lint
make docs-check
make check
```

Focused commands:

```sh
mise exec -- uv run pytest tests/tools
mise exec -- uv run python tools/check_phase0.py
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/trusted_routing_test.exs
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/synthetic_module_lifecycle_test.exs
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
- Every core execution-context change needs complete, missing, raw-map, malformed, stale-routing, and tenant-mismatch cases where applicable.
- Every placement-routing change needs pooled and dedicated positive cases plus wrong-tenant, request-selected, stale-version, missing-placement, spawned-task, and job-context negative cases.
- Every module gate change needs independent entitlement, activation, and authorization cases; no test may infer one from another.
- Every read-routing change needs writer-required, read-your-write, bounded-staleness, lagging-reader, unavailable-reader, and prohibited request-selected-repository cases where applicable.
- Every generated-client change must start from the checked-in OpenAPI artifact, reject contract drift, keep tenant placement out of caller input, and prove whether write retries are explicit or automatic.
- Every pool or application-node change must recalculate the per-placement connection budget, including writer, reader, Oban, administration, monitoring, replication, and failover reserve.
- A benchmark report states its data shape, time distribution, hardware, PostgreSQL settings, connections, repeated-run variance, and limitations. Row-count arithmetic alone is not benchmark evidence.
- Do not weaken an assertion to make an unsafe implementation pass.
- Record an intentionally skipped test with its owner and unblock condition.

`make check` is the required pre-push proof. A clean exit means the current Phase 0 working checks and provisional Phase 1 core checks passed; it does not close Phase 0, accept an ADR, or certify later foundation gates that have not been implemented.
