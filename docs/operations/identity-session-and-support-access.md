# Identity, session, and support-access operating runbook

- Status: Accepted L0 operating outline; no production provider or public route exists
- Owner: Platform engineering with security architecture
- Escalation owner: François — interim Security/Privacy Owner until an independent owner is named
- Review trigger: first Slice 2.0-D implementation, provider/dependency change, deployment
  selection, incident, or production-readiness review
- Governing decision: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)

## Purpose and safety boundary

This runbook defines the fail-closed operating procedure selected with ADR 0027. It is an L0
outline for synthetic implementation and rehearsal. It contains no credential, secret, tenant
identifier, email address, callback secret, raw token, or production endpoint.

Until deployment qualification explicitly replaces this statement:

- no real identity or institutional provider is connected;
- no public callback, login, tenant selector, support grant, or service credential is enabled;
- the local UI-1A token and auth demo remain removable synthetic tools, not recovery paths; and
- provider outage, uncertain validation, stale assurance, missing ownership, or incomplete audit
  always closes the affected path.

## Roles and separation

| Role | Responsibility | Forbidden shortcut |
| --- | --- | --- |
| Identity configuration operator | Maintain the allowlisted ZITADEL issuer, application registration, institutional connections, and secret references | Cannot create Chimwemwe membership, role, or support authority by changing broker claims |
| Session operator | Revoke application sessions and inspect minimized session evidence | Cannot recover a provider credential or alter an identity link silently |
| Account-link reviewer | Approve invitation/bootstrap and resolve issuer/subject conflicts through named actions | Cannot link by email/domain alone |
| Support grantor | Approve one tenant, purpose, ticket, capability set, assurance level, and expiry | Cannot self-approve or create standing/wildcard grants |
| Support actor | Use the visible elevated mode under the approved grant | Cannot impersonate another user, export broadly, run in background, or reuse the grant in another tenant |
| Incident lead | Coordinate containment, evidence, communication, and recovery | Cannot re-enable authentication before validation and current authorization are proven |

## Initial tenant-administrator bootstrap

1. A separately governed provisioning workflow creates or identifies the tenant-owned actor,
   membership, and tenant-defined role assignment before sign-in. No broker role or first login
   creates authority.
2. An authorized provisioning operator issues a one-time invitation bound to the tenant and actor.
   Store only its hash; expire it after 30 minutes; accept no browser-supplied role, capability,
   tenant, or placement.
3. The invited person authenticates through the accepted provider path. A named acceptance action
   links the verified `(issuer, subject)` to the pre-approved actor and consumes the invitation in
   one transaction with audit and outbox evidence.
4. Replay, changed identity, expired invitation, existing or conflicting link, tenant mismatch, or
   transaction failure creates no link or authority. A retry after an uncertain response returns
   only the exact committed result.
5. There is no hidden global administrator or standing break-glass identity. A failed bootstrap is
   recovered by revoking the invitation and issuing a new approved invitation after review.

## Configuration and change procedure

1. Record the exact ZITADEL instance, Europe region proof, custom domain, OIDC application,
   issuer, discovery origin, client identifier, exact callbacks, logout callback, back-channel
   logout endpoint, scopes, token algorithms, and responsible owners without storing secrets in
   the repository.
2. Provision secrets only through the selected deployment secret manager. The database may store
   a secret reference, never a secret value.
3. Keep development and production instances and application registrations separate.
4. Configure authorization code plus S256 PKCE. Require state and nonce; allow only RS256; request
   no `offline_access`; disable application-side auto-registration and email auto-linking.
5. Review broker organization/domain discovery as user routing only. Every institutional identity
   provider must be explicitly approved; arbitrary discovery URLs and direct SAML callbacks to
   Chimwemwe are denied.
6. Require peer review for issuer, redirect, signing-key, upstream provider, login-policy,
   assurance-mapping, or application-registration changes. Record a change reference and planned
   rollback.
7. Run forged issuer/audience/signature, state/nonce/PKCE replay, redirect, key-rotation,
   account-link, session, tenant, support, redaction, and outage tests before activation.

## Institution SSO onboarding and offboarding

1. Receive an approved institution request with a named school administrator and Chimwemwe
   tenant reference in operator-only state.
2. Create a draft ZITADEL organization identity-provider connection. Domain hints may route login
   but never establish tenant authority.
3. Validate issuer/metadata, redirect, keys/certificate, assurance signals, recovery ownership,
   test identities, disablement, and offboarding using synthetic accounts.
4. Approve and activate the connection only after the application still resolves the test actor
   through an explicit `(issuer, subject)` link and current membership.
5. To disable, stop new broker sign-ins, revoke affected application sessions, preserve links and
   audit for the approved retention period, notify the institution, and verify that other
   institutions are unaffected.

## Key, issuer, and dependency rotation

1. Announce a bounded change window and capture current non-secret configuration fingerprints.
2. Exercise the new JWK through the allowlisted discovery path. Unknown, conflicting, stale, or
   revoked keys fail closed; no operator may paste a key into application state as a bypass.
3. For issuer or client changes, use a time-bounded dual-validation plan that maps each old and new
   subject to the same pre-approved application actor. No silent mapping is permitted.
4. Rotate the application secret reference and revoke the old secret after verified cutover.
5. For an Ash Authentication upgrade, pin the exact dependency pair, review OIDC/session changes,
   run the complete negative suite and `make check`, then retain a tested rollback. If maintained
   APIs cannot satisfy the contract, remove or close the route instead of introducing a custom
   validator.

## Provider outage or validation uncertainty

1. Stop new sign-in and callback processing when issuer discovery, keys, audience, signature,
   nonce/state/PKCE, assurance, or provider status is uncertain.
2. Show a non-disclosing temporary-unavailability message with a correlation reference. Never
   expose provider detail, tenant existence, subject, token, or validation reason.
3. Do not enable UI-1A, a local password, cached token, alternate issuer, or support access as a
   production bypass.
4. Existing application sessions remain usable only until their normal idle/absolute limits and
   only while current membership, tenant placement, module gates, capabilities, and grant state
   still pass on the writer.
5. Resume only after discovery/key consistency, synthetic sign-in, revocation, logging redaction,
   and current authorization checks pass and the incident lead records approval.

## Suspected session or account-link compromise

1. Identify the application session or actor using safe references; do not copy raw cookies or
   tokens into tickets or logs.
2. Revoke the exact session and, when scope is uncertain, every application session for the actor.
3. Disable the affected identity link through a named action. Do not delete or remap it during
   investigation.
4. Terminate the broker session and request provider-side credential recovery where applicable.
5. Inspect minimized sign-in, link, session, tenant-selection, named-action, and support-grant
   evidence for tenant crossing or capability use.
6. Restore access only through a reviewed invitation or conflict-resolution action followed by a
   fresh authentication and session. Old support grants never revive.

## Support grant lifecycle

1. Receive a ticket naming one tenant, an approved purpose, requested code-owned capabilities,
   start, expiry no more than 60 minutes later, and the support actor.
2. Require an independently authorized grantor; the support actor cannot approve their own grant.
3. Require a broker-native support identity with passkey/WebAuthn MFA and authentication no older
   than five minutes. A missing or unrecognized `acr`/`amr` mapping denies elevation.
4. Create the grant through a named action. Wildcards, grant administration, identity-link
   administration, arbitrary role/grant mutation, bulk export, and background execution are not
   delegable in the initial support capability allowlist.
5. Rotate the application session into a visible elevated mode showing the real support actor,
   tenant, purpose, ticket reference, and expiry. The actor is never rendered as another user.
6. Recheck grant state, tenant, assurance, session, membership-independent support policy, module
   gates, action capability, and field policy on every use at the writer.
7. Record minimized start/use/end or deny evidence. Revocation, expiry, assurance loss, tenant
   mismatch, browser backgrounding beyond the idle bound, or session closure ends elevation
   immediately.
8. Close or revoke the grant, invalidate the elevated session, and attach the safe evidence
   references to the ticket.

## Provider exit

1. Inventory application actor links, broker subjects, active sessions, institutional connections,
   assurance mappings, and required broker configuration using safe identifiers.
2. Export the supported broker configuration and users, recognizing that the ZITADEL export does
   not preserve the event stream or every key, policy, token, passkey, and application artifact.
3. Configure the replacement issuer in a separate environment and prove exact actor mappings.
4. Run a bounded dual-issuer migration. Every new link requires explicit approval; ambiguous or
   duplicate mappings fail closed.
5. Invalidate old application and broker sessions, communicate recovery to affected users, disable
   the old connections, and retain application audit continuity.
6. Verify export/deletion obligations and revoke old credentials only after rollback and recovery
   evidence are complete.

## Evidence required before real use

- exact configuration and dependency versions, non-secret fingerprints, environment, timestamp,
  reviewer, and result;
- complete callback/session/account-link/tenant/support negative suite;
- provider DPA, subprocessor, transfer, retention, deletion, breach, SLA, and exit disposition;
- key rotation, provider outage, actor revocation, support-grant, and provider-exit rehearsals;
- selected-deployment edge/TLS, secret, database, backup/restore, telemetry, rate-limit, and
  incident controls;
- independent security/privacy review before any real Restricted data or pilot; and
- `make check` with no skipped required check.
