# Local credential administration runbook

- Status: Local synthetic operating procedure
- Governing decision: [ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md)
- Applies to: loopback `make auth-demo` only

## Start and enter the administration page

1. Run `make auth-demo` from the repository root.
2. Copy the bootstrap administrator email and generated password from that terminal. Do not place
   either password in a ticket, chat, document, fixture, screenshot, or log.
3. Open the printed loopback sign-in address and sign in. The administrator is taken to
   `/admin`.

Stopping the command ends the local server. A later run generates a new bootstrap password and
rotates the stored bootstrap hash.

## Create a staff account

1. Confirm the intended prepared staff record independently from the email address. Email does not
   prove the record or grant authority.
2. Select that record, enter the normalized email sign-in name, and choose **Create account and
   temporary password**.
3. Copy the temporary password from the one-time response. Confirm its account email and expiry.
4. Deliver it through an appropriate private channel. The local proof does not qualify a real
   delivery channel.
5. Ask the staff member to sign in before expiry and replace it with a permanent passphrase.

Never choose a shared default password, store the plaintext, or create a second account when the
existing account should be reissued.

## Reissue access

Use **Issue new password** only after verifying the staff member and the intended account. Reissue
immediately invalidates the earlier password, first-login state, and account tokens. Copy the new
temporary password once and use a fresh private delivery. If the response is lost, reissue again;
the existing plaintext cannot be recovered.

## Suspend access

Use **Suspend** when the credential may be compromised or the person should no longer authenticate.
Suspension revokes tokens and removes temporary state. It does not delete the person, employment or
staff participation, membership, role, class, attendance, or audit history.

The local candidate has no reactivation action. A production reactivation and recovery procedure
requires a later reviewed decision.

## Failure and incident handling

- Treat repeated generic sign-in failures as possibly wrong, expired, suspended, or temporarily
  locked credentials; do not disclose account state to an unverified caller.
- After suspected disclosure, reissue or suspend immediately and preserve only safe account and
  time references.
- Never copy plaintext passwords, hashes, cookies, tokens, or full denial detail into support
  evidence.
- If account identity and the selected staff record conflict, suspend the credential and escalate;
  do not fix the link by changing email alone.
- If database, token revocation, or response completion is uncertain, fail closed and verify
  authoritative state before telling the user that access changed.

## Production prohibition

This runbook is not authorization to use real identity data or expose the harness beyond loopback.
Production requires the entry conditions in ADR 0044 and a deployment-specific runbook.
