# Academic calendar executable-contract evidence

- Status: Focused executable pre-persistence evidence complete; persistent calendar slice not started
- Evidence date: 2026-10-03
- Owner: Product and platform engineering
- Governing decision: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Delivery plan: [Classroom-first six-week plan](../plans/classroom-first-six-week-plan.md)
- Next review trigger: CF-1 institutional/operator implementation or calendar persistence entry

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

The current zone check is syntactic because this increment performs local-date calculations only.
The persistent writer must validate the zone against the selected runtime/database catalogue before
publication; this evidence does not claim that arbitrary submitted names are known IANA zones.

## Verification

The focused command passed on 2026-10-03:

```text
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/academic_calendar/contract_test.exs

7 tests, 0 failures
```

Compilation with warnings treated as errors also passed after the focused implementation.

The required `make check` was run on 2026-10-03. Documentation and repository-tool checks passed.
The full core verification passed all nine stages, including formatting, warning-free compilation,
OpenAPI drift, migration drift, Credo, dependency audit, Dialyzer with zero errors, 197 tests, and
the Git whitespace check. The complete repository check then stopped in `check-web` at the existing
`npm audit --audit-level=high` result: nine high-severity transitive `braces`/`micromatch`
advisories, for which npm offers only a breaking forced dependency change. No later web E2E or
tooling stage ran. The repository is therefore not claimed green; the focused calendar and full
core results are green.

## Explicitly not implemented

- no `InstitutionalUnit` or primary-operator persistence;
- no calendar/year/period/closure table or Ash resource;
- no release manifest, entitlement, activation, or capability path for the calendar module;
- no named writer action, optimistic version, idempotency claim, audit row, or outbox event;
- no database overlap constraint, migration, rollback, or recovery proof;
- no public API, same-origin write, browser preparation screen, or connected identity;
- no publication, published-revision correction, template, source migration, or attendance consumer;
- no representative-domain, C25-03-R, C25-05, C25-06, or deployment evidence.

## Next bounded increment

Implement CF-1's minimum institutional identity and initial verified primary-operator/publication
eligibility admitted by ADRs 0034/0035. Then persist the accepted calendar aggregate and expose its
named draft, preview, publish, exact-read, and resolver actions with compound tenant/owner keys,
current module/capability checks, optimistic concurrency, exact idempotency, audit/outbox atomicity,
rollback injection, read-after-write, and reviewed migration evidence. The small calendar
preparation screen follows that writer; it does not substitute synthetic browser state for core
publication.
