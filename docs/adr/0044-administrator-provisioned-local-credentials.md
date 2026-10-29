# ADR 0044: Administrator-provisioned local credentials

- Status: Accepted
- Date: 2026-10-08
- Decision date: 2026-10-08
- Accountable approver: François — Project Owner and interim Security/Privacy Owner
- Accountable owners: Security architecture, platform engineering, and product engineering
- Depends on: ADR 0029, ADR 0030, and ADR 0036
- Supersedes: ADR 0029 only where it says Chimwemwe does not become a credential authority by
  default and where it prohibits every local-password path; its provider-neutral federation,
  identity-link, session, membership, authorization, and no-automatic-fallback controls remain
  binding

## Context

ADR 0029 left people without an institutional identity dependent on a later selected credential
authority. The Project Owner has now selected the initial product path: an administrator creates a
staff account manually, enters its username as an email address, receives a system-generated
temporary password, and gives that password to the staff member for replacement at first login.

This changes a stable credential-authority boundary, so it is recorded as a superseding decision
rather than silently modifying ADR 0029. It does not collapse authentication into authorization.
An account email still cannot create a Person, staff participation, tenant membership, role,
capability, class assignment, or institutional relationship.

## Decision drivers

- Start with an understandable account workflow that does not require a school identity provider.
- Prevent public self-registration, email-based authority, and administrator-chosen shared default
  passwords.
- Make temporary credential expiry, first-login replacement, reissue, suspension, lockout, and
  session invalidation explicit server-owned states.
- Retain OIDC and SAML as optional future connection paths without making them prerequisites for
  the first staff login.
- Keep the local proof honest about its synthetic staff records and unqualified deployment edge.

## Considered options

1. Require OIDC before any staff account can sign in. Rejected as the initial product path because
   the Project Owner selected administrator-provisioned credentials and no real provider has been
   supplied or qualified.
2. Let administrators choose a shared default password. Rejected because it creates predictable,
   reusable plaintext knowledge and no reliable first-login boundary.
3. Send public email reset or invitation links. Deferred because delivery ownership, anti-replay,
   account-enumeration, recovery, and selected email infrastructure are not yet qualified.
4. Generate a one-time temporary password, require replacement, and retain OIDC as an independent
   future path. Selected.

## Decision

Chimwemwe may act as the credential authority for administrator-provisioned staff accounts under
the following contract:

1. An administrator selects one existing, eligible staff record and enters a normalized email
   address. Production authorization for that action must be checked against current writer-side
   tenant membership and a dedicated account-administration capability. The local proof uses two
   prepared synthetic staff records and a fixed bootstrap administrator actor only.
2. Email and staff actor identifiers are independently unique. Email is the sign-in name only; it
   grants no tenant, role, class, or business authority.
3. Chimwemwe generates a cryptographically random temporary password. The plaintext is shown once
   in a `no-store` administrator response, is never committed or logged, and expires after 24
   hours. PostgreSQL stores only the slow password hash.
4. A valid temporary password establishes only a restricted, ten-minute first-login browser
   state. It cannot create a normal application session. The state is bound to the account's
   optimistic-lock version so reissue or suspension invalidates an already-open replacement form.
5. The staff member must choose and confirm a permanent password before ordinary sign-in. The
   initial policy permits passphrases, requires 15–128 characters, and rejects a small predictable
   and email-contextual blocklist without composition rules.
6. Five failed attempts lock the local credential for 15 minutes. Unknown email, wrong password,
   expired temporary password, suspended account, and locked account return the same public
   failure shape.
7. Reissue and suspend are named administrator actions. Reissue replaces the hash, returns a new
   one-time temporary password, and invalidates the earlier first-login state. Reissue, permanent
   password activation, and suspension revoke existing account tokens.
8. There is no public registration, email password reset, security-question recovery, learner or
   guardian account path, password export, or administrator visibility of an existing password.
9. The first deployment administrator is established through a separate operator-owned bootstrap
   ceremony. The local harness generates that bootstrap password for each run and prints it only
   to the invoking terminal.
10. OIDC remains an optional independent sign-in path. A failed OIDC attempt must never silently
    fall back into a local-password session; the user deliberately chooses an approved path.

## Consequences

### Positive

- A school can begin with manually governed staff accounts before an identity-provider project.
- Temporary-password handling and recovery stay explicit and testable.
- Authentication remains separate from people, membership, role, and classroom authority.
- Later federation can link to stable actors without replacing school records.

### Negative

- Chimwemwe now owns password hashing, guessing resistance, recovery, compromise response, and
  credential-support obligations.
- Manual delivery of temporary passwords creates an operational social-engineering and disclosure
  risk that each deployment must control.
- Lockout can be abused for denial of service unless the selected edge also applies rate and abuse
  controls.
- The bootstrap administrator is a high-value credential and needs a qualified setup and recovery
  ceremony; the local terminal proof is not that ceremony.

## Security, privacy, operability, and migration effects

Password plaintext exists only in the generating or submitting request process. Sensitive form
fields remain filtered, temporary-password responses are `no-store`, and committed evidence must
never contain a real or generated password. Hash cost, denial telemetry, lockout behavior, and
token revocation become operated security controls rather than provider responsibilities.

The account table gains a stable actor identifier, pending-first-login state, temporary expiry,
password-change time, failure count, lock time, and optimistic-lock version. Migration backfills a
unique actor identifier for an existing local account before enforcing non-null uniqueness; the
bootstrap action then binds its known synthetic administrator actor. No migration infers a Person,
membership, role, or staff relationship from email.

Manual temporary-password delivery processes personal identity data and security credentials. A
real deployment must minimize recipients, prohibit help-desk disclosure without verification,
define retention and incident handling, and make reissue preferable to recovery of plaintext.

## Production-entry conditions

The local database-backed proof is L1 engineering evidence only. Before real staff identity or a
connected deployment, the candidate still requires:

- a real staff-account association and current tenant capability check instead of prepared IDs;
- HTTPS edge, secure host-only cookie qualification, CSRF, rate limiting, monitoring, and alerting;
- administrator step-up or MFA, least-privilege account administration, and independent security
  and privacy review;
- a reviewed temporary-password delivery channel, bootstrap ceremony, recovery and lost-admin
  procedure, incident owner, support boundaries, and session-revocation drill;
- selected password-hash cost and upgrade measurements on deployment hardware; and
- representative usability and accessibility review of sign-in, first-login replacement,
  administrator creation, reissue, suspension, and failure messages.

No production claim may be inferred from the synthetic loopback workflow.

## Validation evidence

The bounded candidate must prove normalized unique account and actor identifiers; hash-only
storage; random one-time temporary passwords; expiry; restricted first-login state; lock-version
invalidation; permanent-password activation; active session token creation; generic denial;
lockout; reissue; suspension; token revocation; administrator denial; CSRF; `no-store`; migration
from an existing local account; and repository checks. The current results and manual checklist
are recorded in the
[local credential administration evidence](../phase-2/local-credential-administration-evidence.md).

## Accountable decision

On 2026-10-08, François directed that real authentication initially be created manually through
an administrator form using email and a generated temporary password that must change at first
login, then explicitly authorized implementation. This ADR accepts that credential-authority
change at the bounded local engineering level and retains the production-entry conditions above.

## Fallback and exit cost

If the local credential path cannot meet the production conditions, it remains disabled outside
the loopback harness. Removing it preserves actors, people, memberships, roles, class records,
external identity links, and future provider connections. Password hashes and local sessions are
revoked and deleted under an approved retention and migration plan; they are never exported as
recoverable passwords.

## Review triggers

- learner, guardian, service, or public account provisioning;
- self-registration, email reset, magic link, passkey, MFA, recovery code, or password-history
  work;
- a different temporary lifetime, retry/lockout policy, hash provider, or password policy;
- bulk provisioning, import, directory sync, invitations, or administrator delegation;
- production deployment, real identity data, a public origin, or a second tenant; or
- linking, merging, or migrating a local account to an external identity provider.

## Related records

- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [Threat model](../security/threat-model.md)
- [Local credential administration evidence](../phase-2/local-credential-administration-evidence.md)
- [Local credential administration runbook](../operations/local-credential-administration.md)
- [Local authentication production qualification plan](../plans/local-authentication-production-qualification-plan.md)
