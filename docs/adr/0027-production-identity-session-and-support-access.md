# ADR 0027: Production identity, session, and support-access boundary

- Status: Accepted
- Date: 2026-09-26
- Decision date: 2026-09-27
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Security architecture and platform engineering
- Deciders: Project owner, security architecture, platform engineering, and product experience
- Selected arrangement: ZITADEL Cloud Europe as federation broker; Chimwemwe as the OIDC relying
  party through Ash Authentication
- Conditions: no real identity, public route, or L2 claim until Slice 2.0-D implementation evidence,
  selected-deployment controls, contractual/privacy review, and the separate public boundary pass
- Supersedes: None

## Context

The production identity boundary is still deliberately absent. `ExecutionContext` proves only that
internal callers received trusted context, and ADR 0022's local token is a loopback-only,
synthetic qualification aid. Neither is a sign-in mechanism, a session, an account directory, or a
support-access grant.

The production core already uses Ash and Phoenix. The bounded local proof now declares
`ash_authentication` and `ash_authentication_phoenix` so it can exercise their maintained password,
token-revocation, Phoenix-session, and router seams. That proof is loopback-only and does not make
either a public or production route. Any later identity implementation must keep using the maintained
Ash extension rather than create a parallel, hand-written callback, token-validation, or session framework.

Chimwemwe will serve people with different relationships to a learning institution: learners,
educators, education administrators, non-academic staff, parents and guardians, admissions
invitees, alumni, and community members. An identity account proves only a particular external
identity was validated. It must not by itself create a Person record, a tenant membership, a role,
a relationship to a learner, or an authorization outcome. Those decisions belong to separately
governed People, Relationships, Membership, and Access work.

Phase 2 nevertheless needs a durable boundary before any public browser workflow, production
session, or support action can run. In particular, TM-03 requires attributable, constrained,
revocable support access rather than a hidden operator bypass.

## Decision drivers

- Keep identity proof, tenant membership, authorization, and person/relationship semantics
  separately reviewable.
- Support school federation while retaining safe invitation and recovery paths for people who do
  not arrive through an institutional directory.
- Reuse Ash Authentication's reviewed OIDC and Phoenix integration while retaining Chimwemwe's
  existing tenant-qualified membership and authorization boundary.
- Establish trusted, server-side actor, tenant, assurance, purpose, placement, and correlation
  context before a named action runs.
- Make expired, revoked, stale, forged, or cross-tenant access fail closed.
- Provide a bounded, inspectable support path without creating a standing super-user session.
- Avoid committing real credentials, provider configuration, or personal data while the work
  remains L0.

## Considered options

1. Promote the UI-1A local token registry to production. Rejected: it has no independently
   reviewed identity proof, session lifecycle, revocation, recovery, support grant, or public
   boundary, and ADR 0022 explicitly forbids that promotion.
2. Make Chimwemwe the initial credential authority and build password, recovery, MFA, federation,
   and account-lifecycle operations in the product core. Rejected for the first production
   boundary: it creates a large credentials and recovery security surface before a school journey
   or operating envelope is selected.
3. Use Ash Authentication as the server-side OIDC relying-party and session layer, with ZITADEL
   Cloud Europe as the first federation broker. Selected. ZITADEL provides one allowlisted OIDC
   issuer to Chimwemwe while brokering approved institutional OIDC or SAML providers and native
   invited identities. The provider and region remain subject to contractual, privacy, deployment,
   and implementation gates before real use.
4. Give the browser a long-lived bearer token that directly carries tenant, role, or support
   authority. Rejected: browser-held authority makes revocation, tenant switching, assurance,
   safe logging, and support constraints harder to enforce and audit.

## Decision

Chimwemwe will use `ash_authentication` as the application
authentication boundary and `ash_authentication_phoenix` for the reviewed Phoenix routes and
session integration. The first browser strategy will be Ash Authentication's OIDC strategy using
the authorization-code flow with PKCE and a session-bound nonce. It will validate an authentication
response from a selected, standards-compatible identity arrangement and establish an
application-owned, opaque session. The browser receives only a secure, `HttpOnly`, host-scoped
session cookie; no token claim, cookie, header, route, query parameter, or form value establishes
tenant, placement, role, capability, support-grant, or repository authority.

The accepted first broker is ZITADEL Cloud in its Europe data region. This is a provider selection
for Slice 2.0-D engineering, not a deployment or production-readiness decision. Contract and DPA
execution, subprocessor and transfer review, an exact non-production integration, operational
rehearsal, selected-deployment controls, and independent review remain required before real
identity data or a public sign-in. The local proof may continue to use synthetic credentials and a
loopback-only Ash Authentication session to exercise the database boundary.

### Federation model

The preferred multi-institution topology is:

```text
school Google Workspace, Microsoft Entra, or other institutional IdP
    -> approved ZITADEL organization connection
    -> ZITADEL Cloud Europe
    -> Ash Authentication OIDC strategy in Chimwemwe
    -> IdentityAccount / Actor -> current Membership -> tenant-defined authorization
```

ZITADEL is responsible for the institution-specific connection and, where needed, translates a
standards-supported upstream protocol such as SAML into the one reviewed OIDC contract presented to
Chimwemwe. This gives each institution the option to bring its own Google, Microsoft, or other SSO
provider without requiring a new Ash strategy, callback route, or issuer trust rule for every
tenant. A ZITADEL-native invitation supplies the initial path for people without an institutional
account. Direct Google or Microsoft sign-in is outside the accepted first topology and is a review
trigger even if it would use the same Ash OIDC/session boundary.

An identifier, domain, or institution choice supplied before sign-in may help the broker discover an
upstream connection. It is not a Chimwemwe tenant, placement, membership, or authorization selector.
After a response is verified, Chimwemwe resolves those meanings only from its current authoritative
state.

### Separate the four meanings

1. **External identity proof:** Ash Authentication's OIDC strategy accepts a subject only from the
   selected broker's allowlisted issuer. Its verified issuer and
   subject identify the proof; its unverified profile fields do not grant authority.
2. **Application actor and account link:** the application keeps a stable actor and a unique,
   auditable link from verified `(issuer, subject)` to that actor. Ash Authentication's identity
   resource is the implementation seam for that link; it must not retain provider access/refresh
   tokens unless a later named integration requires them and a separate security decision approves
   the retention. A successful sign-in cannot silently create a membership or link an actor to a
   Person. First association, invitation, and disabling an association are separately authorized
   named actions.
3. **Tenant membership and access:** the server resolves current membership, tenant-defined roles,
   capabilities, module gates, and placement from authoritative state. A user selects only among
   currently permitted memberships through a server action; the selection is rechecked before each
   named action. A school category such as “educator” or “guardian” is not a production role
   constant and has no authorization effect by itself.
4. **Person and relationship context:** a future People and Relationships boundary may associate
   an actor with one or more people, guardianships, employments, applications, or community
   affiliations. It is outside this ADR and cannot be inferred from an identity-provider claim.

The initial tenant-administrator bootstrap is not “first login wins.” A separately governed
provisioning workflow must prepare the tenant-owned actor, membership, tenant-defined role
assignment, and one-time invitation before authentication. The public acceptance action binds the
verified `(issuer, subject)` only to that pre-approved actor through a single-use, hashed,
tenant-bound invitation that expires after 30 minutes. It accepts no role, capability, tenant, or
placement from the browser, records audit and outbox evidence, invalidates the invitation on exact
success, and fails closed on replay, changed identity, expiry, existing link, or tenant mismatch.
No hidden or standing break-glass administrator is included in the initial slice.

### Authentication and session rules

The first browser adapter must configure Ash Authentication's OIDC strategy for the
authorization-code flow, PKCE, and a one-time session-bound nonce. It stores a one-time attempt
record server side and verifies the exact redirect URI, state, nonce, PKCE result, issuer,
audience, signature, expiry, and approved authentication context before linking or resuming an
actor. Key discovery and issuer metadata are allowlisted, bounded, cached safely, and support
planned key rotation; unknown or conflicting keys fail closed. Provider client identifiers and
secrets are supplied only through the reviewed runtime secret mechanism, never resource DSL literals
or committed configuration.

The accepted configuration requires `code_verifier true`, generated nonce, state validation,
`registration_enabled? false`, a provider-identity resource keyed by `(issuer, subject)`,
`trust_email_verified? false`, RS256, an exact callback allowlist, and one allowlisted ZITADEL
issuer/discovery origin. Chimwemwe requests no `offline_access` and does not retain provider access
or refresh tokens after callback processing. Any custom callback, token validator, or browser-token
workaround fails the decision.

The application session is database-backed, opaque, random, server-controlled, and rotated at authentication,
tenant switch, assurance elevation, and other reviewed privilege boundaries. It has explicit
idle and absolute expiry, logout, global or actor-scoped revocation, and per-session invalidation.
The one-time sign-in attempt expires after ten minutes. An ordinary application session has a
30-minute idle and eight-hour absolute lifetime. An elevated support session has a ten-minute idle
and at most 60-minute absolute lifetime and can never outlive its grant. The browser cookie is
`Secure`, `HttpOnly`, host-only, `SameSite=Lax`, and uses a `__Host-` name. Browser state-changing
requests also require CSRF and origin protections; session and sensitive responses use no-store
controls and safe, non-disclosing errors and logs.

Credential enrolment, password recovery, MFA recovery, and credential revocation belong to
ZITADEL or the approved upstream institutional provider. Chimwemwe recovery may disable an account link, invalidate
application sessions, or require a new approved invitation; it does not reset or receive provider
credentials. A non-human service identity uses a separate ZITADEL service account with short-lived
`private_key_jwt` credentials and a stable application service actor. Personal access tokens,
browser cookies, human support grants, and provider roles are forbidden for service identity.

### Tenant selection and support access

After authentication, the server may present the memberships the actor can currently use. The
browser may return an opaque membership reference only as an untrusted selection request. The
selected tenant is server-side session context and is resolved on the writer through current membership and
trusted placement; it is not trusted from an external claim. A membership, role, entitlement,
module activation, placement, or session change immediately affects the next named action and
cannot be bypassed with a stale page or session.

TM-03 support access is a future, separately authorized `SupportAccessGrant` boundary. A grant
must name the acting support actor, target tenant, approved purpose and ticket or approval
reference, least set of capabilities, required assurance, start and expiry, grantor, and audit
correlation. The grant lasts at most 60 minutes, uses no wildcard, and requires a separate
authorized grantor; the support actor cannot self-approve. The initial support population uses
ZITADEL-native identities with WebAuthn/passkey MFA. Elevation requires an allowlisted `acr`/`amr`
mapping and `auth_time` no older than five minutes. Missing, ambiguous, or stale assurance denies
elevation. The server validates that the grant is still active on every elevated use. The support
experience visibly identifies the support actor, target tenant, purpose, and expiry; it has no
background or reusable standing mode. Revocation, expiry, lost assurance, changed scope,
missing purpose, or a tenant mismatch ends the elevated context immediately. A support grant is
not a tenant membership, does not create a person relationship, and cannot weaken normal module,
field, or action authorization. The initial support path never impersonates another user and
cannot delegate grant administration, account-link administration, arbitrary role/grant changes,
bulk export, or background work.

## Consequences

### Positive

- The first production browser journey can rely on a reviewed identity proof while authority
  remains in the application’s tenant-qualified domain boundary.
- The model supports both school federation and invited people without treating either as an
  authorization shortcut.
- A provider or federation arrangement can change without changing actor identity, membership,
  roles, or person relationships.
- Support work becomes attributable, finite, purpose-bound, and independently revocable.

### Negative

- The selected managed broker introduces contract, subprocessor, transfer, regional-processing,
  availability, recovery, and exit dependencies that must pass before real use.
- The currently compatible `ash_authentication` / `ash_authentication_phoenix` pair is a release
  candidate and must pass the complete implementation gate or be upgraded to a reviewed stable pair.
- The first public workflow must wait for application session, callback, tenant-selection, and
  support controls rather than reusing UI-1A.
- Account-linking and relationship semantics require later named actions and cannot be solved by
  identity-provider profile synchronisation.
- The selected arrangement creates an external trust boundary and a recovery dependency that must
  be monitored and rehearsed.

## Security, privacy, operability, and migration effects

Identity proof, actor association, membership resolution, tenant placement, module gates, and
support grants remain server-authoritative and fail closed. Session and support records must carry
only the minimum safe identifiers and evidence needed for revocation and audit; raw tokens,
credentials, provider assertions, child data, and detailed denial reasons must not enter logs,
telemetry, fixtures, or committed evidence.

The public-source review selects ZITADEL Cloud Europe while explicitly recording that its DPA
permits subprocessors and protected transfers outside the EU/EEA and that its export does not
carry the event stream or every credential artifact. Contract execution must establish
data-processing, residency, retention, breach-notification, availability, recovery, export,
deletion, and exit responsibilities before any real data is used. The local proof's additive migration creates only synthetic-account/session records and
institutional SSO metadata with a secret reference; it is not a production schema approval. A later
production implementation must retain the stable application actor, make account-link migration
explicit and reversible, preserve tenant-qualified audit evidence, and prove that a provider switch
cannot grant or widen access.

## Validation evidence

The local proof supplies a database-backed account, revocable session-token records, and an
authenticated administration page for synthetic SSO metadata. It does not provide provider login,
account linking, membership resolution, support access, or production evidence. The accountable
reviewers approved the [decision evidence plan](../phase-2/identity-session-and-support-access-decision-evidence.md)
and [decision review](../phase-2/identity-session-and-support-access-decision-review.md) for
architecture entry. Slice 2.0-D implementation must still supply:

- an evaluated Ash Authentication integration and provider/federation arrangement with a secure
  exit path, named operational owner, assurance/recovery mapping, and data-processing disposition;
- synthetic callback and session tests for forged or wrong issuer/audience/signature, replayed or
  missing state/nonce/PKCE, redirect mismatch, key rotation, fixation, idle/absolute expiry,
  logout, revocation, recovery, and safe error/logging behaviour;
- tenant-selection and authorization tests for stale or altered browser state, changed membership,
  placement, entitlement, role, and module activation, including non-disclosure across tenants;
- TM-03 negative tests for missing purpose, insufficient assurance, expired/revoked grant,
  cross-tenant reuse, capability widening, background reuse, and complete start/use/end audit;
- incident, key-rotation, provider-outage, account-link, session-revocation, and support-grant
  rehearsal against the accepted [operating runbook](../operations/identity-session-and-support-access.md); and
- `make check` after the bounded implementation is authorized.

## Accountable decision

On 2026-09-27, François accepted this ADR and the ZITADEL Cloud Europe candidate after reviewing
the provider comparison, Ash compatibility seam, threat treatment, session and support limits,
privacy/exit constraints, test design, and operating outline. The acceptance authorizes the
synthetic, non-production Slice 2.0-D engineering entry in the already accepted Phase 2 sequence.

The following conditions remain binding:

- no real identity, provider credential, institutional connection, public callback, or L2 claim
  exists until the complete Slice 2.0-D implementation evidence passes;
- Europe-region selection does not replace DPA, subprocessor, transfer, retention, deletion,
  breach, and independent privacy review;
- ZITADEL organization, role, domain, profile, or assurance claims never create Chimwemwe
  membership, capability, institutional relationship, tenant placement, or support authority;
- support remains non-impersonating, separately approved, visible, tenant-specific, strongly
  assured, least-privilege, short-lived, and rechecked on every use; and
- failure of a provider, dependency, assurance mapping, operational rehearsal, or exit requirement
  closes or removes the affected route instead of weakening the boundary.

## Fallback and exit cost

Until the decision is implemented and its later gates pass, no production identity route exists; the fallback
is to keep L2 and public workflows closed and retain UI-1A solely as its removable local synthetic
qualification harness. If the selected provider/federation arrangement cannot satisfy the
evidence, do not weaken session or support controls—select another reviewed arrangement or keep
the gate closed.

Changing a selected arrangement requires a review of account-link migration, dual-validation
period, session invalidation, user communication, recovery, audit continuity, data export/deletion,
and rollback. No provider exit may silently remap an external subject to a different actor or
retain a standing support grant.

## Review triggers

- Selection or material change of an Ash Authentication strategy, identity provider, federation
  broker, credential model, external directory, service-identity mechanism, or hosting/deployment
  environment.
- Introduction of a public sign-in, account linking, user provisioning, invitation, recovery,
  step-up, tenant switch, or person/guardian relationship flow.
- Any session, identity, support-access, cross-tenant, privacy, or audit incident.
- Addition of a staff, learner, guardian, applicant, alumni, or community journey that needs a
  different assurance, relationship, or lifecycle rule.

## Related records

- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0022](0022-local-read-only-browser-core-bridge.md)
- [ADR 0024](0024-assurance-proportionality-and-module-evolution.md)
- [Phase 2 entry proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Identity, people, relationships, and access proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [Identity, session, and support-access decision review](../phase-2/identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, and TM-03
