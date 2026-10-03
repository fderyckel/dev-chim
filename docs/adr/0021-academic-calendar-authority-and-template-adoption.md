# ADR 0021: Academic calendar authority and explicit adoption

- Status: Conditionally Accepted
- Accepted scope: bounded private synthetic L1; connected and real adoption remain gated
- Original proposal date: 2026-09-24
- Decision date: 2026-10-03
- Accountable owner: François — Project Owner
- Deciders: François — Project Owner, with the accepted platform, security, temporal, and institutional-structure boundaries remaining binding
- Required later reviewers: representative learning-institution/domain review before connected or real adoption; product-experience and security review at their existing gates
- Supersedes: The obsolete flat `school_scope_id` and single-school assumptions in this ADR's original proposal
- Implementation authorization: François's instruction on 2026-10-03 to start calendar construction after C25-04 closure

## Context

Academic years and periods are prerequisites for attendance, enrolment, admissions, timetabling,
assessment, reporting, and other education modules. The legacy evidence reviewed for the original
proposal showed useful explicit years and terms, but spread calendar authority across years, terms,
school calendars, generated events, hierarchy/global defaults, and mutable current flags. A direct
port would preserve duplicate truth and ambiguous current-year selection.

[ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md) subsequently
replaced the flat school model with stable recursive institutional units. The approved
[classroom-first plan](../plans/classroom-first-six-week-plan.md) and
[first-slice contract](../phase-2/classroom-first-slice-contract.md) also require more than one
calendar to be possible for the same unit and date range. The original `school_scope_id` wording
can therefore no longer govern implementation.

[ADR 0034](0034-c25-03-delegated-educational-structure-acceptance.md) closes C25-03 for bounded
synthetic educational identity, while retaining C25-03-R before connected or real adoption.
[ADR 0035](0035-c25-04-delegated-primary-operator-acceptance.md) closes the synthetic operator
decision and admits bounded operator/publication proof. On 2026-10-03 François explicitly directed
that calendar construction start. This record treats that instruction as the Project Owner's
bounded synthetic domain disposition; it does not invent representative review or close the
retained connected, real-data, identity, experience, security, or deployment gates.

## Decision drivers

- One authoritative and deterministic answer for an exact calendar and local date.
- Stable identifiers and immutable published meaning for downstream attendance and enrolment.
- Several simultaneous calendars without tenant-wide or institution-wide overlap assumptions.
- No implicit calendar selection through hierarchy, active-unit context, labels, or latest rows.
- Named, tenant-authorized actions with concurrency, idempotency, audit, outbox, and recovery.
- A small first contract that supports year, term, semester, block, or other local labels without
  becoming a universal temporal or scheduling engine.

## Considered options

1. Port the legacy academic-year, term, school-calendar, calendar-term, default, and callback
   records one for one. Rejected because it preserves duplicate authority and hidden inheritance.
2. Make an academic year itself the only calendar identity. Rejected because several programme,
   intake, or organizational calendars may use the same dates and need stable identity across
   years.
3. Give one exact institutional unit an explicit stable `AcademicCalendar`; place academic years
   and their definitions under that calendar; select every calendar explicitly. Selected.
4. Build a generic temporal, workflow, recurrence, or scheduling engine first. Rejected because it
   expands scope without classroom evidence and duplicates accepted platform responsibilities.

## Decision

Adopt option 3 for bounded private synthetic L1.

### Calendar identity and ownership

`AcademicCalendar` is a stable, tenant-qualified identity owned by one exact
`institutional_unit_id`. A unit may own several calendars. Two calendars may cover the same local
dates; publication overlap is prohibited within one calendar, not across the tenant or the owning
unit.

Calendar ownership is not authorization or legal accountability. The later writer derives tenant
and actor from trusted context, verifies the exact unit, and separately checks the module and
capability gates. For an institution, publication requires that institution's eligible primary
operator. For an ordinary organizational unit, eligibility resolves through its exact nearest
containing institution under the accepted structural contract. Containment selects the legal
accountability check only; it never silently selects or copies a calendar. An unresolved draft
unit, missing containing institution, under-review operator state for a restricted action, or
unknown policy fails closed.

No active-unit selector, parent, ancestor, tenant default, site, legal owner, operator, display
name, or arbitrary latest row supplies a calendar identity. A class or another durable consumer
stores the exact calendar and published academic-year revision it used.

### Academic year publication aggregate

One `AcademicYear` aggregate belongs to one `AcademicCalendar`. Its first definition contains:

- a stable year identity, code and localized label;
- inclusive local `start_on` and `end_on` dates plus an explicit IANA time zone;
- an ordered, non-overlapping primary sequence of `AcademicPeriod` values contained by the year;
- the explicit set of ordinary instructional weekdays; and
- zero or more unique dated closures contained by the year.

Period type keys and labels are tenant-controlled vocabulary; they may describe terms, semesters,
blocks, or another locally meaningful primary sequence. Their labels do not change behavior. A
date inside the year but outside all primary periods is non-instructional. A closure can retain a
named-break reason outside a period, but does not make that date instructional. Additional opening
exceptions, overlapping secondary cycles, templates, recurrence, and generated calendar-day
authority are deferred from this first implementation.

Draft definition is mutable working state through named actions and optimistic version checks.
Publication freezes an immutable complete revision. Downstream durable records pin that revision.
The first persisted slice must reject direct edits to a published revision. Successor publication,
correction impact, and reconciliation are later named contracts under ADR 0018; their deferral is
not permission to rewrite history.

There is no mutable `is_current` flag. Resolution requires an exact calendar identifier and local
date, reads one published revision from the authoritative writer, and returns the year, optional
period, publication revision, instructional status, and typed reason. Missing and conflicting
authority are explicit outcomes rather than sorting rules.

### Named action boundary

The first persisted surface will use code-owned intent equivalent to:

- `register_academic_calendar` for one exact eligible institutional unit;
- `define_draft_academic_year` for the explicit calendar and local year dates;
- `replace_draft_calendar_definition` for periods, weekdays, and dated closures under an expected
  draft version;
- `preview_academic_year_publication` without mutation;
- `publish_academic_year` after writer-side revalidation of institutional/operator eligibility,
  current authority, module state, expected version, and all calendar invariants;
- `read_published_academic_year` for immediate writer confirmation; and
- `resolve_instructional_context` for one exact calendar and local date.

These names express the stable intent; code may use compatible names while the first writer is
implemented. Generic CRUD, caller-selected tenant/repository/placement, caller-supplied authority,
ancestor fallback, and public arbitrary filtering are prohibited.

The module declaration will use stable key `academics.calendar`, declare the educational-structure
dependency once that module is present, and keep release availability, entitlement, activation,
and actor authorization independent. Initial capabilities will distinguish definition management,
publication, and reading; no fixed administrator or educator role is introduced.

### Templates and migration

Template identity and immutable explicit adoption remain part of the longer-term design, but are
deferred from the first classroom slice. No live global or ancestor inheritance is permitted.
When implemented, applying one exact template revision copies reviewed values into a draft and
records provenance; future template changes never mutate a published year.

Migration is reconciliation, not table copy. Source year/term identifiers map to stable target
identities through an immutable ledger. Duplicate years, overlaps, calendar-term discrepancies,
implicit hierarchy/default choices, missing owners, invalid dates, and orphaned downstream
references fail into explicit reconciliation. A source modified timestamp does not invent a
publication history.

## Current implementation admission

This decision authorizes the calendar work in reviewable increments. The first increment added on
2026-10-03 is deliberately pre-persistence: `Chimwemwe.AcademicCalendar` validates and
canonicalizes an exact institution-owned publication candidate, calculates instructional dates,
produces a deterministic candidate revision, and resolves local dates across terms, gaps,
weekdays, and closures. It accepts no tenant input and exposes no write, route, module declaration,
database table, or publication state.

Database persistence and the preparation screen remain the next increments. They are not allowed
to bypass CF-1: the core must first supply the minimum stable institutional identity and accepted
primary-operator publication eligibility used by the calendar writer. The first persistent slice
must then prove compound tenant/owner integrity, named actions, module gates, capability denial,
optimistic concurrency, idempotency, audit/outbox atomicity, rollback, exact read-after-write, and
the migration review required by the repository instructions.

## Consequences

### Positive

- Multiple legitimate calendars remain possible without ambiguous overlap or hierarchy rules.
- Attendance and other consumers can pin exact historical meaning.
- Term, semester, and block vocabulary can vary without changing structural invariants.
- The current executable contract tests calendar meaning before persistence and interface work.

### Negative

- Institutional/operator eligibility must exist before a real publication action can be safe.
- Immutable publication and pinned consumers require more deliberate correction and reconciliation.
- Template adoption, openings, successor revisions, migration, and connected screens remain
  separate work rather than appearing automatically in the first slice.

## Security, privacy, operability, and migration effects

Every persisted calendar, year, period, closure, action, audit fact, event, job, projection, cache
key, and migration mapping will be tenant-qualified. Compound relationships must reject
cross-tenant owner and child links. The server derives tenant, actor, placement, module state, and
capability from trusted context and uses the authoritative writer for publication and immediate
confirmation.

Publication commits state, minimized audit evidence, one outbox fact, and the exact idempotency
result atomically. Events contain stable identifiers and revisions, not unrestricted labels or
free text. Calendars contain no child or staff records. Projections and generated day lists are
disposable. Module deactivation retains published authority and required audit/outbox/recovery
paths while rejecting ordinary new mutations.

The first persistent proof must exercise TM-01, TM-02, TM-09 through TM-15, TM-17, and the relevant
session boundary when a browser write is added. A calendar or institutional identifier must not
become an enumeration or authorization shortcut.

## Validation evidence and retained conditions

Current evidence consists of the repository architecture, synthetic calendar and temporal
walkthroughs, the accepted platform boundaries, ADRs 0034/0035, the classroom-first contract, and
the focused executable contract tests. It is synthetic engineering evidence, not representative
calendar review, database publication proof, or connected user evidence.

Before connected or real adoption:

- close C25-03-R with named representative findings across the required institutional contexts;
- validate at least two materially different real calendar patterns and terminology;
- qualify the actual identity connection, selected environment, institutional/operator evidence,
  data classification, recovery, and operating ownership;
- pass the C25-05 experience/accessibility/security disposition for the connected workflow; and
- retain C25-06 and all real-data/deployment conditions.

No missed review date or passing repository test converts those conditions into approval.

## Fallback and exit cost

If the first persisted aggregate is too broad, retain the stable calendar/year/period identifiers
and exact resolver while limiting admitted definition features. If several primary sequences need
independent ownership, add a separately named cycle or scope through a superseding ADR instead of
allowing overlaps inside the first primary sequence.

Before production data, exit cost is limited to documents and synthetic code. After adoption,
changing identity or publication meaning requires expand-and-contract migration, consumer
reconciliation, projection rebuild, retained-history verification, and an accountable decision.

## Review triggers

- A representative institution cannot identify one exact owning unit for a calendar.
- A calendar needs more than one simultaneous primary instructional sequence.
- A connected workflow proposes ancestor/default selection or a mutable published year.
- A downstream record cannot pin the exact calendar publication revision it used.
- Institution/operator eligibility cannot be enforced without coupling calendar ownership to
  authorization or legal structure.
- The first migration reveals material calendar meaning not covered by this contract.

## Related records

- [Academic calendar authority contract](../architecture/academic-calendar-authority.md)
- [First classroom slice](../phase-2/classroom-first-slice-contract.md)
- [Classroom-first six-week plan](../plans/classroom-first-six-week-plan.md)
- [Synthetic calendar scenario review](../architecture/academic-calendar-synthetic-scenario-review.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0034](0034-c25-03-delegated-educational-structure-acceptance.md)
- [ADR 0035](0035-c25-04-delegated-primary-operator-acceptance.md)
- [Module activation and lifecycle](../architecture/module-activation-and-lifecycle.md)
- [Threat model](../security/threat-model.md)
