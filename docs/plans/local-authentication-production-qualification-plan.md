# Local authentication production qualification plan

- Status: Recorded future-development plan; implementation and release remain separately gated
- Date: 2026-10-08
- Accountable direction: François — Project Owner and interim Security/Privacy Owner
- Governing decision: [ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md)
- Current evidence: [Local credential administration evidence](../phase-2/local-credential-administration-evidence.md)

## Purpose

The initial authentication direction is administrator-provisioned local credentials. An authorized
administrator selects an existing staff record, enters an email sign-in name, and receives a
system-generated temporary password that the staff member must replace at first login. OIDC remains
an optional independent path; it is not a prerequisite for this initial direction.

The current implementation proves that lifecycle only in a database-backed loopback environment
with synthetic staff. This plan records the additional work and evidence required before a real
staff identity, connected deployment, pilot, or production claim. Recording the work does not close
any gate or authorize real data.

## What is already proven

- normalized, independently unique email and staff-actor identifiers;
- cryptographically random temporary passwords shown once, with hash-only database storage;
- 24-hour temporary-password expiry and a restricted ten-minute first-login state;
- mandatory replacement with a 15–128 character permanent passphrase;
- generic denial, five-attempt lockout, named reissue and suspension actions; and
- token revocation on permanent activation, reissue, and suspension.

These are engineering properties, not production qualification.

## Ordered future slices

| Order | Slice | Required outcome | Exit evidence |
| --- | --- | --- | --- |
| LA-1 | Real staff and authority boundary | Replace prepared staff IDs with an exact, tenant-owned staff-account association. Only a current administrator with a dedicated account-administration capability may create, reissue, suspend, or inspect account status. Email never grants authority. | Positive and negative tenant/capability tests; stale, ended, cross-tenant, duplicate-email, duplicate-actor, and missing-context denials; audit and transactional-outbox evidence. |
| LA-2 | Privileged administrator protection | Select and implement administrator MFA or step-up, least-privilege delegation, a controlled first-administrator ceremony, lost-administrator recovery, and emergency suspension. | MFA/step-up tests, two-person or equivalent recovery disposition, bootstrap rehearsal, revocation drill, and named operational owner. |
| LA-3 | Qualified HTTPS and session edge | Run only on a selected HTTPS origin with secure host-only cookies, origin and CSRF enforcement, bounded idle and absolute session lifetime, logout and global revocation, safe headers, and no sensitive caching. | Deployment-specific browser and proxy tests; cookie/header evidence; cross-origin, CSRF, replay, expired-session, and revoked-session denial tests. |
| LA-4 | Temporary-password delivery and recovery | Select a private delivery channel and identity-verification procedure. Operators may reissue but can never recover an existing plaintext password. Public registration and public email reset remain disabled unless separately decided. | Delivery threat review, one-time-display and back/refresh checks, support script, failed-delivery procedure, recovery rehearsal, retention decision, and incident owner. |
| LA-5 | Guessing resistance and security operations | Add deployment-edge rate limits in addition to account lockout, safe security events, monitoring, alerting, abuse response, hash-cost measurement, and future hash-upgrade handling. | Load and lockout measurements, rate-limit tests, redacted event samples, alert exercise, hardware hash benchmark, and incident runbook. |
| LA-6 | Human qualification and release | Review creation, temporary delivery, first login, failure, reissue, suspension, and recovery with representative administrators and staff. Complete accessibility, security, privacy, and operational reviews and make an explicit release decision. | Recorded findings and repairs, keyboard/screen-reader checks, independent security/privacy disposition, data-protection/retention disposition, support acceptance, and signed go/no-go record. |

LA-1 is the next implementation slice when future work is authorized. LA-2 through LA-5 may be
prepared in parallel only after their deployment-specific inputs exist. LA-6 evaluates the complete
candidate and cannot be replaced by automated tests.

## Inputs that must be supplied before connected qualification

The production-qualification work needs these exact decisions and owners:

1. The institution and deployment environment, including the intended HTTPS hostname.
2. The authoritative staff record and staff-account association that the administrator will select.
3. The tenant capability and accountable role allowed to administer credentials.
4. The administrator MFA or step-up method and the first-administrator/recovery owners.
5. The approved temporary-password delivery channel and staff identity-verification procedure.
6. The support, incident, monitoring, privacy, and retention owners.
7. Named representative administrator and staff reviewers for the complete workflow.

Until those are supplied, development may use fictional records only and must remain disabled
outside a loopback or explicitly isolated synthetic environment.

## Non-negotiable controls

- Every account action requires authenticated actor, tenant, current membership, module state, and
  dedicated capability at the domain boundary. Missing or stale context fails closed.
- A staff affiliation, email address, successful password check, or prepared UI choice never creates
  tenant membership, role, teaching assignment, class access, or another permission.
- Passwords, hashes, cookies, tokens, and recovery material never enter committed fixtures, logs,
  prompts, tickets, screenshots, exports, analytics, or audit payloads.
- Reissue and suspension revoke current sessions. Suspension preserves institutional, staff, class,
  attendance, and audit history.
- PostgreSQL remains authoritative. Rate-limit caches and security projections are disposable and
  must not become identity or authorization authorities.
- A failed OIDC attempt never silently falls back to a local-password session. The user deliberately
  chooses an enabled sign-in path.
- Synthetic bootstrap accounts and local demonstration databases are never migrated into a real
  deployment.

## Explicitly deferred

This plan does not authorize learner or guardian accounts, public self-registration, public password
reset, magic links, passkeys, security questions, bulk imports, directory synchronization, shared
default passwords, automatic account creation from email, or production use of the local harness.
Each changes the risk or authority boundary and requires its own decision and evidence.

## Production release decision

Production is permitted only after every applicable LA-1 through LA-6 exit item has inspectable
evidence, unresolved findings have an accountable disposition, required repository and deployment
checks pass, and the Project Owner records an explicit production release. Passing the current
local tests or completing one future slice cannot imply that decision.
