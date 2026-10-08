# Phase 1 archive: what, how, and why

- Status: Complete and archived at the bounded repository boundary
- Decision date: 2026-09-26
- Accountable decision authority: François — Project Owner and interim Security/Privacy Owner
- Outcome: the production-core foundation, local synthetic browser work, and guarded read-only bridge were implemented; remaining production-entry gates transferred to Phase 2

## Why Phase 1 existed

Phase 1 converted the Phase 0 architecture decisions into a small production-core foundation without prematurely building a school product or selecting production infrastructure. It established the reusable security, tenancy, persistence, lifecycle, temporal, extension, and event-delivery boundaries that Phase 2 work depends on.

## What was done

- Built the trusted execution context and fail-closed resource, action, admission, and persistence boundaries.
- Implemented tenant-defined authority, safe role rename and assignment actions, exact idempotency, minimized audit facts, and transactional outbox facts.
- Qualified a neutral temporal model for immutable revisions, effective segments, append-only facts, correction, and consumer reconciliation.
- Implemented independent module gates, controlled drain, retained ownership, and compatible reactivation.
- Added governed presentation definitions and exact compatible resolution.
- Added internal outbox leases, supervised database-local consumption, durable receipts, dead-letter handling, and audited exact replay.
- Built UI-0 as a local synthetic browser experience and UI-1A as one guarded, loopback, read-only core connection.

## How it was done

Each slice was intentionally bounded. Positive paths were paired with missing-context, capability-denial, stale-route, cross-tenant, conflict, replay, and rollback tests. Database changes were generated, reviewed, applied, rolled back where safe, reapplied, and drift-checked. The browser work used synthetic records and explicit local guards. Repository-wide checks were run at the closure points recorded in the handover evidence.

The implementation under `apps/chimwemwe_core` is still live platform code. Its tests remain active because Phase 2 depends on those guarantees. They are now described as core-platform tests rather than Phase 1 tests.

## Decisions that still govern current work

- State changes are named domain actions, never generic CRUD.
- Trusted actor, tenant, placement, routing, correlation, purpose, and locale context must be validated before work begins.
- Tenant authority is data-driven, hierarchical, renameable, and composable.
- Persistence routing and database admission come from trusted current placement.
- Audit, outbox, and idempotency facts commit atomically with the state change.
- Temporal history remains immutable and corrections append successors rather than rewriting history.
- Module activation does not grant actor authority, and deactivation does not erase retained data.
- UI-0 and UI-1A remain local synthetic qualification surfaces, not production identity or public interfaces.

The maintained rules live in the [ADR index](../adr/README.md), [architecture index](../architecture/README.md), [threat model](../security/threat-model.md), and current [Phase 2 records](../phase-2/README.md).

## What Phase 1 did not authorize

Phase 1 did not select a deployment or identity provider, authorize real restricted data, establish a public production client, qualify multi-node operations, or add a school business module. Local synthetic evidence is not production readiness.

## Retained proof

The consolidated [Phase 1 handover evidence](handover-evidence.md) records the implemented boundaries, final verification, and the gates transferred to Phase 2. The deleted slice-by-slice narratives remain recoverable from Git history.
