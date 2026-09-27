# Phase 2 identity, people, relationships, and access implementation proposal

- Status: Proposed planning artifact; it authorizes no implementation or release-level change
- Owner: Product and platform engineering, with learning-institution domain ownership and security/privacy review
- Decision authority: Project Owner for a later Phase 2 sequence extension; accountable deciders for new ADRs
- Scope: detailed planning for existing Slice 2.0-D and a proposed follow-on People, Relationships, and Access sequence
- Review trigger: identity-provider selection, session or support-access decision, account-to-person linkage, child/guardian policy, membership lifecycle, role administration, public client, or any real-data use

## Purpose

Chimwemwe serves people in several overlapping contexts: learners, educators, academic and
non-academic administrators, guardians, applicants, alumni, and community members. Those labels
should improve a person's workflow and language, but they must not become a fixed production role
hierarchy or a client-side authorization rule.

This proposal turns that principle into an implementation order. It keeps four questions separate:

1. **Identity and session:** who or what has proved control of a credential now?
2. **Person and relationship:** which human is represented, and how are they related to learners,
   institutional units, or the wider learning community?
3. **Membership and authority:** which tenant may the authenticated actor enter, and which
   tenant-defined capabilities may they exercise there?
4. **Experience:** which safe, useful tasks, language, and starting workspace should be presented
   for the person's current context?

The existing Phase 2 plan owns the first of those questions in Slice 2.0-D. The proposed follow-on
sequence owns the second and third. It is intentionally not a generic `users` module, a setup
wizard, a fixed school-role catalogue, or a generic administrative CRUD surface.

## Current position and authority

The accepted Phase 2.0/2.1 sequence already makes production identity, session, and support access
an L2 gate. It also intentionally excludes learner, guardian, staff, household, identity-account,
and employment records from the first institutional-structure module. See the
[Phase 2 entry proposal](phase-2-entry-and-school-structure-proposal.md) and the
[entry decision register](../phase-2/entry-decision-register.md).

Consequently:

- Accepted ADR 0027 selects ZITADEL Cloud Europe and closes Slice 2.0-D's L0 architecture decision
  gate. Bounded synthetic engineering may proceed under the authorized Phase 2 sequence, but no
  real provider connection, public session, L2 claim, or real-data authority exists yet.
- The People, Relationships, and Access sequence below is a **proposed Phase 2.2 follow-on**. This
  document permits no code, migration, resource, capability, public route, session, or real data
  for it. Project-owner authorization and the stated ADRs are required before its L0 work is treated
  as an active slice.
- The local UI-1A token and fixture data remain a removable qualification mechanism. They cannot be
  extended into a production account, login, invitation, or support-access implementation.

## Product model: contexts are not roles

One person can hold more than one context at the same time. For example, an educator may also be a
guardian, an alumnus may volunteer for the institution, and a finance employee may be a guardian.
Conversely, a learner, applicant, alumnus, or community contact may not need an account at all.

| Context | Domain fact to model | Authority rule | Experience implication |
| --- | --- | --- | --- |
| Learner/student | A person and, later, an enrolment or participation record | Learner status is not a role; a learner account, if allowed, receives only explicit capabilities | Age- and task-appropriate learning tasks; no assumption that every learner signs in |
| Educator or academic administrator | A person plus a staff affiliation and, later, teaching or leadership assignments | Capabilities come from tenant-defined roles and any future explicit scope contract | Browser-dense operational work and phone-first immediate tasks may differ |
| Finance, IT, nurse, or other non-academic administrator | A person plus the relevant staff affiliation | Access is a narrow capability set; finance, health, and support rules need their own domain safeguards | Separate workspaces and stronger confirmation or assurance where the owning domain requires it |
| Parent or guardian | A person-to-person guardian relationship | A relationship does not itself grant access; the server evaluates membership, capabilities, and relationship policy for each named action | A family-oriented view starts from permitted linked learners, never a broad learner search |
| Invited applicant | A pre-admission person/contact and a future application invitation | No school membership, role, or general tenant access follows from an invitation | A narrowly scoped application journey, designed in the Admissions module |
| Alumni or community member | A person and a typed affiliation or relationship when an approved use case needs one | No default staff, learner, guardian, or school-data authority | A later engagement or community journey; no placeholder dashboard or implied access |

This table is deliberately a planning vocabulary, not an approved schema or a final set of
relationship types. In particular, `student` describes educational participation, not an identity
or authorization constant; enrolment remains a later owner decision.

## Target trust flow

The production request path must keep authentication, person context, and authorization separate:

```text
identity provider verifies credential
  -> server verifies callback or token and establishes a session
  -> server resolves a stable actor and permitted tenant membership
  -> server resolves tenant placement and the current module gates
  -> authoritative writer resolves current tenant-defined capabilities
  -> named action evaluates its relationship and domain rules
  -> server returns only the permitted task data and experience state
```

The browser cannot select an actor, tenant, repository, placement, capability, role graph, support
grant, or policy result. A visible tenant or institutional-unit chooser is a request for context;
the server validates it and it never expands authority. A UI workspace is a consequence of the
result, not an authorization source.

## Required decisions before implementation

### Production identity, session, and support-access ADR

Slice 2.0-D now has accepted [ADR 0027](../adr/0027-production-identity-session-and-support-access.md),
which adopts Ash Authentication as the application identity/session layer and selects ZITADEL
Cloud Europe for the first federation-broker/OIDC candidate. Its linked
[decision review](../phase-2/identity-session-and-support-access-decision-review.md) accepts the
account-link, application-session, tenant-selection, assurance, service-identity, and
non-impersonating support-grant boundaries. Slice 2.0-D implementation must prove these
requirements before L2:

- stable provider/subject identity, verified issuer/audience/signature handling, account-linking
  rules, and a safe migration or provider exit path;
- sign-in, callback, session creation and rotation, idle and absolute expiry, logout, revocation,
  credential recovery, assurance or step-up, and service-identity behaviour;
- tenant discovery and selection after authentication, without allowing an untrusted request to
  choose a database, placement, or a membership it does not hold;
- secure cookie, CSRF, origin, content-security, redirect, no-store, secret/key rotation, telemetry
  redaction, incident response, and deployment ownership requirements;
- accountable recovery for lost credentials and account-linking conflicts without giving support an
  unbounded impersonation path; and
- separately authorized support grants with explicit tenant, approved purpose, ticket or approval
  reference, assurance, bounded capabilities, expiry, revocation, and start/use/end evidence.

The decision review compares a managed external provider, standards-based institution-managed
federation, and self-managed alternatives. ZITADEL Cloud Europe is selected because it meets the
architecture criteria with explicit lifecycle, assurance, recovery, revocation, audit, privacy,
and exit conditions; naming the service alone would not have satisfied the gate.

### People, relationship, and account-association ADR

Before the proposed Phase 2.2 persistence work, a separate ADR must define the following bounded
model and data-lifecycle choices:

- whether a technical `Actor` is global or tenant-scoped, and how one verified external identity
  maps to that actor;
- the cardinality and lifecycle of `Actor`, `Person`, tenant `Membership`, staff affiliation,
  guardian relationship, and an institutional or community affiliation;
- which relationships are first-class, their direction, evidence/provenance, validity period,
  correction, suspension, and end semantics;
- the separation of person identity from learner participation, enrolment, employment, payroll,
  medical/safeguarding records, household data, admissions, and alumni engagement;
- data classification, minimization, retention, legal hold, correction, account unlinking, merge,
  duplicate-resolution, and erasure responsibilities; and
- the initial tenant and institutional-unit scope semantics. An institutional hierarchy, visible
  parent, or staff affiliation must not imply a descendant access grant.

The ADR must include the overlapping-context cases in the table above, including educator-plus-
guardian, guardian-plus-staff, one actor with several permitted tenant memberships, no-account
learner, and an identity that must be refused because its claimed person or tenant association is
not verified.

## Implementation sequence

### Slice 2.0-D.1 — identity and support decision evidence

**Release level:** L0, within the existing authorized Slice 2.0-D.

**Status:** Complete on 2026-09-27 through accepted ADR 0027, its decision review, evidence plan,
threat disposition, and operating runbook.

1. The named deciders reviewed and accepted ADR 0027 and its provider, threat, privacy, assurance,
   account-link, tenant-selection, service-identity, support, and exit dispositions.
2. The evidence plan defines the synthetic callback, key-rotation, session, revocation, recovery,
   tenant-selection, and support-grant positive and negative proofs for implementation.
3. The accepted boundary defines a single-use, hashed, tenant-bound, 30-minute initial-
   administrator invitation tied to pre-approved actor, membership, and tenant-defined role state;
   first login never wins authority and no standing break-glass account exists.
4. Elevated support requires a second authorized grantor, broker-native passkey/WebAuthn MFA,
   assurance no older than five minutes, and a grant of at most 60 minutes. Missing or uncertain
   evidence fails closed.
5. Platform engineering owns identity configuration and key/secret operations with security
   architecture approval; François is the interim incident/privacy escalation owner. Deployment
   ownership remains a separate production gate until a deployment is selected.

**Exit evidence:** accepted ADR, threat and abuse-case review, accountable owners, provider
evaluation and exit plan, session/support test design, recovery/key-rotation/incident runbooks, and
a recorded entry disposition for Slice 2.0-D.2.

### Slice 2.2-A — people and relationship scenarios

**Release level:** L0; proposed follow-on requiring a recorded project-owner authorization.

1. Turn each context in the product-model table into a representative journey for browser and
   phone, including the starting state, permitted task, denied state, recovery state, and end of
   access.
2. Agree the smallest initial relationship vocabulary. Do not use generic `group`, `user_type`, or
   arbitrary relationship scripting as a shortcut.
3. Define what proof creates, changes, suspends, or ends a guardian, staff, or community
   relationship and who is accountable for disputed or duplicate records.
4. Classify each fact and its field-level minimum. Do not put health, safeguarding, payroll, or
   unrestricted contact histories into the first People module.
5. Create low- and high-fidelity prototypes for at least one guardian, educator, non-academic
   administrator, and learner or applicant transition. Prototypes do not authenticate users or
   connect to real data.

**Exit evidence:** accepted People/Relationships ADR, reviewed persona-to-task-to-capability matrix,
relationship lifecycle and correction choices, classification/minimization record, representative
user review, and a recorded L1 entry disposition.

### Slice 2.1-B dependency — institutional reference

The proposed People persistence work waits for the first institutional-unit aggregate to provide a
stable `institutional_unit_id`. It does not use an institution name, hierarchy path, a client
selection, or an inferred parent scope as a durable relationship target.

### Slice 2.2-B — person and bounded affiliations

**Release level:** L1 with synthetic data only, after Slice 2.1-B and the Phase 2.0 L1 gates.

Implement the smallest tenant-owned `Person` aggregate and only the affiliations accepted by the
ADR. A staff affiliation may name an exact institutional unit when required; it does not create
employment, payroll, teaching allocation, role, or account access by itself. Person creation,
revision, suspension, and correction must be named actions with tenant context, classification,
concurrency, idempotency where replay is possible, audit, outbox, and retention semantics.

**Required negatives:** cross-tenant and cross-unit disclosure; inferred access from affiliation;
duplicate or changed idempotency replay; stale correction; alternate database writes; missing
context; deactivated module; and restricted fields in logs or outbox payloads.

### Slice 2.2-C — guardian and other approved relationships

**Release level:** L1 with synthetic data only.

Add only relationship types approved in Slice 2.2-A, beginning with the smallest justified
guardian relationship. The relationship is an attributable domain fact with explicit source,
state, and correction/end rules. It is not a capability grant, a household model, a broad learner
directory, an admissions record, or proof that a guardian can alter a learner's record.

The first relationship-policy actions must make the relevant target and purpose explicit. A
guardian can see or act only where the named action separately authorizes the current membership,
capabilities, relationship, classification, module state, and any required assurance.

### Slice 2.0-D.2 — production-candidate identity and support boundary

**Release level:** L2, after Slice 2.0-D.1's ADR and the public-browser/API entry conditions pass.

1. Add the reviewed server-side callback/session adapter. It establishes a validated actor, tenant
   membership, assurance, purpose, locale, and correlation context before a named action runs.
2. Add named account-link, unlink, membership-provision, suspend, revoke, and reactivation actions
   only where the accepted ADR defines their preconditions. A first login never silently creates a
   broad membership or role.
3. Integrate support grants as an intentionally visible elevated-session mode. It displays the real
   support actor, tenant, purpose, expiry, and limited scope; expiration or revocation immediately
   ends the elevated authority.
4. Keep session and security-sensitive authority decisions on the authoritative writer. A browser
   cache, replica, or client-held claim cannot continue an expired or revoked grant.

**Exit evidence:** passing forged/expired/revoked/fixated-session, callback, CSRF, redirect,
cross-tenant, key-rotation, recovery, support-grant, placement, and no-disclosure tests; checked
public contract; incident and recovery runbooks; accessibility and error-recovery evidence; and
`make check`.

### Slice 2.2-D — first membership and role-management journey

**Release level:** L2, after a production-candidate session and public contract are proven.

Expose one intentionally narrow staff administration journey:

1. select an already authorized person or verified account association through a bounded named read;
2. review the exact tenant membership being created, suspended, restored, or revoked;
3. assign or remove a tenant-defined role through resource-specific named actions; and
4. show a written result, audit reference where appropriate, and recovery or conflict state.

This builds on the existing private `Membership`, `Role`, `Capability`, and role-assignment
foundation. It does **not** introduce generic user management, fixed administrator/educator/
guardian role constants, client-selected capabilities, bulk role changes, or a hidden bootstrap
administrator. Creation and revocation of roles, grants, and compositions require their own
resource-specific actions and evidence; none may be inferred from a person context.

### Deferred follow-ons

- **Admissions invitation and applicant account:** belongs to the separately authorized Admissions
  module. An invitation must have a bounded application scope and expiry; it does not create a
  tenant membership, guardian relationship, enrolment, or general school workspace.
- **Learner participation:** belongs to the separately authorized Enrollment module. A person does
  not become a student merely by receiving an account or a guardian relationship.
- **Cohorts, classes, rosters, and teaching allocation:** belong to the later academic-structure and
  rostering work. They are not authorization groups.
- **Employment, finance, health, safeguarding, payroll, and support operations:** each needs its
  own domain records, classification, and assurance rules. This plan supplies no shortcut around
  them.
- **Alumni and community experiences:** begin only with an approved engagement use case. A typed
  affiliation may later support that module, but it does not justify an early generic portal.

## Verification matrix

Every implementation slice must convert its applicable cases into automated tests and link them
to the threat model.

| Area | Required evidence |
| --- | --- |
| Identity | Invalid issuer/audience/signature, replayed or forged callback, session fixation, idle and absolute expiry, logout, revocation, recovery, key rotation, and non-disclosing error handling |
| Tenant and placement | Missing, stale, forged, or cross-tenant membership/context; no request-selected tenant, repository, or placement; current membership rechecked on the writer |
| Support | Missing or expired grant, insufficient assurance, wrong tenant or purpose, over-broad capability, revoked session, visible elevated mode, and minimized start/use/end audit |
| Person and relationship | Cross-tenant and cross-unit isolation, relationship proof and lifecycle, duplicate/merge dispute path, correction, end/suspension, idempotency, concurrent writes, and field minimization |
| Authority | A relationship, affiliation, hierarchy, UI route, cache, or hidden control never grants authority; all allowed actions recheck current tenant-defined capability and module gates |
| Experience | Keyboard and screen-reader operation, focus/error states, narrow and wide reflow, expired/revoked/denied/recovery states written in words, and no sensitive identifiers or tokens in HTML, JavaScript, URLs, logs, or telemetry |
| Operations | Key/recovery/support incident runbooks, rate limits, monitoring, backup/restore and forward-repair posture for retained data, and clear local-versus-deployment evidence |

## Explicit non-goals

This proposal selects no provider beyond ADR 0027's ZITADEL Cloud Europe candidate and does not add
credentials, create a production session, ship a public route, define an admissions workflow, or
introduce real people or restricted data.
It also does not define a universal person graph, fixed job titles, automatic role assignment,
client-side authorization, a generic user/role administration screen, a household model, payroll,
health, safeguarding, learner records, enrolment, or alumni/community engagement functionality.

## Acceptance and next decision

The Slice 2.0-D.1 decision pack is complete and accepted; the immediate implementation deliverable
is the bounded synthetic Slice 2.0-D boundary, alongside the proposed Slice 2.2-A scenario pack.
The first implementation request must name the exact slice, release level, ADR status,
accountable owner, data classification, and verification evidence it will produce. Passing
`make check` proves repository consistency; it does not create a provider contract, authorize real
identity data, or open a higher release level.

## Related records

- [Phase 2 entry and institutional-structure proposal](phase-2-entry-and-school-structure-proposal.md)
- [Phase 2 entry decision register](../phase-2/entry-decision-register.md)
- [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](../adr/0007-transactional-outbox-and-event-envelope.md)
- [ADR 0014](../adr/0014-primary-api-and-generated-typescript-client.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0022](../adr/0022-local-read-only-browser-core-bridge.md)
- [ADR 0024](../adr/0024-assurance-proportionality-and-module-evolution.md)
- [Threat model](../security/threat-model.md)
- [Security abuse cases](../security/abuse-cases.md)
