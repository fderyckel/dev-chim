# Security policy

This repository handles no production school data during Phase 0. All examples, fixtures, evidence, logs, and screenshots must be synthetic.

## Reporting a vulnerability

Do not open a public issue with exploit details, credentials, personal information, or child data. Report privately to the accountable repository owner through the private channel configured on the future hosting platform. Until that channel exists, stop work and contact the owner directly.

## Security expectations

- Do not commit secrets or local `.env` files.
- Use least-privilege local database accounts and synthetic databases.
- Treat cross-tenant access, missing tenant context, authorization bypass, sensitive logging, unsafe file parsing, export leakage, and over-broad AI tools as release-blocking classes of defect.
- Link security decisions to the threat model and ADRs.
- Preserve evidence without including sensitive payloads.

The current threat model is [docs/security/threat-model.md](docs/security/threat-model.md).

