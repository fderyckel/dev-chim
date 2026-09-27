# Identity, session, and support-access decision evidence plan

- Status: L0 decision evidence reviewed and accepted; Slice 2.0-D synthetic engineering entry open
- Date: 2026-09-26
- Decision date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Security architecture and platform engineering
- Decision record: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- Gate: Phase 2.0-D; L2 remains closed

## Purpose and current disposition

This plan supplied the L0 decision pack for the first identity/session and support-access boundary
without pretending that a planned test or a local UI token is completed production evidence. It
does not decide people, guardianship, employment, admissions, membership provisioning, role design,
or a public journey.

**Current disposition: accepted for architecture entry.** The accountable review selected ZITADEL
Cloud in its Europe data region as the first federation broker and accepted ADR 0027. No vendor
credential exists in the repository, and no production callback, account-link, membership, or
support-access implementation exists. A loopback-only local proof declares `ash_authentication` and
`ash_authentication_phoenix`, persists synthetic account/session/SSO-connection records in a
dedicated local PostgreSQL database, and provides an authenticated administration page. It stores
only a secret reference, never a raw client secret, certificate, access token, or refresh token.
The [decision review](identity-session-and-support-access-decision-review.md) records the current
primary-source provider, framework, privacy, exit, and threat disposition, and the
[operating runbook](../operations/identity-session-and-support-access.md) records the L0 operating
outline. Contract/DPA execution, a real provider connection, implementation evidence, selected-
deployment qualification, and independent review remain later gates. ADR acceptance opens bounded
Slice 2.0-D engineering; it does not close Slice 2.0-D or L2.

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
other OIDC provider, or a SAML connection through the accepted ZITADEL broker. It records a name,
issuer URL, client ID, allowed domains, lifecycle state, and a deployment-secret reference. It can
activate or disable a connection. It deliberately cannot accept, store, or display a raw secret.

This proof remains synthetic and local: the seeded account is not a school administrator, the
fixed synthetic tenant is not a tenant-selection mechanism, and signing in does not create a
membership, role, Person, learner relationship, or provider callback. A record changing from draft
to active means only that the metadata lifecycle works; it does not activate Google, Microsoft, or
another provider until the ZITADEL and provider-registration implementation evidence below is complete.

## Accepted Ash and federation seam

ADR 0027 accepts `ash_authentication` as Chimwemwe's application authentication layer and its OIDC
strategy as the one reviewed inbound browser protocol. The first Phoenix integration will use
`ash_authentication_phoenix` only when the public browser boundary is separately authorized. Ash
Authentication therefore validates sign-in and manages the application session; it does not replace
our `Membership`, tenant-defined role/capability, placement, module-gate, or People/Relationships
boundaries.

For an institution that already uses Google Workspace, Microsoft Entra, or another SSO provider,
ZITADEL owns that institution's approved upstream connection and offers one reviewed
OIDC issuer to Ash Authentication. SAML-only institutions may be supported through that broker's
approved protocol translation, not by adding an unreviewed SAML implementation to the first
Chimwemwe slice. Direct Google or Microsoft OIDC is outside the accepted first topology and
requires a new review trigger.

Slice 2.0-D must establish that the currently compatible Ash Authentication versions support the
required OIDC PKCE, nonce, callback, session, logout, and identity-link controls. It must also
prove that a pre-login home-realm discovery input cannot select a Chimwemwe tenant, placement,
membership, role, capability, or support grant.

## Decision questions

The accountable deciders recorded the following disposition when accepting ADR 0027. Required
implementation evidence still fails closed as shown:

| Question | Accepted answer | Fails closed when |
| --- | --- | --- |
| Which Ash integration is supported? | Exact current candidate pair: `ash_authentication` 5.0.0-rc.14 and `ash_authentication_phoenix` 3.0.0-rc.11; Slice 2.0-D must qualify it or replace it with a compatible reviewed stable pair | A package/API incompatibility or missing PKCE/nonce/session control would require a custom workaround |
| Which identity arrangement is selected? | ZITADEL Cloud Europe, OIDC to Chimwemwe, approved institutional OIDC/SAML upstream, and ZITADEL-native invited identities | Contract, privacy, deployment, or integration evidence fails |
| How does an institution bring its SSO? | An approved ZITADEL organization connection with audited onboarding, disablement, and offboarding; domain discovery is routing only | An input dynamically trusts an issuer or establishes Chimwemwe tenant/placement authority |
| Can the arrangement establish the required assurance? | Allowlisted `acr`/`amr` plus `auth_time`; initial support identities are ZITADEL-native and require passkey/WebAuthn MFA | A required assurance signal is absent, stale, ambiguous, or not mapped per connection |
| Can Chimwemwe validate a response safely? | One allowlisted issuer/discovery origin, exact redirect, RS256, state, nonce, S256 PKCE, audience/signature/expiry checks, and key-rotation rehearsal | Any validation input is missing, untrusted, replayed, expired, or inconsistent |
| Who may receive or change an account link? | A named invitation/bootstrap or conflict-resolution action owns a unique `(issuer, subject)` link; initial administration uses a hashed, single-use, tenant-bound, 30-minute invitation to pre-approved actor/membership/role state; registration and email auto-linking are disabled | Provider profile data or first login would create or change an actor, person, membership, role, or authority |
| How is a tenant selected? | An opaque membership reference is an untrusted request; the writer resolves current membership, tenant, placement, module gates, and capability before session rotation | Browser or token state establishes a tenant, placement, role, or capability |
| How is support access constrained? | Non-impersonating, independently approved, one-tenant, purpose/ticket-bound, allowlisted, strongly assured, visible grants lasting at most 60 minutes | A grant is standing, self-approved, unattributable, broad, stale, background-capable, or cross-tenant |
| Can the school leave the arrangement safely? | Stable application actors, account-link export, reviewed dual issuer, explicit subject mapping, session invalidation, audit continuity, and deletion/communication procedure | An exit silently remaps subjects, loses application audit, or retains authority |

## Provider and federation evaluation

The [decision review](identity-session-and-support-access-decision-review.md) evaluates ZITADEL,
Auth0, Keycloak, direct institutional providers, and Chimwemwe-owned credentials. Future
re-evaluation must consider only arrangements that can act as a standards-compatible external identity boundary for
Ash Authentication's server-side OIDC relying-party strategy. A school may federate its own
directory through the selected arrangement, but a federation assertion still has to pass the same
issuer, subject, account-link, session, and membership checks.

The accepted comparison applied the following non-negotiable criteria:

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

Cost, administration fit, school federation availability, and operational ownership could break a
tie only after every non-negotiable criterion was satisfied. The decision review names the
candidate, review date, rejected candidates and reasons, residual risks, compensating controls,
accountable owner, and triggers for re-evaluation.

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
| Account link and bootstrap | An explicitly authorized action links a verified subject to the intended actor; initial administration consumes the accepted pre-approved invitation atomically with audit/outbox evidence | Reject first-login authority, automatic actor/person/membership/role creation, invitation replay/expiry/identity or tenant mismatch, duplicate subject links, subject changes, unauthorized unlinking, and provider-profile privilege changes |
| Tenant selection | An authenticated actor can select a current permitted membership and receive matching trusted placement | Reject altered cookie/header/route/claim selection, stale membership, placement move, entitlement change, role/capability change, inactive module, and cross-tenant existence inference |
| Support grant | An authorized support actor uses a visible, purpose-bound, least-privilege grant in its named tenant | Reject no purpose/ticket, inadequate assurance, missing approval, excess capability, tenant switch, stale/revoked/expired grant, background reuse, and incomplete start/use/end evidence |
| Recovery and outage | A provider-side recovery plus reviewed application invalidation path returns an approved actor safely | Reject local credential reset, unsupported recovery assertion, provider outage fail-open, and recovery that restores an old grant or session |

The eventual L2 test harness must assert named-action authorization at the domain boundary, not only
screen visibility. It must test both direct and generated public-interface paths after their own
boundary is accepted.

## Required runbooks and operating evidence

The accepted [operating runbook](../operations/identity-session-and-support-access.md) outlines:

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

The bounded L0 deliverable is complete: the decision questions, evaluated candidates, Ash
compatibility seam, synthetic test design, runbook outline, owners, threat treatments, residual
risks, and accountable acceptance are linked to ADR 0027. This is decision evidence, not completed
implementation evidence.

Bounded synthetic Slice 2.0-D engineering may begin under the accepted sequence. L2 remains
separately gated by passing identity/session/support implementation evidence, an accepted public
browser/API boundary, selected deployment controls, and a reviewed data classification. Passing
`make check` validates repository consistency; it does not authorize real data or production use.

## Related records

- [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- [Accountable decision review](identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Phase 2 entry proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Identity, people, relationships, and access proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, and TM-03
