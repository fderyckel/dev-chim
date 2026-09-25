# Core-foundation slice 1A evidence

- Status: Focused implementation and working-tree checks passed; governing ADRs subsequently accepted
- Owner: Platform engineering
- Date: 2026-09-15
- Source: revision `61469c9` plus the current uncommitted Phase 0 and Phase 1 work
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, Ash 3.33.11, PicoSAT 0.2.3, Python 3.14.5, PostgreSQL 18.6, and Node.js 24.15.0
- Boundary: [core foundation](../../architecture/core-foundation-boundary.md)

## Implemented proof

The root is now an Elixir umbrella with one production app, `chimwemwe_core`. It pins Ash 3.33.11 and PicoSAT 0.2.3 and resolves every shared dependency to the same version already present in the Phase 0 Foundation Lab lock. The coordinated [security-patch reviews](../../phase-0/evidence/ash-security-patch.md) supersede the original 3.33.3 pin without importing any spike module into production.

The core defines:

- a resource-empty `Chimwemwe.Platform` Ash domain with authorization forced to `:always` and actor presence required;
- opaque trusted-actor and trusted-placement types with UUID, assurance, placement-profile, opaque-reference, and positive-routing-version validation;
- execution-context establishment that requires tenant agreement plus correlation, purpose, and locale metadata;
- revalidation immediately before supplied work, returning typed errors without echoing actor, tenant, placement, or correlation values;
- a base-resource convention that requires code-owned tenant or global-reference ownership and installs the Ash policy authorizer; and
- a domain/resource audit for global authorization, actor presence, registration, policy presence, tenant shape, global-reference separation, and named state-changing actions.

Synthetic in-memory resources compile only in the test environment. They prove the structural contract without creating a production resource, table, migration, API, or second model source.

## Test evidence

Focused command: `mise exec -- env MIX_ENV=test mix test`

Focused result: 14 production-core tests passed. They prove:

- matching authenticated and routed tenant sources establish a usable execution context;
- authenticated and routed tenant mismatch fails closed;
- missing context and a raw request map cannot invoke the supplied operation;
- a non-positive routing version is rejected again immediately before work;
- malformed actor, placement, and execution metadata returns typed field-level errors;
- the configured production Ash domain reports authorization mode `:always` and requires an actor;
- valid tenant-owned and global-reference resource shapes pass;
- a resource that bypasses the base or omits policy configuration fails;
- missing, nullable, or public tenant attributes and unsafe multitenancy settings fail;
- global reference data that silently carries tenant scope fails;
- wrong-domain registration fails; and
- a generic state-changing action name fails.

Core verification command: `./bin/core-check`

Core result: shell and Elixir formatting, warnings-as-errors compilation, Credo strict analysis, Hex advisory and unused-dependency checks, Dialyzer, 14 tests, and Git whitespace checks passed.

Full command: `make check`

Full working-tree result: 5 repository-tool tests, 88 Phase 0 Ash/PostgreSQL tests, 6 Phase 0 TypeScript client tests, and 14 Phase 1 core tests passed. Ruff, ShellCheck, documentation and phase-boundary validation, generated migration, resource-descriptor, OpenAPI, and TypeScript drift checks, type checking, Credo, Hex and npm audits, unused-dependency checks, Dialyzer, formatting, and Git whitespace checks also passed.

## Historical Phase 0 state at slice completion

The explicit exit command `mise exec -- uv run python tools/check_phase0.py --exit-review` failed as expected. It continues to report unresolved accountable owners, dates, numeric targets, evidence, decisions, `NOT_RUN` recovery/capacity cases, and every required ADR that remains Proposed.

This expected failure proves that the early core start did not mark Phase 0 complete or convert passing local checks into architecture approval.

Follow-up on 2026-09-16: the accountable review completed Phase 0 and the exit check now passes. Ash is conditionally accepted and ADR 0019 is accepted; all retained production gates and slice boundaries still apply.

## Limits

- The trusted inputs are types and validation contracts, not live authentication or placement-registry integrations.
- The routing version is validated structurally; currentness against an authoritative registry is not yet resolved.
- The production Ash domain intentionally contains no resource, action, capability lookup, policy, or data layer.
- Phase 0 scenario 15 contains a disposable descriptor, drift check, and experience-metadata validator. None is a production API or part of this Phase 1 core slice; production consumers and persistence still require a separately authorized slice and their ADR 0019 security gates.
- There is no PostgreSQL repository, migration, transaction, outbox, API, worker, module registry, or school business module.
- The Phase 0 third-party warning baseline and broader Ash adoption scorecard remain upgrade and production-gate inputs.
- Independent security/privacy review remains required before real restricted data.
