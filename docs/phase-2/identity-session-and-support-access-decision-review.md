# Identity, session, and support-access decision review

- Status: Reviewed and accepted for the Slice 2.0-D architecture boundary
- Review date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Delivery owners: Security architecture, platform engineering, and product experience
- Decision record: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- Evidence freshness: vendor and framework evidence reviewed on 2026-09-27; recheck before any
  production connection or contract

## Accountable outcome

ADR 0027 is accepted. The first production candidate will use Chimwemwe as an OpenID Connect
relying party through `ash_authentication` and `ash_authentication_phoenix`, with **ZITADEL Cloud
in its Europe data region** as the selected federation broker. Institutional Google Workspace,
Microsoft Entra ID, OIDC, or SAML identity providers terminate at ZITADEL; Chimwemwe accepts only
the one allowlisted ZITADEL issuer. ZITADEL-native invited identities cover people who do not have
an institutional account.

This accepts the protocol, provider, account-link, application-session, tenant-selection,
assurance, service-identity, and support-grant boundaries needed to enter Slice 2.0-D engineering.
It does not create a provider account, approve a contract, configure a real callback, authorize
real personal data, open a public route, satisfy L2, or qualify a deployment.

## Fixed decision

| Boundary | Accepted position |
| --- | --- |
| Broker and region | ZITADEL Cloud in the Europe data region; separate development and production instances and application registrations |
| Application protocol | OIDC authorization-code flow with S256 PKCE, state, nonce, exact redirect allowlist, RS256 ID tokens, and an allowlisted issuer/discovery origin |
| Institutional federation | ZITADEL owns approved per-organization Google Workspace, Microsoft Entra ID, OIDC, or SAML connections; arbitrary issuer discovery and direct SAML callbacks to Chimwemwe are forbidden |
| Invited-user path | ZITADEL-native accounts with invitation and recovery owned by the broker; a broker account still grants no Chimwemwe membership or role |
| Application account link | Unique `(issuer, subject)` to stable Chimwemwe actor link; `registration_enabled? false`, an identity resource is mandatory, and email/profile claims never auto-link or grant authority |
| Initial tenant administrator | A separately governed provisioning workflow prepares the actor, membership, tenant-defined role assignment, and a hashed, single-use, tenant-bound invitation with a 30-minute expiry; accepting it links the verified subject but accepts no role or authority input and provides no hidden break-glass account |
| Provider tokens | Chimwemwe requests only required OIDC scopes, does not request `offline_access`, and does not retain provider access tokens, refresh tokens, credentials, or assertions after callback validation |
| Application session | Database-backed opaque handle stored in a `Secure`, `HttpOnly`, host-only `__Host-` cookie with `SameSite=Lax`; rotate at authentication, tenant switch, step-up, and support elevation |
| Session lifetime | Ten-minute one-time sign-in attempt; 30-minute idle and eight-hour absolute ordinary session; ten-minute idle and at most 60-minute elevated support session, never beyond its grant |
| Tenant selection | The browser may submit an opaque membership reference only as an untrusted request; the writer resolves the current membership, tenant, placement, module gates, and capabilities before rotating the session |
| Strong assurance | Ordinary actions declare their assurance requirement. Initial support operators use ZITADEL-native identities with WebAuthn/passkey MFA; elevated support requires verified `amr`/`acr`, `auth_time` no older than five minutes, and fails closed when mapping is absent or stale |
| Service identity | Separate ZITADEL service accounts using short-lived `private_key_jwt` credentials; no personal access token, browser cookie, human grant, or provider role becomes domain authority |
| Support access | No impersonation. A separately authorized grant names the real support actor, one tenant, approved purpose, ticket, capability allowlist, independent approver, assurance, start, expiry, and revocation; every use rechecks it and records minimized start/use/end evidence |
| Exit | Chimwemwe keeps stable actor IDs and authoritative membership. Export account links and required broker configuration, establish a reviewed dual-issuer migration period, prohibit silent subject remapping, revoke old sessions, and retain application audit continuity |

Identity configuration and key/secret operations are owned by platform engineering with security
architecture approval. François remains the interim incident and privacy escalation owner. The
selected deployment owner remains deliberately unassigned until the separate deployment decision;
that blocks production use, not this L0 architecture decision.

## Candidate evaluation

| Candidate | Evidence-backed strengths | Principal drawback | Disposition |
| --- | --- | --- | --- |
| ZITADEL Cloud Europe | Per-organization identity brokering for OIDC and SAML, domain discovery, native and federated identities, OIDC `acr`/`amr` claims, session termination and back-channel logout, service accounts, append-only audit events, selectable Europe data region, and a Cloud-to-self-hosted path | Contract and DPA still permit subprocessors and some processing outside the selected region; export does not carry the broker event stream or every credential artifact | **Selected**, with contractual/privacy and exit rehearsal gates before real use |
| Auth0 managed service | Mature enterprise connections, organization-bound connections, PKCE, session revocation, back-channel logout, MFA/step-up, and user/configuration export tools | Greater proprietary dependence, feature/plan coupling, and public-cloud backup/password-hash export limitations | Rejected for the first candidate; retain as a fallback if ZITADEL cannot pass deployment qualification |
| Self-managed Keycloak | OIDC/SAML identity brokering, step-up authentication, service accounts, and complete infrastructure control | Introduces an identity-service deployment, upgrade, availability, backup, incident, and staffing burden before Chimwemwe has selected its deployment operating envelope | Rejected for the first candidate; retain as the fail-closed self-managed alternative |
| Direct Google/Microsoft connections | Fewer broker components for a narrow population | Does not provide one governed path for mixed institutional IdPs, SAML-only schools, invited users, shared assurance mapping, or provider exit | Rejected as the primary topology; a direct connection requires a new review trigger |
| Chimwemwe-owned passwords and MFA | Maximum local control | Makes Chimwemwe the credential, recovery, MFA, and breach-response authority before that operational capability exists | Rejected for the first boundary |

## Source disposition

The selected candidate is supported by the following current primary sources:

- ZITADEL documents [per-organization identity brokering](https://zitadel.com/docs/concepts/features/identity-brokering)
  for OIDC and SAML providers and domain discovery.
- Its [OIDC claims reference](https://zitadel.com/docs/apis/openidoauth/claims) exposes `acr`, `amr`,
  and `auth_time`; Chimwemwe treats those as assurance evidence only after an explicit allowlisted
  mapping.
- Its [back-channel logout guide](https://zitadel.com/docs/guides/integrate/back-channel-logout)
  and [session termination guide](https://zitadel.com/docs/guides/integrate/login-ui/logout) provide
  revocation signals; Chimwemwe still owns and revokes its application session independently.
- ZITADEL advertises selectable [Europe, United States, Switzerland, and Australia regions](https://zitadel.com/pricing)
  and describes the [cloud/shared-responsibility and backup model](https://zitadel.com/docs/legal/service-description/cloud-service-description).
- Its [DPA](https://zitadel.com/docs/legal/data-processing-agreement) expressly allows subprocessors
  and protected transfers outside the EU/EEA. Europe-region selection is therefore not treated as
  complete privacy qualification.
- Its [migration guide](https://zitadel.com/docs/guides/migrate/sources/zitadel) records that a
  Cloud-to-self-hosted export omits the event stream and some policy, key, token, and passkey
  artifacts. Chimwemwe must preserve its own identity-link and authorization audit and rehearse
  exit rather than assuming a lossless broker export.
- Auth0's official [enterprise-provider](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers),
  [organization-connection](https://auth0.com/docs/manage-users/organizations/configure-organizations/enable-connections),
  [session-revocation](https://auth0.com/docs/api/management/v2/sessions/revoke-session), and
  [data-export](https://auth0.com/docs/troubleshoot/customer-support/operational-policies/data-export-and-transfer-policy)
  documentation supports the fallback comparison.
- Keycloak's [server administration guide](https://www.keycloak.org/docs/latest/server_admin/)
  supports the self-managed comparison for identity brokering, step-up authentication, and
  service accounts.

## Ash compatibility disposition

The repository pins `ash_authentication` 5.0.0-rc.14 and
`ash_authentication_phoenix` 3.0.0-rc.11. The checked dependency source exposes the OIDC strategy,
S256 PKCE through `code_verifier`, generated nonce, state validation, allowlisted discovery,
issuer/audience/signature/expiry validation, unique issuer/subject identity resources, Phoenix
session storage, and logout token revocation. The existing local proof compiles and exercises a
database-backed revocable token and Phoenix session without adding a production callback.

The release-candidate dependency status remains a bounded implementation risk. Slice 2.0-D must
pin an exact reviewed pair, run dependency audit and the full negative suite, and either qualify
that pair or move to a compatible stable pair. A custom callback, validator, or browser-token
workaround is not an allowed fallback.

## Threat and privacy disposition

- TM-01 and TM-02 remain governed by current membership, tenant-defined capabilities, module gates,
  and writer-side authorization; no ZITADEL organization, role, domain, or claim grants access.
- TM-03 is accepted at design level through non-impersonating, tenant-specific, short-lived,
  independently approved support grants with strong assurance and enhanced evidence. Its
  implementation and negative suite remain open.
- TM-09 requires token, credential, assertion, email, and detailed denial redaction from logs,
  telemetry, fixtures, and evidence.
- TM-11 and TM-14 require tenant placement and every security-sensitive membership, session,
  assurance, and grant decision to use current writer state and fail closed on stale routing.
- ZITADEL Cloud is a processor of identity data. Contract/DPA execution, selected-region proof,
  subprocessor review, data minimization, deletion/retention configuration, and an independent
  privacy review remain mandatory before real Restricted data or a pilot.

## Residual risks accepted for engineering entry

| Risk | Accepted containment and later gate |
| --- | --- |
| Managed broker outage or compromise | No fail-open path; existing sessions continue only while their local validity and current authorization remain valid, new authentication fails closed, and incident/session-revocation procedures apply |
| Broker subject or connection drift | Immutable issuer/subject link, approved connection versions, no email auto-link, conflict action, and dual-issuer migration rehearsal |
| Federated MFA semantics vary by upstream IdP | Support operators initially use broker-native passkey MFA; all other assurance mappings are allowlisted and tested per connection or denied |
| Release-candidate Ash dependencies | Exact pin, dependency audit, upgrade rehearsal, complete callback/session negatives, and removal rather than custom security workaround if the candidate cannot pass |
| EU region is not EU-only processing | DPA/subprocessor/transfer review and independent privacy approval before real data; use a self-hosted reviewed alternative if the disposition fails |
| Broker export is not lossless | Chimwemwe remains authority for actor, membership, grants, and audit; rehearse export, dual validation, user recovery, and session invalidation before production acceptance |
| External identity administration could be confused with tenant authority | ZITADEL organization and role data are never imported as Chimwemwe roles or memberships; every named action resolves current application state |

## Slice 2.0-D entry disposition

The L0 decision gate is satisfied. The accepted Phase 2 sequence may now implement Slice 2.0-D
with synthetic identities and a non-production ZITADEL instance. Before any real provider
connection or public availability, the implementation must satisfy the ADR negative suite, the
[operating runbook](../operations/identity-session-and-support-access.md), exact dependency and
contract review, selected-deployment controls, and `make check`.

L2 remains blocked until the identity/session/support implementation evidence and the separate
public browser/API candidate both pass. L3 remains blocked by selected-deployment qualification,
independent security/privacy review, learning-institution records ownership, and real-data policy.
