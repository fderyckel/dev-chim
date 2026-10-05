# Academic calendar authority

- Status: Accepted synthetic L1 contract; CF-2B private publication writer implemented
- Owner: Product and platform engineering
- Governing record: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Review trigger: first persistent writer, first browser preparation screen, representative finding,
  temporal successor/correction work, migration fixture, or connected adoption

## Purpose and present boundary

This contract defines the academic-calendar meaning that attendance and later education modules
will consume. It uses one exact tenant-qualified `AcademicCalendar` owned by one exact
`institutional_unit_id`; `school_scope_id`, active-unit selection, and parent/default fallback are
not accepted contracts.

`Chimwemwe.AcademicCalendar` validates and canonicalizes one publication candidate, calculates
instructional dates, produces a deterministic candidate revision, and resolves a local date.
`Chimwemwe.AcademicCalendar.Foundation` now owns the private persistent named-action boundary. It
revalidates trusted tenant, actor, placement, institution/operator publication, module, capability,
version, idempotency, stored revision and database time zone on PostgreSQL. The four resources
remain closed to generic Ash actions, and no public API or connected browser route is included.

## Ownership model

```text
InstitutionalUnit (exact owner; no hierarchy fallback)
  |
  +-- AcademicCalendar (stable identity; several allowed per unit)
        |
        +-- AcademicYear (stable aggregate identity)
              |
              +-- immutable PublishedRevision[]
                    +-- ordered AcademicPeriod[]
                    +-- explicit instructional weekdays
                    +-- dated Closure[]
```

Two calendars may cover the same dates. Within one calendar, two published academic years cannot
cover the same local date. The owner relationship is not authorization: the actor still needs the
code-owned capability, and hierarchy alone grants no read or write.

For publication, an institution must have eligible verified primary-operator accountability. An
ordinary organizational unit resolves that eligibility through its exact nearest containing
institution under ADRs 0034/0035. This resolution checks legal accountability only; it does not
select a calendar or copy an ancestor calendar.

## First definition

One academic-year publication candidate contains:

| Field | Meaning |
| --- | --- |
| `calendar_id` | Exact stable calendar identity selected by the caller's authorized task |
| `institutional_unit_id` | Exact owner; never inferred from an active selector or ancestor |
| `academic_year_id` | Stable year aggregate identity |
| `code`, `label` | Tenant vocabulary and presentation, not authority |
| `start_on`, `end_on` | Inclusive local date range |
| `time_zone` | Explicit IANA time-zone name used by the authoritative calendar |
| `instructional_weekdays` | Explicit ISO weekday values, Monday `1` through Sunday `7` |
| `periods` | Ordered, contained, non-overlapping primary periods |
| `closures` | Unique named non-instructional local dates contained by the year |

Periods carry stable IDs, tenant-controlled type keys, labels, sequence, and inclusive dates. Type
keys may express terms, semesters, or blocks without introducing different structural behavior.
Gaps are valid and non-instructional. A closure in a gap preserves its named-break reason. The
first slice does not include opening exceptions, recurring rules, overlapping secondary cycles,
or stored generated-day authority.

The pure executable contract validates IANA-shaped zone names. The persistent writer additionally
checks PostgreSQL's time-zone catalogue when defining or replacing a draft and again before
publication; syntax alone is not publication evidence.

## Invariants

- Every persisted row is tenant-qualified; owner/child relationships use compound tenant keys.
- Calendar, institutional-unit, year, period, and closure identities are stable opaque UUIDs.
- A year end is not before its start; the first executable candidate is bounded to 731 dates.
- At least one primary period exists, each period is contained by the year, sequence values and IDs
  are unique, and inclusive period ranges do not overlap.
- Instructional weekdays are a non-empty unique subset of ISO values `1..7`.
- Closure IDs and dates are unique within the year, and every closure is contained by the year.
- Publication overlap is evaluated within one exact calendar, never tenant-wide or unit-wide.
- Draft state may change only through named actions with an expected version.
- Published revisions are immutable; a correction or successor creates new durable meaning under
  ADR 0018 rather than rewriting a published payload.
- Durable consumers store the exact calendar, year, and publication revision they used.
- State, audit, outbox, and idempotency result commit atomically on the authoritative writer.

Database constraints enforce the policy-independent invariants. Compound foreign keys preserve
tenant ownership. Triggers enforce eligible initial ownership, lifecycle/version transitions,
draft-only child replacement, child containment, published immutability, and evidence-backed
state transitions. A partial GiST exclusion constraint enforces non-overlapping published years
within one exact tenant/calendar even under concurrency. Rollback refuses retained calendar state
or authority evidence; the bundled `btree_gist` extension is retained because another schema may
reuse it.

## Resolution contract

There is no mutable current-year flag and no arbitrary latest-row fallback.

```text
resolve_instructional_context(calendar_id, local_date)
  -> {
       institutional_unit_id,
       academic_year_id,
       academic_period_id | none,
       publication_revision,
       instructional | non_instructional,
       reason
     }
  -> not_found
  -> conflict
```

The authenticated tenant comes from trusted execution context. The local date is explicit. If a
caller begins with an instant, the server converts it using the stored calendar time zone; request
input cannot override that zone. Only published state is eligible in the persistent resolver.

Resolution order is fixed:

1. select the exact published year for the exact calendar and local date;
2. find the optional primary period;
3. return a named closure as non-instructional when one exists;
4. otherwise return `outside_period` when no period exists;
5. otherwise apply the ordinary instructional-weekday set.

A conflict is an integrity incident, not a sorting problem. Immediate read-after-publication uses
the authoritative writer. Replica, cache, generated day list, or interface state cannot authorize
publication or resolve a protected inconsistency.

## Named domain surface

| Intent | Required behavior |
| --- | --- |
| Register calendar | Bind a stable calendar to one exact eligible institutional unit |
| Define draft year | Set explicit identity, dates, zone, label, and optimistic version |
| Replace draft definition | Atomically validate periods, weekdays, and closures under expected version |
| Preview publication | Return canonical validation, conflicts, calculated dates, and candidate revision without mutation |
| Publish year | Revalidate institutional/operator eligibility, authority, lifecycle, expected version, and all invariants; commit immutable revision and evidence atomically |
| Read published year | Return one minimal exact revision from the writer for immediate confirmation |
| Resolve instructional context | Return deterministic published meaning for one exact calendar and local date |

Generic create/update/delete, caller-selected tenant or repository, hierarchy/default selection,
arbitrary private filters, and runtime action invocation are not public interfaces. The first
module key is `academics.calendar`; definition management, publication, and reading use distinct
tenant-defined capabilities rather than fixed job-title roles.

## Templates, successors, and consumers

Template adoption is deferred from the first classroom slice. A later template contract uses
stable identity and immutable revisions. Explicit adoption copies reviewed values into a draft and
records provenance; parent, tenant, or platform templates never become live inherited authority.

Published successor/correction work is also deferred. Before it is implemented, define impact
preview, exact predecessor semantics, consumer reconciliation, and attributable reason policy
under ADR 0018. Direct editing of published state remains prohibited while that work is absent.

Attendance, enrolment, assessment, timetabling, admissions, reporting, and finance consume named
reads or stable IDs. A consumer declares whether it follows a current published revision while
preparing disposable work or pins an exact revision for durable history. Search, reports, feeds,
and analytics are disposable projections and never another calendar authority.

## Implementation sequence

1. **Implemented: executable candidate contract.** Validate exact ownership inputs, year and
   period boundaries, overlap, weekday and closure uniqueness; calculate instructional dates;
   resolve terms, gaps, weekdays, and closures; produce a deterministic candidate revision.
2. **Implemented: CF-1 institutional prerequisite.** Persist the minimum institutional identity and
   primary-operator publication eligibility admitted by ADRs 0034/0035. Do not add the wider
   hierarchy, site, affiliation, or transfer backlog merely to reach calendar work.
3. **Implemented: CF-2B calendar persistence.** Add tenant-owned calendar/year/period/closure resources,
   reviewed migrations, lifecycle declaration, named draft/preview/publish/read actions, compound
   integrity, authorization, concurrency, idempotency, audit/outbox, and rollback proof.
4. **Next: CF-3 connected preparation screen.** Use the same-origin named-action boundary for a small accessible
   year/term/weekday/closure workflow; refresh from the committed writer revision.
5. **Later:** successor correction, templates, migration shadow, additional exceptions, and the
   first pinned attendance consumer, each through its own admitted slice.

## Acceptance evidence

The implemented contract tests currently prove:

- a two-term calendar with a gap and closures;
- instructional weekday, weekend, gap, and closure resolution;
- two distinct calendars over identical dates for one exact unit;
- stable canonical revision despite harmless input order;
- missing owner, caller-supplied tenant, malformed identity, invalid ranges, outside-year periods,
  overlap, duplicate sequences/dates/weekdays, invalid zone shape, and out-of-range date rejection.

The CF-2B suite adds focused database publication, module/dependency/capability denial,
tenant-isolation, exact idempotency, rollback, immutable-publication, direct-write, time-zone,
overlap, exact-read and resolution evidence. It does not prove connected browser usability,
external outbox consumption/recovery, representative calendar correctness, real-data adoption, or
deployment readiness. Those claims remain attached to their separate exits.

Before connected or real adoption, retain C25-03-R, C25-05, C25-06, identity and selected-
environment qualification, actual operator/legal validation, and representative review of at
least two materially different calendar patterns. Synthetic fixtures and repository checks cannot
substitute for those records.

## Explicit non-goals for CF-2B

- no public or connected browser route;
- no template catalogue, recurrence engine, scheduling solver, or generated-day authority;
- no real institution, person, student, staff, or restricted data;
- no claim that C25-03-R, C25-05, C25-06, identity, migration, or deployment gates are closed.

## Related records

- [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- [First classroom slice](../phase-2/classroom-first-slice-contract.md)
- [Classroom-first six-week plan](../plans/classroom-first-six-week-plan.md)
- [Synthetic calendar scenario review](academic-calendar-synthetic-scenario-review.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0034](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)
- [ADR 0035](../adr/0035-c25-04-delegated-primary-operator-acceptance.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
