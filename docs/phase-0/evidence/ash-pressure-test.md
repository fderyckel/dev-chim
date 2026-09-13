# Ash pressure-test evidence

- Status: Environment smoke test passed; adoption scorecard incomplete
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)

## Environment proof

- Date: 2026-09-13
- Host: Apple silicon macOS 26.6.2
- Project runtimes: Erlang/OTP 29.0.5, Elixir 1.20.3, Python 3.14.5, uv 0.12.13
- Services: PostgreSQL 18.6 over the local Unix socket
- Framework packages: Ash 3.33.3, AshPostgres 2.13.1, AshJsonApi 1.7.1, Phoenix 1.8.13
- Commands: `make bootstrap`, `make format`, `make check`, and `mix dialyzer`
- Results: 3 repository-tool tests passed; 4 Ash/PostgreSQL tests passed; Ruff, ShellCheck, documentation validation, Credo, dependency audit, Dialyzer, formatting, migrations, and Git whitespace checks passed.

The Ash tests currently prove attribute-based tenant filtering, cross-tenant invisibility, missing-tenant failure for reads and creates, and a database constraint against an alternate unsafe write.

The first clean compilation emitted warnings inside current third-party Ash/Phoenix dependency code under Elixir 1.20/OTP 29. None originated in the spike modules, and the required checks pass, but the warning volume is evidence to consider under upgrade and maintenance ergonomics rather than suppressing or ignoring it.

## Scorecard

| Category | Required result | Current result | Evidence |
| --- | --- | --- | --- |
| Action and policy expressiveness | Mandatory pass | Not evaluated | Planned spike tests |
| Tenant scoping and missing-context failure | Mandatory pass | Partial pass | Four basic tenant/database tests |
| Tenant-defined hierarchical capability resolution | Mandatory pass | Not evaluated | Planned role tests |
| State transitions, concurrency, and errors | Mandatory pass | Not evaluated | Planned action tests |
| Transaction and rollback ergonomics | Mandatory pass | Not evaluated | Planned failure injection |
| Migration readability and safety | Mandatory pass | Not evaluated | Migration review |
| Generated API policy preservation | Mandatory pass | Not evaluated | Planned JSON:API tests |
| Telemetry and redaction | Mandatory pass | Not evaluated | Planned capture assertions |
| Test and maintenance ergonomics | Pass or bounded remediation | Not evaluated | Review notes |
| Upgrade effort and dependency health | Pass or bounded remediation | Not evaluated | Upgrade exercise |

The environment smoke test must not be used to accept Ash. Every mandatory category needs direct evidence.

## Limits

- No tenant-defined hierarchical role/capability policy is implemented yet.
- No named state transition, concurrency conflict, audit/outbox transaction, generated JSON:API route, or telemetry assertion is implemented yet.
- No dependency upgrade exercise has been completed.
- No clean-machine or CI-host rehearsal has been completed.
