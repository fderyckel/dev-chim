# Ash dependency warning baseline

- Status: Pass with a zero-delta review gate
- Owner: Platform engineering
- Date: 2026-09-15
- Scope: complete dependency compilation for the disposable Ash Foundation Lab
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3
- Decision boundary: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)

## Implemented contract

The checked [normalizer](../../../tools/check_ash_dependency_warnings.py) runs a forced `MIX_ENV=test mix deps.compile --force` against the complete locked dependency graph. It captures combined compiler output without suppressing warnings and converts each recognized warning into a stable record containing:

- the dependency package;
- the normalized first-line warning message; and
- every emitted source path, line, column, and function when the compiler supplies them.

Absolute paths, ANSI colour, whitespace, compilation progress, timing, and diagnostic body layout do not enter the comparison. Erlang's file-prefixed warning form is attributed from its `deps/<package>/` path even when Rebar reports the parent application as the current build. Locationless Mix configuration warnings remain recorded rather than discarded. An unrecognized warning format fails the checker so a compiler-output change cannot silently bypass the baseline.

The checked [baseline](../../../spikes/ash-foundation-lab/priv/maintenance/ash-dependency-warnings.json) also fixes the full Hex package/version map, the `mix.lock` SHA-256, the exact compile command, and the Elixir/OTP pair. Both added and removed normalized warning groups have an allowed delta of zero. A dependency or toolchain update therefore fails until Platform engineering reviews the new output and deliberately replaces the artifact; an apparent improvement is reviewed too, so accidental parser loss cannot pass as warning removal.

Chimwemwe-owned code remains governed separately by `mix compile --warnings-as-errors`. The dependency baseline is not an allowlist for application warnings and does not change compiler options in dependency source.

## Results

- Baseline command: `mise exec -- uv run python tools/check_ash_dependency_warnings.py`
- Review command: `mise exec -- uv run python tools/check_ash_dependency_warnings.py --print-current`
- Result: 39 normalized warning groups matched with zero added and zero removed.
- Locked graph: 41 Hex packages, identified by version and complete lock digest.
- Negative tests: added, removed, scope-changed, malformed, orphaned, and nonzero-delta-policy inputs fail closed.
- Integration: the checker runs in `make lint` and the required `make check` path.

The 39 groups are classified for review as follows:

| Category | Groups | Current packages |
| --- | ---: | --- |
| Optional development-module references unavailable at compile time | 6 | Ash and AshPostgres |
| Redundant, unreachable, disjoint-type, or match/type findings | 22 | Ash, AshJsonApi, AshSql, Multigraph, OpenApiSpex, and PhoenixTemplate |
| Unused requirements | 6 | AshJsonApi, AshSql, and Crux |
| Deprecated API, configuration, or Erlang syntax | 5 | OpenApiSpex, Spark, and Yamerl |

These are observed third-party facts, not claims that every warning is harmless. The review value is that their exact locations and dependency ownership are visible and any delta is blocking.

## Limits

- The baseline proves repeatability for the pinned lock and Elixir/OTP pair on the recorded local platform. A clean CI-host run and a non-patch framework upgrade remain required.
- Dependency compilation is forced from the locally available locked source; this is not a package-freshness, advisory, runtime, or behavioural test. Those remain separate checks.
- Compiler warnings can expose a future compatibility problem without being an immediate application defect. The baseline detects change but does not replace dependency release-note review or issue triage.
- Runtime log warnings, generated-migration safety notices, and application warnings belong to their existing evidence and gates; they are intentionally not folded into this compile-warning artifact.

This closes the machine-normalized dependency-warning condition for the current Phase 0 toolchain. It does not close the non-patch upgrade, production-shaped migration measurement, bounded-condition disposition, or accountable Ash adoption decision.
