# CF-3 connected academic-calendar workflow evidence

- Date: 2026-10-06
- Owner: Product and platform engineering
- Authority: [ADR 0039](../adr/0039-public-calendar-evidence-for-cf-3-engineering-entry.md)
- Entry disposition: [CF-3 connected calendar entry disposition](cf-3-connected-calendar-entry-review-packet.md)
- Status: Disabled local synthetic implementation verified; repository-wide dependency audit remains red
- Boundary: Local synthetic engineering only; no real-data, deployment, pilot, or production claim

## Delivered task

A synthetic calendar owner starts the local application session, opens one server-selected academic
year, edits its definition, saves a versioned draft, reloads committed state from PostgreSQL,
publishes the year, and resolves one local date against that immutable publication. The existing
disconnected UI-0 preview remains unchanged outside the explicit classroom-demo environment.

Run `make classroom-demo`, accept the ephemeral self-signed certificate for
`https://localhost:3013`, and open `https://localhost:3013/academic-calendar`. Every run creates
and retains a fresh database named `chimwemwe_attendance_demo_<timestamp>_<process>`. The same
isolated process also hosts the previously qualified attendance screen. Ports 3013, 3014, and 4013
must be free. Stopping the command stops the servers; it does not delete the retained database.

## Authority and action boundary

The browser contract contains no tenant, institution, calendar, academic-year, actor, membership,
placement, role, module-state, capability, or repository selector. Startup-owned configuration
selects the exact fictional institution/calendar/year tuple. The local-only plug validates that
tuple and also requires the explicit enablement flag, loopback host, loopback peer, and an HTTPS
loopback origin. The TLS edge allowlists only the named routes.

Every calendar call authenticates the opaque application cookie for its named purpose. Inside the
calendar writer transaction, the current session, actor, tenant, and membership are revalidated;
support mode is refused; module and capability checks remain independent. Draft replacement,
publication, draft preview, published read, and date resolution delegate to the existing exact
`Chimwemwe.AcademicCalendar.Foundation` actions. The demo's initial fictional draft is prepared
server-side through the existing registration and definition actions. No generic CRUD or browser
authority path was added.

`GET /api/v1/calendar/preparation` reads the one exact draft or publication. The three unsafe
actions are `POST /api/v1/calendar/save-draft`, `POST /api/v1/calendar/publish`, and
`POST /api/v1/calendar/resolve`; they require the exact same-origin and CSRF proofs. Requests have
closed schemas and responses omit authority identifiers. The checked OpenAPI artifact and generated
TypeScript declarations are the browser contract. Responses are no-store, route parameter logging
is disabled, and failures use stable non-disclosing error shapes.

## Product behavior

The connected screen visibly distinguishes an unsaved edit, an authoritative saved draft, and a
published immutable year. Saving and publishing always replace the browser state with an immediate
writer read. A stale or conflicting result disables further mutation until reload. An interrupted
request says that the result is unknown and requires reload; the client does not invent success or
automatically issue a different request. Validation errors preserve the editable draft. Lost or
denied access returns to the explicit synthetic sign-in state.

Publication disables the definition fields. Published date meaning is not presented as writer
confirmed until the user invokes the named resolution action. The original local-only page still
says that it does not save or connect when `CHIMWEMWE_CLASSROOM_DEMO` is absent.

## Verification recorded so far

Results on 2026-10-06:

| Check | Result |
| --- | --- |
| Connected calendar, calendar writer, and attendance focused core tests | 26 passed |
| Connected calendar tests | 4 passed: save/read-after-write, stale, publication, conflict, resolution, support refusal, revoked session, capability denial, mismatched server target, inactive module, disabled/remote route, invalid session, origin, CSRF, exact-input, and stable HTTP status behavior |
| Existing calendar rollback coverage included in the focused run | Passed: failed transition removes state, audit, outbox, and idempotency evidence before a successful retry |
| `CHIMWEMWE_UI0_SYNTHETIC=true npm run check` | Formatting, lint, types, 8 design-token tests, 27 unit tests, and production build passed |
| HTTPS classroom Playwright suite | 3 passed: attendance, class/student preparation, and connected calendar against the actual session adapter and PostgreSQL |
| Connected calendar browser coverage | Local validation, interrupted save recovery, authoritative reload, persistence across page reload, rejection of browser-supplied tenant input, publication, and published date resolution passed |
| Responsive and accessibility coverage | 1440, 768, and 320 pixel widths had no horizontal overflow and zero axe violations; native inputs and the save/publish/resolve journey were exercised by keyboard; screenshots were visually inspected |
| Existing browser suites run directly after the gate stopped | UI-0: 33 passed; connected UI-1A: 6 passed; unavailable UI-1A: 1 passed |
| Checked public OpenAPI and generated TypeScript | Regenerated and current; generator drift and its dependency audit passed |
| Required `make check` | Ran. Documentation/tools passed; core formatting, compile, both OpenAPI checks, migration drift, strict Credo, dependency audit, Dialyzer, 285 tests, and whitespace passed. Web then stopped at the existing client dependency audit: 9 high-severity `braces`/`micromatch` findings whose offered repair is a breaking Stylelint downgrade. |
| Checks after the required gate stopped | Web format/lint/types, 8 token tests, 27 unit tests, build, all browser suites above, final tooling, documentation, and `git diff --check` passed when run directly |

The first repository-gate attempt stopped at concurrent CF-4 Credo findings. After that task
repaired its owned files, the complete rerun reached the web dependency audit and stopped on the
known `braces`/`micromatch` advisory chain. No advisory was suppressed and no breaking forced
repair was applied. Because `make check` stopped there, the repository is **not green**, even
though the remaining web and tooling stages pass when invoked directly.

## Scope retained

The fixture is fictional and does not copy any public school's operational calendar. Official
school calendars remain design evidence only. This slice adds no source import, ICS/feed,
subscription, synchronization, event, timetable, rotating-day, recurrence, bell-period, half-day,
room, boarding, athletics, or parent-conference behavior. It adds no production migration or
publicly enabled endpoint.

Institution-side validation, representative usability, independent security/privacy review,
selected provider-neutral identity and origin, deployment controls, real data, pilot approval, and
production release remain exactly where ADR 0039 places them.
