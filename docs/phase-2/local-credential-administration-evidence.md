# Local credential administration evidence

- Status: Bounded local engineering candidate
- Decision: [ADR 0044](../adr/0044-administrator-provisioned-local-credentials.md)
- Date: 2026-10-08
- Data: synthetic only
- Runtime: loopback-only `make auth-demo`

## Implemented boundary

The local authentication harness now lets its bootstrap administrator select one of two prepared
synthetic staff records, enter an email sign-in name, and create a database-backed account. The
system generates a random temporary password, shows it once, stores only its bcrypt hash, and
requires replacement before the staff account can establish an ordinary token-backed session.

Named lifecycle actions cover provisioning, temporary-password reissue, permanent-password
activation, and suspension. Temporary credentials expire after 24 hours. The restricted
first-login browser state lasts at most ten minutes and is bound to the account lock version.
Five failed attempts produce a 15-minute credential lock. Reissue and suspension revoke tokens.

This candidate deliberately keeps email separate from authority. Successful staff sign-in leads
only to a credential-proof page; it creates no tenant membership, role, permission, teaching
assignment, class access, or school record.

## Automated evidence

Focused tests cover:

- email normalization and independent unique email/staff-actor constraints;
- random temporary generation and hash-only database storage;
- temporary credential entry into restricted first-login state without an application token;
- rejection of reusing the temporary password as the permanent password;
- permanent activation and token-backed sign-in;
- expiry, five-attempt lockout, suspension, and non-disclosing unknown-account denial;
- reissue invalidating the prior temporary password and lock-version-bound first-login state;
- reissue and suspension converting all active account tokens into revocation records; and
- length, predictable-password, and email-context password-policy checks.

Focused command result on 2026-10-08:

```text
CHIMWEMWE_TEST_DATABASE=chimwemwe_local_credentials_slice_test \
  MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/local_credentials_test.exs
Result: 9 passed
```

Compilation with warnings treated as errors passed for the candidate source. The final repository
core check also passed 309 tests, formatting, compilation, OpenAPI drift, migration drift, lint,
dependency audit, type analysis, and whitespace checks. The repository-wide `make check` then
stopped at the web dependency audit: the current client dependency tree reports ten high-severity
advisories through `braces`/`micromatch` and Next.js, whose available automatic fixes cross declared
dependency ranges or introduce a breaking Stylelint downgrade. This is not a repository-wide green
claim, and those unrelated web dependency changes were not forced into this slice.

## Live loopback evidence

The retained `chimwemwe_auth_demo` database contained the earlier bootstrap account. Running
`make auth-demo` applied the lifecycle migration safely, backfilled its actor identifier, rebound
the known bootstrap actor, and started on `127.0.0.1:4012`.

An HTTP browser-journey rehearsal then passed administrator sign-in, account creation, one-time
temporary-password display, redirect to the restricted first-login page, permanent-password
replacement, ordinary password sign-in, and the credential-only staff page. Request logging
showed submitted password structures as `[FILTERED]`. The sign-in response returned
`Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, and a restrictive referrer policy.
The synthetic rehearsal account and its token were removed afterward so the review site starts
with both prepared staff choices available.

## Manual review checklist

Start `make auth-demo`, then use the generated bootstrap credentials printed in the terminal.

1. Sign in as the bootstrap administrator and confirm `/admin` opens.
2. Create an account for a prepared staff record and confirm the temporary password appears once
   with a 24-hour expiry.
3. Sign out, sign in with that staff email and temporary password, and confirm only the password
   replacement page opens.
4. Set a compliant permanent password and confirm the browser returns to sign-in.
5. Sign in with the permanent password and confirm the page explicitly says no school authority
   was granted.
6. As administrator, issue a new temporary password and confirm the previous permanent password no
   longer works.
7. Suspend the account and confirm sign-in is denied without disclosing suspension.
8. Confirm browser back/refresh does not reveal a previously shown temporary password.

## Retained gates

The proof does not include a real staff record, tenant capability check, administrator MFA,
qualified HTTPS/public edge, production cookie, protected delivery channel, real recovery owner,
production rate limiting, representative accessibility review, independent security/privacy
review, or real identity data. Those remain mandatory before connected or production use and are
carried as ordered future slices in the
[local authentication production qualification plan](../plans/local-authentication-production-qualification-plan.md).
