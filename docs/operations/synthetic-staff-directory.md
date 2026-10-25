# Synthetic staff directory and connected sign-in

- Status: Local fictional evaluation only
- Governing decisions: [ADR 0049](../adr/0049-privileged-synthetic-staff-account-directory.md) and [ADR 0050](../adr/0050-local-credential-application-session.md)
- Evidence: [Current slice checks and reviews](../phase-2/staff-directory-connected-login-evidence.md)

## Start

Run `make staff-demo` from the repository root. It creates a fresh `chimwemwe_staff_demo_…`
database, a run-specific administrator password and temporary localhost TLS certificate.
Open [staff sign-in](https://localhost:3015/sign-in), accept the local evaluation certificate,
and use the generated administrator details printed in the invoking terminal. Never copy a
password into a ticket, chat, screenshot or committed evidence. Stopping the command stops its
servers; the fictional database is retained for inspection. Previous databases are not reset.

The ordinary fictional institution viewer (`make demo`), old credential proof (`make auth-demo`)
and classroom qualification (`make classroom-demo`) remain separate. This candidate has no
passwordless classroom-demo login endpoint and no external identity-provider connection.

## Try the staff lifecycle

1. Open Accounts. Select the prepared fictional teacher and review the exact staff identity.
2. Enter its sign-in email and names, choose the interface language, then create the account.
   A display name is required; given/family names are optional. Creating credentials grants no role.
3. Copy the generated temporary password from its one-time result. It expires after 24 hours.
   Generated does not mean delivered; actual private delivery remains unqualified.
4. Open account details. Add the existing permitted classroom access profile. Its permissions
   still require the current teaching assignment. Preferences cannot change these permissions.
5. In another browser session, open Sign in and enter the teacher's temporary credentials. Only
   password replacement is permitted. Set a 15–128-character permanent passphrase, then sign in
   afresh to open My classes. The local certificate and fictional data are for evaluation only.
6. Open the assigned class. The existing attendance workflow continues to check current class,
   local date, membership, capability and teaching assignment for every action.
7. As administrator, suspend access to this institution. The teacher's next protected request
   must be denied, including from an already-open tab. Institution records and history remain.

Adding or removing an access profile preserves suspension. Reactivation is not supplied by this
slice. A source-unavailable account needs resolution of its staff association/participation;
password reissue and role changes cannot repair that source.

## Credential and response recovery

Existing passwords cannot be displayed or recovered. Reissue requires separately authorized
account-security authority and refuses cross-tenant-linked targets in this first candidate.
Reissue invalidates previous local application sessions. The new plaintext is displayed once.
If a response is lost, reload authoritative status before making a distinct reissue request.
Exact request replay returns a safe receipt, never the previous plaintext. Do not assume a timed-out
request rolled back, repeatedly press a credential action, or create a second identity.

Cancel on first login discards its restricted browser state without granting application access.
Signing into a different account ends the previous current application session before accepting
the new credential. Use Sign out before leaving a shared device; a failed logout must remain
visible and must not be treated as confirmed.

## Limits and release gates

The one startup-selected tenant and fixed inventory budget are intentional. No learner, guardian,
applicant, referee or external-college account is created. No name/email coincidence links people.
No email change, global credential suspension, public registration/reset, directory sync, bulk
export or privileged role delegation is enabled by this workflow. Interface translation in this
slice covers the staff-account experience; it does not claim that all classroom screens are translated.

This harness is disabled by default and bound to loopback. It supplies no MFA assurance. Real
staff identity, protected delivery, operator recovery, MFA/step-up, selected HTTPS infrastructure,
deployed abuse controls, GDPR/retention and processor decisions, representative usability and
independent security/privacy review remain under [LA-1–LA-6](../plans/local-authentication-production-qualification-plan.md).
Fictional tests and AI reviews are not production or legal approval.
