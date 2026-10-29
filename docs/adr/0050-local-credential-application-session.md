# ADR 0050: Local credential application session

- Status: Conditionally Accepted
- Date: 2026-10-24
- Deciders: François — Project Owner and interim Security/Privacy Owner
- Accountable owner: Identity, security and web engineering
- Implementation authority: François authorized the synthetic staff-directory and connected-login slice on 24 October 2026
- Supersedes: ADR 0030 only where application-session establishment requires external identity proof; ADR 0044's hash-provider and initial blocklist interpretation for the upgraded candidate
- Conditions: synthetic loopback HTTPS qualification only; LA-1–LA-6 retained before real identity or release

## Context

The local password demonstration ends at a credential-proof page. Existing application sessions
require an external identity link, so redirecting that demonstration cannot create a real local
application session. Fabricating an OIDC link would hide the credential-authority boundary.
The current bcrypt implementation truncates at 72 bytes although policy accepts long passwords.

## Decision drivers

- Use one application-session and server authorization boundary for local and federated login.
- Reject forged proof, stale credentials, revoked institutional access and login/suspension races.
- Preserve long passphrases without silent truncation and keep first-login state restricted.

## Considered options

1. Promote the demonstration cookie: rejected; it is not a current tenant application session.
2. Invent an external identity: rejected; it misrepresents authentication provenance.
3. A typed local credential proof and explicit local session origin: selected.

## Decision

A credential verifier creates a short-lived, integrity-protected local proof only after checking
the permanent password of an active account. It binds account ID, actor, credential version,
assurance and authentication time. A domain-separated keyed fingerprint binds the actual stored credential hash/status and principal-binding marker without storing the hash in a session. A caller-provided account struct is not proof. The server
selects the startup-owned tenant/membership target and rechecks current placement, membership,
eligible staff association, effective participation and enabled directory access on the writer
before session commit. Local and external identity origins are mutually exclusive.

Every protected request validates the current credential account/actor/status/version and keyed credential basis and tenant
access/source chain in addition to normal session, membership, placement and domain policy.
Credential replacement/reissue/suspension invalidates local application sessions even if a token
deletion or asynchronous effect fails. Administrative tenant-access suspension cannot disable a
global identity. Federated sessions retain their existing link/connection validation.

Use maintained Argon2id for new password hashes with per-password salt, explicit algorithm/cost
metadata and measured bounded cost. Verify supported legacy bcrypt hashes only under an explicit
safe compatibility rule; never claim a truncated long password was fully verified. Keep the
15–128-character passphrase policy, defined Unicode normalization/counting, whole-password common/
compromised/contextual screening, paste/autofill support and no routine password expiry. Permanent
changes on evidence of compromise remain required. No plaintext/hash enters logs or audit.

The initial temporary password still expires after 24 hours and establishes only a ten-minute
replacement state bound to account version. Only the replacement route accepts that state.
Replacement invalidates the temporary credential; it does not itself grant classroom authority.
The normal session is created only from a fresh verified permanent credential. One-time display
does not mean the temporary password could only be submitted once before replacement.

Reuse the same-origin HTTPS contract and Secure/HttpOnly/host-only session cookie, exact origin,
session-bound CSRF, no-store responses, safe headers, bounded request size and allowlisted return
paths. Pre-authentication/replacement forms have their own encrypted short-lived state and CSRF
binding. Public unknown/wrong/expired/locked/suspended failures share one shape. No public reset,
self-registration, local-storage bearer, external fallback, or credential-bearing GET is added.
Logout invalidates the authoritative session before clearing the browser cookie.

The guarded synthetic harness uses generated run-specific operator credentials, an isolated fresh
database and startup-owned context. It does not claim MFA assurance. Privileged MFA/step-up,
phishing-resistant enrollment/recovery, deployed rate/abuse controls, secure delivery, bootstrap/
lost-admin ceremony and independent/human review remain mandatory before real connected use.

## Plain-English summary

### What this means

A staff member can replace a temporary password, sign in and use only currently authorized work.
Removing institutional access also blocks an already-open session at its next protected request.

### What was agreed

This implements a complete fictional login-to-app proof, with no production authentication claim.

### Context

Verifying a password and admitting someone to an institution are separate security steps.

### Examples

- Illustrative: the replacement form cannot read the account directory or classroom records.
- Illustrative: a suspended teacher's stale browser session cannot submit attendance.
- Illustrative: an external sign-in still requires its genuine provider/link evidence.

## Consequences

### Positive

- One session lifecycle supports explicit local and external proof without invented federation.
- Current writer validation closes stale-session access and truncation ambiguity.

### Negative

- Local credentials add hashing, recovery and security-operation responsibilities.
- The session-origin schema needs a compatible expansion and retained-row migration review.

## Security, privacy, operability, and migration effects

Expand the session schema additively with nullable origin references, mutually exclusive checks,
credential version and appropriate foreign keys/indexes. Existing external rows remain valid;
never backfill a fictional local identity. Generated migrations must be inspected, applied,
drift-checked and empty rollback/reapply tested; retained evidence requires forward repair.
Record only safe authentication/action references. No secrets enter stored idempotency receipts,
audit, outbox, screenshots or committed evidence. GDPR/retention decisions follow ADR 0049 and the
existing qualification plan; the fictional candidate is not legal assurance.

## Validation evidence

See [slice evidence](../phase-2/staff-directory-connected-login-evidence.md) for actual proof,
version/revocation, tenant/source, origin/CSRF/cookie, long Unicode/hash compatibility, first-login,
browser lifecycle, migration and repository results. Agent reviews do not replace independent
security/privacy review or representative usability/accessibility evidence.

## Fallback and exit cost

Keep the new local-login routes closed if qualification fails. Existing external sessions retain
their origin and controls. Preserve retained records; revoke local sessions and repair forward.

## Review triggers

- Real identities, public origin, additional tenant, MFA/passkeys or recovery changes.
- Session lifetime, keyring, hash policy/provider/cost, credential or source-version changes.
- Revocation races, stale access, alternate writers, or migration compatibility findings.

## Related records

- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0044](0044-administrator-provisioned-local-credentials.md)
- [ADR 0049](0049-privileged-synthetic-staff-account-directory.md)
- [Qualification plan](../plans/local-authentication-production-qualification-plan.md)
- [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
