# Identity, session, and support-access implementation evidence

- Status: Slices 2.0-D.2a through D.2c complete at L0; the bounded D.3 public-session adapter is
  implemented with synthetic evidence behind the still-closed L2 release gate
- Date: 2026-09-27
- Governing decision: [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- Accountable owner: Security architecture and platform engineering
- Release effect: production-candidate routes and a checked session contract now exist in code but
  no endpoint starts by default; no real provider/directory connection, provider credential, real
  identity data, deployed support experience, or L2 release claim exists

## Implemented boundary

The internal identity foundation now separates five closed records:

1. tenant-owned provider-neutral identity connections with `oidc` or `saml` protocol, exact
   issuer/entity ID, application identifier, deployment-secret reference, assurance mapping,
   configuration version, optimistic version, and draft/qualified/active/suspended/retired
   lifecycle;
2. global protocol-qualified external identity links keyed only by protocol, issuer/entity ID, and
   stable subject/NameID;
3. tenant-owned invitations containing only a SHA-256 token digest and naming one pre-approved
   actor, current membership, current assigned role, and active connection for at most 30 minutes;
4. tenant-owned application sessions containing only a SHA-256 opaque-token digest, current actor
   and membership, bounded assurance, 30-minute idle expiry, 12-hour absolute expiry, rotation,
   logout, exact revocation, and actor-wide revocation state; and
5. tenant-owned support grants containing the real support actor, independent grantor, purpose,
   ticket reference, code-owned capability allowlist, strong assurance requirement, bound current
   application session, expiry of at most 60 minutes, lifecycle version, and start/use/end or
   revocation evidence.

Every production-candidate resource exposes no direct Ash action. Named internal boundaries own
strict input allowlists, trusted execution context, writer routing, current authorization or
membership recheck, advisory serialization, exact idempotency, optimistic state, transaction,
audit, outbox, stable redacted errors, and rollback. The implementation stores no raw invitation
or session token, provider token/assertion, client secret, directory credential, provider group,
provider role, email-match rule, repository selector, or placement coordinate.

## Slice 2.0-D.2a evidence

The connection lifecycle requires the tenant capability `identity.connections.manage`; invitation
issue requires `identity.invitations.issue`. Qualification and activation are distinct. Invitation
issue verifies the named membership, actor, assigned tenant role, and active connection on the
writer. Acceptance requires a fresh `VerifiedExternalIdentity` from a trusted adapter, matches the
pre-approved actor and exact connection, consumes the invitation, creates one global external key,
and commits audit/outbox/idempotency evidence in the same transaction.

The focused suite proves exact retry, changed request/actor rejection, wrong tenant or connection,
issuer mismatch, missing current authority, expired/revoked/replayed invitation, duplicate
external key, provider-shaped extra authority input, concurrent exact acceptance, and injected
post-outbox rollback. Audit and outbox evidence excludes the raw invitation token and external
subject.

## Slice 2.0-D.2b evidence

Session creation rechecks the active link, exact protocol identity, actor, and current tenant
membership on the writer. Session rotation treats the requested membership as an opaque request
and resolves it again against the trusted actor and current tenant. The old token is marked rotated
and the replacement has a distinct digest. Validation refreshes idle expiry without exceeding the
original absolute expiry.

The focused suite proves exact retry, fixation-resistant rotation, concurrent exact rotation,
wrong-tenant denial, stale membership denial, stale assurance denial, idle/absolute expiry,
logout, exact-token invalidation, actor-wide revocation, token redaction, and writer routing. This
L0 boundary still receives an already validated server execution context; deriving that context
from a public callback or session cookie belongs to Slice 2.0-D.3.

## Slice 2.0-D.2c evidence

Support approval requires `identity.support.grants.create`, a different real support actor, a
current strongly assured grantor session no older than five minutes, a current support-actor
membership, one purpose and ticket, one tenant, and only these initial capabilities:

- `support.identity.connection.inspect`;
- `support.session.revoke`; and
- `support.tenant.configuration.inspect`.

Activation binds the grant to the support actor's exact current session. Each use rechecks grant,
actor, tenant, purpose, capability, session, membership, assurance freshness, idle/absolute
session expiry, grant expiry, and revocation on the writer, then advances the grant version and
records minimized evidence. Inputs for wildcard scope, background mode, impersonation, arbitrary
role mutation, identity-link administration, grant administration, and bulk export have no
accepted contract.

The focused suite proves independent approval, exact replay, tenant mismatch, stale assurance,
wildcard and excessive-duration rejection, background and impersonation-input rejection,
revocation, stale version, grant expiry, session expiry, end-of-access, and non-disclosure of raw
session tokens and ticket references in the use event.

## Slice 2.0-D.3 bounded public-adapter evidence

Accepted [ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md) fixes the
first public candidate as one same-origin Next.js/Phoenix surface. Phoenix owns provider callback,
the encrypted host-only application cookie, current context establishment, origin/CSRF controls,
logout, support elevation, stable errors, and named actions. Next.js remains an experience client
and receives no provider token, application bearer token, placement coordinate, or policy claim.

The implemented adapter now:

- resumes only a five-minute encrypted server-issued sign-in intent containing one pre-approved
  actor, tenant membership, identity link, connection, locale, correlation, idempotency, and
  relative return path;
- accepts only a qualified `CallbackVerifier` result expressed as `VerifiedExternalIdentity`, then
  rechecks the active link, connection, actor, and membership on the authoritative writer;
- issues `__Host-chimwemwe-session` as a `Secure`, `HttpOnly`, host-only, path-root,
  `SameSite=Lax` cookie whose encrypted locator is not authority by itself;
- resolves current placement from the startup-owned registry, then rechecks the exact opaque
  application session, actor, tenant, membership, assurance, idle/absolute expiry, and revocation
  on every request;
- supports one current key and at most two bounded previous cookie keys while issuing new state
  only with the current key;
- exposes only callback, current-session, authoritative logout, and support-elevation routes; the
  endpoint has no default application child and cannot start without deployment-supplied runtime,
  qualified verifier, exact HTTPS origin, and cookie keys;
- requires the exact configured origin and a session-bound CSRF proof for unsafe routes, returns
  `no-store` and restrictive browser-security headers, and filters callback code/state, tokens,
  CSRF proof, passwords, assertions, and secrets from Phoenix parameter logs; and
- carries an activated support-grant reference only in the encrypted cookie, validates it on every
  request, exposes safe real-actor/purpose/expiry/scope state, and records every capability use on
  the writer without impersonation.

The public session OpenAPI document is checked against code and generates immutable TypeScript
declarations. It has no collection, pagination, caller-defined filter/sort, generic mutation,
tenant selector, repository selector, or export route. The focused suite proves callback replay,
connection-proof mismatch, unsafe redirect denial, cookie tamper and forged-locator denial,
current-route resolution, membership removal, authoritative expiry and logout, active/previous key
rotation, missing origin/CSRF denial, secure-cookie attributes, support activation/use/expiry,
redacted inspection, and non-disclosing HTTP outcomes.

This is bounded synthetic implementation evidence, not a deployed identity connection. A real
OIDC implementation must still prove PKCE, nonce, issuer/audience/signature/expiry, key rotation,
provider-code replay, exact redirects, outage, recovery, and its contractual/privacy controls.
The visible tenant label and complete accessible browser treatment remain part of the first
2.0-E workflow; no elevated session is exposed to users before that experience passes.

## Migration review

The generated migrations and resource snapshots were reviewed for non-null tenant keys, global
external-key uniqueness, compound tenant references, token-digest length, lifecycle checks,
invitation/session/grant maximum lifetimes, independent approval, activation consistency,
optimistic versions, indexes, and reversible down paths. Nullable session references use the
globally unique session identifier; the named action still verifies the same tenant before bind or
use. Existing temporal test reset lists now include the new referencing tables so fresh test state
does not bypass foreign-key behavior.

## Verification and remaining gate

The focused identity suite passed 20 tests, `make test-fast` passed 172 tests, and generated
migration drift checking found no pending change. The complete `make check` repository gate passed
on 2026-09-27 with no skipped required check. It covered documentation and repository conventions,
formatting, compilation with warnings denied, migration and generated-contract drift, strict lint,
dependency audits, Dialyzer, 106 Phase 0 tests, 172 production-core tests, 25 repository-tool tests,
21 web unit tests, and 22 browser tests across the local synthetic and connected-qualification
surfaces.

Slices 2.0-D.2a through D.2c are complete at L0, ADR 0030 is accepted, and the bounded D.3
public-session adapter is implemented with synthetic evidence. D.3 cannot be released at L2 until
all L1 gates pass, and no provider or endpoint is enabled. Slice 2.0-E additionally depends on the
first accepted linked-structure workflow and therefore cannot complete before ADR 0025 G1–G6 and
the applicable Slice 2.1 persistence entry. Selected deployment, accessible connected experience,
independent security/privacy review, institution-side records ownership, real data, and pilot
gates remain open.

## References

- [Identity/session/support decision evidence](identity-session-and-support-access-decision-evidence.md)
- [Identity/session/support decision review](identity-session-and-support-access-decision-review.md)
- [Identity/session/support operating runbook](../operations/identity-session-and-support-access.md)
- [ADR 0030 public session and named-action boundary](../adr/0030-same-origin-public-session-and-named-action-boundary.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [Phase 2 identity/people/access proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Threat model](../security/threat-model.md)
