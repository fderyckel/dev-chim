# Phase 0 handover evidence

- Status: Historical exit evidence retained for later phases
- Exit decision: Complete on 2026-09-16
- Evidence type: synthetic local engineering evidence plus accountable review
- Detailed source records: recoverable from Git history before the Phase 0 archive consolidation

## Exit conclusion

Phase 0 passed its repository exit boundary. The architecture decisions were recorded, the threat model was accepted as the engineering baseline, all fifteen Ash pressure-test scenarios and their follow-ups were exercised, and Ash was conditionally accepted as the default production-core framework.

That conclusion was deliberately narrower than production readiness. Later phases must not use this archive as proof of a selected deployment, real-user suitability, independent security approval, or safe handling of real restricted child data.

## Consolidated evidence register

| Evidence area | Historical result | What later phases may rely on | What still requires current evidence |
| --- | --- | --- | --- |
| Repository verification | Clean-checkout bootstrap and the then-current complete repository check passed | Declared inputs could reproduce and verify the Phase 0 candidate | Current Phase 2 changes must pass their own boundary checks |
| Ash pressure test | The final recorded run passed 22 repository-tool tests, 96 Ash/PostgreSQL tests, 6 generated-client tests, and 34 early core tests, plus formatting, lint, audits, drift checks, type analysis, migrations, and whitespace checks | The tested framework patterns were viable inside the bounded synthetic lab | Every production capability must satisfy the applicable bounded condition below |
| Security maintenance | Ash 3.33.11 closed the recorded field-policy and bulk-private-argument advisories; dependency and warning drift checks passed | The adopted dependency baseline addressed the known issues at exit | Current dependency advisories and real production review remain live obligations |
| Tenant isolation and authority | Negative tests covered missing context, cross-tenant access, tenant-defined roles, nested role composition, rename independence, and database constraints | The platform must preserve tenant-qualified, fail-closed authority | Real identity, support access, routing, and domain-specific authority require current qualification |
| Trusted routing and placement | Synthetic pooled and dedicated routing, stale-version denial, movement, rollback, and non-HTTP propagation were exercised | Placement comes from trusted authenticated context, never request input | Selected-deployment multi-node routing, movement, residency, capacity, and recovery remain later gates |
| Module lifecycle | Release, entitlement, activation, dependency, actor authority, drain, retained data, mandatory work, and compatible reactivation were exercised independently | The four server-side gates and retained-data model remain binding | Real modules, queues, consumers, runbooks, and operational telemetry require current evidence |
| Capacity and recovery | Local synthetic burst, noisy-tenant, failover, point-in-time recovery, pre-checkout admission, and a 131.2-million-row full-horizon restore were recorded; the bounded admission follow-up passed | Numeric targets and workload-driven placement are the planning baseline | A selected deployment must repeat capacity, failover, backup, restore, and recovery qualification |
| Migrations and generated interfaces | Apply/rollback/reapply, retained-data migration, OpenAPI, generated TypeScript, descriptors, and drift checks passed in the lab | Generated outputs are reviewable artifacts and migration safety remains explicit | Each production schema or interface change needs its own compatibility and rollback evidence |
| Security and privacy review | The threat model and abuse cases were accepted as an engineering baseline | Current work must preserve the threat controls and fail-closed boundaries | Independent security/privacy review and a learning-institution records owner are required before real restricted data |

## Eight Ash conditions carried forward

Ash was accepted with eight owned escape hatches. They remain production gates, not reasons to rerun the whole Phase 0 suite for ordinary Phase 2 work.

| Condition | Required check when the boundary becomes real | Fallback principle |
| --- | --- | --- |
| Non-atomic action boundary | Prove transaction, authorization, audit, outbox, idempotency, and failure rollback | Own the bounded orchestration explicitly if the framework cannot preserve the contract |
| Raw SQL boundary | Prove trusted repository selection, tenant-qualified predicates, constraints, and transaction participation | Move the operation behind a safer owned adapter or framework action |
| Generated public interface | Prove input limits, action semantics, error mapping, OpenAPI drift, and client behaviour | Own the public route in a thin adapter |
| Migration choreography | Prove expand-and-contract safety, mixed-version operation, bounded backfill, rollback, and retained-data handling | Stop the rollout or use an operator-owned migration path |
| Resource authoring and metadata | Prove allowlisted descriptors, stable references, re-authorization, and rejection of executable or private metadata | Keep the capability code-owned and closed |
| Dependency maintenance | Review advisories, warning deltas, non-patch upgrades, generated artifacts, and regression tests | Hold or replace the dependency when the bounded upgrade cannot pass |
| Trusted routing and movement | Prove authenticated placement, current routing version, quiescence, reconciliation, cutover, stale-envelope denial, and rollback | Fail closed and keep the source authoritative |
| Module lifecycle integration | Prove drain, cursor and replay state, mandatory work, retained ownership, reactivation, and operational visibility | Keep the module inactive until the integration is qualified |

## Historical verification boundary

The Phase 0 verification command at exit exercised the disposable lab, its generated client, repository documentation, migration and interface drift, security audits, static analysis, and synthetic databases. That suite is now an archive-only maintenance command because its purpose was to decide and de-risk the foundation, not to retest every Phase 2 change.

Current work must use the checks selected for the files and platform boundaries it changes. A historical pass supports the handover; it never substitutes for current tests at a changed boundary.

## Authoritative current records

- [Architecture index](../architecture/README.md)
- [ADR index](../adr/README.md)
- [Threat model](../security/threat-model.md)
- [Phase 2 status and evidence](../phase-2/README.md)
- [Phase 1 handover evidence](../phase-1/handover-evidence.md)

The repository history retains the retired scorecards, measurements, review record, decision register, risk register, and individual evidence narratives if an audit needs the original detail.
