# ADR 0027: Production identity, session, and support-access boundary

- Status: Proposed
- Date: 2026-09-26
- Accountable owner: Security architecture and platform engineering
- Deciders: Project owner, security architecture, platform engineering, and product experience
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
3. Use Ash Authentication as the server-side OIDC relying-party and session layer, with a selected
   federation broker or directly registered shared provider upstream. Selected as the proposed
   architecture. The actual broker and any direct provider are **not selected by this ADR** and
   must pass the linked decision evidence before this record can be accepted.
4. Give the browser a long-lived bearer token that directly carries tenant, role, or support
   authority. Rejected: browser-held authority makes revocation, tenant switching, assurance,
   safe logging, and support constraints harder to enforce and audit.

## Decision

Subject to accountable acceptance, Chimwemwe will use `ash_authentication` as the application
authentication boundary and `ash_authentication_phoenix` for the reviewed Phoenix routes and
session integration. The first browser strategy will be Ash Authentication's OIDC strategy using
the authorization-code flow with PKCE and a session-bound nonce. It will validate an authentication
response from a selected, standards-compatible identity arrangement and establish an
application-owned, opaque session. The browser receives only a secure, `HttpOnly`, host-scoped
session cookie; it never chooses a tenant, placement, role, capability, support grant, or repository
through a token claim, cookie, header, route, query parameter, or form value.

This is a protocol and trust-boundary decision, not a vendor selection. A later accountable
provider/federation selection must be recorded against the [decision evidence plan](../phase-2/identity-session-and-support-access-decision-evidence.md).
Until then this ADR remains Proposed and no production provider connection, public sign-in, callback,
or credential configuration is authorized. The explicitly requested local proof may use synthetic
credentials and a loopback-only Ash Authentication session to exercise the database boundary.

### Federation model

The preferred multi-institution topology is:

```text
school Google Workspace, Microsoft Entra, or other institutional IdP
    -> selected federation broker
    -> Ash Authentication OIDC strategy in Chimwemwe
    -> IdentityAccount / Actor -> current Membership -> tenant-defined authorization
```

The broker is responsible for the institution-specific connection and, where needed, translates a
standards-supported upstream protocol such as SAML into the one reviewed OIDC contract presented to
Chimwemwe. This gives each institution the option to bring its own Google, Microsoft, or other SSO
provider without requiring a new Ash strategy, callback route, or issuer trust rule for every
tenant. Direct Google or Microsoft sign-in may be approved for a shared population only if it uses
the same reviewed Ash OIDC/session boundary and account-link controls.

An identifier, domain, or institution choice supplied before sign-in may help the broker discover an
upstream connection. It is not a Chimwemwe tenant, placement, membership, or authorization selector.
After a response is verified, Chimwemwe resolves those meanings only from its current authoritative
state.

### Separate the four meanings

1. **External identity proof:** Ash Authentication's OIDC strategy accepts a subject only from the
   selected broker or directly registered provider's allowlisted issuer. Its verified issuer and
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

### Authentication and session rules

The first browser adapter must configure Ash Authentication's OIDC strategy for the
authorization-code flow, PKCE, and a one-time session-bound nonce. It stores a one-time attempt
record server side and verifies the exact redirect URI, state, nonce, PKCE result, issuer,
audience, signature, expiry, and approved authentication context before linking or resuming an
actor. Key discovery and issuer metadata are allowlisted, bounded, cached safely, and support
planned key rotation; unknown or conflicting keys fail closed. Provider client identifiers and
secrets are supplied only through the reviewed runtime secret mechanism, never resource DSL literals
or committed configuration.

The application session is opaque, random, server-controlled, and rotated at authentication,
tenant switch, assurance elevation, and other reviewed privilege boundaries. It has explicit
idle and absolute expiry, logout, global or actor-scoped revocation, and per-session invalidation.
Exact durations, refresh behaviour, assurance mapping, cookie policy, and selected deployment
controls are acceptance evidence, not defaults hidden in code. Browser state-changing requests
also require CSRF and origin protections; session and sensitive responses use no-store controls
and safe, non-disclosing errors and logs.

Credential enrolment, password recovery, MFA recovery, and credential revocation belong to the
selected identity arrangement. Chimwemwe recovery may disable an account link, invalidate
application sessions, or require a new approved invitation; it does not reset or receive provider
credentials. A non-human service identity uses a separately selected, narrowly scoped server-to-
server flow, never a browser cookie or a human support grant.

### Tenant selection and support access

After authentication, the server may present the memberships the actor can currently use. The
selected tenant is server-side session context and is resolved through current membership and
trusted placement; it is not trusted from an external claim. A membership, role, entitlement,
module activation, placement, or session change immediately affects the next named action and
cannot be bypassed with a stale page or session.

TM-03 support access is a future, separately authorized `SupportAccessGrant` boundary. A grant
must name the acting support actor, target tenant, approved purpose and ticket or approval
reference, least set of capabilities, required assurance, start and expiry, grantor, and audit
correlation. The server validates that it is still active on every elevated use. The support
experience visibly identifies the support actor, target tenant, purpose, and expiry; it has no
background or reusable standing mode. Revocation, expiry, lost assurance, changed scope,
missing purpose, or a tenant mismatch ends the elevated context immediately. A support grant is
not a tenant membership, does not create a person relationship, and cannot weaken normal module,
field, or action authorization.

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

- A compatible `ash_authentication` / `ash_authentication_phoenix` version, provider/federation
  evaluation, privacy review, operational ownership, and incident runbooks are required before the
  decision can be accepted.
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

The provider evaluation must establish data-processing, residency, retention, breach-notification,
availability, recovery, export, deletion, and contract-exit responsibilities before any real data
is used. The local proof's additive migration creates only synthetic-account/session records and
institutional SSO metadata with a secret reference; it is not a production schema approval. A later
production implementation must retain the stable application actor, make account-link migration
explicit and reversible, preserve tenant-qualified audit evidence, and prove that a provider switch
cannot grant or widen access.

## Validation evidence

The local proof supplies a database-backed account, revocable session-token records, and an
authenticated administration page for synthetic SSO metadata. It does not provide provider login,
account linking, membership resolution, support access, or production evidence. Before acceptance,
accountable reviewers must approve the
[identity, session, and support-access decision evidence plan](../phase-2/identity-session-and-support-access-decision-evidence.md), including:

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
  runbooks; and
- `make check` after the bounded implementation is authorized.

## Fallback and exit cost

Until the decision is accepted and implemented, no production identity route exists; the fallback
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
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, and TM-03
