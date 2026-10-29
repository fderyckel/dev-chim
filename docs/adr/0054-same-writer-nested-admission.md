# ADR 0054: Same-writer nested admission

- Status: Proposed
- Date: 2026-10-25
- Accountable owner: Platform engineering
- Deciders: François — Project Owner; independent security/privacy review before connected use
- Implementation authority: François asked to address the blocked COMM-1 attendance-impact
  qualification after the People-fence checkpoint identified nested admission as the next repair
- Supersedes: None; supplements ADR 0017's pre-checkout accounting without changing its limits,
  current-route requirement or classification of tenant and placement saturation

## Context

The [People-fence checkpoint](../phase-2/people-source-write-fence-evidence.md) removed the
measured People-row conflict. Its foundation workload passes, but the real attendance workload
rejects work even in baseline: attendance already holds a writer permit and transaction when
`SessionFoundation.validate` enters the same writer and requests a second permit. Six concurrent
operations therefore compete for more than six permits despite using at most six connections.
Rejected operations cannot supply valid successful-call latency comparisons.

## Decision drivers

- Account for one synchronous checked-out writer without charging its nested session validation
  for another connection.
- Preserve current context, routing, session refresh, authority and whole-transaction rollback.
- Keep tenant admission six, placement admission twelve, pool six and all workload/capture bounds.
- Refuse ambiguous reuse and keep spawned or independent work subject to ordinary admission.

## Considered options

1. Increase capacity, reduce concurrent clients, retry rejections or omit failed samples. Rejected:
   changes the retained workload or hides an invalid comparison.
2. Skip the writer-side session recheck or refresh. Rejected: weakens current authority.
3. Add a session-specific unguarded persistence bypass. Rejected: duplicates route/accounting
   logic and makes a second entry path responsible for proving the writer scope.
4. Reuse admission only within the exact active synchronous writer scope. Selected for this
   bounded repair, with fail-closed negative controls.

## Decision

Keep `DatabaseAdmission` responsible for every outer writer's permit, including its monitored
owner and release on all termination paths. Do not change counters, limits or admission keys.
`Persistence.with_writer/3` continues to validate the full execution context and resolve the
current trusted route and supervised repository before every callback, including nested calls.

While an outer admitted callback runs, Persistence holds a private process-local scope containing
the owner process, exact execution context, current registry/admission/repository process IDs.
An inner call can reuse the held permit only when that scope matches exactly, the selected
dynamic repository still matches, and `Repo.in_transaction?/0` confirms that this process is
already in a transaction on that writer. It executes synchronously on the existing checkout;
the inner operation does not release the outer permit or independently commit the transaction.
Existing domain transaction wrappers, session revalidation/refresh and every lock remain intact.

Different actor, tenant, placement/version, purpose, correlation, locale, runtime or repository
cannot borrow the scope. An inner call outside the active writer transaction is also refused.
Return a non-disclosing persistence dependency failure before invoking that inner operation;
never fall back to another checkout within the scope. Invalid/stale routes retain their existing
context/route failures before the reuse decision. Ordinary top-level admission retains its
rate-limited and dependency classifications.

Restore the previous repository and process-local scope on success, exception, exit or rollback.
Spawned processes inherit neither scope nor dynamic repository: they must establish their own
current context and acquire their own permit. The scope is private trusted application state,
not a client credential or protection against arbitrary code executing inside the server process.
No scope token, tenant or repository selector enters a public API.

## Plain-English summary

An attendance request can recheck its session using the database connection it already holds.
Other requests still need their own capacity, and every permission check still runs. The repair
does not enlarge the test environment or make a failed performance trial acceptable.

## Consequences and retained boundaries

This removes duplicate accounting for synchronous nested writer work. Existing calls that try to
nest a different scope or nest without a transaction now fail closed; this compatibility boundary
needs explicit negative tests. Wider cross-runtime/tenant orchestration requires a separate action
after the current scope ends. No new database table, migration, service, session contract, route,
communication publication or release is introduced. Admission remains node-local.

## Security, privacy, operability, and migration effects

This changes synchronous persistence composition, not authorization. Current session validation,
refresh, context and route checks still run on the authoritative writer. The private scope never
appears in client output, logs, telemetry or durable evidence. The outer permit remains monitored
and held through the complete callback, including rollback and nested failures. No schema or data
migration is needed. Real placement movement, multi-node admission and independent security/privacy
assurance remain separate gates.

## Validation evidence

Record results in [nested-admission and attendance evidence](../phase-2/same-writer-admission-evidence.md).
Prove one permit and one PostgreSQL backend/transaction for valid nesting under a one-slot limit;
exact-context/runtime/repository mismatch, stale-route and no-transaction refusal; spawned work
requiring independent admission; release/restoration after exception, exit and rollback; and
atomic rollback of both nested writes and session refresh with the outer operation.

Run all existing platform, identity, source, fence and attendance denials. Repeat the unchanged
foundation qualifier and actual attendance qualifier, each with at least three complete baseline
and mixed comparisons. Every attempted operation must succeed before latency comparisons are
valid. Preserve the 20% read/write p95 limit and absolute targets. Obtain the four delegated
specialist dispositions and run `make check` before declaring this correction complete.

## Fallback and exit cost

If accounting, isolation, rollback or impact qualification fails, retain the failure and keep
publication stopped. Do not relax workload limits or remove session/authority locks to pass.
The prior implementation can be restored without a data migration, but restores duplicate
admission and therefore the invalid attendance qualification. Passing this prerequisite does not implement publication
or close its later action, fan-out, delivery, receipt and release gates.

## Review triggers

Review again for asynchronous work, another repository/runtime, a context change, pool or
placement movement, a failed rollback/impact check, or production/real-data use.

## Related records

- [ADR 0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0038](0038-local-classroom-attendance-workflow.md)
- [ADR 0052](0052-private-staff-audience-source-capture.md)
- [ADR 0053](0053-people-owned-source-write-fence.md)
- [Threat model](../security/threat-model.md), TM-01, TM-02, TM-09, TM-11–TM-15 and TM-19
