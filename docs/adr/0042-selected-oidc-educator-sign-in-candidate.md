# ADR 0042: Selected OIDC educator sign-in candidate

- Status: Proposed
- Date: 2026-10-08
- Owners: Security architecture, platform engineering and product engineering
- Decision scope: One disabled-by-default educator sign-in path for the existing classroom journey
- Depends on: ADR 0029, ADR 0030, ADR 0037, ADR 0038, ADR 0041
- Supersedes: None

## Context

The classroom-first workflow now reaches PostgreSQL through a synthetic session, but it has not
proved an actual OpenID Connect authorization-code exchange. ADRs 0029 and 0030 deliberately left
the provider adapter and selected-deployment qualification outside their synthetic foundation.
The Project Owner authorized the next bounded slice after the attendance-correction proof.

No institution, identity provider, issuer, client registration, educator subject, hosting region,
contract or secret has been supplied. The implementation can therefore complete the real-protocol
candidate and its local qualification harness, but it cannot claim that a real provider or school
identity is connected.

## Decision drivers

- Put one authenticated educator into the existing classroom journey without adding a school
  module or a second authorization model.
- Require authorization-code flow, S256 PKCE, state, nonce, exact issuer, audience, signature,
  expiry and authentication-time validation.
- Keep tenant, actor, membership, identity link, connection and classroom authority in
  PostgreSQL and trusted startup configuration.
- Discard provider tokens after normalized identity evidence is established.
- Fail closed when the connection, link, membership, assurance mapping, secret reference,
  provider metadata or selected deployment is stale or missing.
- Keep all provider-specific claims from creating roles, capabilities or school relationships.

## Considered options

1. Let the provider choose tenant or actor from email, domain or groups. Rejected because provider
   claims are not Chimwemwe authority and ambiguous matches cannot fail safely.
2. Add a broad multi-provider login picker. Rejected because no provider has been selected and it
   widens the public and support surface before one connection works end to end.
3. Add one startup-selected, pre-linked OIDC educator path using the provider-neutral connection
   record and existing public session boundary: selected.
4. Call the existing synthetic callback a real connection. Rejected because it does not perform
   discovery, code exchange, PKCE, nonce or signed ID-token validation.

## Decision

Add one optional `GET /auth/sign-in` route. It has no tenant, connection, email, issuer, redirect,
role or provider input. When the route is disabled or its trusted startup target is incomplete, it
returns a stable unavailable response. When enabled, trusted startup configuration supplies one
pre-approved actor, tenant, membership, external-identity link, active connection, locale and
relative classroom return path.

Before redirecting, the authoritative writer rechecks that the membership belongs to the actor,
the external-identity link is active, and its OIDC connection is active. It returns only the
connection's exact issuer, application identifier, secret reference, assurance mapping and
configuration version. Provider discovery and secret resolution must agree with those values.

The provider adapter generates a nonce and PKCE verifier, puts only their encrypted short-lived
state inside the existing five-minute sign-in intent, and sends the S256 challenge to the selected
provider. The callback repeats the current writer preflight, pins the connection configuration
version, exchanges the code with the verifier, validates the signed ID token and maps one exact
provider assurance value through the connection's allowlist. Raw access, refresh and ID tokens,
email, name, domain, groups and roles are discarded.

The normalized result contains only connection ID, OIDC issuer, stable subject, mapped assurance
and provider authentication time. Existing session creation then rechecks the exact link subject,
membership, actor, tenant and active connection before it commits an opaque application session.
Classroom actions continue to revalidate that session and current teaching authority.

The candidate supports only HTTPS issuers, RS256 ID tokens, `client_secret_basic`, `openid` scope,
S256 PKCE and a provider authentication time no older than ten minutes. A different algorithm,
client authentication method, SAML path, directory sync, account discovery, multi-tenant picker or
provider-initiated login requires another decision.

The browser may show **Sign in with your school account** only when its build-time experience flag
is enabled. That flag controls presentation only. The server route, selected connection, active
link, current membership and writer authorization remain authoritative.

## Plain-English summary

The app can perform a real OIDC protocol flow for one educator whose school account was linked in
advance. The identity provider proves who signed in; it cannot decide which school, role, class or
permission that person receives.

## Consequences

### Positive

- The existing classroom journey gains one real OIDC protocol path without introducing tenant or
  role discovery from provider claims.
- The authoritative writer checks the selected membership, link and connection both before the
  provider redirect and before code exchange.
- PKCE, nonce, configuration version and callback destination stay bound inside the encrypted
  five-minute intent.
- Provider tokens and profile claims do not enter the application session or school records.

### Negative

- One pre-linked educator and one startup-selected connection do not provide general account
  onboarding or multi-institution sign-in.
- Provider logout, directory provisioning and identity-link recovery remain separate work.
- A selected provider, registration, credential, environment and representative qualification are
  still required before connected use.
- The environment-backed secret resolver is only a candidate interface until a deployment-owned
  secret manager and rotation procedure are reviewed.

## Security, privacy, operability, and migration effects

Secrets are resolved at runtime from a deployment-owned resolver by exact secret reference and are
never returned, logged or committed. Callback code/state, tokens, assertions and secrets remain
filtered. Discovery and token endpoints must be HTTPS, discovery must report the exact configured
issuer, S256 and RS256 must be advertised, and uncertain metadata or network results fail closed.

The adapter does not store provider tokens. Application sessions retain only the established
issuer, subject-derived link, mapped assurance and authentication time already required by the
existing session contract. Provider logout, global single logout and directory deprovisioning are
not inferred; application logout and session revocation remain authoritative locally.

No migration is added. The candidate reads the existing membership, identity-link and connection
tables and reuses the existing encrypted intent and application-session records. Removing the
route and adapter leaves those records intact.

## Validation evidence required

Prove sign-in is disabled without exact trusted configuration; active target preflight; S256,
state and nonce emission; exact issuer and connection-version binding; signed token, audience,
expiry and authentication-time checks; assurance allowlisting; replay rejection; stale link,
membership and connection denial; secret and token redaction; provider outage; changed discovery
metadata; secure cookie creation; classroom entry using the resulting session; exact OpenAPI and
generated-client drift; focused and repository checks.

Actual provider qualification must additionally record the issuer and application registration,
exact redirect, credential owner, secret rotation, key rotation, outage and recovery exercise,
contract/privacy/subprocessor/residency review, incident owner, exit procedure and representative
sign-in evidence. None of those facts may be invented by the local harness.

## Fallback and exit cost

The route and browser control remain disabled. Failure never falls back to the synthetic fixture,
email matching, a local password, cached provider proof, another issuer or support access. Removing
the adapter preserves actors, memberships, links, classroom records and application-session audit
history.

## Review triggers

Actual provider selection; another issuer or client; SAML, LDAP, SCIM or provider API; multi-login
selection; dynamic tenant discovery; provider-initiated login; different algorithms or client
authentication; token retention; directory claims; real identity data; deployment or pilot.

## Related records

- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [Attendance correction evidence](../phase-2/attendance-correction-and-recovery-evidence.md)
- [Identity implementation evidence](../phase-2/identity-session-and-support-access-implementation-evidence.md)
- [Identity operating runbook](../operations/identity-session-and-support-access.md)
- [Threat model](../security/threat-model.md)
