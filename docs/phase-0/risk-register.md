# Phase 0 risk register

- Status: Active
- Owner: Architecture review group

| ID | Risk | Severity | Control | Gate | Owner |
| --- | --- | --- | --- | --- | --- |
| R-01 | Ash becomes irreversible before it is proven | High | Pre-registered pressure-test; explicit fallback | ADR 0002 review | Platform engineering |
| R-02 | Phase 0 expands into production platform work | High | Enforced scope and forbidden production folders | `make check` and review | Architecture review group |
| R-03 | Authorization hard-codes school job titles | Critical | [Tenant-defined role/capability graph, administration, cycle, and policy-matrix tests](evidence/ash-pressure-test.md#authorization-graph-integrity-and-policy-matrix-slice) | ADR 0003 review | Security architecture |
| R-04 | Documentation says more than tests prove | High | Separate Proposed decisions from evidence; link exact commands/results | Evidence review | Architecture review group |
| R-05 | Developer machines drift | High | Brewfile, mise pins, uv/Mix locks, bootstrap and check commands | Clean-machine rehearsal | Platform engineering |
| R-06 | Quality targets are guessed or remain vague | High | Numeric owner-approved targets with load/environment | Target approval | Product and operations owners |
| R-07 | Local tests use real school data | Critical | Synthetic-only rule and fixture review | Security review | All contributors |
| R-08 | Student count or average volume hides synchronized domain bursts | High | Per-domain burst, amplification, mixed-load, and retained-footprint model | Tenant-placement capacity approval | Platform engineering and operations |
| R-09 | Trusted placement routing sends a tenant to the wrong database, queue, or storage namespace | Critical | Authenticated versioned registry, placement membership constraints, no default fallback, [cross-placement tests](evidence/trusted-routing.md), movement rehearsal | ADR 0003 and threat-model review | Security architecture |
| R-10 | A pooled tenant exhausts shared connections or resources | High | Per-tenant fairness, pool and saturation targets, noisy-neighbour test, dedicated-placement escape path | Capacity acceptance | Platform engineering and operations |
| R-11 | Module activation is treated as authorization or deactivation loses data/work | Critical | Independent server-side gates, declared dependencies, controlled drain, and [retained-data and replay tests](evidence/module-lifecycle.md) | ADR 0001 review | Platform engineering and security architecture |
| R-12 | A stale read replica supplies authorization, placement, module-gate, or read-your-write state | Critical | Central consistency classification, writer-only security decisions, lag gates, fail-closed routing, and stale-read negative tests | ADR 0017 and threat-model review | Platform engineering and security architecture |
| R-13 | HA standby, read replica, backup, and cross-region recovery are treated as interchangeable | High | Separate RPO/RTO and responsibility contracts, failover and restore drills, and explicit promotion/failback runbooks | ADR 0017 review | Platform engineering and operations |
| R-14 | Application, reader, Oban, and placement pools multiply beyond PostgreSQL capacity | High | Per-placement connection formula, failover reserve, checkout-wait targets, backpressure, and evidence-triggered pooling | Capacity acceptance | Platform engineering and operations |
| R-15 | Generated interface behaviour or documentation diverges from the public contract | High | Thin edge enforcement, supported OpenAPI modification, checked-in contract drift detection, and transport-level negative tests | ADR 0014 review | Platform and web engineering |
