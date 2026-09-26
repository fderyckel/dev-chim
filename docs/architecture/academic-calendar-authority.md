# Academic calendar authority

- Status: Proposed; scope revision required by ADR 0025; no implementation authorization
- Owner: Product and platform engineering
- Governing record: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Review trigger: ADR 0025 alignment, ADR acceptance, temporal-record decision, real migration
  fixture, or first authorized academics-module slice

## Purpose and boundary

This contract translates the useful academic-year and academic-term concepts from the supplied Frappe implementation into Chimwemwe without copying its DocType structure. It defines a future business-module boundary and migration target. It does not create a production resource, table, application, public API, scheduler, or user interface.

The current `school_scope_id` examples predate
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md). They
remain design evidence only. Before acceptance, this contract must use the recursive institutional
model, distinguish exact institutional-unit scope from programme or other academic scope, and
cover simultaneous calendar patterns used across learning institutions. No current school-scoped
identifier or hierarchy fallback is approved as a stable contract.

The module owns school-calendar meaning. The platform kernel continues to own trusted tenant and actor context, capability evaluation, persistence routing, module lifecycle, audit conventions, idempotency, and outbox infrastructure. Other school modules consume stable calendar identifiers and named reads; they do not recreate current-year rules.

## Source model translation

| Frappe concept or behaviour | Chimwemwe proposal | Reason |
| --- | --- | --- |
| Academic Year | School-scoped `AcademicYear` aggregate | Keeps one stable identity and publication boundary |
| Academic-type Term | Owned `AcademicPeriod` | Instructional periods cannot drift outside their year or become a parallel calendar |
| Activity or Other Term | Explicit migration disposition to its owning module | Prevents overlapping non-academic cycles from weakening the primary sequence |
| School Calendar weekly offs | `WeekPattern` within the year definition | Makes the ordinary instructional pattern explicit |
| School Calendar holidays | `CalendarException` | Represents dated deviations without treating every day as authoritative state |
| School Calendar Term | Reconciled during migration, then removed | Avoids duplicate period truth |
| Stored instructional-day total | Derived count and migration reconciliation evidence | Prevents a calculated value from becoming independent truth |
| Global or ancestor calendar fallback | Explicit application of an immutable `CalendarTemplateRevision` | Preserves reuse with visible provenance and no live inheritance |
| Several rows marked current or returned by date | One deterministic date-based resolver over published state | Prevents arbitrary selection |
| Admission visibility on Academic Year or Term | Admissions-owned configuration referencing a published year or period | Keeps admission policy with its owner |
| Save callbacks creating start/end events | Disposable projection and transactional outbox facts | Prevents callback-created secondary authority |
| Fixed school roles in permission hooks | Tenant-defined capabilities | Preserves renameable, composable tenant authority |

The source review is input evidence, not executable instruction. Chimwemwe does not import Frappe permission hooks, callbacks, framework globals, naming assumptions, or hierarchy defaults as production contracts.

## Proposed aggregate

```text
AcademicYear
  tenant_id
  school_scope_id
  stable id, code, localized label
  start_on, end_on, time_zone
  lifecycle state, optimistic revision
  applied_template_revision_id and provenance
  |
  +-- AcademicPeriod[]
  +-- WeekPattern
  +-- CalendarException[] (one school-local date each)
```

The aggregate boundary means that publication validates one coherent definition. Physical tables may be separate for integrity and queryability, but no child is independently authoritative.

### `AcademicYear`

- belongs to exactly one authenticated tenant and one stable school scope;
- has a stable UUID that survives label and code changes;
- has inclusive start and end dates interpreted in an explicit IANA time zone;
- has an auditable lifecycle such as draft, published, closed, and superseded, subject to the temporal-record decision;
- records the template revision applied, when relevant, without remaining linked to future template mutations; and
- has an optimistic revision used by every state-changing action.

### `AcademicPeriod`

- belongs to one year and shares its tenant and school scope;
- has its own stable UUID, tenant-controlled type key, localized label, sequence, and inclusive dates;
- is contained by the year;
- cannot overlap another primary period in the same year; and
- is resolved by date only from the published year revision.

Gaps are allowed because holidays and transitions do not always form a period. The first slice deliberately does not model overlapping programme, billing, reporting, examination, or timetable cycles as academic periods.

### `WeekPattern` and `CalendarException`

The week pattern states the explicit set of weekdays that are ordinarily instructional. An exception overrides that expectation for one school-local date and uses a typed effect, reason, or category. A named action may accept a bounded date range for user convenience, but it expands the range atomically into canonical per-date records and rejects conflicting effects. Free text is optional, classified, and excluded from unsafe logs and event payloads.

The resolver first determines period membership. A date inside the year but outside every primary period has a non-instructional base status. A closure exception may annotate that date with a named-break reason, but an opening exception is valid only inside a primary period. Inside a period, the resolver calculates ordinary status from the published week pattern and then applies at most one effective exception. A materialized day list or instructional-day total may improve presentation or reporting, but it is versioned, rebuildable, and never mutated as source truth.

## Invariants

- Tenant and school scope are non-null on every authoritative row and protected by compound relationships.
- A year end is not before its start.
- Period dates are contained by the year, sequence values are unique within the year, and primary periods do not overlap.
- At most one published year covers a date for a school scope.
- A calendar exception is contained by the year and has one unambiguous effect.
- An exception that opens an ordinary non-instructional date is contained by a primary period; a closure outside periods may annotate a named break without changing the base status.
- At most one effective exception applies to a school-local date; a range action commits all expanded dates or none.
- A platform template is immutable global reference data; a tenant or school template is tenant-owned and cannot reference another tenant.
- A published year never changes because its source template changed.
- Durable consumers use stable IDs, never labels or implicit latest-row lookup.
- State changes require named actions, capability checks, optimistic concurrency, idempotency where replay is possible, and safe audit evidence.
- State and required side-effect facts commit atomically through the transactional outbox.

Database constraints enforce every invariant that can be expressed independently of application policy. Generated migrations require review for tenant keys, compound uniqueness and foreign keys, indexes, lock behaviour, retained data, and forward-fix or rollback strategy.

## Named domain surface

The exact action names remain an implementation concern, but the public meaning is bounded:

| Intent | Required outcome |
| --- | --- |
| Create draft year | Creates one empty or explicitly based draft for a school scope |
| Create successor draft | Copies approved structure while requiring concrete dates for the new target year |
| Apply template revision | Copies validated template values and records provenance |
| Compare template revision | Reports differences without mutating the year |
| Rebase unpublished draft | Applies selected changes with explicit conflict resolution |
| Define or reschedule period | Preserves containment, order, concurrency, and audit |
| Set week pattern | Replaces ordinary weekday rules through one validated transition |
| Add, change, or withdraw exception | Records one dated deviation without editing generated days |
| Preview publication | Returns validation and impact evidence without mutation |
| Publish year | Commits one coherent version and its outbox fact |
| Close or supersede year | Uses a governed transition without erasing retained data |
| Resolve instructional context | Returns one published year, optional period, publication revision, instructional status, and typed reason for a school and date |

Generic create, update, delete, arbitrary filters over private fields, caller-selected repositories, and caller-selected tenant or school ownership are not public interfaces.

## Deterministic current context

There is no mutable `is_current` flag. Current context is a query with explicit inputs and result semantics:

```text
resolve_instructional_context(school_scope_id, as_of_date)
  -> {
       academic_year_id,
       academic_period_id | none,
       publication_revision,
       instructional | non_instructional,
       reason
     }
  -> not_found
  -> conflict
```

The authenticated tenant comes from trusted execution context. `as_of_date` is required and is interpreted as a school-local calendar date. If a caller starts with an instant, the server converts it with the stored IANA time zone; caller input cannot override that zone. The resolver does not fall back to an ancestor, a global default, an unpublished year, or an arbitrary latest record. A conflict is an integrity incident to surface and repair, not a sorting problem.

Resolution order is fixed: published year, optional primary period, base status, then one dated exception. No period produces a non-instructional base status with reason `outside_period`; a closure exception may replace the reason with a named break, while an opening is rejected. Inside a period, the week pattern supplies the base status and an exception may close an ordinary instructional weekday or open an ordinary non-instructional weekday. Instructional totals reuse this exact calculation.

Interfaces may offer a resolved default while a user prepares work. Backdated, imported, scheduled, and integration work must keep the explicit date and stable IDs used. Once a dependent record becomes durable, it cannot be silently reclassified by a later calendar edit.

## Template agility without hidden inheritance

A calendar template has a stable identity and immutable revisions. The initial contract contains concrete target-year dates, primary periods, an ordinary week pattern, dated exceptions, and localization defaults. Template application copies those values into a draft and records the result. Relative offsets, recurrence rules, automatic year shifting, and expressions are deferred until evidence shows concrete dates plus an explicitly dated successor-draft action are insufficient. A template cannot contain actor roles, authorization rules, tenant routing, arbitrary code, SQL, or module activation decisions.

Discovery may show compatible platform, tenant, or parent-school templates. Adoption is always explicit:

1. an authorized actor selects one exact template revision;
2. the server previews validation and differences;
3. application copies values into a draft and records source provenance;
4. school-specific edits occur on the draft; and
5. publication freezes the reviewed meaning independently of later template revisions.

When a new template revision appears, the school sees a comparison. Only an authorized rebase action may apply selected changes to an unpublished draft. Published or historically used years are never mass-updated. This supports rapid multi-school setup without turning hierarchy into hidden runtime authority.

## Cross-module contract

- Attendance, assessment, timetabling, admissions, reporting, and finance call named reads or keep stable year and period IDs; they do not query calendar tables directly as public behaviour.
- A consumer must define whether it needs current published context, an explicit historical context, or a versioned planning snapshot.
- Admissions owns visibility, application windows, and applicant eligibility while referencing the calendar's stable IDs.
- Scheduling owns candidate generation and constraint explanation only. It consumes a versioned calendar snapshot and cannot publish calendar state.
- Search, caches, calendar feeds, reports, and analytics are disposable projections with tenant-qualified keys and rebuild paths.
- External notifications or integrations consume allowlisted outbox facts. Event payloads contain stable references and minimal safe data.
- Module release, entitlement, activation, and actor authorization are checked independently on every synchronous and asynchronous entry point.

## Frappe migration contract

Migration is a reconciliation project, not a table copy.

| Source | Target or treatment |
| --- | --- |
| Academic Year identity and dates | `AcademicYear`; retain source ID in the migration ledger |
| Academic-type Term | `AcademicPeriod`; preserve mapped stable ID and source evidence |
| Activity or Other Term | Block until its owning module and mapping are explicit |
| School Calendar weekly offs | `WeekPattern` |
| Holiday rows and special days | `CalendarException` after category mapping |
| School Calendar Term | Compare with mapped Term; block unresolved discrepancies |
| Stored instructional-day total | Recalculate; retain any mismatch as reconciliation evidence |
| School hierarchy/global default | Resolve source behaviour once, then record explicit template provenance |
| Year or term admission flag | Move to admissions-owned configuration when that module exists |
| Generated start/end events | Do not import as authority; regenerate projections or emit governed facts |
| Downstream year/term fields | Replace name matching with ledger-backed stable-ID mapping |

Each rehearsal produces an immutable source snapshot, mapping revision, source and target counts, per-type reference coverage, conflict report, orphan report, and read-back reconciliation. Required conflict classes include duplicate names, invalid or overlapping date ranges, several current candidates, term/calendar-term mismatch, missing school scope, unresolved hierarchy/default selection, and references to absent years or periods.

Cutover is blocked until every in-scope reference is mapped or explicitly dispositioned. Silent fallback, name-only matching, and last-write-wins repair are prohibited.

## Delivery gates

### A0 — decision and source contract

This document, ADR 0021, the [synthetic calendar scenario review](academic-calendar-synthetic-scenario-review.md), and the [temporal-records synthetic scenario review](temporal-records-synthetic-scenario-review.md) are the complete authorized slice. The walkthroughs support the model and its immutable successor correction path after bounded refinements but do not provide stakeholder or accountable architecture acceptance. No runtime code is added.

### A1 — prerequisite platform closure

Before an academics business module starts, complete and accept the relevant core boundaries for safe writes, module lifecycle, governed extensions, and production operations. Satisfy the relevant binding conditions of [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md) and prove its correction semantics for the calendar domain. Obtain a separate implementation authorization.

### A2 — executable model proof

Use synthetic data to implement the smallest tenant-owned aggregate, constraints, deterministic resolver, and policy matrix. Add positive, missing-context, denied-capability, cross-tenant, cross-school, date-boundary, overlap, and concurrency tests. Do not expose a public client yet.

### A3 — publication and templates

Add named draft, template, preview, publish, correction, and closure transitions with idempotency, optimistic concurrency, audit, outbox, replay, and recovery evidence. Prove that template changes cannot mutate a published year.

### A4 — migration shadow

Build an adapter around frozen, synthetic or properly governed Frappe exports. Run repeatable shadow imports, discrepancy reports, ID mapping, destination read-back, and downstream reference reconciliation. No cutover occurs in this gate.

### A5 — intentional experience

Prototype and test the browser-first drafting, conflict, comparison, preview, publication, and correction journeys. Define a compact phone read experience only where research shows a frequent mobile task. Server authorization and validation remain authoritative.

### A6 — first consumer and progressive migration

Adopt one explicitly authorized consumer, preferably a low-blast-radius read path, and measure resolver, migration, and support behaviour before moving write-critical modules. Each additional consumer owns its compatibility and reconciliation evidence.

## Acceptance evidence

ADR acceptance and implementation require all evidence named in ADR 0021 plus:

- school-domain representative review of at least two representative calendar patterns; the [synthetic scenario review](academic-calendar-synthetic-scenario-review.md) is design evidence only;
- an aggregate and action contract review against ADRs 0003, 0005, 0007, 0019, and 0020;
- migration reconciliation over representative Frappe fixtures;
- threat review for TM-01, TM-02, TM-09, TM-10, TM-11, TM-13, TM-14, TM-15, and TM-16;
- measured query and publication behaviour at a representative tenant scale; and
- recovery rehearsal showing that authoritative state, outbox facts, and disposable projections converge after interruption.

## Explicit non-goals

- no implementation authorization from this document;
- no field-for-field Frappe compatibility API;
- no generic temporal, workflow, runtime-schema, or universal settings engine;
- no fixed school role names or client-side authorization;
- no live template inheritance or silent hierarchy/global fallback;
- no independently mutable calendar-day or generated-event authority;
- no scheduling solver selection or authoritative solver state;
- no production web, mobile, job, integration, or analytics surface; and
- no claim that planned tests are completed evidence.

## Related records

- [Core foundation boundary](core-foundation-boundary.md)
- [Synthetic calendar scenario review](academic-calendar-synthetic-scenario-review.md)
- [Temporal records decision review](temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](temporal-records-synthetic-scenario-review.md)
- [Domain model authoring and metadata](domain-model-authoring-and-metadata.md)
- [Module activation and lifecycle](module-activation-and-lifecycle.md)
- [ADR 0016](../adr/0016-scheduling-service-contract-and-publication-boundary.md)
- [ADR 0018](../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- [Phase 1 core-foundation plan](../plans/phase-1-core-foundation-plan.md)
- [Threat model](../security/threat-model.md)
