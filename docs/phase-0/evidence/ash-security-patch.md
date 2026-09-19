# Ash 3.33.4 security-patch review

- Status: Pass
- Owner: Platform engineering
- Date: 2026-09-16
- Machine record: [`ash-security-patch.json`](../../../spikes/ash-foundation-lab/priv/maintenance/ash-security-patch.json)
- Advisory: [EEF-CVE-2026-86338](https://osv.dev/vulnerability/EEF-CVE-2026-86338)

## Decision

Upgrade both the Phase 0 Foundation Lab and the then-provisional production core from Ash 3.33.3 to 3.33.4. The advisory affects Ash before 3.33.4 and permits a forbidden calculation or aggregate to act as a filter oracle when field policies deny the field but an interface exposes filtering. The production domain was resource-empty, but a failing security audit is not an acceptable pinned baseline.

The resolver also moved Reactor 1.0.6 to 1.0.7 and Spark 2.7.2 to 2.7.3 in both locks. No other direct framework component changed.

## Focused regression

The new synthetic ETS resource has a field-policy-protected calculation that copies a restricted value. A restricted actor filtering for the exact hidden value receives zero records; an authorized actor using the identical filter receives the matching record. This directly exercises the affected calculation-reference path without adding a production resource or public route.

```sh
cd spikes/ash-foundation-lab
MIX_ENV=test mix test test/ash_foundation_lab/field_policy_calculation_regression_test.exs
```

## Warning and compatibility review

The forced dependency compile moved from 39 to 38 normalized warning groups. It added no group and removed Spark's `Kernel.ParallelCompiler.async/1` deprecation after the transitive Spark patch. The checked baseline records Ash 3.33.4, Reactor 1.0.7, Spark 2.7.3, the new lock digest, and the two expected Ash source-line moves.

The complete `make check` passed after the update: 22 repository-tool tests, 103 Phase 0 Elixir/PostgreSQL tests, six generated-client tests, and 43 production-core tests. Both Hex audits passed, both Dialyzer runs reported zero errors and zero skipped warnings, and the generated migration, OpenAPI, descriptor, formatting, lint, and whitespace gates passed.

## Boundary

This closes the newly published advisory and restores a green verification contract. The later accountable review conditionally accepts Ash, but this patch alone does not authorize a production business resource or waive the eight bounded conditions. Advisory freshness remains time-dependent and is checked on every complete run.
