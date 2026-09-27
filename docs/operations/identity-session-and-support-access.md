# Identity, session, and support-access operating runbook

- Status: Accepted L0 operating runbook with synthetic D.2a through D.2c implementation; no
  production provider or public route exists
- Owner: Platform engineering with security architecture
- Escalation owner: François — interim Security/Privacy Owner until an independent owner is named
- Review trigger: first Slice 2.0-D implementation, connection/dependency change, deployment
  selection, incident, or production-readiness review
- Governing decision: [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- Superseded decision: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)

## Purpose and safety boundary

This runbook defines the provider-neutral, fail-closed procedure accepted in ADR 0029. The closed
internal connection/link/invitation, opaque-session, and bounded support-grant boundaries are now
implemented and rehearsed at L0 with synthetic data. The runbook contains no credential, secret,
real tenant identifier, real email address, callback secret, raw token, directory credential, or
production endpoint.

Until deployment and selected-connection qualification explicitly replace this statement:

- no real identity provider, broker, gateway, Active Directory/Entra connection, Google Workspace
  connection, or provisioning client is connected;
- no public callback, login, tenant selector, support grant, service credential, direct SAML
  parser, LDAP bind, or SCIM endpoint is enabled;
- the local UI-1A token and auth demo remain removable synthetic tools, not recovery paths; and
- provider/gateway outage, stale directory synchronization, uncertain validation, stale assurance,
  missing ownership, or incomplete audit closes the affected path.

## Roles and separation

| Role | Responsibility | Forbidden shortcut |
| --- | --- | --- |
| Identity connection operator | Maintain allowlisted versioned OIDC or gateway metadata, application registration, secret references, and lifecycle | Cannot create membership, role, relationship, or support authority from provider claims |
| Institution directory owner | Own Entra/Google/directory configuration, federation or sync health, recovery, and school-side change approval | Cannot select Chimwemwe tenant, placement, or authorization through directory structure |
| Provisioning operator | If separately authorized, operate least-scoped SCIM/provider lifecycle integration and reconciliation | Cannot map a group to application authority by default or delete retained records through deprovisioning |
| Session operator | Revoke application sessions and inspect minimized evidence | Cannot recover provider credentials or alter an identity link silently |
| Identity-link reviewer | Approve invitation/bootstrap and resolve external-key conflicts through named actions | Cannot link by email, domain, provider group, or display name alone |
| Support grantor | Approve one tenant, purpose, ticket, capability set, assurance level, and expiry | Cannot self-approve or create standing/wildcard grants |
| Support actor | Use visible elevated mode under the approved grant | Cannot impersonate, export broadly, run in background, or reuse across tenants |
| Incident lead | Coordinate containment, evidence, communication, and recovery | Cannot re-enable a route before validation and current authorization are proven |

## Initial tenant-administrator bootstrap

1. A separately governed workflow creates or identifies the tenant-owned actor, membership, and
   tenant-defined role assignment before sign-in. No provider role, group, directory path, or first
   login creates authority.
2. An authorized operator issues a one-time invitation bound to the tenant and actor. Store only
   its hash, expire it after 30 minutes, and accept no browser-supplied role, capability, tenant, or
   placement.
3. The invited person authenticates through an active qualified connection. A named action links
   the verified protocol-qualified external identity to the pre-approved actor and consumes the
   invitation in one transaction with audit and outbox evidence.
4. Replay, changed external identity, expiry, existing/conflicting link, tenant mismatch, or
   transaction failure creates no link or authority. An uncertain retry returns only the exact
   committed result.
5. There is no hidden global administrator or standing break-glass identity. Revoke and reissue an
   invitation after accountable review when bootstrap fails.

## Connection qualification and change

1. Classify the profile: direct OIDC, SAML-to-OIDC gateway, managed/self-managed broker, or future
   provisioning adapter. Record the institution, environment, connection owner, incident owner,
   provider/gateway, hosting/region, and approved data classification.
2. Record non-secret configuration: protocol/version, exact issuer or SAML entity ID, discovery or
   metadata origin, client/audience ID, exact callbacks/logout endpoint, signing algorithms,
   key/certificate rotation, scopes/attributes, assurance mapping, recovery, disablement, export,
   and exit procedure. Never store secrets in the repository.
3. Provision secrets only through the selected deployment secret manager. Database state contains
   a reference, not the value. Separate development and production registrations.
4. For OIDC, require authorization code plus S256 PKCE, state, and nonce; use an approved signing
   algorithm; request no `offline_access`; disable auto-registration and email auto-linking.
5. For SAML or AD FS, terminate at the qualified gateway. Review metadata, certificate rollover,
   assertion replay protection, audience/destination, NameID stability, logout, and the OIDC
   contract presented to Chimwemwe. Direct SAML parsing is denied.
6. Treat domain, institution, and home-realm hints as routing only. Arbitrary discovery/metadata
   URLs and request-selected issuer or connection activation are denied.
7. Require peer review for issuer/entity ID, redirect, key/certificate, gateway, upstream provider,
   login policy, assurance mapping, scopes, attributes, or registration changes. Record rollback.
8. Run provider-neutral callback, account-link, session, tenant, support, redaction, outage,
   rotation, and exit tests before activation. A profile-specific test supplements rather than
   replaces the common contract.

## Microsoft Entra and Active Directory path

1. Choose and document either direct Entra OIDC, institution-managed Active Directory
   synchronization to Entra through Connect/Cloud Sync followed by OIDC, or a qualified AD FS/SAML
   or OIDC gateway. Never configure a direct Chimwemwe LDAP bind.
2. Record the exact Entra tenant issuer or gateway entity/issuer, application registration,
   conditional-access and assurance evidence, directory/federation owner, synchronization scope,
   recovery path, and certificate/key rotation ownership.
3. Use synthetic identities to prove stable subject mapping, disablement, stale-sync behavior,
   directory outage, certificate/key rollover, and session revocation. Provider tenant, AD group,
   organizational unit, or role claims grant no application authority.
4. If synchronization health or issuer/federation validation is uncertain, stop new sign-in for
   the affected connection. Never fall back to cached directory membership or local passwords.

## Google Workspace and other providers

1. For Google Workspace, qualify Google's OIDC issuer directly or use a qualified gateway. Hosted
   domain information may route sign-in but cannot select a Chimwemwe tenant or auto-link an actor.
2. For generic OIDC, verify discovery, algorithms, key rotation, subject stability, logout,
   assurance, recovery, privacy, operations, and exit against the common contract.
3. For SAML-only institutions, onboard and test the qualified gateway path. No SAML assertion is
   accepted directly by the initial production core.
4. Activate each institution connection independently. Qualification of one provider, gateway,
   region, or hosting model does not qualify another.

## Directory provisioning, if separately authorized

1. Create a separate provisioning connection and secret with least scope. Enabling sign-in never
   enables provisioning.
2. Bind every request to one tenant and approved source; enforce authentication, rate limits,
   replay/idempotency controls, attribute allowlists, and safe audit.
3. Ingest users/groups as external lifecycle observations. Default group-to-role mapping is none.
4. Apply any actor/link/session effect through a named, authorized action with current writer
   context. Never create a Person, membership, role, relationship, unit access, or placement from a
   directory claim.
5. Treat deprovisioning as a reviewed suspend/revoke signal. Preserve retained records and
   historical evidence; do not silently delete school data.
6. Reconcile source and application state, report drift without sensitive bulk disclosure, and
   disable the connection on cross-tenant, schema, or authority-mapping ambiguity.

## Key, issuer, certificate, and dependency rotation

1. Announce a bounded change window and capture current non-secret configuration fingerprints.
2. Exercise the new key/certificate through the allowlisted metadata path. Unknown, conflicting,
   stale, or revoked material fails closed; no pasted-key bypass is allowed.
3. For issuer, entity-ID, client, gateway, or provider changes, use a time-bounded dual-validation
   plan with explicit old/new external-subject mapping. No email or group-based remapping.
4. Rotate the secret reference and revoke the old credential after verified cutover.
5. For Ash Authentication upgrades, pin the dependency pair, review OIDC/session changes, run the
   complete negative suite and `make check`, and retain tested rollback. Remove the route if the
   maintained API cannot satisfy the contract.

## Provider, gateway, or directory uncertainty

1. Stop new sign-in/callback processing when metadata, keys/certificates, audience, signature,
   state/nonce/PKCE, subject, assurance, provider status, gateway status, or directory lifecycle is
   uncertain.
2. Show a non-disclosing temporary-unavailability message with a correlation reference. Do not
   expose provider detail, tenant existence, subject, token, assertion, or validation reason.
3. Do not enable UI-1A, a local password, cached assertion, alternate unapproved issuer, direct
   LDAP, or support access as a production bypass.
4. Existing sessions remain usable only within normal limits and while current membership,
   placement, module gates, capabilities, and grant state still pass on the writer.
5. Resume only after metadata/key consistency, synthetic sign-in, revocation, redaction, current
   authorization, and incident-lead approval pass.

## Suspected session or identity-link compromise

1. Identify the session or actor using safe references; do not copy raw cookies, tokens,
   assertions, or directory credentials into tickets/logs.
2. Revoke the exact session and, when scope is uncertain, every application session for the actor.
3. Suspend the affected external identity link through a named action. Do not delete or silently
   remap it during investigation.
4. Terminate the provider/gateway session and request provider-side credential recovery where
   applicable.
5. Inspect minimized connection, sign-in, link, session, tenant-selection, named-action,
   provisioning, and support-grant evidence for tenant crossing or capability use.
6. Restore access only through reviewed conflict resolution or a new invitation followed by fresh
   authentication. Old support grants never revive.

## Support grant lifecycle

1. Receive a ticket naming one tenant, approved purpose, requested code-owned capabilities, start,
   expiry no more than 60 minutes later, and the support actor.
2. Require an independent grantor. Require qualified strong assurance with authentication no older
   than five minutes; missing or unrecognized mapping denies elevation.
3. Create the grant through a named action. Wildcards, identity-link administration, arbitrary
   role/grant mutation, bulk export, and background execution are not delegable initially.
4. Rotate the session into a visible elevated mode showing the real support actor, tenant, purpose,
   ticket reference, and expiry. Never render the actor as another user.
5. Recheck grant, tenant, assurance, session, support policy, module gates, capability, and field
   policy on every use at the writer; record minimized start/use/end or denial evidence.
6. Revocation, expiry, assurance loss, tenant mismatch, or session closure ends elevation
   immediately. Close the grant and attach safe evidence references to the ticket.

## Connection exit

1. Inventory external identity links, active sessions, connections, assurance mappings, and
   required non-secret configuration using safe identifiers.
2. Export only supported provider/gateway configuration and identity mapping evidence. Record any
   vendor-specific omissions; Chimwemwe audit and authorization remain authoritative.
3. Configure the replacement in a separate environment and prove explicit old/new subject maps.
4. Run bounded dual validation. Every new link requires explicit approval; ambiguity or duplicate
   mapping fails closed.
5. Invalidate old application/provider sessions, communicate recovery, disable old connections,
   and retain application audit continuity.
6. Verify export/deletion obligations and revoke old credentials only after rollback and recovery
   evidence are complete.

## Evidence required before real use

- exact dependency, protocol, provider/gateway, connection, and environment versions plus safe
  fingerprints, timestamp, reviewer, owner, and result;
- complete provider-neutral callback/session/account-link/tenant/support negative suite and the
  selected profile's additional tests;
- selected candidate contract/DPA, subprocessor, transfer, residency, retention, deletion,
  breach, SLA, recovery, and exit disposition;
- key/certificate rotation, outage, actor revocation, support-grant, and connection-exit rehearsals;
- if provisioning is authorized, lifecycle/replay/reconciliation/cross-tenant/authority-mapping
  evidence;
- selected-deployment edge/TLS, secret, database, backup/restore, telemetry, rate-limit, and
  incident controls;
- independent security/privacy review before real Restricted data or pilot; and
- `make check` with no skipped required check.
