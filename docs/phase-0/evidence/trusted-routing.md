# Trusted tenant-placement routing evidence

- Status: Focused routing slice passed; wider placement evidence incomplete
- Owner: Platform engineering and security architecture
- Date: 2026-09-13
- Source: revision `5c4569024d00` plus the current uncommitted Phase 0 spike changes
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, PostgreSQL 18.6
- Decision boundary: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md)

## Implemented proof

The disposable [`TrustedRouting`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/trusted_routing.ex) slice models four explicit inputs:

1. authenticated tenant, actor, routing-version, and correlation context established outside request parameters;
2. a platform-owned immutable registry entry that selects the repository, profile, database, cell, and tenant-qualified queue, storage, cache, and projection namespaces;
3. an untrusted request map that is never consulted for placement; and
4. an operation that runs only after current registry resolution succeeds.

The resolver installs the selected Ecto dynamic repository and placement in process-local state for the operation's scope. An `after` block restores both values on success or exception. Repository validation confirms that the registry target is a live `AshFoundationLab.Repo`, preventing Ecto's globally named dynamic-repository mechanism from accepting an unrelated process or repository type.

Spawned work does not inherit routing implicitly. The explicit task helper resolves the authenticated context inside the child process. The job envelope carries only tenant ID, actor ID, routing version, and correlation ID; job execution resolves the current registry again and ignores any injected database field.

## Database and test evidence

The focused test creates two real disposable PostgreSQL databases with `ash_foundation_lab_routing_pooled_` and `ash_foundation_lab_routing_dedicated_` prefixes. It applies the complete spike migration chain to both, stores one synthetic tenant only in the pooled database and another only in the dedicated database, starts independent unnamed repository pools, and removes both databases at module exit.

- Test: [`trusted_routing_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/trusted_routing_test.exs)
- Command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/trusted_routing_test.exs`
- Result: 7 tests passed.
- Static checks: `mise exec -- mix compile --warnings-as-errors`, `mise exec -- mix format --check-formatted`, and `mise exec -- mix credo --strict` passed.
- Cleanup check: no database matching `ash_foundation_lab_routing_%` remained after the run.

The tests prove:

- authenticated tenant A reaches the pooled database and authenticated tenant B reaches the dedicated database;
- request-supplied tenant, database, cell, queue, and routing-version values cannot redirect the authenticated tenant;
- a row present only in the other placement is absent from the selected database;
- missing authenticated context, an unknown tenant, a stale routing version, and an unavailable or wrong repository type fail before the operation runs;
- a plain spawned task has neither the parent's route nor its dynamic repository, while the explicit helper resolves and installs both in the child;
- job arguments contain only the four allowlisted context fields, injected placement data is ignored, and a job with stale or missing context is rejected; and
- process-local routing state is restored after both normal completion and a raised operation, preventing route leakage into reused processes.

## What this does not prove

- The registry is an immutable in-memory test value, not the production control-plane store, authentication integration, cache, or availability design.
- The job proof exercises a serialized job boundary but does not add or validate Oban, retries, uniqueness, scheduling, or queue supervision.
- Queue, storage, cache, and projection namespaces are resolved and asserted as metadata; this slice does not connect those external capabilities.
- There is no placement-movement, quiescence, dual-routing, reconciliation, rollback, backup, or restore rehearsal.
- Pool sizing, exhaustion, noisy-neighbour behaviour, burst performance, dedicated cells, read replicas, and regional topology remain separate evidence.
- Logical Ash policy and compound foreign-key protection remain mandatory inside every selected database; physical routing does not replace tenant authorization.

This evidence closes only Phase 0 pressure-test scenario 13. It does not accept a final placement profile, approve RLS, or close ADR 0003.
