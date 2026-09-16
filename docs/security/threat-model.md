# Phase 0 threat model

- Status: Proposed
- Owner: Security architecture
- Review trigger: architecture review or any new trust boundary/data class

## Assets

- tenant identity, actor identity, sessions, credentials, and service accounts;
- tenant-defined roles, capabilities, relationships, and support grants;
- child, safeguarding, education, employment, and operational records;
- uploaded files, derivatives, reports, exports, evidence, and audit history;
- resource descriptors, view and report definitions, and tenant-owned experience metadata;
- outbox events, jobs, projections, search documents, caches, and telemetry; and
- AI prompts, retrieved context, tool inputs/results, and provider traces.

See [data classification](data-classification.md).

## Trust boundaries

1. Browser or integration to Next.js/Phoenix edge.
2. Phoenix/Ash action and consistency-routing boundary to the PostgreSQL writer, HA standby, optional read replicas, recovery plane, and Oban.
3. Core metadata to object storage, ClamAV, Tika, Gotenberg, and external drives.
4. Core state to caches, search, realtime, read models, and analytics publications.
5. Core scheduling contract to the solver runtime.
6. Core authorized tools to the AI gateway and external model provider.
7. Platform support tooling to a selected tenant.
8. Authenticated tenant context to the placement registry and database, queue, storage, cache, search, analytics, and telemetry routing.
9. Module release, entitlement, activation, dependency, and authorization gates to every interface and asynchronous consumer.
10. Code-defined Ash resources to derived descriptors and tenant-owned view or report metadata.

Every boundary authenticates the caller or service, propagates tenant and correlation context, minimizes data, and records safe evidence. No projection, cache, solver, renderer, provider, or interface grants authority independently.

## High and critical threats

| ID | Threat | Severity | Primary treatment | Verification | Owner |
| --- | --- | --- | --- | --- | --- |
| TM-01 | Cross-tenant read, mutation, inference, or subscription | Critical | Mandatory tenant context, compound constraints, Ash policies, optional RLS backstop | [Direct and generated-interface cross-tenant, existence-shape, and missing-context tests](../phase-0/evidence/ash-pressure-test.md#generated-jsonapi-policy-slice), plus [bounded non-HTTP routing and Ash re-authorization tests](../phase-0/evidence/trusted-routing.md#tenant-movement-and-non-http-interface-slice); real adapter suites remain later | Security architecture |
| TM-02 | Authorization escalation through relationship or role composition | Critical | Tenant-defined capability graph, cycle/privilege validation, policy matrix | [Renamed/composed-role, field/relationship policy, and direct/indirect/concurrent cycle tests](../phase-0/evidence/ash-pressure-test.md#authorization-graph-integrity-and-policy-matrix-slice) | Security architecture |
| TM-03 | Unbounded or unattributable support access | Critical | Explicit tenant, strong assurance, purpose, expiry, least privilege, enhanced audit | Support-access negative suite in Phase 2 | Security architecture |
| TM-04 | Restricted data cached or served after revocation | Critical | Classification policy, tenant/version keys, durable invalidation, bypass | Adversarial cache suite in Phase 5 | Platform engineering |
| TM-05 | Malicious upload or parser/render exploit | High | Quarantine, type validation, scanning, isolation, patching, resource/network limits | Malicious-file corpus in Phase 6 | Security engineering |
| TM-06 | Over-broad or replayable export | High | Read-equivalent policy, step-up, bounded manifest, expiry, audit | Unauthorized export suite in Phase 10 | Platform engineering |
| TM-07 | Search, realtime, or read-model authorization drift | Critical | Tenant-filter before retrieval, re-authorization on access, rebuild/deletion controls | Restricted-result and stale-access tests | Platform engineering |
| TM-08 | AI prompt injection, cross-tenant retrieval, or unverified write | Critical | Provider-neutral gateway, curated tools, real actor/tenant, minimization, confirmation, kill switch | Adversarial AI evaluation in Phase 11 | Security architecture |
| TM-09 | Sensitive logs, traces, events, or evidence | High | Minimal payloads, classification, source redaction, safe identifiers | [Captured correlated telemetry allowlist and redaction assertions](../phase-0/evidence/ash-pressure-test.md#telemetry-and-redaction-slice); third-party logger review remains | Platform engineering |
| TM-10 | State commits without durable side-effect fact, or event without state | High | Transactional outbox and rollback | [Injected Ash transaction-failure test](../phase-0/evidence/ash-pressure-test.md#transactional-outbox-slice) | Platform engineering |
| TM-11 | Forged, stale, or conflicting placement routes a tenant to another database, queue, or storage namespace | Critical | Authenticated versioned registry, placement membership constraint, least-privilege credentials, no default fallback | [Pooled/dedicated, non-HTTP, movement, reconciliation, version-conflict, rollback, and stale-route tests](../phase-0/evidence/trusted-routing.md); durable control-plane and real-adapter drills remain | Security architecture |
| TM-12 | A synchronized write burst or noisy pooled tenant denies service or delays authorization, outbox, and recovery work | High | Per-tenant fairness, bounded bulk actions, pool budgets, backpressure, mixed-load targets, dedicated-placement escape path | Period-start burst, report-overlap, pool-exhaustion, backup, and restore tests | Platform engineering and operations |
| TM-13 | Module activation bypasses authorization, or deactivation loses data, audit, jobs, events, or compliance access | Critical | Independent server-side gates, explicit dependencies, controlled drain, retained-data ownership, replay/reconciliation | [Gate matrix, concurrent deactivation, drain, retained-data, and reactivation tests](../phase-0/evidence/module-lifecycle.md); accountable review remains | Platform engineering and security architecture |
| TM-14 | A stale or misrouted replica supplies revoked authorization, old placement/module state, or a contradictory read-after-write result | Critical | Central consistency classes, writer-only security decisions, lag gates, read-only credentials, and no request-selected repository | Replica-lag/outage, revocation, immediate-confirmation, and cross-placement negative tests | Platform engineering and security architecture |
| TM-15 | A replayed or mutated idempotency key duplicates a transition, suppresses another actor's action, crosses tenant boundaries, or separates state from its durable event | High | Tenant-and-action uniqueness, actor/aggregate/canonical-request binding, writer transaction, exact-result replay, stable conflict, and bounded retention policy | [Exact, conflicting, cross-tenant, concurrent, rollback, and alternate-write tests](../phase-0/evidence/ash-pressure-test.md#idempotency-and-generated-typescript-client-slice); retention and abuse limits remain | Platform engineering and security architecture |
| TM-16 | Malicious, cross-tenant, stale, or incompatible experience metadata exposes a forbidden field or action, broadens a report, or bypasses a domain rule | Critical | Code-defined authority, allowlisted versioned descriptors, tenant-qualified definitions, no arbitrary SQL or code, fail-closed validation, and re-authorization at execution | [Scenario 15 private-field, unapproved-action, arbitrary-SQL/code, authority, stale-version, missing-context, cross-tenant, filtered-execution, and denied-actor tests](../phase-0/evidence/resource-authoring-and-governed-metadata.md); accountable security review remains pending | Platform engineering and security architecture |

## Assumptions and scope limits

- Phase 0 contains synthetic data and a local spike only.
- Identity-provider, file, report, analytics, AI, and scheduler implementations are not present yet; their controls are architectural requirements, not completed evidence.
- Application policy is the proposed authorization layer. RLS remains an evidence-driven backstop decision.
- The five-school topology and attendance calculations are planning hypotheses, not accepted production sizing or placement evidence.
- The placement registry and module lifecycle are Phase 0 contracts only; production implementations are outside this phase.
- The local developer account and device security remain outside repository enforcement, but secrets and production data are prohibited.

## Residual-risk process

High or critical residual risk needs a named accountable acceptor, expiry, mitigation owner, and review date in the Phase 0 review record. A planned later-phase test does not mean the threat is already mitigated.

## Related records

- [Abuse cases](abuse-cases.md)
- [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md)
- [ADR 0009](../adr/0009-cache-taxonomy-invalidation-and-valkey-trigger.md)
- [ADR 0010](../adr/0010-file-ownership-storage-pipeline-and-external-drives.md)
- [ADR 0015](../adr/0015-ai-gateway-tool-exposure-and-evaluation-policy.md)
- [ADR 0017](../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- [Tenant placement and workload capacity](../architecture/tenant-placement-and-capacity.md)
- [PostgreSQL availability, recovery, and read routing](../architecture/postgresql-availability-recovery-and-read-routing.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Domain model authoring and metadata](../architecture/domain-model-authoring-and-metadata.md)
