# ADR 0030: Same-origin public session and named-action boundary

- Status: Accepted
- Date: 2026-09-27
- Decision date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Platform and web engineering with product experience and security architecture
- Deciders: Project owner, platform engineering, web engineering, product experience, and security
  architecture
- Conditions: acceptance authorizes a synthetic production-candidate boundary only; no real
  identity provider, public deployment, Restricted data, representative-user acceptance, or L3
  claim exists until its separately named gates pass
- Supersedes: the production-use interpretation of
  [ADR 0022](0022-local-read-only-browser-core-bridge.md); UI-1A remains a removable local
  qualification harness

## Context

ADRs 0014 and 0020 select a checked named-action contract and an intentional Next.js browser
experience. ADR 0022 proves only a loopback bearer-token bridge over synthetic data. Accepted
ADR 0029 supplies the provider-neutral identity, external-link, application-session, tenant, and
support rules, but deliberately leaves the first public callback and browser-session boundary to a
separate decision.

The first connected workflow needs one exact boundary before its adapter can be implemented and
tested. Promoting UI-1A would expose a long-lived bearer token to server configuration, omit a
public callback and logout contract, and provide no browser-cookie, origin, CSRF, or current-session
semantics. Letting Next.js establish actor or tenant context would create a second security
authority. A provider-specific browser path would also contradict ADR 0029.

## Decision drivers

- One provider-neutral server callback and session contract.
- A browser that never receives provider tokens, placement coordinates, capabilities, or a reusable
  API bearer token.
- Current writer-side membership, session, placement, module, capability, field, and support-grant
  decisions on every named action.
- Same-origin browser semantics that make cookie, CSRF, redirect, CSP, caching, and error controls
  explicit.
- Checked OpenAPI and generated TypeScript artifacts without exposing generic CRUD.
- A removable local qualification harness and a reversible Phoenix interface adapter.

## Considered options

1. Promote the UI-1A bearer-token bridge. Rejected because it is local, read-only, synthetic, and
   intentionally lacks production browser-session controls.
2. Let Next.js own authentication, tenant selection, authorization, and direct database access.
   Rejected because it would create a second policy and placement authority.
3. Expose provider tokens to the browser and call Phoenix with them. Rejected because provider
   evidence is not an application session or Chimwemwe authority.
4. Use one same-origin public surface: Next.js owns the experience while Phoenix owns callback,
   opaque application-session, current-context establishment, and named-action APIs. Selected.

## Decision

The production candidate uses one public HTTPS origin. The edge routes browser experience paths to
Next.js and routes `/auth/*` and `/api/v1/*` to a Phoenix public endpoint. These are deployment
routes, not separate trust domains. Next.js never receives a database credential, resolves tenant
placement, or becomes a policy engine. It consumes the checked same-origin API through the generated
TypeScript client.

### Callback and session establishment

A callback accepts only the exact fields required by a qualified connection adapter. For OIDC that
means authorization-code flow with S256 PKCE, exact state, a session-bound nonce, exact redirect,
and verified issuer, audience, signature, expiry, and assurance evidence. SAML remains behind the
qualified gateway path from ADR 0029. The common callback receives only a
`VerifiedExternalIdentity`; it contains no provider role, group, email-match rule, tenant claim, or
placement coordinate.

The callback resumes a short-lived encrypted and signed server-issued sign-in intent. That intent
may carry only the pre-approved connection, actor, membership, locale, correlation, idempotency,
and return-path references required for the exact sign-in. Browser parameters cannot add or replace
those values. The writer rechecks the exact active connection, external-identity link, actor, and
current membership before it creates an application session. Callback replay, changed intent,
connection mismatch, stale assurance, invalid redirect, and unavailable current route fail closed.

The browser receives one `__Host-chimwemwe-session` cookie. It is `Secure`, `HttpOnly`,
`SameSite=Lax`, host-only, scoped to `/`, and never available to client JavaScript. Its value is an
encrypted, authenticated, versioned envelope containing the minimum locator values and opaque
application-session secret needed to reach the authoritative session row. To the browser it is an
opaque bearer. The envelope is not authority by itself: its tenant and actor candidates are
accepted only after server key validation, current startup-owned placement resolution, exact token
digest lookup, current membership recheck, idle and absolute expiry, and actor/tenant/session
comparison on the authoritative writer.

Signing/encryption keys are deployment secrets with an active key and a bounded previous-key
window. New cookies always use the active key. Removing a previous key immediately invalidates
envelopes that depend on it. Application-session logout, rotation, revocation, membership removal,
connection suspension, and expiry remain independently authoritative even while an envelope can be
decrypted.

### Request and action contract

Every authenticated request establishes actor, tenant, assurance, current placement, purpose,
locale, and correlation context before a domain read or action runs. Purpose is selected from the
server-owned route contract; the request may propose an allowlisted locale but cannot supply a
purpose, tenant, repository, placement, capability, module state, or field policy.

The public interface is a thin Phoenix REST/OpenAPI adapter over exact reads and named actions when
the generated Ash JSON:API boundary cannot preserve the contract. It exposes no generic create,
update, delete, filter, sort, or recursive traversal. Each write declares exact input fields,
idempotency, optimistic version, stable success and error shapes, and no automatic client retry.
Each read is exact or task-bounded. Any collection remains closed until its ADR 0023 candidate
review proves enforced limits, cumulative-exposure controls, and separate export denial.

All responses are `no-store`. Stable public errors disclose no cross-tenant existence, provider
assertion, session secret, placement, policy reason, or database detail. Retry guidance is present
only for classified retryable failures. Redirects are relative allowlisted paths; arbitrary return
URLs are invalid.

Cookie-authenticated unsafe methods require same-origin validation and a server-issued CSRF token
bound to the authenticated session. JSON content type, bounded request size, CSP, frame, MIME,
referrer, permissions, TLS, and rate controls are owned by the public endpoint and selected edge.
Logout invalidates the authoritative application session before clearing the cookie. A cleared
cookie without writer invalidation is not logout.

### Visible support mode

Support elevation remains non-impersonating. A public session may carry one encrypted exact grant
reference only after writer-side activation bound it to the same real support actor and application
session. Every elevated named action rechecks the grant and records its use. Every response and
experience in elevated mode exposes a safe banner model containing the real support actor reference,
target tenant label supplied by an authorized presentation read, purpose, expiry, and bounded scope.
Expiry, revocation, session change, wrong purpose, or missing capability ends elevation immediately.

## Consequences

### Positive

- Identity providers remain behind one qualified adapter contract.
- Browser code cannot obtain provider credentials, application bearer tokens, or placement data.
- Next.js can deliver an intentional experience while Phoenix remains the trusted session and
  named-action boundary.
- The opaque cookie can locate pooled or isolated tenant state without making its decoded candidate
  authoritative.
- Exact reads avoid creating an accidental sensitive-data enumeration surface for the first
  workflow.

### Negative

- The public endpoint needs explicit cookie-envelope key rotation, origin/CSRF, callback replay,
  redirect, failure-header, and rate-limit ownership.
- The same-origin edge must route two runtimes consistently and preserve secure-cookie semantics.
- A server-issued sign-in intent is required before callback completion; arbitrary provider-first
  login and email auto-linking remain unsupported.
- Selected-deployment TLS, secrets, edge behavior, observability, backup, restore, and rollback
  still require separate qualification.

## Security, privacy, operability, and migration effects

No raw callback code, provider token, assertion, PKCE verifier, nonce, application-session secret,
cookie value, CSRF secret, private key, child data, or detailed denial reason enters logs, telemetry,
fixtures, audit, outbox, or committed evidence. Callback and session telemetry uses safe correlation,
connection, outcome-class, and latency values only.

The local UI-1A token registry remains separately guarded and impossible to enable in the production
profile. The production candidate uses different routes, configuration, cookie, OpenAPI, generated
client, and startup checks. Removing UI-1A does not change the public contract.

The selected deployment must prove proxy/header trust, TLS termination, host validation, secret
injection and rotation, denial and callback rate limits, cache behavior, database reachability,
backup/restore, incident response, and rollback before L3. This ADR does not select a host, region,
identity provider, or edge product.

## Validation evidence

Slice 2.0-D.3 must prove encrypted-envelope tamper and expiry rejection, active/previous key
rotation, callback replay and connection mismatch, forged actor/tenant/member values, current route
resolution, stale membership, idle/absolute expiry, rotation, logout, exact and actor revocation,
origin and CSRF denial, redirect allowlisting, no-store and stable-error headers, support visibility
and per-use recheck, redaction, and failure recovery.

Slice 2.0-E must check in the public OpenAPI document and generated TypeScript client, fail drift,
and prove the selected named workflow through browser tests including keyboard, screen-reader,
visible-focus, error recovery, narrow reflow, degraded network, conflict, expiry, revocation, and
inactive-module states. Exact reads need no pagination; any later collection must independently pass
ADR 0023.

Acceptance of this ADR closes the Phase 2.0-A public-boundary decision and authorizes bounded D.3
synthetic engineering. It does not satisfy D.3 or E implementation evidence by itself.

## Fallback and exit cost

If the same-origin Phoenix adapter cannot preserve this contract, keep the route closed and retain
UI-1A only for local qualification while the boundary is superseded. If Ash-generated JSON:API
cannot express an exact action safely, use the accepted thin Phoenix REST/OpenAPI fallback. If
Next.js is replaced, preserve the same public contract and server authority.

## Review triggers

- a public origin, edge, hosting topology, session store, cookie shape, or key-rotation change;
- direct browser access to a provider or core bearer token;
- provider-first discovery, email/domain auto-linking, or a request-selected identity connection;
- cross-site embedding, native-client authentication, offline writes, or cross-origin APIs;
- a public collection, recursive traversal, bulk export, or caller-defined filter/sort;
- support impersonation, background support work, or a support scope expansion; or
- inability to preserve current writer-side session, membership, placement, module, capability, or
  field-policy checks.

## Related records

- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0022](0022-local-read-only-browser-core-bridge.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [Identity/session/support implementation evidence](../phase-2/identity-session-and-support-access-implementation-evidence.md)
- [Threat model](../security/threat-model.md)
