# Pre-checkout tenant-admission measurement

- Status: Local candidate passed; selected-deployment qualification is a later production gate
- Owner: Platform engineering and operations
- Measured: 2026-09-16
- Machine record: [`precheckout-admission-measurement.json`](../../../spikes/ash-foundation-lab/priv/maintenance/precheckout-admission-measurement.json)

## Result

The disposable Elixir admission boundary acquires both a tenant permit and a placement permit before invoking the callback that can call Ecto. Rejected work therefore cannot reach `AshFoundationLab.Repo` or request a Postgrex connection. It does not replace Ash action authorization; tenant and actor policy still belongs at the domain boundary.

Three final PostgreSQL 18.6 repetitions passed. Other-tenant p95 degradation ranged from -0.151% to 0.257% against the accepted 20% maximum. Tenant 1 was backpressured before database checkout on 602-603 of 800 attempts per run. Tenants 2-5 admitted all 400 attempts per run, no placement-budget rejection occurred, and every admitted batch retained 25 facts, one audit record, and one outbox record.

The implementation also fails closed for missing tenant context, differentiates tenant saturation as a rate-limited condition from placement saturation as a retryable dependency, releases permits after exceptions, and reclaims them when a caller crashes.

## Reproduction

```sh
mise exec -- uv run python tools/measure_phase0_precheckout_admission.py \
  --repetitions 3 \
  --output spikes/ash-foundation-lab/priv/maintenance/precheckout-admission-measurement.json
```

The result is SHA-256-bound to the runner, Elixir admission module, Mix measurement task, numeric target recommendation, original failed raw pooled measurement, and database-transaction fairness follow-up.

## Boundary

This closes the local pre-checkout admission gap. It does not prove distributed fairness between two application nodes, provider network behaviour, endpoint reconnection, provider failover, or deployment storage performance. Those checks must run in the selected non-AWS deployment; the earlier AWS example is [withdrawn](managed-postgresql-topology.md). The two-per-tenant and ten-per-placement limits are an accepted starting estimate and must be recalibrated from that result before production.
