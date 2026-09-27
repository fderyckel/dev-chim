# ADR 0029: Provider-neutral identity federation and directory connections

- Status: Accepted
- Date: 2026-09-27
- Decision date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Security architecture and platform engineering
- Deciders: Project owner, security architecture, platform engineering, and product experience
- Conditions: no real identity, directory synchronization, public route, or L2 claim until Slice
  2.0-D implementation evidence, selected-connection qualification, selected-deployment controls,
  contractual/privacy review, and the separate public-boundary pass
- Supersedes: [ADR 0027](0027-production-identity-session-and-support-access.md)

## Context

ADR 0027 fixed the necessary separation among external identity proof, application sessions,
Chimwemwe actors, tenant membership, authorization, and bounded support access. It also selected
ZITADEL Cloud Europe as the first federation broker. The project owner has clarified that a single
provider must not be part of Chimwemwe's durable architecture and that institutions must be able to
connect Microsoft Entra ID, hybrid or on-premises Active Directory, Google Workspace, and other
standards-compatible identity systems.

That correction changes a stable architecture outcome and therefore supersedes ADR 0027 rather
than rewriting its accepted history. The session, account-link, tenant-selection, invitation,
support-access, and fail-closed controls from ADR 0027 remain binding where this ADR does not
replace them.

Authentication federation and directory provisioning are different capabilities. OIDC or SAML
can prove an external identity for sign-in. SCIM or a separately reviewed provider API can
provision, suspend, or update external-directory records. Neither kind of connection establishes a
Chimwemwe Person, membership, role, capability, institutional relationship, tenant selection, or
placement.

## Decision drivers

- Let each institution use a suitable standards-compatible identity arrangement without making a
  vendor a permanent Chimwemwe dependency.
- Support Microsoft Entra ID and hybrid/on-premises Active Directory without embedding LDAP,
  Windows-domain, or provider-specific authorization semantics in the product core.
- Support Google Workspace, generic OIDC, and SAML-only institutions through qualified connection
  paths.
- Keep credentials, directory lifecycle, application identity, people records, tenant membership,
  and authorization separately governed.
- Preserve the reviewed Ash Authentication OIDC and Phoenix session seam where it can satisfy the
  contract without custom security code.
- Make provider or connection replacement explicit, reversible, and unable to widen authority.

## Considered options

1. Keep one mandatory cloud federation broker. Rejected as the architecture contract: it creates
   vendor, regional, commercial, availability, and exit dependence that every institution would
   inherit. A broker may still be selected for a deployment after qualification.
2. Add a custom adapter in Chimwemwe for every provider and protocol. Rejected: it multiplies
   callback, token-validation, metadata, certificate, logout, and incident paths in the security
   boundary.
3. Accept only direct OIDC. Rejected as the complete institutional offer: OIDC is the preferred
   application-facing protocol, but some institutions require SAML or hybrid-directory federation.
4. Define one provider-neutral connection boundary with qualified direct OIDC and gateway-backed
   federation profiles, plus a separate optional SCIM provisioning boundary. Selected.
5. Bind Chimwemwe directly to on-premises LDAP or Active Directory. Rejected for the initial
   boundary: it would add network reachability, password/credential, directory-query, availability,
   and legacy-protocol risks. Hybrid Active Directory connects through an institution-managed
   Entra synchronization/federation path or a separately qualified AD FS/SAML or OIDC gateway.

## Decision

Chimwemwe defines a provider-neutral `IdentityConnection` contract. No vendor, broker, region,
hosted service, or self-managed product is the architectural default. A deployment or institution
may choose a connection implementation only after it passes the same protocol, assurance,
privacy, operational, and exit gates.

The preferred application-facing protocol is OpenID Connect authorization-code flow with S256
PKCE, state, a session-bound nonce, exact redirect allowlisting, issuer/audience/signature/expiry
validation, bounded discovery, and planned key rotation. Ash Authentication remains the initial
OIDC relying-party and application-session seam. A direct OIDC connection and a brokered OIDC
connection must satisfy the same contract.

SAML 2.0 is supported as an institutional connection path through a separately qualified
federation adapter or gateway that presents the reviewed OIDC contract to Chimwemwe. Direct SAML
assertion processing in the production core is not authorized by this ADR. It requires its own
threat, library, metadata/certificate, replay, logout, and operational qualification.

The following are supported connection profiles, not privileged domain types:

| Institution arrangement | Initial connection path |
| --- | --- |
| Microsoft Entra ID / Microsoft 365 | Qualified direct OIDC or qualified federation gateway |
| Hybrid or on-premises Active Directory | Institution-managed Entra Connect or Cloud Sync into Entra ID and then OIDC; alternatively a separately qualified AD FS/SAML or OIDC gateway |
| Google Workspace | Qualified direct Google OIDC or qualified federation gateway; SAML may be used through the qualified gateway path |
| Other standards-compatible provider | Qualified direct OIDC |
| SAML-only identity provider | Qualified SAML-to-OIDC federation adapter or gateway |
| People without an institutional identity | A selected, qualified invitation/credential authority; Chimwemwe does not become the credential authority by default |

Product configuration stores the protocol and connection contract, not a provider role model. A
profile may supply setup guidance or defaults, but provider names, organizations, tenants, groups,
roles, domains, and claims never grant Chimwemwe authority.

### Stable identity and connection model

A verified external subject is represented by a protocol-qualified key:

```text
ExternalIdentityKey = protocol + normalized issuer/entity ID + stable subject/NameID
```

The key links to a stable Chimwemwe actor only through an auditable named action. The approved
connection and configuration version used to verify it are recorded as evidence. Email address,
domain, display name, provider group, provider role, directory path, or institutional-unit claim
cannot create or silently change the link. Automatic registration and email auto-linking remain
disabled.

A connection is tenant-governed configuration with an explicit lifecycle such as draft,
qualified, active, suspended, and retired. Activation requires reviewed metadata, protocol
version, exact issuer or entity ID, client/audience, redirect, signing algorithms, key or
certificate rotation, assurance mapping, recovery ownership, safe secret references, data
minimization, incident handling, and exit evidence. A browser-supplied institution, email domain,
home-realm hint, issuer, discovery URL, or connection identifier is untrusted routing input only.
It never selects a tenant, database, placement, membership, or authority.

### Authentication and directory provisioning are separate

OIDC/SAML sign-in proves an external identity. Optional directory provisioning is a later,
separately activated connection using SCIM 2.0 or a specifically reviewed adapter. It has its own
credential, scope, rate, replay/idempotency, reconciliation, retention, and incident controls.
Enabling sign-in does not enable provisioning, and provisioning does not create a login session.

Provisioned users and groups are external observations. They may create or update a quarantined
directory-link candidate, but they do not create a Person, learner, guardian, employee,
membership, role assignment, capability, institutional relationship, placement, or support grant.
Any mapping to application authority requires an explicit, tenant-qualified named action and
current writer-side authorization. Default group-to-role mapping is none. Deprovisioning may
suspend an external identity link and revoke affected application sessions through a reviewed
action; it never silently deletes retained school records or historical evidence.

### Session, tenant, invitation, and support rules retained

ADR 0027's provider-independent controls remain in force:

- the browser receives only a secure, host-only, `HttpOnly`, `SameSite=Lax`, `__Host-` application
  session cookie; provider tokens and assertions are not retained after validation unless a later
  named integration explicitly requires and authorizes them;
- application sessions are opaque, database-backed, rotated at privilege boundaries, and have
  explicit idle/absolute expiry, logout, and revocation;
- the initial tenant-administrator path consumes a hashed, single-use, tenant-bound, 30-minute
  invitation tied to pre-approved actor, membership, and role state; first login never wins;
- the writer resolves current membership, tenant, placement, module gates, and capabilities for
  every named action;
- support access is non-impersonating, independently approved, tenant-specific, purpose-bound,
  strongly assured, visible, least-privilege, at most 60 minutes, revocable, and rechecked on every
  use; and
- service identities use a separate qualified machine-to-machine profile with short-lived,
  minimal credentials and never reuse human cookies, provider roles, or support grants.

Assurance is mapped per connection from verified protocol evidence. No provider-specific `acr`,
`amr`, MFA method, group, or role is assumed to have a universal meaning. Missing, stale,
ambiguous, or unqualified assurance fails closed.

## Consequences

### Positive

- Institutions can bring Microsoft, Google, SAML, or standards-compatible OIDC arrangements
  without changing Chimwemwe's actor, membership, or authorization model.
- Hybrid Active Directory has an explicit supported path without placing LDAP credentials or
  directory reachability inside the core.
- Provider choice becomes a deployment/institution qualification decision rather than a permanent
  architecture dependency.
- Authentication and lifecycle provisioning can evolve independently and be disabled separately.
- Replacing a provider does not require replacing application actors or remapping authority by
  email or group name.

### Negative

- More than one connection profile must be qualified, monitored, documented, and supported.
- Direct OIDC reduces broker dependence but can multiply issuer, key, logout, recovery, and
  assurance variations.
- SAML and hybrid-directory support still require a qualified adapter/gateway and operational
  owner; declaring protocol support alone is insufficient.
- SCIM adds a write-capable external boundary and therefore remains gated until its own named
  actions, reconciliation, rate limits, audit, and negative suite exist.
- Invited identities still need a selected credential authority and recovery owner for each
  deployment.

## Security, privacy, operability, and migration effects

Every provider, broker, gateway, directory synchronizer, and credential authority is an external
trust and data-processing boundary. Qualification records its selected region/hosting model,
subprocessors and transfers, minimized attributes, retention/deletion, availability/recovery,
breach and incident responsibilities, secret/key/certificate ownership, monitoring, support, and
exit obligations. A product name or standards claim does not satisfy those checks.

Tenant context remains mandatory for connection configuration, external-identity links,
provisioning observations, sessions, support grants, audit, telemetry, and outbox facts. Raw tokens,
assertions, passwords, directory credentials, certificates/private keys, child data, and detailed
denial reasons never enter committed fixtures, logs, or evidence. Every security-sensitive decision
uses current writer state and fails closed on missing or stale connection, routing, assurance,
membership, or grant state.

The local migration replaces vendor-shaped `google`/`microsoft` connection values with the `oidc`
protocol and retains existing `oidc`/`saml` values. It preserves tenant, name, issuer, client,
secret-reference, routing-domain, lifecycle, and timestamp data while intentionally discarding a
vendor enum that never carried authority. Rollback restores the old column name but cannot infer a
former vendor label from a normalized OIDC value; display names and issuer metadata remain
available for operator interpretation. No production data is authorized by this migration.

## Validation evidence

Slice 2.0-D implementation must add provider-neutral contract tests before L2:

- at least two synthetic OIDC issuer profiles with no provider-specific authorization branch;
- Microsoft Entra-style tenant issuer and Google-style issuer fixtures plus a generic OIDC fixture,
  all using the same verified callback and account-link contract;
- an Active Directory topology rehearsal covering Entra-synchronized OIDC and the fail-closed
  SAML-gateway path without direct LDAP binding;
- rejection of arbitrary issuer/discovery/entity-ID/certificate input, cross-institution connection
  reuse, metadata/key conflicts, callback replay, and connection-profile claim escalation;
- connection disablement, key/certificate rotation, outage, issuer migration, subject-conflict,
  session revocation, and provider/gateway exit rehearsals;
- if SCIM enters scope, separate provision/update/suspend/deprovision, duplicate, replay,
  out-of-order, over-broad group, cross-tenant, reconciliation, and deletion-preservation tests;
- full tenant-selection, current-authorization, invitation, session, and TM-03 support negatives
  retained from ADR 0027; and
- `make check` after the bounded implementation.

Each real candidate must independently pass contract/DPA, subprocessor/transfer, residency,
retention/deletion, availability/recovery, secret/key ownership, incident, accessibility,
operational support, export, and exit review. Passing one provider never qualifies another.

## Accountable decision

On 2026-09-27, François directed that Chimwemwe remain provider agnostic and explicitly support
Active Directory connection paths in addition to other institutional identity systems. This ADR
accepts that correction and supersedes ADR 0027's provider selection while retaining its
provider-independent security controls.

The acceptance authorizes provider-neutral synthetic Slice 2.0-D engineering only. It does not
select, contract, connect, or enable Microsoft, Google, ZITADEL, Keycloak, Auth0, AD FS, SCIM, or
another real system; expose a public callback; authorize real identity data; or satisfy L2.

## Fallback and exit cost

If no connection implementation passes the contract, the public identity route remains closed and
UI-1A stays a removable local synthetic harness. A failing provider or gateway is disabled without
falling back to an unapproved issuer, local password, cached assertion, direct LDAP bind, or support
bypass.

A connection exit preserves stable Chimwemwe actors, immutable external-identity-link history,
current membership and authorization, application audit continuity, and explicit old-to-new
subject mapping. Ambiguous mappings fail closed. Old sessions and credentials are revoked, and
provider-held data is exported or deleted under the selected arrangement's reviewed obligations.

## Review triggers

- selection, contract, region, hosting model, or material change of any identity provider, broker,
  federation gateway, directory synchronization tool, or credential authority;
- direct SAML, LDAP, Kerberos, WS-Federation, SCIM, provider API, passkey, social-login, or custom
  callback work in Chimwemwe;
- a change to the Ash Authentication/Phoenix integration or use of another application-session
  framework;
- import or mapping of provider groups, roles, organizational units, or profile claims;
- storage of provider access/refresh tokens, assertions, directory credentials, or secrets;
- production identity data, public routes, service identities, support grants, deployment
  selection, or a material change to session/assurance limits; or
- any proposal to make a provider or directory the source of Chimwemwe tenant, placement,
  membership, relationship, or authorization state.

## Related records

- [ADR 0027](0027-production-identity-session-and-support-access.md)
- [Identity/session decision review](../phase-2/identity-session-and-support-access-decision-review.md)
- [Identity/session decision evidence](../phase-2/identity-session-and-support-access-decision-evidence.md)
- [Identity/session operating runbook](../operations/identity-session-and-support-access.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, TM-03, TM-09, and TM-11
