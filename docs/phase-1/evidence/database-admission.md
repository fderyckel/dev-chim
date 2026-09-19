# Core-foundation slice 1D database-admission evidence

- Status: Implementation and complete verification passed; advisory and lint blockers resolved
- Owner: Platform engineering
- Date: 2026-09-16
- Source: revision `50defa1` plus the current uncommitted Phase 0 and Phase 1 work
- Environment: Apple silicon macOS, Erlang/OTP 29.0.5, Elixir 1.20.3, Ash 3.33.4, and PicoSAT 0.2.3
- Boundary: [core foundation](../../architecture/core-foundation-boundary.md)
- Phase 0 source evidence: [pre-checkout tenant admission](../../phase-0/evidence/precheckout-admission-measurement.md)

## Implemented proof

`Chimwemwe.Platform.DatabaseAdmission` is a new production-core contract implemented independently of the disposable Foundation Lab module. It owns no repository and performs no database work. Instead, a caller supplies a validated `ExecutionContext` and a zero-argument callback whose complete synchronous database work must occur inside the admitted scope.

The boundary:

1. revalidates trusted actor, tenant, placement, routing-version shape, correlation, purpose, and locale before inspecting capacity;
2. derives a tenant-within-placement key and placement key from trusted context, with no caller-supplied identifier or repository option;
3. requires explicit positive per-tenant and per-placement limits and has no production capacity defaults;
4. atomically acquires both local limits before invoking the callback;
5. returns `:rate_limited` for tenant saturation and `:retryable_dependency` for placement saturation;
6. includes no tenant or placement identifier in errors or statistics and includes retry guidance only when configured explicitly;
7. releases the permit after normal return, exception, throw, or exit; and
8. monitors the admitted caller and reclaims capacity if that process terminates without returning.

If the admission process is unavailable before acquisition, the boundary fails closed with the same retryable-dependency classification and never invokes the callback.

The public operational snapshot contains only total active permits, total admissions, and the two rejection counts. Internal counters remain keyed by the trusted placement reference and authenticated tenant, but those identifiers are not returned.

## Test evidence

Focused command: `mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/platform/database_admission_test.exs`

Focused result: 9 tests passed. They prove:

- a trusted callback runs after admission and leaves no held permit;
- a saturated tenant is rejected before callback execution while another tenant in the same placement proceeds;
- a saturated placement is classified separately while work in another placement proceeds;
- raw, invalid-routing, and tenant-mismatched context fails before callback execution or capacity mutation;
- exception, throw, and exit release capacity;
- caller death reclaims capacity;
- retry guidance is absent by default and included only when explicitly configured;
- an unavailable admission process fails closed before callback execution; and
- limits are mandatory and positive, unknown infrastructure options fail, statistics are identifier-free, and the gate is absent from the application supervision tree.

Fast command: `make test-fast`

Fast result: all 43 production-core tests passed.

Core command: `./bin/core-check`

Core result after the coordinated patch: shell and Elixir formatting, warnings-as-errors compilation, strict Credo, Hex audit, unused-dependency check, Dialyzer with zero skipped warnings, all 43 core tests, and Git whitespace validation passed.

## Repository baseline

The first `make check` was run before Slice 1D code was added. It passed Python formatting/lint, ShellCheck, repository/documentation validation, and all 22 repository tests, then stopped in the Phase 0 strict-Credo stage on four existing nested-module alias suggestions in `spikes/ash-foundation-lab/lib/mix/tasks/phase0.tenant_admission.measure.ex`. The final full run stopped on the same findings. Slice 1D does not edit that concurrent Phase 0 work.

Those observations remain historical failure evidence. The later coordinated [Ash 3.33.4 security-patch review](../../phase-0/evidence/ash-security-patch.md) resolved the advisory, the four alias suggestions were fixed, and a complete `make check` passed with 22 repository tests, 103 Phase 0 Ash/PostgreSQL tests, 6 TypeScript tests, and all 43 core tests. The current warning baseline contains 38 reviewed groups with zero drift. Both Hex audits and both Dialyzer runs passed, with no skipped warning.

## Newly published Ash advisory

During final verification, refreshed Hex metadata began reporting [EEF-CVE-2026-86338](https://osv.dev/vulnerability/EEF-CVE-2026-86338) against Ash 3.33.3. The advisory describes a field-policy information-disclosure oracle for forbidden calculations and aggregates and identifies 3.33.4 as the fixed release.

Both locks now pin Ash 3.33.4. The coordinated review refreshes the warning baseline, adds a focused forbidden-calculation filter regression, preserves generated artifacts, and passes both complete verification contracts. The production domain remains resource-empty; the regression lives only in test support.

## Limits and next gate

- This is one node's concurrency gate, not a distributed tenant quota across the proposed two application nodes.
- It is not installed in `Chimwemwe.Application` and is not yet integrated with Ecto, Postgrex, a placement registry, a repository selector, pool telemetry, or failover handling.
- A gate-process restart does not preserve outstanding permit state. Live supervision and failure semantics require the repository/pool integration slice.
- The callback must keep all database work inside its synchronous scope; detached work must acquire its own permit.
- The candidate two-per-tenant and ten-per-placement values remain Phase 0 evidence. They are deliberately absent as code defaults and still require selected-deployment and multi-node calibration.
- Admission is capacity control, not authorization, idempotency, transactionality, or tenant isolation. Every admitted operation must still enter the named domain boundary with the same trusted context.
- This slice adds no production resource, database dependency, migration, write invocation, public interface, service, or infrastructure.
- ADR 0017 is now Accepted as a provider-neutral PostgreSQL contract and Phase 0 is complete. This proof still does not approve pooled production placement or the eventual deployment topology.
