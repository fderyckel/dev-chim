# Phase 1 handover evidence

- Status: Historical closure evidence retained for Phase 2 and later work
- Closure decision: Accepted on 2026-09-26
- Closed boundary: Slices 1A through 1J-B, ADR 0018 T1-A/T1-B/T1-C, local synthetic UI-0, and local UI-1A
- Detailed source records: recoverable from Git history before the Phase 1 archive consolidation

## Closure conclusion

Phase 1 completed the bounded repository foundation it was authorized to build. Every included boundary had executable positive and negative evidence, and the complete repository check passed at closure. The work that remained was transferred to Phase 2 rather than left as an ambiguous Phase 1 task.

Closure did not certify production deployment, real restricted data, public access, operational ownership, or a school business workflow.

## Consolidated implementation and evidence register

| Boundary | Implemented guarantee | Evidence retained in the live repository |
| --- | --- | --- |
| Execution and resource contract | Trusted actor and tenant context, fail-closed validation, globally authorized domains, explicit tenant ownership, and rejection of generic state-changing actions | Core execution-context, resource-contract, and domain-audit tests under `apps/chimwemwe_core/test` |
| Resource descriptors and read invocation | Deterministic allowlisted descriptors and trusted invocation of public named reads without caller-selected Ash options or placement | Descriptor and action-invocation tests plus checked interface artifacts |
| Database admission and persistence | Tenant and placement admission occurs before checkout; current trusted routes select pooled or dedicated writers and process state is restored after failure | Admission, placement-registry, persistence, and real synthetic PostgreSQL tests |
| Tenant authority | Tenant-defined memberships, roles, capabilities, assignments, grants, and nested roles remain tenant-qualified; cycles and cross-tenant edges are rejected | Authority resource, resolver, database-constraint, and negative authorization tests |
| Safe authority writes | Role rename and role assignment require code-known capabilities, optimistic concurrency, exact idempotency, and atomic state/audit/outbox evidence | Named-action, replay, conflict, concurrent retry, and rollback tests |
| Temporal qualification | Stable identities, immutable revisions and facts, effective segments, exact history, correction, reversal, and deliberate consumer reconciliation | Temporal qualification tests and reviewed migrations |
| Module lifecycle | Release, entitlement, activation, dependency, and actor authorization are independent; controlled drain retains ownership and cursor state for compatible reactivation | Module-lifecycle action, concurrency, drain, retained-data, and reactivation tests |
| Governed definitions | Definitions are code-constrained, revisioned, tenant-bound, and resolved only at an exact compatible revision with re-authorization | Governed-extension publication, resolution, compatibility, and denial tests |
| Outbox delivery | Tenant/current-route leases, retry state, receipts, acknowledgment-crash idempotency, dead letter, supervised consumption, and audited exact replay are durable | Outbox delivery, supervised-consumer, replay, failure, and migration tests |
| Local browser qualification | UI-0 is synthetic-only; UI-1A exposes one loopback read with server-owned synthetic session context, denial recovery, no mutation client, accessibility, and responsive reflow | Web unit, contract, accessibility, and local browser suites under `clients/web` |

## Final recorded verification

The last complete verification recorded for the Phase 1 closure boundary passed:

- 25 repository-tool tests;
- 106 disposable Phase 0 Ash/PostgreSQL tests;
- 6 generated TypeScript contract tests;
- 134 production-core tests;
- 20 browser unit tests;
- 12 UI-0 browser tests;
- 6 connected UI-1A browser tests; and
- 1 unavailable-core recovery browser test.

The same run also passed formatting, lint, warnings-as-errors compilation, generated migration and interface drift checks, dependency audits, unused-dependency checks, static type analysis, responsive and accessibility checks, and Git whitespace validation.

These numbers are historical closure evidence. Current Phase 2 work must run the suite for each boundary it changes; it must not rerun the retired Phase 0 suite merely because core or browser code changed.

## Gates transferred to Phase 2

| Transferred gate | Phase 2 ownership at closure | Meaning |
| --- | --- | --- |
| Replay ranges, module-aware drain/reactivation integration, operational telemetry, runbooks, and restore/replay convergence | Phase 2.0-B | Local neutral foundations existed; real-module and selected-deployment proof remained separate |
| Retention, legal hold, redaction/erasure, migration provenance, restore, projection convergence, performance limits, and final temporal review | Phase 2.0-C | Domain policy and higher release qualification remained closed |
| Production identity, session, and bounded support access | Phase 2.0-D | Provider-neutral decision work did not itself supply production identity evidence |
| Production browser/API candidate and representative experience evidence | Phase 2.0-E | Local UI-0/UI-1A did not open a production interface |
| Multi-node admission, selected-deployment capacity, routing, movement, recovery, secrets, edge, and observability | Phase 2 L3 admission | Local synthetic checks could not qualify the selected environment |
| Independent security/privacy review and learning-institution records ownership | Phase 2 L3 admission | Real restricted data remained prohibited |

The current disposition of these gates belongs only in the [Phase 2 records](../phase-2/README.md). This archive records the handover point and must not compete with the live Phase 2 status.

## Current verification rule

The core and browser foundations remain in use, so their boundary tests remain in routine verification. The Phase 0 disposable lab and its phase-specific documentation checks are archive-only. Changed-path selection should run documentation, repository-tool, core, web, tooling, or archive maintenance checks only when the corresponding files change.

## Authoritative current records

- [Phase 2 status and evidence](../phase-2/README.md)
- [Architecture index](../architecture/README.md)
- [ADR index](../adr/README.md)
- [Threat model](../security/threat-model.md)
- [Phase 0 handover evidence](../phase-0/handover-evidence.md)

Git history retains the retired slice evidence pages and the original Phase 1 closure record for audits that need the full contemporaneous narrative.
