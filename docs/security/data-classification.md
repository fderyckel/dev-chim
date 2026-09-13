# Data classification

- Status: Proposed
- Owner: Security and privacy owners
- Review trigger: privacy review, new data category, or new external processor

| Class | Examples | Default controls |
| --- | --- | --- |
| Public | Approved public-site content | May use public CDN after publication; integrity and versioning still apply |
| Internal | Synthetic operational metadata and non-sensitive internal guidance | Authenticated access; ordinary audit and retention |
| Confidential | Personal contact, employment, or school operational records | Need-to-know access; tenant isolation; encrypted storage and transport; no public/shared cache |
| Restricted | Child records, safeguarding, health, credentials, secrets, sensitive evidence, privileged exports | Explicit purpose and relationship policy; enhanced audit; minimization; no shared cache or generic AI; strict export and support controls |

Classification travels with records, events, jobs, files, projections, exports, telemetry, and AI tools. A derivative cannot silently receive a lower classification than its source. Unknown data defaults to Restricted until classified by an accountable owner.

Production data is never copied to development or generic AI evaluation. Phase 0 uses synthetic records only.

