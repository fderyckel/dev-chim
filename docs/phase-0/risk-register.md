# Phase 0 risk register

- Status: Active
- Owner: Architecture review group

| ID | Risk | Severity | Control | Gate | Owner |
| --- | --- | --- | --- | --- | --- |
| R-01 | Ash becomes irreversible before it is proven | High | Pre-registered pressure-test; explicit fallback | ADR 0002 review | Platform engineering |
| R-02 | Phase 0 expands into production platform work | High | Enforced scope and forbidden production folders | `make check` and review | Architecture review group |
| R-03 | Authorization hard-codes school job titles | Critical | Tenant-defined role/capability model and tests | ADR 0003 review | Security architecture |
| R-04 | Documentation says more than tests prove | High | Separate Proposed decisions from evidence; link exact commands/results | Evidence review | Architecture review group |
| R-05 | Developer machines drift | High | Brewfile, mise pins, uv/Mix locks, bootstrap and check commands | Clean-machine rehearsal | Platform engineering |
| R-06 | Quality targets are guessed or remain vague | High | Numeric owner-approved targets with load/environment | Target approval | Product and operations owners |
| R-07 | Local tests use real school data | Critical | Synthetic-only rule and fixture review | Security review | All contributors |
| R-08 | Student count or average volume hides synchronized domain bursts | High | Per-domain burst, amplification, mixed-load, and retained-footprint model | Tenant-placement capacity approval | Platform engineering and operations |
| R-09 | Trusted placement routing sends a tenant to the wrong database, queue, or storage namespace | Critical | Authenticated versioned registry, placement membership constraints, no default fallback, cross-placement tests, movement rehearsal | ADR 0003 and threat-model review | Security architecture |
| R-10 | A pooled tenant exhausts shared connections or resources | High | Per-tenant fairness, pool and saturation targets, noisy-neighbour test, dedicated-placement escape path | Capacity acceptance | Platform engineering and operations |
| R-11 | Module activation is treated as authorization or deactivation loses data/work | Critical | Independent server-side gates, declared dependencies, controlled drain, retained-data and replay tests | ADR 0001 review | Platform engineering and security architecture |
