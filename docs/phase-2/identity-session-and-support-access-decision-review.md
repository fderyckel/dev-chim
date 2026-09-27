# Identity, session, and support-access decision review

- Status: Reviewed and accepted for the Slice 2.0-D architecture boundary
- Review date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Delivery owners: Security architecture, platform engineering, and product experience
- Current decision: [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- Superseded decision: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- Evidence freshness: protocol, provider, and framework evidence reviewed on 2026-09-27; recheck
  each candidate before any production connection or contract

## Accountable outcome

ADR 0029 is accepted and supersedes ADR 0027's selection of ZITADEL Cloud Europe. Chimwemwe's
durable boundary is provider neutral. It accepts a qualified standards-based identity proof and
creates its own application session; no vendor, broker, cloud region, or self-managed product is
the permanent architecture default.

The supported institutional profiles include Microsoft Entra ID, hybrid/on-premises Active
Directory through an institution-managed Entra synchronization path or qualified federation
gateway, Google Workspace, generic OIDC, and SAML through a qualified adapter/gateway. These are
connection choices, not Chimwemwe authority sources. ZITADEL, Keycloak, Auth0, or another broker
may be evaluated for a deployment, but none is selected by the architecture.

This accepts the protocol-neutral connection, account-link, application-session, tenant-selection,
assurance, service-identity, and support-grant boundaries needed to enter Slice 2.0-D engineering.
It does not create a provider account, approve a contract, configure a real callback, enable
directory synchronization, authorize real personal data, open a public route, satisfy L2, or
qualify a deployment.

## Fixed decision

| Boundary | Accepted position |
| --- | --- |
| Provider choice | No architectural default. Each direct provider, broker, gateway, region, and hosting model is independently qualified for the institution/deployment that uses it. |
| Application protocol | Prefer OIDC authorization-code flow with S256 PKCE, state, nonce, exact redirect allowlist, qualified signing algorithms, and allowlisted issuer/discovery metadata. |
| SAML | Supported through a qualified SAML-to-OIDC adapter/gateway. Direct SAML processing in the production core requires a new security decision. |
| Microsoft path | Microsoft Entra ID may connect by qualified OIDC. Hybrid/on-premises Active Directory reaches that path through institution-managed Entra Connect/Cloud Sync, or through a separately qualified AD FS/SAML or OIDC gateway; no direct LDAP bind is authorized. |
| Google path | Google Workspace may connect through qualified Google OIDC or a qualified federation gateway. |
| Other providers | A standards-compatible OIDC provider may connect after per-connection qualification; a SAML-only provider uses the qualified gateway path. |
| Invited-user path | A selected qualified credential authority owns invitation, credential, MFA, and recovery operations; a provider account still grants no Chimwemwe membership or role. |
| Application account link | A protocol-qualified external identity key links to a stable Chimwemwe actor only through a named action. Email, domain, profile, provider role, and group claims never auto-link or grant authority. |
| Directory provisioning | Optional SCIM 2.0 or a reviewed provider adapter is a separate later boundary. Default group-to-role mapping is none; provisioning does not create application authority. |
| Initial tenant administrator | A separately governed workflow prepares the actor, membership, tenant-defined role assignment, and hashed single-use tenant-bound invitation with a 30-minute expiry; first login never wins. |
| Provider tokens | Request only required scopes. Do not retain provider access/refresh tokens, directory credentials, or assertions after validation unless a later named integration explicitly requires and approves it. |
| Application session | Database-backed opaque handle in a `Secure`, `HttpOnly`, host-only `__Host-` cookie with `SameSite=Lax`; rotate at authentication, tenant switch, step-up, and support elevation. |
| Session lifetime | Ten-minute one-time sign-in attempt; 30-minute idle and eight-hour absolute ordinary session; ten-minute idle and at most 60-minute elevated support session, never beyond its grant. |
| Tenant selection | Browser input is an untrusted request. The writer resolves current membership, tenant, placement, module gates, and capabilities before rotating the session. |
| Strong assurance | Map verified protocol evidence per connection. No provider-specific MFA/group/role claim has universal meaning. Missing, stale, ambiguous, or unqualified evidence fails closed. |
| Service identity | Use a separate qualified machine-to-machine profile with short-lived minimal credentials; no human cookie, support grant, or provider role becomes domain authority. |
| Support access | No impersonation. A separately authorized grant names the real actor, one tenant, purpose, ticket, capabilities, independent approver, assurance, start, expiry, and revocation; every use is rechecked and evidenced. |
| Exit | Keep stable Chimwemwe actors and authoritative membership; explicitly map old/new subjects, revoke sessions, preserve application audit, and rehearse export/deletion. |

Identity configuration and key/secret operations are owned by platform engineering with security
architecture approval. François remains the interim incident and privacy escalation owner. The
selected deployment owner remains deliberately unassigned until the deployment decision; that
blocks production use, not this L0 architecture decision.

## Connection-profile evaluation

| Profile | Standards path | Principal qualification concern | Disposition |
| --- | --- | --- | --- |
| Microsoft Entra ID | Direct OIDC authorization code with PKCE | Tenant-specific issuer, conditional-access/assurance mapping, logout/revocation, directory lifecycle, contract/privacy, and exit | Supported candidate; qualify each connection |
| Hybrid/on-premises Active Directory | Entra Connect/Cloud Sync to Entra OIDC, or qualified AD FS/SAML/OIDC gateway | Synchronization/federation ownership, stale directory state, certificate rotation, outage, and no direct LDAP fallback | Supported candidate; qualify topology and owner |
| Google Workspace | Direct Google OIDC or qualified gateway | Hosted-domain routing is not tenant authority; assurance, lifecycle, privacy, logout, and exit vary | Supported candidate; qualify each connection |
| Generic OIDC | Direct OIDC through the same Ash relying-party contract | Discovery, algorithms, key rotation, subject stability, assurance, recovery, privacy, and operations vary | Supported candidate only after qualification |
| SAML-only provider | Qualified SAML-to-OIDC adapter/gateway | Metadata/certificate rollover, assertion replay, NameID stability, logout, and gateway ownership | Supported connection path; direct core SAML is not authorized |
| Managed broker | Broker terminates qualified upstream OIDC/SAML and presents reviewed OIDC | Vendor, contract, region, availability, assurance translation, export, and exit dependency | Optional deployment choice, not architecture default |
| Self-managed broker | Same provider-neutral gateway contract | Deployment, upgrades, hardening, availability, backup, incident, and staffing burden | Optional deployment choice after operating qualification |
| Chimwemwe-owned credentials | Application-owned credential authority | Makes Chimwemwe responsible for passwords/passkeys, MFA, recovery, breach response, and federation | Rejected for the initial boundary |

## Source disposition

Current primary sources support the feasible connection paths, not a mandatory provider:

- Microsoft documents the [OIDC authorization-code flow with PKCE](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
  for Entra ID application sign-in.
- Microsoft's [directory synchronization overview](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/sync-directory)
  and [Cloud Sync topology guidance](https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/plan-cloud-sync-topologies)
  establish supported hybrid Active Directory paths into Entra ID.
- Microsoft's [SAML/WS-Federation guidance](https://learn.microsoft.com/en-us/entra/external-id/direct-federation)
  documents federation with external identity systems including AD FS; Chimwemwe still requires a
  qualified application-facing adapter/gateway.
- Google documents its [OpenID Connect implementation](https://developers.google.com/identity/openid-connect/openid-connect),
  discovery metadata, authorization-code exchange, issuer, and subject validation.
- Google Workspace documents [custom SAML applications](https://support.google.com/a/answer/6087519),
  supporting the qualified gateway path for SAML deployments.
- [SCIM 2.0](https://www.rfc-editor.org/rfc/rfc7644) defines a cross-domain identity-management
  protocol. Microsoft documents Entra acting as a
  [SCIM provisioning client](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/scim-support-in-entra-id).
  SCIM feasibility does not authorize a Chimwemwe provisioning endpoint.

Provider and broker documentation remains useful during candidate qualification, but prior
ZITADEL/Auth0/Keycloak comparison evidence no longer selects a product. Every selected candidate
must be rechecked against current official documentation, contract terms, deployment constraints,
and the complete negative suite.

## Ash compatibility disposition

The repository pins `ash_authentication` 5.0.0-rc.14 and
`ash_authentication_phoenix` 3.0.0-rc.11. The checked dependency source exposes the OIDC strategy,
S256 PKCE through `code_verifier`, generated nonce, state validation, identity resources,
revocable tokens, and Phoenix session/router hooks. The local proof exercises the database-backed
password/session seam without adding a production callback.

The release-candidate dependency status remains a bounded implementation risk. Slice 2.0-D must
pin an exact reviewed pair, run dependency audit and the full negative suite, and either qualify
that pair or move to a compatible stable pair. A custom callback, validator, direct-SAML parser,
or browser-token workaround is not an allowed fallback.

## Threat and privacy disposition

- TM-01 and TM-02 remain governed by current membership, tenant-defined capabilities, module gates,
  and writer-side authorization. No provider tenant, directory unit, role, group, domain, or claim
  grants access.
- TM-03 retains non-impersonating, tenant-specific, short-lived, independently approved support
  grants with qualified strong assurance and enhanced evidence. Implementation remains open.
- TM-09 requires token, credential, assertion, email, directory attribute, and detailed-denial
  redaction from logs, telemetry, fixtures, and evidence.
- TM-11 and TM-14 require current writer state for tenant placement and every membership, session,
  assurance, and grant decision.
- Each provider, broker, gateway, and provisioning adapter is a distinct processor/trust boundary.
  Its contract, region, subprocessors, transfers, minimization, retention/deletion, availability,
  recovery, and exit require independent review before real data.

## Residual risks accepted for engineering entry

| Risk | Accepted containment and later gate |
| --- | --- |
| Provider/gateway outage or compromise | No fail-open path; new authentication closes, existing sessions continue only within local validity and current authorization, and incident/session-revocation procedures apply. |
| Subject or connection drift | Immutable protocol-qualified external key, approved configuration versions, no email auto-link, conflict action, and explicit issuer migration rehearsal. |
| Assurance semantics vary | Allowlist and test mappings per connection or deny; provider groups/roles never substitute for application authorization. |
| More profiles increase operating load | Each active profile needs an owner, qualification pack, monitoring, recovery, and exit rehearsal; unsupported profiles remain disabled. |
| Hybrid directory synchronization is stale or misconfigured | Treat it as external identity evidence only, recheck application authority locally, reconcile lifecycle explicitly, and fail closed without current connection status. |
| SCIM could become an authority shortcut | Keep provisioning separately activated, default group mapping to none, and require named application actions for any authority-affecting change. |
| Release-candidate Ash dependencies | Exact pin, dependency audit, upgrade rehearsal, complete callback/session negatives, and route removal instead of a custom security workaround. |

## Slice 2.0-D entry disposition

The corrected L0 decision gate is satisfied by ADR 0029. The accepted Phase 2 sequence may
implement Slice 2.0-D with synthetic provider-neutral identity fixtures. Before any real connection
or public availability, the implementation must satisfy the ADR negative suite, the
[operating runbook](../operations/identity-session-and-support-access.md), selected-connection and
deployment qualification, and `make check`.

L2 remains blocked until identity/session/support implementation evidence and the separate public
browser/API candidate both pass. L3 remains blocked by selected-deployment qualification,
independent security/privacy review, learning-institution records ownership, and real-data policy.
