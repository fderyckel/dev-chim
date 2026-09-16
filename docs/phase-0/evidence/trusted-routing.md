# Trusted tenant-placement routing evidence

- Status: Mandatory routing, movement, and non-HTTP scoping slice passed; wider placement evidence incomplete
- Owner: Platform engineering and security architecture
- Date: 2026-09-15
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

## Tenant movement and non-HTTP interface slice

The same resolver now exercises event, file, cache, search, realtime, export, analytics, telemetry, AI-tool, and integration invocations. Each invocation accepts only the four-field routing envelope, re-resolves the current placement, derives a tenant- and version-qualified target from a code-owned interface allowlist and trusted registry field, installs the selected repository, and then re-enters the existing Ash actor and tenant authorization path. Caller-supplied tenant, repository, database, namespace, and routing-version fields cannot select the target. Missing, stale, unavailable, unsupported, and unauthorized contexts fail closed.

Movement is a sequence of named transitions rather than a mutable placement edit:

1. `prepare_movement` requires the current routing version, a live destination for the same tenant at exactly the next version, an allowlisted reason, and the tenant-defined `tenant_placement.manage` capability. The source remains authoritative during copying.
2. `quiesce_movement` blocks ordinary request, task, job, and non-HTTP routes for the tenant while retaining the source placement.
3. `reconcile_movement` reads fixed, tenant-qualified snapshots of every table in the current spike migration chain from the real source and destination repositories. It rejects unequal snapshots and retains only a SHA-256 digest, not row contents.
4. `cutover_movement` is available only after successful reconciliation. It replaces the trusted registry entry with the destination at the incremented version, after which every old interface envelope is stale.
5. `rollback_movement` abandons any pre-cutover attempt and restores ordinary source routing. Each transition is bound to the preparing actor, tenant, correlation ID, and source routing version, and emits a minimal in-memory event with an allowlisted reason.

## Database and test evidence

The focused test creates three real disposable PostgreSQL databases with `ash_foundation_lab_routing_pooled_`, `ash_foundation_lab_routing_dedicated_`, and `ash_foundation_lab_routing_movement_` prefixes. It applies the complete spike migration chain to all three, stores one synthetic tenant only in the pooled database and another only in the dedicated database, leaves the movement destination unassigned and empty, starts independent unnamed repository pools, and removes all three databases at module exit.

- Test: [`trusted_routing_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/trusted_routing_test.exs)
- Command: `mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/trusted_routing_test.exs`
- Result: 13 tests passed.
- Static checks: `mise exec -- mix compile --warnings-as-errors`, `mise exec -- mix format --check-formatted`, and `mise exec -- mix credo --strict` passed.
- Cleanup check: no database matching `ash_foundation_lab_routing_%` remained after the run.

The tests prove:

- authenticated tenant A reaches the pooled database and authenticated tenant B reaches the dedicated database;
- request-supplied tenant, database, cell, queue, and routing-version values cannot redirect the authenticated tenant;
- a row present only in the other placement is absent from the selected database;
- missing authenticated context, an unknown tenant, a stale routing version, and an unavailable or wrong repository type fail before the operation runs;
- a plain spawned task has neither the parent's route nor its dynamic repository, while the explicit helper resolves and installs both in the child;
- job arguments contain only the four allowlisted context fields, injected placement data is ignored, and a job with stale or missing context is rejected;
- process-local routing state is restored after both normal completion and a raised operation, preventing route leakage into reused processes;
- all ten bounded non-HTTP interface classes derive their targets from the trusted placement and execute a real Ash read with actor and tenant policy, while forged target fields are ignored;
- every non-HTTP interface rejects stale and missing envelopes, and unauthorized Ash access remains forbidden after routing;
- movement preparation rejects stale, cross-tenant, wrong-version, incomplete, occupied-destination, unauthorized, free-text-reason, and concurrent attempts;
- movement continuation rejects a different actor, correlation ID, or movement ID;
- a real tenant scope copied between two disposable databases remains on its source while copying, is blocked while quiesced, reconciles through code-owned snapshots, cuts over at the next version, and invalidates old envelopes across every interface; and
- a deliberately unequal copy cannot reconcile or cut over, while rollback restores source routing and leaves the destination version unavailable.

## What this does not prove

- The registry, movement state, and movement events are immutable in-memory test values, not a durable or transactionally serialized production control plane, authentication integration, cache, or availability design.
- The job proof exercises a serialized job boundary but does not add or validate Oban, retries, uniqueness, scheduling, or queue supervision.
- The ten non-HTTP interface classes use derived targets and a real Ash policy read, but do not connect queues, object storage, caches, search, realtime, exports, analytics, telemetry providers, AI providers, or integrations. Production envelopes still need authenticated transport identity and real adapter suites.
- The test copies a fixed tenant scope directly between disposable databases. It does not implement a copy worker, durable lock or compare-and-swap, controlled dual writes, outbox drain, external-object reconciliation, post-cutover reverse movement, backup, or restore.
- The snapshot table allowlist is code-owned and complete for the current spike migration chain. Any tenant-owned table change must update it; the checked maintenance boundary makes that an explicit review trigger.
- Support access is not modelled as a generic interface because its strong assurance, explicit purpose, expiry, and enhanced-audit contract remains a later security slice.
- Pool sizing, exhaustion, noisy-neighbour behaviour, burst performance, dedicated cells, read replicas, and regional topology remain separate evidence.
- Logical Ash policy and compound foreign-key protection remain mandatory inside every selected database; physical routing does not replace tenant authorization.

This evidence closes the mandatory Ash tenant-scoping gap at the Phase 0 pressure-test abstraction. It does not accept Ash, approve a final placement profile or RLS decision, satisfy the capacity and recovery campaign, or close ADR 0003.
