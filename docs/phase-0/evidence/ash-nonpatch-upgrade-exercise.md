# AshJsonApi non-patch upgrade exercise

- Status: Pass with bounded remediation
- Owner: Platform engineering
- Date: 2026-09-16
- Source revision: `50defa1a2190f25414aced0bc6887d8f3e7c1524`
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, PostgreSQL 18.6
- Decision boundary: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)
- Machine-readable result: [ash-nonpatch-upgrade.json](../../../spikes/ash-foundation-lab/priv/maintenance/ash-nonpatch-upgrade.json)

## Scope and selection

The exercise upgraded the JSON:API framework component from [AshJsonApi 1.6.6](https://hex.pm/packages/ash_json_api/1.6.6) to [1.7.1](https://hex.pm/packages/ash_json_api/1.7.1) in a disposable repository copy. This is a minor, non-patch transition. Ash remained fixed at 3.33.3 and AshPostgres at 2.13.1 so the result isolates the interface-framework change.

The immediately preceding Ash and AshPostgres minors were considered first and rejected as baselines before compatibility testing:

| Component | Rejected baseline | Hex audit result | Reason for exclusion |
| --- | --- | --- | --- |
| Ash | 3.32.3 | `EEF-CVE-2026-82752`, medium | An advisory-affected framework is not an acceptable compatibility baseline. |
| AshPostgres | 2.12.0 | `EEF-CVE-2026-78699`, high | The advisory concerns failed tenant rename and possible cross-tenant access, so using it as an accepted baseline would contradict the tenancy gate. |

AshJsonApi 1.6.6 produced no retired-package or security-advisory finding with the fixed Ash/AshPostgres pair. The disposable resolver selected the same compatible transitive graph on both sides. The upgrade lock diff contained only `ash_json_api`; the repository lock was not modified.

## Release review

The package changelog and `mix hex.package diff ash_json_api 1.6.6..1.7.1` showed one material feature family and its follow-up fixes:

- 1.7.0 added the `show_fields` and `hide_fields` DSL, validation, and filtering through schemas, routes, sorting, includes, writes, and serialized results;
- it corrected OpenAPI field-name mapping and serialization of constrained non-resource structures; and
- 1.7.1 stopped generating filter schemas for resources without a JSON:API type.

The field-visibility DSL is not accepted as authorization. It may constrain presentation after policy authorization, but domain policies, tenant scope, and the governed public contract remain authoritative.

## Commands and results

The baseline and candidate ran in one disposable copy against the same synthetic PostgreSQL database. The database was dropped after the exercise.

```sh
mix deps.get
mix hex.audit
mix deps.unlock --check-unused
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=test mix ash_postgres.generate_migrations nonpatch_previous \
  --migration-path priv/nonpatch_previous/migrations \
  --snapshot-path priv/nonpatch_previous/resource_snapshots
MIX_ENV=test mix openapi.spec.json \
  --spec AshFoundationLab.JsonApiRouter \
  --check --pretty=true --filename priv/openapi/phase0-v1.json
MIX_ENV=test mix phase0.descriptor.check
PGDATABASE=ash_foundation_lab_nonpatch_review_20260916_v2 MIX_ENV=test mix test
```

After changing only the disposable AshJsonApi pin from 1.6.6 to 1.7.1:

```sh
mix deps.update ash_json_api
mix hex.audit
mix deps.unlock --check-unused
MIX_ENV=test mix compile --force --warnings-as-errors
MIX_ENV=test mix ash_postgres.generate_migrations --check \
  --migration-path priv/nonpatch_previous/migrations \
  --snapshot-path priv/nonpatch_previous/resource_snapshots
MIX_ENV=test mix openapi.spec.json \
  --spec AshFoundationLab.JsonApiRouter \
  --check --pretty=true --filename priv/openapi/phase0-v1.json
MIX_ENV=test mix phase0.descriptor.check
PGDATABASE=ash_foundation_lab_nonpatch_review_20260916_v2 MIX_ENV=test mix test
```

| Check | 1.6.6 baseline | 1.7.1 candidate |
| --- | --- | --- |
| Application compile with warnings as errors | Passed | Passed |
| Hex security audit | No advisory or retired package | No advisory or retired package |
| Unused dependency check | Passed | Passed |
| Full suite on the same migrated schema | 94 passed | 94 passed |
| Generated migration bundle | SHA-256 `e36e7e8c910bb5b514a3a8ad6bb3165d7ab82d5dfa5a0abf6bed52940631c5f1` | Same; check mode passed |
| Checked OpenAPI artifact | SHA-256 `c3282aac350b39f81642167fecdb8fe97cc497d954e67271b5b463893b413138` | Same |
| Checked resource descriptor | SHA-256 `88890d1fa5ae6a48b0176132f6542486ec9e92505bc338a6f55f7358741a236f` | Same |

No application source changed. The baseline lock SHA-256 was `e45e619b4c360dd32999d5ef16788d6ab4ddd5e24dc72115e2d51f544d8e48b1`; the candidate was `bc7a379bca1f9c19417e67ee21716b983a5d00fb8112257f0b8b6534be94e451`. Their only lock entry difference was AshJsonApi.

## Warning review

Forced full dependency compilation produced 38 normalized groups on both sides of the isolated graph. Three groups were removed and the same three messages were added at later source lines after the new feature code shifted their locations:

- `json_schema/json_schema.ex`: line 343 to 347;
- `request.ex`: line 1223 to 1246; and
- `json_schema/open_api.ex`: line 1354 to 1387.

There was no new warning message, category, owning package, or net group. The repository's separate 39-group [warning baseline](ash-dependency-warning-baseline.md) continues to govern its exact checked lock; the isolated exercise resolved three newer transitive patches equally on both sides and therefore must not replace that artifact.

## Assessment

The non-patch upgrade criterion passes with bounded remediation. A real minor transition in the generated-interface component required no application change, preserved migration and public artifacts byte-for-byte, passed the full policy/tenancy/API suite against the same schema, and produced only reviewed warning-location movement.

This closes the specific ADR 0002 condition to exercise a non-patch Ash/AshPostgres/AshJsonApi update. It does not pre-approve future minors or majors. Every dependency update must still review release notes, advisories, lock and warning deltas, generated artifacts, migrations, and the full negative suite.

After the evidence artifact and its fail-closed repository validator were integrated, `make check` passed with 14 repository-tool tests, 94 Phase 0 lab tests, 6 generated-client tests, and 34 provisional core tests, together with all formatting, lint, generated-artifact, audit, type-analysis, warning-drift, migration, and whitespace gates.

## Limits

- This tests an AshJsonApi minor, not an Ash core or AshPostgres minor; unsafe preceding minors for those packages were rejected rather than treated as acceptable baselines.
- The disposable graph held Ash and AshPostgres fixed and resolved three newer transitive patches equally on both sides. It isolates the direct minor delta but is not byte-identical to the repository's current lock.
- The lab does not use the new field-visibility DSL, so the exercise proves compatibility with the existing contract rather than exhaustive new-feature behaviour.
- The run used one local machine and a synthetic database, not a clean CI host or production-shaped workload.
- Package freshness and advisory results are dated evidence and must be refreshed at each relevant upgrade or production gate.
- The later production-shaped migration measurement, owned-boundary disposition, and accountable conditional Ash decision close the Phase 0 documentation gaps without pre-approving future upgrades.
