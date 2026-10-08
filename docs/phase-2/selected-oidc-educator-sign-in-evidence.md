# Selected OIDC educator sign-in candidate evidence

- Status: Local protocol candidate implemented and focused checks passing; no school provider or
  connected environment is qualified
- Date: 2026-10-08
- Owner: Platform and product engineering under Project Owner authorization
- Governing decision: [ADR 0042](../adr/0042-selected-oidc-educator-sign-in-candidate.md)
- Classroom purpose: replace the synthetic session starter with one pre-linked educator sign-in
  before the existing attendance journey

## Implemented boundary

The candidate adds a disabled `GET /auth/sign-in` route to the existing Phoenix session surface.
It accepts no tenant, issuer, email, connection, role, redirect or provider choice. Exact startup
configuration names one tenant, actor, membership, external-identity link, active OIDC connection,
locale and relative classroom return path. Missing or malformed configuration returns a stable
unavailable response.

Before redirect and again before code exchange, the authoritative tenant writer rechecks the exact
membership, actor, origin tenant, active external-identity link and active OIDC connection. It
returns only the current issuer, application identifier, secret reference, assurance mapping and
configuration version. Provider claims cannot select the tenant, create a role, link by email or
grant classroom authority.

The OIDC adapter performs discovery from the configured HTTPS issuer, requires an exact metadata
issuer, HTTPS authorization/token/JWKS endpoints, S256 support, RS256 support and
`client_secret_basic`. It sends authorization code plus S256 PKCE, state, nonce, `openid` and a
ten-minute maximum authentication age. The callback checks state, PKCE, nonce, signature, issuer,
audience, expiry, authorized party where present, fresh provider authentication time and an exact
allowlisted `acr`/`amr` assurance mapping.

The PKCE verifier and nonce exist only inside the existing encrypted five-minute intent. The
runtime resolves the client secret by exact deployment-owned reference. Provider access, refresh
and ID tokens and all profile claims are discarded after a normalized external identity proof is
created. Existing application-session creation then rechecks the linked subject and current
membership before issuing the secure opaque cookie.

The classroom screen uses **Sign in with your school account** only when
`NEXT_PUBLIC_CHIMWEMWE_OIDC_SIGN_IN=true` is present at build time. This presentation flag grants
no server access. With the flag absent, the existing isolated synthetic login remains the local
qualification path.

## Focused qualification

The identity foundation suite now covers:

- disabled sign-in and rejection of caller-supplied query selection;
- exact selected educator redirect, encrypted state, secure headers and callback cookie;
- repeated writer preflight at callback before the verifier runs;
- stale membership, revoked identity link, suspended connection and mismatched link denial; and
- preservation of all previous provider-neutral callback, opaque-session, CSRF, logout,
  revocation, expiry and support-access behavior.

The OIDC adapter suite uses a local signed-token provider harness. It proves S256 challenge and
verifier continuity, nonce, exact state, `openid`, `max_age`, client-secret Basic authentication,
RS256 JWKS validation, issuer, audience, expiry, fresh `auth_time`, assurance allowlisting, token
discard, changed discovery denial, configuration-version binding and retryable provider outage.
No provider credential, real subject or school record is present in this harness.

Results recorded on 2026-10-08:

- the combined identity foundation and OIDC adapter suites passed all 27 tests;
- affected Elixir formatting, Credo, compilation and the public-session OpenAPI drift check passed;
- the flagged classroom component unit test passed, along with focused Prettier, ESLint and the
  complete web TypeScript check;
- production web builds passed both with the existing synthetic-session presentation and with
  `NEXT_PUBLIC_CHIMWEMWE_OIDC_SIGN_IN=true`; and
- `make check` passed documentation, repository tooling, formatting, compilation, OpenAPI and
  migration drift, Credo, the core dependency audit, Dialyzer and all 308 core tests. It then
  stopped at the web dependency audit, before the repository browser suites, because npm reports
  ten high-severity advisories in the existing `braces`/`micromatch` dependency chain and Next.js
  16.3.6. The available automated fixes cross the accepted Stylelint boundary or move Next.js
  outside the repository's declared version. This repository-wide run used the shared checkout,
  which also contained active unrelated calendar and local-credential work; the 308-test total is
  a current-checkout result rather than OIDC-only evidence.

The repository is therefore not green. These focused and core results qualify only this local
candidate and do not authorize deployment.

## Deployment-owned input still required

No actual identity connection can be claimed until the Project Owner supplies the institution and
selected environment and the accountable owners record:

1. exact provider issuer and client/application registration;
2. the registered `https://<selected-origin>/auth/callback` redirect;
3. the credential owner and secret-manager reference, with rotation and revocation procedure;
4. one pre-approved educator actor, current membership and pre-linked stable OIDC subject;
5. approved assurance mapping for the provider's real `acr` or `amr` values;
6. provider key rotation, outage, recovery and authorization-code replay evidence;
7. privacy, contract, subprocessor, transfer, residency, retention, incident and exit disposition;
8. selected edge/TLS, origin, cookie-key, telemetry-redaction and rate-limit controls; and
9. representative successful and denied sign-in evidence followed by an explicit connected-release
   decision.

Runtime secret resolution currently requires the configured connection's `secret_reference` to
equal `CHIMWEMWE_OIDC_SECRET_REFERENCE` and reads the secret from
`CHIMWEMWE_OIDC_CLIENT_SECRET`. These names describe the local candidate interface; an actual
deployment must bind them to its reviewed secret manager without committing the value.

## Claims deliberately withheld

This evidence does not identify or qualify Microsoft Entra, Google Workspace, another OIDC
provider, a school tenant, a real educator, a public origin or a deployment. It does not authorize
real student data, a pilot, production traffic, provider logout, directory provisioning, account
discovery, multi-provider selection, SAML processing or email/domain/group-based authority.

## References

- [ADR 0042](../adr/0042-selected-oidc-educator-sign-in-candidate.md)
- [Identity implementation evidence](identity-session-and-support-access-implementation-evidence.md)
- [Identity operating runbook](../operations/identity-session-and-support-access.md)
- [Classroom attendance workflow](classroom-attendance-workflow-evidence.md)
- [Attendance correction and recovery](attendance-correction-and-recovery-evidence.md)
- [Threat model](../security/threat-model.md)
