# Ash test and maintenance ergonomics evidence

- Status: Pass with bounded remediation
- Owner: Platform engineering
- Date: 2026-09-15
- Source revision: working tree based on `61469c9`
- Scope: disposable Ash Foundation Lab only

## Executed checks

The following commands ran from `spikes/ash-foundation-lab` on Apple silicon macOS 26.6.2 with the repository-pinned Erlang/OTP 29.0.5 and Elixir 1.20.3:

```sh
mise exec -- env MIX_ENV=test mix compile --force --warnings-as-errors
(cd ../.. && mise exec -- uv run python tools/check_ash_dependency_warnings.py)
mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/maintenance_contract_test.exs --trace
mise exec -- env MIX_ENV=test mix test --seed 0
mise exec -- env MIX_ENV=test mix test --seed 1
for test_file in test/ash_foundation_lab/*_test.exs; do
  mise exec -- env MIX_ENV=test mix test "$test_file" --seed 0
done
cd ../.. && make check
```

Results:

- Forced test-environment compilation rebuilt 32 maintained and test-support modules and passed with warnings treated as errors.
- The complete forced dependency compile matched its 38-group normalized warning baseline with zero additions and zero removals.
- The focused maintenance contract passed 5 tests.
- Both complete seeded runs passed all 94 tests. ExUnit reported 3.6 seconds for seed 0 and 3.5 seconds for seed 1.
- All nine test files have focused passing evidence: 2 idempotency, 33 resource/API, 3 generated-migration, 5 maintenance, 10 resource-authoring, 3 retained-data migration, 10 role-administration, 15 module-lifecycle, and 13 trusted-routing tests. The original file-isolation campaign covered the same files before the six-test routing expansion; the expanded routing file and maintenance contract were then rerun directly.
- No maintained library source contains `authorize?: false`; no test file or test helper silently excludes a test.
- The required repository-wide `make check` passed after the non-patch evidence integration: 14 repository-tool tests, 94 Phase 0 lab tests, 6 TypeScript client tests, and 34 provisional Phase 1 core tests, plus formatting, generated-artifact and upgrade-evidence checks, the 39-group dependency-warning zero-delta check, lint, dependency audits, Dialyzer, compilation with warnings as errors, migrations, and whitespace checks.

The 2026-09-16 retained-data measurement follow-up adds a tenth independently runnable test file with two tests, registers its raw SQL and operational choreography in the same eight-boundary manifest, and adds a source-bound machine-readable evidence validator. The bounded-condition follow-up adds a machine-checked one-to-one disposition proposal and two repository tests that prevent it from claiming unrecorded acceptance. The quality-target and capacity/recovery follow-up adds two more repository tests that bind the proposed targets to the measured sources and preserve the failed noisy-tenant gate. The fairness follow-up adds two repository tests that bind the passing candidate to that failed baseline, recompute its three-run results, and prevent it from claiming production admission readiness. The required current `make check` passed with 22 repository-tool tests, 96 Phase 0 lab tests, 6 TypeScript client tests, and 34 provisional Phase 1 core tests. The 94-test results above remain the dated pre-measurement ergonomics campaign.

## Checked maintenance contract

The machine-readable [owned-boundary manifest](../../../spikes/ash-foundation-lab/priv/maintenance/owned-boundaries.json) records eight known maintenance surfaces with a classification, accountable owner, concrete cost, bounded remedy, closure gate, recheck trigger, exact source files, and linked evidence. The [maintenance contract tests](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/maintenance_contract_test.exs) fail when:

- a manifest entry is incomplete, contains a Phase 0 placeholder, or points outside the repository;
- a new `require_atomic? false` or raw `Repo.query` source appears without explicit ownership;
- the page-limit or failure-header edge adapter is detached;
- the OpenAPI modifier is detached;
- a retained-data operational migration appears without being registered;
- an authorization bypass appears in maintained spike source; or
- a test is silently skipped or excluded.

Scenario 15 adds the seventh registered surface: the one-way resource descriptor, experience-metadata validator, and code-owned execution registry. The routing follow-up adds the eighth: the tenant-movement and non-HTTP control-plane adapter, including its code-owned tenant-snapshot SQL. Their [authoring evidence](resource-authoring-and-governed-metadata.md) and [routing evidence](trusted-routing.md) record the compatibility behaviour, limits, and production closure gates.

The compile-feedback probe deliberately defines a disposable Ash resource with an unknown attribute type. Compilation fails immediately, names the invalid type, and lists valid types including `Ash.Type.String`. This is useful and actionable feedback for the tested DSL error; it is not a claim that every Ash macro or policy error has equivalent diagnostics.

## Maintenance assessment

The lab has 4,085 maintained library lines across 31 files and 5,442 test lines across nine files. Its full suite is fast enough for the local gate and is repeatable across fixed seeds. Focused files run independently, so investigation does not require the complete suite. Generated migration, descriptor, OpenAPI, and TypeScript declaration checks catch derived-artifact drift.

The maintenance cost is real rather than hidden. The evidence still owns a transaction-backed non-atomic action, dynamic-repository SQL, two HTTP edge adapters, an OpenAPI modifier, and platform-managed retained-data choreography. Two scenario-heavy test files are large because the disposable lab keeps end-to-end setup next to its proof. The spike must not be promoted or copied into production; production boundaries need smaller fixtures and contract-specific helpers.

Third-party dependency compilation still emits 38 reviewed warning groups under the pinned runtime even though a forced compile of the maintained application succeeds with warnings as errors. The [machine-normalized dependency-warning baseline](ash-dependency-warning-baseline.md) blocks any added or removed group, package/lock change, toolchain change, or unrecognized warning form. The [Ash security-patch reviews](ash-security-patch.md) disposition the earlier removed Spark warning and the Ash 3.33.11 zero-group delta; the separate [non-patch exercise](ash-nonpatch-upgrade-exercise.md) retains the AshJsonApi minor comparison.

## Scorecard result

Test and maintenance ergonomics are **Pass with bounded remediation** for the Phase 0 lab:

- positive evidence: application warnings fail the build, the whole suite is short and seed-repeatable, every test file is independently runnable, compile feedback is actionable for the exercised invalid DSL, and the custom integration surface is machine-checked;
- bounded cost: every current custom boundary has an owner, remedy, closure gate, and recheck trigger in the manifest, while current dependency warnings remain visible and zero-delta checked; and
- acceptance limit: tenant movement and non-HTTP scoping now have bounded direct evidence, but this result still cannot accept Ash while the remaining bounded conditions are unresolved and ADR 0002 has no accountable review outcome.

## Limits

- Two seeds and one machine do not prove universal order independence or clean-machine reproducibility.
- The individual-file run proves isolation at file granularity, not at every test-case permutation.
- The source checks find the registered high-risk patterns; they are not a general static security analyser.
- Compile feedback was exercised for one invalid resource attribute type only.
- The warning baseline detects compile-output change; it does not prove that each third-party warning is harmless or replace release-note and compatibility review.
- The manifest covers the known Phase 0 lab boundaries, not future production code.
- No CI-host or clean-checkout rehearsal was completed in this slice.
