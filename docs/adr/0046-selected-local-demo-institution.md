# ADR 0046: Startup-selected local demo institution

- Status: Proposed
- Date: 2026-10-23
- Accountable owner: Product experience and platform engineering
- Deciders: François — Project Owner
- Implementation authority: François explicitly requested loading the demo sets, choosing an institution at startup, and viewing its students, guardians, educators and calendar
- Supersedes: None

## Context

The four fictional packs are prepared but the browser still renders unrelated tiny fixtures.
The Project Owner now authorizes a local demonstration that actually consumes a selected pack.
Guardian and college course-registration production contracts do not yet exist.

## Decision drivers

- Make each institution's related records visible in the existing browser app.
- Keep the selected synthetic institution fixed for the process lifetime.
- Preserve production domain, identity, authorization and calendar writer boundaries.

## Considered options

1. Import every fixture field into core tables: rejected because it invents unsupported domains.
2. A server-loaded, startup-selected synthetic view adapter: selected for this authorized demo.
3. A browser tenant switcher with arbitrary file paths: rejected because the startup context must
   remain explicit and file access must not depend on request input.

## Decision

Add `make demo` with an interactive institution menu and `make demo DEMO=<allowlisted-pack>` for
direct startup. It prepares all four packs, pins one institution and tenant in an isolated
instance manifest, and starts the existing loopback Next.js app with explicit synthetic flags.
The selected pack becomes the app's home and its Students, Families & guardians (college
Contacts), Educators (college Instructors) and Calendar views. These are read-only demo views.

The server checks local mode, loopback Host, instance metadata, selected-pack allowlist, the
code-owned manifest digest and every row's tenant before rendering a projected view. Request
parameters never select tenant, pack or file. Missing/corrupt context fails closed with concise
recovery; no fallback institution is silently substituted. Rendering is request-time, so build
output and shared static caches cannot pin one institution into another process. No source
paths, other institution payloads, credentials or raw fixture files are sent to the browser.

The fixed example date and calendar zone remain visible. Enrolment, contact, placement and
assignment state uses its own half-open interval. Applicants stay outside student results.
Daily registers, subject groups, college sections and their sessions remain distinct; calendar
periods, student closures and informational events remain distinct. Contact links grant no
account, collection, disclosure or messaging authority. The demo offers no sends or login.

This extends the local fixture adapter only. It adds no production module, database import,
operational write, identity path, public API, migration, real data or production deployment.
Existing core-backed preparation/attendance qualification is separate; this viewer does not
claim its selected records can be edited through that writer.

## Consequences

### Positive

All four settings become inspectable through one consistent, audience-specific app.

### Negative

The demo cannot prove production persistence, record policies or operational workflow fitness.
Changing institution requires a new process and prepared instance.

## Security, privacy, operability, and migration effects

Only code-owned fictional packs are permitted, with digest and tenant checks. Local flags and
loopback binding are exposure guards, not authentication. No account or role is manufactured.
Files are instance-specific and read-only to the app. PostgreSQL remains authoritative for all
operational domains; fixtures are illustrative data. No migration, audit history or outbox fact
is invented. Relevant threats are TM-01, TM-02, TM-04, TM-09, TM-16, TM-17 and TM-19.

## Validation evidence

Required: all four startup selections; missing/invalid context, wrong tenant/hash/Host denial;
no request-selected institution; applicant exclusion; dates and joins; duplicate-name/shared-email
identity handling; calendar scopes; mobile reflow, keyboard, accessibility and screenshots;
specialist review; and the full `make check`. Actual results belong in
[demo-data documentation](../../demo-data/README.md); planned checks are not executed evidence.

## Fallback and exit cost

Stop the demo and retain its instance directory. The existing fixture prototype and guarded core
qualification remain independently runnable. No database rollback or data migration is needed.

## Review triggers

Any write, real record, deployed origin, runtime institution switching, production import,
guardian authority, or claim of operational readiness requires its applicable later decision.

## Related records

- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0021](0021-academic-calendar-authority-and-template-adoption.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0037](0037-class-register-enrolment-and-placement.md)
- [Threat model](../security/threat-model.md)
- [Specialist review profiles](../development/specialist-review-team.md)
