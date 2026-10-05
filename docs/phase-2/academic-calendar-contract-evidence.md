# Academic calendar contract and publication evidence

- Status: CF-2B private synthetic publication writer implemented; final repository verification recorded below
- Evidence date: 2026-10-04
- Owner: Product and platform engineering
- Governing decision: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Delivery plan: [Classroom-first six-week plan](../plans/classroom-first-six-week-plan.md)
- Next review trigger: connected calendar preparation workflow, successor/correction work, or real adoption

## Achieved boundary

The first calendar construction increment adds a production-core executable contract under
`Chimwemwe.AcademicCalendar`. It accepts one exact institutional-unit-owned calendar publication
candidate and:

- requires explicit calendar, institutional-unit, and academic-year UUIDs;
- accepts no caller-supplied tenant, active unit, parent, default, or latest-row selector;
- validates inclusive year dates and bounds the current candidate to 731 dates;
- validates one or more contained, ordered, non-overlapping primary periods;
- validates a non-empty unique ISO instructional-weekday set;
- validates unique, contained dated closures;
- canonicalizes harmless list ordering and produces a deterministic candidate revision;
- derives the instructional-date list without storing generated days; and
- resolves one local date to an exact period or gap and an instructional/non-instructional reason.

Two distinct calendars for the same institutional unit may cover the same dates. The candidate
does not introduce tenant-wide or institution-wide year uniqueness.

CF-2B now adds the private authoritative writer behind that contract:

- `academics.calendar` is a release-declared module depending on `institution.structure`;
- definition management, publication, and exact reading use distinct tenant-defined capabilities;
- calendar registration requires one exact published root institution with its recorded initial
  operator publication; no active-unit, ancestor, tenant default, or latest-row selector exists;
- draft definition and full draft replacement use stable calendar/year/period/closure identities
  and expected-version checks;
- publication revalidates the institutional/operator basis, current module and capability state,
  PostgreSQL time-zone catalogue, stored candidate revision, and within-calendar overlap;
- every mutation commits state, minimized audit, one internal outbox event, and its exact
  actor/request-bound idempotency result in the same writer transaction;
- exact read-after-write and exact-calendar/local-date resolution use the authoritative writer;
- database triggers prohibit calendar mutation, year deletion, direct published edits, child edits
  after publication, invalid child containment, and evidence-free state transitions; and
- a partial PostgreSQL GiST exclusion constraint prevents overlapping published date ranges for
  the same tenant and calendar, including concurrent publication attempts.

The four Ash resources remain closed: they expose no generic create, read, update, delete,
filtering, collection, or public interface actions.

## Focused scenarios

| Scenario | Result |
| --- | --- |
| Two terms, an explicit gap, Monday–Friday instruction, one in-term closure, and one named break closure | Passed |
| Instructional weekday, weekend, term gap, in-term closure, and closure outside a term | Passed |
| Two exact calendar identities over identical dates for one unit | Passed |
| Reordered period, closure, and weekday inputs | Passed with the same canonical candidate revision |
| Missing owner, extra caller tenant, or malformed identifier | Rejected |
| Reversed year, period outside year, or overlapping periods | Rejected |
| Duplicate period sequence, closure date, or weekday | Rejected |
| IANA-shaped `Africa/Blantyre` zone and malformed local zone | Accepted and rejected respectively |
| Non-date or date outside the year during resolution | Rejected |

The pure candidate check remains syntactic. The persistent writer additionally validates the zone
against PostgreSQL's `pg_timezone_names` catalogue when a draft is defined or replaced and again
at publication.

## CF-2B persistent scenarios

The focused writer suite covers:

- registration, full draft definition, non-mutating preview, publication, exact published read,
  instructional-date resolution, and exact replay;
- draft replacement, stale-version denial, candidate-revision change, and immutable publication;
- missing context, capability denial, inactive dependency, wrong-tenant non-disclosure, and unknown
  input denial;
- actor-bound and request-bound idempotency;
- injected completion failure with rollback of state, audit, outbox, and idempotency state;
- unsupported database time zone, overlapping published year, evidence-free direct insert, direct
  publication bypass, and direct published-definition update; and
- minimized event payloads containing identifiers, status, version, kind, and candidate revision,
  without labels or free text.

The initial root-institution eligibility is intentionally bounded to the CF-1 structure currently
implemented. Ordinary organizational-unit ownership and nearest-containing-institution resolution
remain unavailable rather than being guessed.

## Verification

The original pure-contract command passed on 2026-10-03:

```text
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/academic_calendar/contract_test.exs

7 tests, 0 failures
```

The persistent focused command passed on 2026-10-04:

```text
mise exec -- env MIX_ENV=test CHIMWEMWE_TEST_DATABASE=chimwemwe_calendar_test mix test \
  apps/chimwemwe_core/test/chimwemwe/academic_calendar/contract_test.exs \
  apps/chimwemwe_core/test/chimwemwe/academic_calendar/foundation_test.exs

14 tests, 0 failures
```

A fresh database applied all migrations through CF-2B. A separate empty database then applied
through migration `20261004120000`, rolled that migration back one step, and reapplied it
successfully. The migration retains `btree_gist`; it refuses rollback when calendar state or its
audit/outbox/idempotency authority evidence is retained.

The required `make check` ran against the shared checkout on 2026-10-04. Documentation and
repository-tool checks passed. The core gate passed formatting, warnings-as-errors compilation,
OpenAPI drift, migration drift, Credo, Hex dependency audit, unused-dependency check, Dialyzer with
zero errors, 262 tests, and Git whitespace. The complete repository gate then stopped at the
existing web `npm audit --audit-level=high` result: nine high-severity transitive
`braces`/`micromatch` findings through `fast-glob` and dependent tooling, with only a breaking
forced npm remediation offered. The repository is therefore not claimed fully green; the focused
calendar suite, migration proof, and full core gate are green. A passing focused suite does not
close any connected, representative, real-data, security-review, or deployment condition.

## Explicitly not implemented

- no ordinary-unit/nearest-containing-institution calendar ownership yet;
- no public API, connected same-origin write, or connected identity/session path;
- no published successor/correction, template adoption, or source migration;
- no stored generated-day table, timetable, recurrence engine, clock-time scheduling, or solver;
- no representative-domain, C25-03-R, C25-05, C25-06, or deployment evidence.

## Next bounded increment

CF-3 is the connected synthetic calendar preparation workflow: connect the existing local
year/period/weekday/closure screen to these exact named actions through the accepted same-origin
session boundary, refresh it from the committed writer result, and prove accessible success,
validation, denial, stale-version, session, origin, and CSRF states. It must not expose generic
resource actions or turn the browser's current draft into calendar authority. C25-03-R, C25-05,
C25-06 and the other connected/real-adoption gates remain fail closed.
