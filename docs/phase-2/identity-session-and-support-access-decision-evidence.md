# Identity, session, and support-access decision evidence plan

- Status: L0 decision-evidence plan; no identity provider, public route, session, or real-data
  integration is authorized by this document
- Date: 2026-09-26
- Accountable owner: Security architecture and platform engineering
- Decision record: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- Gate: Phase 2.0-D; L2 remains closed

## Purpose and current disposition

This plan makes ADR 0027 reviewable without pretending that a planned test or a local UI token is
completed production evidence. It supplies the L0 decision pack for the first identity/session and
support-access boundary. It does not decide people, guardianship, employment, admissions,
membership provisioning, role design, or a public journey.

**Current disposition: open.** No provider or federation broker is named, no vendor credentials
exist in the repository, and no production callback, account-link, membership, or support-access
implementation exists. A loopback-only local proof now declares `ash_authentication` and
`ash_authentication_phoenix`, persists synthetic account/session/SSO-connection records in a
dedicated local PostgreSQL database, and provides an authenticated administration page. It stores
only a secret reference, never a raw client secret, certificate, access token, or refresh token.
No provider data-processing or operational review has been completed. Therefore neither this plan
nor ADR 0027 closes the Phase 2.0-D or L2 gate.

The local proof pins `ash_authentication` 5.0.0-rc.14 and
`ash_authentication_phoenix` 3.0.0-rc.11. Those paired versions retain compatibility with the
repository's pinned Ash/Phoenix releases and use the OTP-29-compatible Ash resource record type;
the earlier stable pair failed the repository's zero-warning type-analysis gate.

## Local database-backed proof

Run `make auth-demo` to create/migrate the dedicated `chimwemwe_auth_demo` database, start a
loopback-only server on port 4012, and print a fresh synthetic local password. The page at
`/sign-in` exercises Ash Authentication's password strategy, server-managed encrypted Phoenix
session, and database-backed revocable token resource. After sign-in, `/` displays the institutional
SSO administration page.

The administration page can create a draft record for Google Workspace, Microsoft Entra ID, an
other OIDC provider, or a SAML connection through a future federation broker. It records a name,
issuer URL, client ID, allowed domains, lifecycle state, and a deployment-secret reference. It can
activate or disable a connection. It deliberately cannot accept, store, or display a raw secret.

This proof remains synthetic and local: the seeded account is not a school administrator, the
fixed synthetic tenant is not a tenant-selection mechanism, and signing in does not create a
membership, role, Person, learner relationship, or provider callback. A record changing from draft
to active means only that the metadata lifecycle works; it does not activate Google, Microsoft, or
another provider until the selected federation and provider-registration evidence below is complete.

## Proposed Ash and federation seam

ADR 0027 proposes `ash_authentication` as Chimwemwe's application authentication layer and its
OIDC strategy as the one reviewed inbound browser protocol. The first Phoenix integration will use
`ash_authentication_phoenix` only when the public browser boundary is separately authorized. Ash
Authentication therefore validates sign-in and manages the application session; it does not replace
our `Membership`, tenant-defined role/capability, placement, module-gate, or People/Relationships
boundaries.

For an institution that already uses Google Workspace, Microsoft Entra, or another SSO provider,
the selected federation broker owns that institution's upstream connection and offers one reviewed
OIDC issuer to Ash Authentication. SAML-only institutions may be supported through that broker's
approved protocol translation, not by adding an unreviewed SAML implementation to the first
Chimwemwe slice. Direct Google or Microsoft OIDC may be a separate shared-provider connection, but
must still converge on the same Ash OIDC strategy, `issuer`/`subject` account link, and server-side
membership resolution.

The proof must establish that the currently compatible Ash Authentication versions support the
required OIDC PKCE, nonce, callback, session, logout, and identity-link controls. It must also
prove that a pre-login home-realm discovery input cannot select a Chimwemwe tenant, placement,
membership, role, capability, or support grant.

## Decision questions

The accountable deciders must record an explicit answer and evidence for each question before
accepting ADR 0027:

| Question | Required evidence | Fails closed when |
| --- | --- | --- |
| Which Ash integration is supported? | Compatible `ash_authentication` and `ash_authentication_phoenix` versions for the pinned Ash/Phoenix versions, OIDC-strategy configuration, secret source, route boundary, and upgrade plan | A package/API incompatibility or missing PKCE/nonce/session control would require a custom workaround |
| Which identity arrangement is selected? | Named provider or federation broker, protocol/version, supported upstream school SSO, invited-user path, contract owner, and exit path | No evaluated arrangement is selected |
| How does an institution bring its SSO? | Broker connection model for Google Workspace, Microsoft Entra, OIDC, and any SAML-only institution; home-realm discovery rule; connection approval, disablement, audit, and offboarding path | An institution or browser input can dynamically trust an arbitrary issuer or select a Chimwemwe tenant/placement |
| Can the arrangement establish the required assurance? | MFA/step-up signals, verified claim mapping, recovery policy, service-identity separation, and assurance owner | A required assurance signal is absent, stale, or cannot be mapped safely |
| Can Chimwemwe validate a response safely? | Allowlisted issuer/discovery, redirect inventory, signature/JWK rotation procedure, audience/nonce/state/PKCE rules, and synthetic negative suite | Any validation input is missing, untrusted, replayed, expired, or inconsistent |
| Who may receive or change an account link? | Named-action policy, invitation/bootstrap procedure, duplicate/link-conflict handling, disabling and audit evidence | Provider profile data alone would create or change an actor, person, membership, or role |
| How is a tenant selected? | Server-side current-membership selection and reauthorization design, placement-reroute checks, non-disclosure cases | Browser or token state can choose a tenant, placement, role, or capability |
| How is support access constrained? | Grant policy, approval/purpose/ticket rule, capability vocabulary, assurance requirement, expiry/revocation, visible experience, and audit query | A grant is standing, unattributable, too broad, stale, or usable in another tenant |
| Can the school leave the arrangement safely? | Actor/link export and migration plan, session invalidation, audit continuity, deletion/retention terms, outage runbook, and user communications | A provider exit silently maps subjects differently or retains authority |

## Provider and federation evaluation

Evaluate only arrangements that can act as a standards-compatible external identity boundary for
Ash Authentication's server-side OIDC relying-party strategy. A school may federate its own
directory through the selected arrangement, but a federation assertion still has to pass the same
issuer, subject, account-link, session, and membership checks.

The decision pack compares named candidates against the following non-negotiable criteria:

1. Authorization-code flow with PKCE, server-side response validation, key rotation, controlled
   redirect registration, and protocol-version support.
2. A verified Ash Authentication OIDC/Phoenix compatibility proof with no custom callback, token
   validator, session implementation, or direct browser-token workaround.
3. Support for institutional federation and an approved invitation path for guardians, applicants,
   alumni, community members, and others without school-directory accounts.
4. MFA and step-up signals that can be verified, mapped, audited, and recovered without placing
   credentials or recovery secrets in Chimwemwe.
5. Stable opaque subject identifiers, account disablement/lifecycle signals, bounded profile-data
   exposure, and a documented conflict/linking path.
6. Incident, availability, support, privacy, residency, retention, deletion, export, and exit
   commitments suitable for the selected deployment and data classification.
7. Separate non-human service-identity support with minimal server-side scopes; no browser-token
   workaround.
8. A documented way to test logout, revocation, key compromise, provider outage, and migration.

Cost, administration fit, school federation availability, and operational ownership can break a tie
only after every non-negotiable criterion is satisfied. The decision record must name the candidate,
review date, rejected candidates and reasons, residual risks, compensating controls, accountable
owner, and trigger for re-evaluation.

## Synthetic validation design

All L0/L2 fixtures use synthetic opaque subjects, tenants, actors, memberships, roles, grants, and
ticket references. They contain no child data, real email addresses, credentials, raw tokens, or
provider configuration.

| Area | Required positive proof | Required negative proof |
| --- | --- | --- |
| Ash integration | A compatible Ash Authentication OIDC strategy and Phoenix route/session configuration handles one synthetic response without a custom token validator | Reject missing PKCE/nonce/state controls, resource-link ambiguity, secret in source, or an incompatibility hidden by a hand-written workaround |
| Institution SSO | A provisioned synthetic institution connection reaches the selected broker and returns only the broker's approved OIDC issuer to Ash Authentication | Reject arbitrary issuer/discovery URL, unapproved institution connection, altered home-realm hint, cross-school connection reuse, SAML assertion direct to Chimwemwe, and any pre-login input that selects tenant or placement |
| Callback | The server accepts exactly one valid authorization response and establishes the expected actor only after all validations pass | Reject wrong or unallowlisted issuer/audience/signature/redirect, missing or replayed state/nonce/PKCE, expired response, malformed claims, unknown key, and stale metadata |
| Key and incident rotation | A planned key transition keeps a legitimate response valid only through the reviewed metadata path | Reject unannounced, conflicting, revoked, or stale keys; logs disclose no token or sensitive validation detail |
| Session | A new opaque session is renewed only at the approved boundary and remains server-controllable | Reject fixation, theft/replay, idle/absolute expiry, logout, actor/session revocation, stale assurance, cross-origin state change, and cached sensitive response |
| Account link | An explicitly authorized action links a verified subject to the intended actor and records the evidence | Reject automatic actor/person/membership/role creation, duplicate subject links, subject changes, unauthorized unlinking, and provider-profile privilege changes |
| Tenant selection | An authenticated actor can select a current permitted membership and receive matching trusted placement | Reject altered cookie/header/route/claim selection, stale membership, placement move, entitlement change, role/capability change, inactive module, and cross-tenant existence inference |
| Support grant | An authorized support actor uses a visible, purpose-bound, least-privilege grant in its named tenant | Reject no purpose/ticket, inadequate assurance, missing approval, excess capability, tenant switch, stale/revoked/expired grant, background reuse, and incomplete start/use/end evidence |
| Recovery and outage | A provider-side recovery plus reviewed application invalidation path returns an approved actor safely | Reject local credential reset, unsupported recovery assertion, provider outage fail-open, and recovery that restores an old grant or session |

The eventual L2 test harness must assert named-action authorization at the domain boundary, not only
screen visibility. It must test both direct and generated public-interface paths after their own
boundary is accepted.

## Required runbooks and operating evidence

Before acceptance, the owners must review and store non-secret runbooks for:

- provider configuration change and redirect/issuer/key rotation;
- Ash Authentication dependency upgrade, OIDC strategy/configuration review, and safe route rollback;
- institution SSO connection onboarding, approval, disablement, domain/home-realm change, and
  federation-broker incident escalation;
- provider outage and degraded sign-in, including a clear fail-closed user message;
- suspected session theft, account-link conflict, account disablement, and actor-session revocation;
- step-up failure and recovery escalation;
- support-grant request, approval, start, visible use, expiry, revocation, and post-incident review;
- provider exit, account-link migration, data export/deletion, audit continuity, and rollback; and
- security, privacy, platform, and school-operations ownership/escalation contacts.

Evidence records must identify the test version, synthetic fixture source, policy/rule version,
environment, timestamp, reviewer, result, and residual-risk disposition. They must never contain
real secrets, raw tokens, credentials, restricted school data, or unrestricted log exports.

## Entry and exit criteria

The bounded L0 deliverable is complete only when the decision questions, evaluated candidates,
Ash compatibility proof, synthetic test design, runbook outlines, owners, and threat treatments
have been reviewed and linked to ADR 0027. The named deciders then either accept the ADR, reject it
with an alternative, or leave the gate explicitly open.

L2 implementation remains separately gated by an accepted identity/session/support decision,
accepted public browser/API boundary, exact authorized slice, selected deployment controls, and a
reviewed data classification. Passing `make check` validates repository consistency; it does not
select a provider, accept an ADR, or authorize real data.

## Related records

- [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- [Phase 2 entry proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Identity, people, relationships, and access proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, and TM-03
