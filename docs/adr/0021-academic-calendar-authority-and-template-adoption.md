# ADR 0021: Academic calendar authority and template adoption

- Status: Proposed
- Date: 2026-09-24
- Accountable owner: Product and platform engineering
- Deciders: Architecture review group, product owner, school-domain representative, and security architecture
- Supersedes: None

## Context

Chimwemwe needs academic years and periods before attendance, admissions, timetabling, assessment, reporting, and other school modules can use a shared temporal context. The supplied Frappe implementation provides useful evidence: academic years and terms are explicit records, schools may select a calendar, and many dependent records keep year or term references.

The same implementation also distributes authority across Academic Year, Term, School Calendar, School Calendar Term, and generated start/end events. Current-year resolution may return several records, school hierarchy and global defaults are implicit fallbacks, admission visibility is stored on the year, and save callbacks create secondary calendar state. A local source inventory on 2026-09-24 found downstream Academic Year links in 58 DocTypes and downstream Term links in 15 DocTypes across 11 modules after excluding their defining and duplicate calendar records. A field-for-field port would therefore preserve duplicate truth and couple many future modules to settings-layer behaviour.

This record proposes the durable boundary for a future academics business module. It does not authorize a production resource, migration, public interface, scheduler, or user interface.

## Decision drivers

- One authoritative answer for a school's academic year, period, instructional days, and exceptions.
- Deterministic current-context resolution for browser, mobile, jobs, imports, and integrations.
- Fast reuse across schools without live inheritance, tenant forks, or copied code.
- Named, authorized changes with tenant isolation, concurrency control, audit, and recoverability.
- Stable identifiers for downstream modules and migration from existing Frappe references.
- Explicit module, entitlement, activation, and authorization gates.
- A bounded first model that can grow from evidence without becoming a universal temporal or workflow engine.

## Considered options

1. Port Academic Year, Academic Term, School Calendar, School Calendar Term, and callbacks one for one. This lowers superficial migration effort but preserves duplicate ownership, implicit fallbacks, fixed-role assumptions, and callback side effects.
2. Use one school-scoped Academic Year aggregate with owned periods, week pattern, and exceptions; apply immutable template revisions explicitly into drafts. This creates one authority while preserving fast reuse and traceable local adaptation.
3. Keep Academic Year and School Calendar as independent normalized authorities joined at runtime. This separates reusable patterns but leaves conflicts and ambiguous current resolution as permanent application concerns.
4. Build a generic temporal, workflow, or runtime-schema engine first. This maximizes theoretical flexibility but duplicates Ash, migration, policy, and lifecycle responsibilities before representative needs exist.

## Decision

Propose option 2 for later acceptance and implementation.

A future bounded academics module will own a tenant-qualified, school-scoped `AcademicYear` aggregate. Its authoritative calendar definition contains:

- the stable year identity, school scope, code, localized label, date range, time zone, lifecycle state, and optimistic revision;
- an ordered primary sequence of `AcademicPeriod` children replacing Academic Term;
- a `WeekPattern` describing the explicit set of ordinary instructional weekdays; and
- one-date `CalendarException` records describing closures, additional instructional days, and other governed deviations.

The first implementation will support one non-overlapping primary instructional-period sequence within a year. Labels and period-type vocabulary are tenant-controlled data. Overlapping programme, assessment, billing, or reporting cycles require concrete evidence and their own owner; they will not be smuggled into the primary sequence.

There will be no separate School Calendar Term authority. Calendar-day rows and period start/end events may be disposable projections for search, display, or integration, but they cannot become independently mutable truth.

Reusable configuration is represented by immutable `CalendarTemplateRevision` data. The initial contract contains concrete target-year dates and values, not relative expressions or automatic year shifting. A platform, tenant, or parent school scope may publish a discoverable template revision, but a school must explicitly apply a selected revision to a draft year. Application copies the governed values and records provenance. Published years do not follow template changes automatically. A school may compare a later template revision and deliberately rebase an unpublished draft through a named action. This replaces implicit ancestor/global fallback with visible adoption.

The public domain surface will use named actions rather than generic CRUD. The initial contract is expected to include actions equivalent to:

- create a draft year;
- create an explicitly dated successor draft from an existing structure;
- apply or compare a template revision;
- define or reschedule a period;
- set the ordinary week pattern;
- add, change, or withdraw an exception;
- validate and preview publication;
- publish, close, or supersede a year through governed transitions; and
- resolve instructional context for one school and date.

Capabilities are tenant-defined and checked at the domain boundary. No educator, administrator, or other school job title is a production role constant.

`resolve_instructional_context(school_scope_id, as_of_date)` will use the authenticated tenant and an explicit school-local date, read only published calendar authority, and return the stable year identifier, period identifier when one applies, publication revision, instructional status, and typed reason. A year date outside every period has a non-instructional base status. A closure exception may replace its `outside_period` reason so a named break remains visible, but an opening outside every period is invalid. Inside a period, the week pattern supplies the ordinary status and at most one dated exception may override it. If resolution starts from an instant, the server converts it with the stored IANA time zone; callers cannot override that zone. The resolver returns a typed not-found or conflict result instead of choosing an arbitrary latest row. Publication must prevent overlapping published years for the same school scope. Backdated transactions, imports, and integrations pass an explicit date or stable identifiers; they do not depend on the wall clock.

An action may accept a closure or opening range for user convenience, but it expands the range atomically into canonical one-date exceptions and rejects conflicting effects on the same date. Instructional-day totals are derived from periods, week pattern, and exceptions. Any stored total is a disposable, rebuildable projection rather than independently editable truth.

Downstream modules reference stable academic-year and period identifiers with tenant-qualified integrity. They may resolve defaults while preparing a draft, but a posted or otherwise durable record keeps the selected identifiers and relevant temporal evidence rather than silently changing when a calendar is corrected. Admissions-owned visibility and application-window rules remain in the admissions module and reference published year identifiers; they are not attributes of the calendar authority.

Publishing or correcting calendar state records required side-effect facts through the transactional outbox. Scheduling or optimization services may consume a versioned calendar snapshot and return candidates, but cannot own or publish calendar state. Release availability, entitlement, module activation, and actor authorization remain independent gates.

Published-history correction, effective dating, and evidence semantics must align with conditionally accepted [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md). Until its binding conditions are satisfied and proven for the calendar domain, this proposal requires only that published meaning is never silently rewritten and that every correction is attributable, reviewable, and recoverable.

## Consequences

### Positive

- Schools get one explainable calendar authority instead of reconciling year, term, calendar, and generated-event models.
- Explicit template adoption preserves reuse while making local divergence and later updates visible.
- Stable identifiers and deterministic resolution reduce repeated current-year logic across modules.
- Ordinary tenant-owned data supports local terminology and operating patterns without tenant-specific code.
- Projections, notifications, and integrations can be rebuilt or replayed from authoritative state and outbox facts.

### Negative

- Migration must reconcile duplicated Frappe term and calendar-term data before cutover.
- Template comparison and draft rebasing require product design and conflict reporting.
- The bounded primary-period model will not initially represent every overlapping school cycle.
- Cross-module consumers must migrate from names and implicit defaults to stable identifiers and explicit dates.
- Publication, correction, and template provenance add more deliberate workflow than direct row editing.

## Security, privacy, operability, and migration effects

Every academic-calendar record, query, action, event, job, cache key, projection, and import mapping is tenant-qualified and school-scoped. The server derives tenant and placement from trusted execution context and fails closed on missing, stale, or conflicting context. Template discovery never permits a cross-tenant read; platform templates are explicit global reference data, while tenant and school templates retain non-null tenant ownership.

Publishing, correction, closure, template adoption, and exception changes require capabilities and record safe actor, tenant, purpose, correlation, revision, and provenance evidence. Optimistic concurrency and idempotency protect state transitions. Side effects are emitted through the transactional outbox after the authoritative transaction commits. Calendar data must not expose restricted learner or staff records; free-text exception descriptions require bounded classification and logging rules.

The Frappe migration will preserve source identifiers in a migration ledger and map Academic Year to the aggregate, academic-type Term records to `AcademicPeriod`, weekly-off rules to `WeekPattern`, and holidays or special days to `CalendarException`. Activity and Other term types require an explicit owning-module disposition and are not forced into the primary instructional sequence. School Calendar Term rows are reconciled against their referenced Term rather than imported as a second authority. Global and ancestor calendar fallbacks become explicit template-revision provenance. Year and term admission visibility move to admissions-owned configuration. Generated period-boundary events are regenerated as projections or downstream events and are not imported as independent truth.

Before cutover, a shadow import must report source counts, reference coverage, duplicate names, date overlaps, hierarchy/default resolution, term/calendar-term discrepancies, orphaned consumers, and unresolved mappings. No conflict may be resolved by silent last-write-wins behaviour.

## Validation evidence

Current evidence is limited to repository architecture constraints, the 2026-09-24 read-only review of the supplied Frappe school-settings source and reference inventory, the [synthetic calendar scenario review](../architecture/academic-calendar-synthetic-scenario-review.md), the [temporal-records synthetic scenario review](../architecture/temporal-records-synthetic-scenario-review.md), and the [ADR 0018 decision review](../architecture/temporal-records-decision-review.md). The fixtures support the single aggregate, primary periods, explicit weekday set, per-date exceptions, deterministic resolver, concrete template adoption, and an immutable successor publication revision for correction. They do not satisfy ADR 0018's binding executable conditions, provide school-domain stakeholder acceptance, or prove this proposal in production.

Acceptance requires, at minimum:

- school-domain review of the aggregate, primary-period limit, terminology, template adoption, and correction journeys;
- migration fixtures covering exact matches, conflicting term definitions, hierarchy/global fallbacks, duplicate labels, gaps, overlaps, and orphaned references;
- positive and negative capability tests, missing-context tests, and cross-tenant and cross-school isolation tests;
- database constraints and concurrency tests for containment, ordering, non-overlapping publication, stable identities, and optimistic revisions;
- deterministic resolver tests across boundaries, gaps, time zones, backdated dates, conflicts, and closed years;
- template immutability, explicit adoption, comparison, and unpublished-draft rebase tests;
- transaction, idempotency, outbox rollback, replay, and recovery tests; and
- browser and phone workflow prototypes for drafting, resolving conflicts, previewing, publishing, and correcting a calendar.

Planned evidence does not accept this ADR or authorize the module.

## Fallback and exit cost

If the aggregate proves too restrictive, keep the stable year and period identifiers plus named action contract while splitting week patterns or exceptions behind versioned internal interfaces. If multiple simultaneous programme calendars are demonstrated, introduce an explicit calendar scope through a superseding ADR rather than allowing overlapping school calendars implicitly.

Before production data exists, exit cost is limited to documentation and prototypes. After migration, changing authority requires a ledger-backed data rewrite, consumer-contract migration, projection rebuild, and reconciliation of every referenced year and period. Keeping templates as copied revisions and projections as disposable state bounds that cost.

## Review triggers

- Two representative schools require overlapping primary academic calendars within one school scope.
- Published-calendar correction cannot fit Conditionally Accepted [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md) or its accepted successor.
- A downstream module needs to reinterpret durable records after a calendar change.
- Template adoption creates unacceptable duplication or cannot express legitimate school variation.
- A proposal introduces implicit hierarchy fallback, generic CRUD, live template inheritance, runtime schema mutation, or a second calendar authority.
- The first real Frappe shadow import reveals material semantics not covered by this model.

## Related records

- [Academic calendar authority contract](../architecture/academic-calendar-authority.md)
- [Temporal records decision review](../architecture/temporal-records-decision-review.md)
- [Temporal records synthetic scenario review](../architecture/temporal-records-synthetic-scenario-review.md)
- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0016](0016-scheduling-service-contract-and-publication-boundary.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
