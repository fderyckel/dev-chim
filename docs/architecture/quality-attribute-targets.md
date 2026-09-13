# Quality-attribute targets

- Status: Proposed - business approval required before Phase 0 exit
- Owner: Platform engineering coordinates; accountable business and operations owners must be named
- Review trigger: architecture review, material scale change, or production-region decision

Final targets are not invented in code. The architecture review must replace each `OWNER_REQUIRED` and `TARGET_REQUIRED` marker with an accountable name and numeric target before running `tools/check_phase0.py --exit-review`.

| Area | SLI | Numeric target | Load and environment | Owner |
| --- | --- | --- | --- | --- |
| Interactive API reads | p95 server duration for representative authorized read | TARGET_REQUIRED | Representative tenant and dataset; target region defined | OWNER_REQUIRED |
| Interactive mutations | p95 server duration excluding explicitly asynchronous work | TARGET_REQUIRED | Named action with policy, transaction, audit, and outbox | OWNER_REQUIRED |
| User-visible web | p75 LCP and interaction latency | TARGET_REQUIRED | Target mobile device and network profile | OWNER_REQUIRED |
| Scale | tenants, users per tenant, active sessions, and concurrent requests | TARGET_REQUIRED | Launch and planning-horizon profiles | OWNER_REQUIRED |
| Report campaigns | reports/pages completed within deadline and retry budget | TARGET_REQUIRED | Defined template complexity and concurrency | OWNER_REQUIRED |
| Files | maximum upload, derivative expansion, and scan deadline | TARGET_REQUIRED | Allowed formats and malicious-file profile | OWNER_REQUIRED |
| Database recovery | RPO and RTO | TARGET_REQUIRED | Regional failure and dated restore drill | OWNER_REQUIRED |
| Object recovery | RPO and RTO | TARGET_REQUIRED | Versioned object store and metadata reconciliation | OWNER_REQUIRED |
| Availability | monthly SLO and maintenance treatment | TARGET_REQUIRED | Core action and critical dependencies | OWNER_REQUIRED |

Every accepted row must also record the measurement tool, exclusions, evidence location, and review date.

