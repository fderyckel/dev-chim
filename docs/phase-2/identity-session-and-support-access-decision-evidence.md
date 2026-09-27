# Identity, session, and support-access decision evidence plan

- Status: L0 decision evidence reviewed and accepted; Slice 2.0-D synthetic engineering entry open
- Date: 2026-09-26
- Decision correction: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Security architecture and platform engineering
- Current decision: [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- Superseded decision: [ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- Gate: Phase 2.0-D; L2 remains closed

## Purpose and current disposition

This plan supplies the L0 decision and validation contract for the first identity/session and
support-access boundary without treating planned tests or a local UI token as production evidence.
It does not decide people, guardianship, employment, admissions, membership provisioning, role
design, a public journey, or production directory synchronization.

**Current disposition: accepted for provider-neutral architecture entry.** ADR 0029 supersedes ADR
0027's ZITADEL selection. No provider or federation broker is mandatory. Microsoft Entra ID,
hybrid/on-premises Active Directory through Entra or a qualified federation gateway, Google
Workspace, generic OIDC, and SAML through a qualified adapter/gateway are supported profiles that
must pass the same contract.

No vendor credential exists in the repository, and no production callback, real external account,
directory sync, or public support experience exists. Slices 2.0-D.2a through D.2c now add the
closed, provider-neutral synthetic connection/link/invitation, opaque-session, and support-grant
foundation described in the [implementation evidence](identity-session-and-support-access-implementation-evidence.md).
The separate loopback-only proof still declares `ash_authentication` and
`ash_authentication_phoenix`, persists synthetic account/session and connection metadata in a
dedicated local PostgreSQL database, and stores only a secret reference. Neither boundary stores a
raw client secret, certificate, invitation/session/provider token, directory credential, or
assertion.

The [decision review](identity-session-and-support-access-decision-review.md) records the current
protocol/profile, framework, privacy, exit, and threat disposition. The
[operating runbook](../operations/identity-session-and-support-access.md) records the L0 operating
outline. Candidate qualification, contract/DPA execution, a real connection, implementation
evidence, selected-deployment qualification, and independent review remain later gates.

The local proof pins `ash_authentication` 5.0.0-rc.14 and
`ash_authentication_phoenix` 3.0.0-rc.11. Those paired versions retain compatibility with the
repository's pinned Ash/Phoenix releases and the zero-warning type-analysis gate. Slice 2.0-D must
qualify or replace the pair; no custom security callback is an accepted workaround.

## Local database-backed proof

Run `make auth-demo` to create/migrate the dedicated `chimwemwe_auth_demo` database, start a
loopback-only server on port 4012, and print a fresh synthetic local password. The `/sign-in` page
exercises Ash Authentication's password strategy, server-managed encrypted Phoenix session, and
database-backed revocable token resource. After sign-in, `/` displays the institutional connection
administration page.

The administration page creates draft OIDC or SAML connection metadata. Microsoft Entra ID,
Entra-connected hybrid Active Directory, Google Workspace, generic OIDC, and a qualified
SAML-gateway path all use those protocol contracts. A profile name is operator guidance, not an
authorization type. The record contains a display name, protocol, issuer/entity URL, client or
audience ID, allowed routing domains, lifecycle state, and deployment-secret reference. It cannot
accept, store, or display a raw secret.

This proof remains synthetic and local. The seeded account is not a school administrator, the
fixed synthetic tenant is not a tenant-selection mechanism, and signing in does not create a
membership, role, Person, learner relationship, provider callback, or directory link. Marking
metadata active proves only the draft lifecycle; it does not establish a real provider connection.

## Accepted application and federation seam

ADR 0029 retains `ash_authentication` as the initial application authentication layer and its OIDC
strategy as the reviewed inbound browser protocol. The first Phoenix integration uses
`ash_authentication_phoenix` only when the public browser boundary is separately authorized. Ash
validates identity proof and supports the application session; it does not replace Membership,
tenant-defined role/capability, placement, module-gate, or People/Relationships boundaries.

An approved direct OIDC issuer or qualified broker may present the OIDC contract. SAML-only and
AD FS arrangements terminate at a qualified gateway and do not add an unreviewed SAML parser to
the first core slice. On-premises Active Directory is connected through institution-managed Entra
synchronization/federation or a qualified gateway; Chimwemwe does not bind directly to LDAP.

A pre-login domain, institution choice, connection hint, discovery URL, issuer, or provider input
cannot select a Chimwemwe tenant, placement, membership, role, capability, or support grant. Every
active connection is allowlisted server-side and versioned. Slice 2.0-D must prove at least two
distinct synthetic issuer profiles use the same callback, external-identity-key, session, and
authorization contract with no provider-specific authority branch.

## Authentication and provisioning separation

Sign-in federation and directory lifecycle are independent. This slice may model provisioning
metadata, but no SCIM endpoint or provider API is authorized. If provisioning enters scope, it
must have a separate activation, secret/scope, named actions, idempotency, rate limiting,
reconciliation, retention, audit, incident response, and negative suite.

Provisioned users, groups, and organizational units remain external observations. Default
group-to-role mapping is none. A lifecycle event may propose or suspend an identity link and revoke
sessions through a reviewed action, but it cannot silently create or delete a Person, membership,
role, capability, learner/guardian/staff relationship, institutional-unit access, or retained
record.

## Decision questions

| Question | Accepted answer | Fails closed when |
| --- | --- | --- |
| Which application integration is supported? | Exact current Ash Authentication/Phoenix candidate pair; qualify it or replace it with a compatible reviewed stable pair. | A package/API incompatibility or missing PKCE/nonce/session control would require custom security code. |
| Which provider is selected? | None at architecture level. Each direct provider, broker, gateway, region, and hosting model is qualified independently. | A candidate's protocol, assurance, privacy, deployment, operations, or exit evidence fails. |
| How does an institution bring SSO? | Qualified Microsoft Entra, Google, or generic OIDC directly; SAML and AD FS through a qualified gateway; hybrid AD through Entra sync/federation or that gateway. | Input dynamically trusts metadata or establishes Chimwemwe tenant/placement authority; direct LDAP or unqualified direct SAML is proposed. |
| Can the connection establish assurance? | Verified, allowlisted evidence is mapped per connection and bounded by freshness. | Evidence is absent, stale, ambiguous, unsupported, or inferred from a group/role/profile. |
| Can Chimwemwe validate a response safely? | Allowlisted versioned connection, exact redirect, qualified algorithm, state, nonce, S256 PKCE, audience/signature/expiry checks, and key/certificate rotation rehearsal. | Any validation input is missing, untrusted, replayed, expired, or inconsistent. |
| Who may receive or change an account link? | A named invitation/bootstrap or conflict-resolution action owns a protocol-qualified external identity link; registration and email auto-linking are disabled. | Profile data or first login would create or change an actor, person, membership, role, relationship, or authority. |
| What may directory provisioning do? | A separately activated later boundary may submit lifecycle observations; application actions own accepted effects. Default group-to-role mapping is none. | A directory write directly grants access, crosses tenants, deletes retained records, or bypasses reconciliation. |
| How is a tenant selected? | An opaque membership reference is an untrusted request; the writer resolves current membership, tenant, placement, module gates, and capability before session rotation. | Browser, provider, directory, or token state establishes tenant, placement, role, or capability. |
| How is support constrained? | Non-impersonating, independently approved, one-tenant, purpose/ticket-bound, allowlisted, strongly assured, visible grants lasting at most 60 minutes. | A grant is standing, self-approved, unattributable, broad, stale, background-capable, or cross-tenant. |
| Can the institution leave safely? | Stable actors, immutable link history, explicit old/new subject mapping, session invalidation, audit continuity, export/deletion, and communication procedure. | Exit silently remaps subjects, loses application audit, retains authority, or depends on an unavailable vendor-only export. |

## Candidate qualification contract

Every direct provider, broker, gateway, credential authority, and provisioning adapter must satisfy:

1. Reviewed protocol/version, authorization-code plus PKCE where applicable, server-side response
   validation, controlled redirect registration, metadata/key/certificate rotation, and replay
   controls.
2. A verified Ash OIDC/Phoenix compatibility proof with no custom callback, token validator,
   direct-SAML parser, or browser-token workaround.
3. Institutional federation plus an approved invitation/recovery path for people without a school
   directory account.
4. Assurance and step-up evidence that is mapped, audited, fresh, recoverable, and denied when
   uncertain.
5. Stable opaque subject identifiers, explicit lifecycle signals, bounded profile data, and a
   conflict/linking procedure.
6. Incident, availability, support, privacy, residency, retention, deletion, export, and exit
   commitments suitable for the selected deployment and classification.
7. Separate non-human identity support with minimal short-lived credentials.
8. Rehearsed logout, revocation, key/certificate compromise, outage, connection disablement, and
   migration.
9. For hybrid directories, named ownership for sync/federation health and stale-state recovery;
   no direct LDAP or cached-password fallback.
10. For provisioning, least-scoped credentials, idempotent writes, tenant binding, rate limits,
    reconciliation, suspend/deprovision semantics, and no implicit authority mapping.

Cost and convenience may break a tie only after every non-negotiable criterion passes. Qualifying
one candidate never qualifies a different provider, broker, gateway, region, or hosting model.

## Synthetic validation design

All fixtures use synthetic opaque subjects, tenants, actors, memberships, roles, grants, and
ticket references. They contain no child data, real email address, credential, raw token, or real
provider configuration.

| Area | Required positive proof | Required negative proof |
| --- | --- | --- |
| Provider neutrality | Entra-style, Google-style, and generic OIDC fixtures use one connection/callback/account-link contract | Reject provider-specific authorization branches, hard-coded mandatory broker, or profile claims that change authority |
| Hybrid Active Directory | Synthetic Entra-synchronized and SAML-gateway topology reaches the same external-key boundary | Reject direct LDAP, arbitrary gateway metadata, stale sync as current application authority, and fallback to cached provider state |
| Ash integration | Compatible OIDC strategy and Phoenix route/session handle a synthetic response without custom validation code | Reject missing PKCE/nonce/state, secret in source, resource-link ambiguity, or incompatibility hidden by a workaround |
| Connection administration | Approved metadata is versioned, qualified, activated, disabled, and retired through named actions | Reject arbitrary issuer/discovery/entity ID, cross-school reuse, altered routing hint, direct unqualified SAML, and request-selected tenant/placement |
| Callback | Exactly one valid response establishes the expected external identity | Reject wrong issuer/audience/signature/redirect, replayed/missing state/nonce/PKCE, expired response, unknown key, stale metadata, and ambiguous subject |
| Rotation and incident | Planned metadata/key/certificate transition preserves only mapped legitimate identities | Reject unannounced/conflicting/revoked keys or silent subject remapping; logs disclose no sensitive validation detail |
| Session | A new opaque session rotates only at approved boundaries and remains server-controllable | Reject fixation, theft/replay, idle/absolute expiry, logout, revocation, stale assurance, cross-origin mutation, and cached sensitive response |
| Account link/bootstrap | Authorized action links verified external identity to pre-approved actor and atomically consumes invitation with audit/outbox evidence | Reject first-login authority, auto-created actor/person/membership/role, invitation replay/expiry/mismatch, duplicate link, and provider-profile privilege change |
| Tenant selection | Actor selects a current permitted membership and receives current trusted placement | Reject altered browser/provider/directory state, stale membership, placement move, entitlement/role/module change, and cross-tenant inference |
| Support grant | Authorized support actor uses visible purpose-bound least-privilege grant in one tenant | Reject missing purpose/ticket/approval/assurance, excess capability, tenant switch, stale/revoked/expired grant, background reuse, and incomplete evidence |
| Provisioning, if authorized | SCIM/provider fixture creates a quarantined lifecycle observation and reviewed action applies allowed effect | Reject group-to-role default, cross-tenant write, duplicate/replay/out-of-order event, over-broad attributes, destructive deprovision, and drift without reconciliation |
| Recovery/outage/exit | Reviewed provider recovery and explicit issuer migration return the same approved actor safely | Reject local credential bypass, outage fail-open, ambiguous subject mapping, old-session revival, and vendor-only data loss |

The eventual L2 harness asserts named-action authorization at the domain boundary, not only screen
visibility. Direct and generated public interfaces require their own accepted boundary.

## Required runbooks and operating evidence

The [operating runbook](../operations/identity-session-and-support-access.md) covers:

- connection qualification and provider/gateway-specific configuration;
- redirect, issuer/entity-ID, key/certificate, secret, and dependency rotation;
- institutional OIDC/SAML onboarding, Active Directory topology review, disablement, and offboarding;
- provider/gateway/directory-sync outage and fail-closed behavior;
- suspected session theft, identity-link conflict, lifecycle suspension, and session revocation;
- assurance/step-up failure and recovery escalation;
- support-grant request, approval, visible use, expiry, revocation, and review;
- provider/gateway exit, explicit subject migration, export/deletion, audit continuity, and rollback;
  and
- security, privacy, platform, school-operations, and institution-directory ownership contacts.

Evidence records identify test version, synthetic fixture source, connection/profile version,
environment, timestamp, reviewer, result, and residual-risk disposition. They never contain real
secrets, raw tokens, credentials, assertions, restricted school data, or unrestricted log exports.

## Entry and exit criteria

The corrected L0 decision pack is complete: ADR 0029, decision questions, connection profiles,
Ash compatibility seam, synthetic test design, runbook, owners, threat treatments, residual risks,
and accountable acceptance are linked. The linked implementation record now supplies the bounded
L0 D.2a–D.2c evidence; this document remains the decision and validation contract.

Bounded synthetic Slice 2.0-D engineering may continue. L2 remains separately gated by passing
the connected D.3 identity adapter, an accepted public browser/API boundary,
selected-connection and deployment controls, and reviewed data classification. Passing
`make check` validates repository consistency; it does not authorize real data or production use.

## Related records

- [ADR 0029](../adr/0029-provider-neutral-identity-federation-and-directory-connections.md)
- [Superseded ADR 0027](../adr/0027-production-identity-session-and-support-access.md)
- [Accountable decision review](identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Phase 2 entry proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Identity, people, relationships, and access proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Phase 2 entry decision register](entry-decision-register.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, TM-03, TM-09, and TM-11
