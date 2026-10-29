# ADR 0049: Privileged synthetic staff account directory

- Status: Conditionally Accepted
- Date: 2026-10-24
- Deciders: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Identity and platform engineering with product experience
- Implementation authority: François authorized architectural documentation, the staff directory and connected login with synthetic data on 24 October 2026
- Supersedes: ADR 0023 only for the explicitly privileged account inventory below; extends ADR 0036's minimal profile/read boundary for this synthetic candidate
- Conditions: disabled by default, isolated fictional database, one startup-selected tenant, specialist review and required verification; independent and human review remain required before real identities or release

## Context

The accepted local credential proof uses prepared staff and a bootstrap actor. The requested
administrative directory needs names, sign-in details, language and access administration over
verified staff associations. An ordinary staff list would contradict ADR 0023. Account creation
must not create a person, membership, staff affiliation or classroom assignment.

## Decision drivers

- Make the intentionally traversable administrative set explicit.
- Separate global identity, institutional access, roles and personal preferences.
- Exercise a complete synthetic staff lifecycle without authorizing deployment or real data.

## Considered options

1. Reuse the unrestricted loopback account helper: rejected as it has no current tenant authority.
2. Exact lookup only: safe fallback, but does not deliver the requested account inventory.
3. A privileged, minimized, tenant-qualified account inventory and named actions: selected for
   this bounded synthetic candidate.

## Decision

Create a tenant-owned staff-directory entry bound to one exact verified staff association,
membership and actor. The credential account remains global. Current staff eligibility, module
state, actor membership and each dedicated capability are checked on the authoritative writer.
The first candidate has a maximum of 25 entries/candidates and fails closed beyond its reviewed
budget. The full traversable set is intentionally authorized administrative access; small pages
and rate controls are not represented as preventing enumeration of that set.

Inventory reading, provisioning, profile maintenance, access changes and global credential
reissue require separate capabilities. There is no generic people directory, student/guardian
account provisioning, export, wildcard database query or browser-selected tenant/placement.
Derived role capabilities remain tenant-defined data. The first access-profile selection assigns
an existing nonprivileged role within a code-owned delegation ceiling; it cannot grant account
administration, recovery, support or unknown capabilities, including through nested roles.
Assignments can be removed. Adding/removing a profile preserves a suspended entry; no reactivation action is supplied by this slice. Administrative self-elevation and self-suspension are refused.
Privileged role creation/delegation and last-administrator succession are outside the selectable
profile contract and remain unavailable rather than receiving a bypass.

Store flexible given/family/display names and an allowlisted interface locale. Never split old
display names or use names/email to merge identities. Sign-in email is the existing global login
name; changing it requires a separately qualified security action and is not a generic profile edit.
Preferences do not grant authority. Access profiles are governed selections of existing roles, not
a second policy engine. Existing account/person/association identifiers remain stable.

Named actions provision credentials, revise details, change access, suspend this tenant's access,
reissue a temporary password and save personal preferences. Writes bind exact input, expected
version, actor/request idempotency and atomic safe audit/outbox evidence. Secrets never enter
stored replay results: replay returns a safe receipt without plaintext. A lost one-time response
requires status reconciliation and a distinct, verified reissue; no automatic mutation retry.

Institutional suspension disables only the selected tenant entry and invalidates its application
sessions. Global reissue additionally requires account-security authority and refuses a target
with another tenant membership in this candidate. A tenant administrator cannot inspect or alter
another institution's access. Source association/participation changes remain authoritative and
are rechecked by every local application-session validation under ADR 0050.

The UI separates Details, Access, Security and Preferences, identifies the institution and exact
staff member before credential generation, shows essential consequences and saved/blocked states,
and provides keyboard/touch-accessible optional help. No password or hash appears in inventory.
Temporary plaintext appears only in its single no-store result; generated does not mean delivered.

## Plain-English summary

### What this means

Authorized administrators can manage fictional staff accounts and their current institutional
access. A login and a permission to see school records remain separate decisions.

### What was agreed

Only the isolated synthetic directory and connected-login candidate are authorized. Real staff,
MFA enrollment, credential delivery, public hosting, pilot and production remain separately gated.

### Context

The earlier credential proof could verify a password but was not an authorized school directory.

### Examples

- Illustrative: changing a staff member's language grants no additional classroom access.
- Illustrative: suspending one institution's access leaves another institution's identity intact.
- Illustrative: a repeated create request returns its receipt without redisplaying a password.

## Consequences

### Positive

- An accountable inventory exception delivers the requested administration task.
- Permission changes are revocable and remain writer-authorized.

### Negative

- The inventory is sensitive administrative disclosure and needs its own assurance.
- Multi-tenant global recovery, richer delegation and large directories need later qualification.

## Security, privacy, operability, and migration effects

Add a tenant-keyed resource with compound references, uniqueness and bounded fields; retain
global accounts. Inspect generated migration constraints/indexes and use additive expansion.
Retained account/directory/session evidence must not be discarded through rollback. Restrict
alternate writes through resource policies and database constraints. PostgreSQL remains
authoritative; safe audit/outbox facts contain identifiers/action/version, not names or secrets.
No Restricted outbox delivery consumer is authorized by storing a fact.

Before real data, the institution and service operator must settle controller/processor roles,
lawful basis, notice, processor contracts/transfers, rights handling, separate account/security
retention, legal holds, backup erasure convergence, DPIA screening, incident ownership and breach
notification. No synthetic result establishes GDPR compliance. See the existing
[qualification plan](../plans/local-authentication-production-qualification-plan.md).

## Validation evidence

The [slice evidence](../phase-2/staff-directory-connected-login-evidence.md) records actual positive,
cross-tenant/capability/missing-context, stale/version/replay, role-ceiling, secret-redaction,
source-ending, browser and migration checks, specialist dispositions and `make check`. Planned
checks are not completion evidence.

## Fallback and exit cost

Keep the guarded routes unavailable if qualification fails. Preserve retained records and use
forward repair; an empty disposable database may roll back. Never fall back to the unrestricted
AuthDemo helpers or a generic staff list.

## Review triggers

- Real identity, deployment, another tenant, more than 25 entries or any export.
- Learner/guardian access, automated linking, bulk import or email changes.
- Privileged role delegation, recovery, MFA, source verification or retention changes.

## Related records

- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0044](0044-administrator-provisioned-local-credentials.md)
- [ADR 0047](0047-private-identity-account-source-fence.md)
- [ADR 0050](0050-local-credential-application-session.md)
- [Threat model](../security/threat-model.md)
