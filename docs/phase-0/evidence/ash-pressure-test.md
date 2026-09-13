# Ash pressure-test evidence

- Status: Named-action and tenant-role slice passed; adoption scorecard incomplete
- Owner: Platform engineering
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)

## Environment proof

- Date: 2026-09-13
- Host: Apple silicon macOS 26.6.2
- Project runtimes: Erlang/OTP 29.0.5, Elixir 1.20.3, Python 3.14.5, uv 0.12.13
- Services: PostgreSQL 18.6 over the local Unix socket
- Framework packages: Ash 3.33.3, AshPostgres 2.13.1, AshJsonApi 1.7.1, Phoenix 1.8.13
- Commands: `make bootstrap`, `make format`, `make check`, and `mix dialyzer`
- Results: 3 repository-tool tests passed; 10 Ash/PostgreSQL tests passed; Ruff, ShellCheck, documentation validation, Credo, dependency audit, Dialyzer, formatting, migrations, and Git whitespace checks passed.

The Ash tests currently prove attribute-based tenant filtering, cross-tenant denial without an existence signal, actor and tenant fail-closed behaviour, capability denial, tenant-defined role composition and rename independence, a named `submit_for_review` transition, invalid-state validation, optimistic-lock conflicts, compound tenant foreign keys, and database constraints against alternate unsafe writes.

The first clean compilation emitted warnings inside current third-party Ash/Phoenix dependency code under Elixir 1.20/OTP 29. None originated in the spike modules, and the required checks pass, but the warning volume is evidence to consider under upgrade and maintenance ergonomics rather than suppressing or ignoring it.

## Named-action and tenant-role slice

- Date: 2026-09-13
- Code: [`foundation_record.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/foundation_record.ex), [`access_control.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/access_control.ex), and [`policy/`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/policy/)
- Database artifact: [`20260913010000_add_access_model_and_record_workflow.exs`](../../../spikes/ash-foundation-lab/priv/repo/migrations/20260913010000_add_access_model_and_record_workflow.exs)
- Tests: [`foundation_record_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/foundation_record_test.exs)
- Focused command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/foundation_record_test.exs`
- Focused result: 10 tests passed.
- Migration commands: `mise exec -- env MIX_ENV=test mix ecto.rollback --step 1` and `mise exec -- env MIX_ENV=test mix ecto.migrate`
- Migration result: the new access/workflow migration rolled back and reapplied successfully against the synthetic test database.

The access model stores tenant-owned actors, roles, capabilities, actor-role assignments, role-capability assignments, and recursive role inclusions. Role names are data: a test renames a composed role and retains the same capability without a code change. Compound foreign keys reject cross-tenant assignments.

The named update uses Ash validation plus optimistic locking inside the data-layer transaction. Ash 3.33.3/AshPostgres 2.13.1 could not compile the custom validation error into a fully atomic SQL expression, so the spike explicitly uses `require_atomic? false`. Concurrency still fails closed through the lock-version predicate, but the atomic-expression limitation remains framework-fit evidence for the final scorecard.

## Scorecard

| Category | Required result | Current result | Evidence |
| --- | --- | --- | --- |
| Action and policy expressiveness | Mandatory pass | Partial pass | [Named create/read/transition policies](#named-action-and-tenant-role-slice); generated interface still pending |
| Tenant scoping and missing-context failure | Mandatory pass | Partial pass | [Actor/tenant denial, cross-tenant invisibility, and compound foreign-key tests](#named-action-and-tenant-role-slice); other interfaces still pending |
| Tenant-defined hierarchical capability resolution | Mandatory pass | Partial pass | [Recursive composition, rename independence, denial, and cross-tenant assignment tests](#named-action-and-tenant-role-slice); cycle rejection still pending |
| State transitions, concurrency, and errors | Mandatory pass | Partial pass | [Named transition, invalid-state, and optimistic-lock tests](#named-action-and-tenant-role-slice); stable transport error mapping still pending |
| Transaction and rollback ergonomics | Mandatory pass | Not evaluated | Planned failure injection |
| Migration readability and safety | Mandatory pass | Partial pass | [Non-null tenant keys, compound foreign keys, indexes, state constraints, and rollback/reapply](#named-action-and-tenant-role-slice); generated-migration review still pending |
| Generated API policy preservation | Mandatory pass | Not evaluated | Planned JSON:API tests |
| Telemetry and redaction | Mandatory pass | Not evaluated | Planned capture assertions |
| Test and maintenance ergonomics | Pass or bounded remediation | Not evaluated | Review notes |
| Upgrade effort and dependency health | Pass or bounded remediation | Not evaluated | Upgrade exercise |

The environment smoke test must not be used to accept Ash. Every mandatory category needs direct evidence.

## Limits

- Role-composition cycle rejection and administration policies are not implemented yet.
- No audit/outbox transaction, generated JSON:API route, or telemetry assertion is implemented yet.
- The named action is not fully atomic because the locked framework pair cannot translate the custom validation error; the current fallback path is transaction-backed with optimistic locking.
- No dependency upgrade exercise has been completed.
- No clean-machine or CI-host rehearsal has been completed.
