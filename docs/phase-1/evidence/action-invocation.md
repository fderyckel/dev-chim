# Core-foundation slice 1C action-invocation evidence

- Status: Focused and full working-tree checks passed; governing ADRs subsequently accepted
- Owner: Platform engineering
- Date: 2026-09-15
- Source: revision `61469c9` plus the current uncommitted Phase 0 and Phase 1 work
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, Ash 3.33.3, PicoSAT 0.2.3, Python 3.14.5, PostgreSQL 18.6, and Node.js 24.15.0
- Boundary: [core foundation](../../architecture/core-foundation-boundary.md)

## Implemented proof

`Chimwemwe.Platform.ActionInvocation` is the sole production-core bridge in this slice from `ExecutionContext` to Ash. It exposes only `read/4`, including its default-input `read/3` form. It does not expose create, update, destroy, generic action, or Ash-options entry points.

For every invocation, the boundary:

1. revalidates the trusted execution context before resource or action discovery;
2. accepts only a loaded Ash resource registered in a real Ash domain that always authorizes, requires an actor, and passes the complete production resource contract;
3. accepts only a public named action whose Ash type is read;
4. accepts ordinary action input as a plain map and rejects actor, tenant, authorization, routing, placement, domain, repository, correlation, purpose, locale, and other platform-owned keys;
5. derives the real actor and tenant from the trusted context, omitting Ash tenant scope only for explicitly global-reference resources; and
6. propagates only correlation ID, purpose, locale, and routing version under a namespaced `chimwemwe` Ash context.

Unavailable resources and actions return coarse, non-disclosing invocation codes. Invalid trusted context retains the existing typed context failure, and Ash policy denial remains an Ash forbidden result rather than being converted into success or hidden by an interface check.

Only neutral ETS resources exist for this test proof. They are not registered in the empty production domain and introduce no production data model or persistence.

## Test evidence

Focused command: `mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/platform/action_invocation_test.exs`

Focused result: 9 tests passed. They prove:

- two trusted tenants invoking the same named read see only their own records;
- an actor lacking the test policy's assurance requirement is forbidden;
- a global-reference read keeps the real actor and policy context without Ash multitenancy;
- raw, malformed, mismatched, and non-positive-routing context fails before resource or action discovery;
- non-resources and unregistered resources share one resource-not-available result;
- private, missing, write-type, and non-atom action references share one read-action-not-available result;
- reserved authority or context input and non-map input fail before Ash executes; and
- the module exports no create, update, or destroy entry point.

Fast command: `make test-fast`

Fast result: all 34 production-core tests passed.

Core command: `./bin/core-check`

Core result: shell and Elixir formatting, warnings-as-errors compilation, strict Credo analysis, Hex advisory and unused-dependency checks, Dialyzer, all 34 tests, and Git whitespace checks passed. Hex could not refresh two registry records during the advisory check and explicitly used its local cache; the audit completed and reported no retired or advisory packages.

Full command: `make check`

Full working-tree result: 12 repository-tool tests, 94 Phase 0 Ash/PostgreSQL tests, 6 Phase 0 TypeScript client tests, and 34 Phase 1 core tests passed. Ruff, ShellCheck, documentation and phase-boundary validation, generated migration, resource-descriptor, OpenAPI, TypeScript, and dependency-warning drift checks, type checking, Credo, Hex and npm audits, unused-dependency checks, Dialyzer, formatting, and Git whitespace checks also passed. The Ash dependency-warning baseline remained at 39 normalized groups with zero delta.

## Historical Phase 0 state at slice completion

The separate exit command `mise exec -- uv run python tools/check_phase0.py --exit-review` failed as expected. It still reports unresolved owners, dates, numeric targets, evidence, decisions, and not-run recovery/capacity work, plus every required ADR that remains Proposed. The failure is retained as evidence that slice 1C did not turn working checks into Ash adoption or Phase 0 approval.

Follow-up on 2026-09-16: the accountable review completed Phase 0, accepted ADR 0005, and conditionally accepted Ash. The exit check now passes. This later decision does not rewrite the historical slice result or authorize write invocation.

## Limits and next gate

- This boundary accepts only reads. The first write path still requires an authorized persistent resource and its migration, tenant constraints, authorization, concurrency, idempotency, transactional outbox, and recovery proof.
- The production Ash domain remains resource-empty; all invocation fixtures are test-only and in memory.
- This slice does not authenticate actors, resolve a live placement registry, verify routing-version currentness, select a PostgreSQL repository, expose an HTTP interface, generate a client, or execute descriptor or experience metadata.
- The resource and action arguments are code-known modules and names, not public discovery or arbitrary module-loading surfaces.
- ADR 0005 is now Accepted and Ash is Conditionally Accepted. This read-only proof still does not authorize the first write path or waive its production gates.
