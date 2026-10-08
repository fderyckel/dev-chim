# ADR 0043: Governed model and workflow views

- Status: Proposed
- Date: 2026-10-08
- Accountable owner: Product experience and platform engineering
- Deciders: François — Project Owner, with architecture and security/privacy review
- Implementation authority: The Project Owner's “go ahead” authorizes only the bounded local synthetic MV-1 renderer qualification described below
- Supersedes: None

## Context

Chimwemwe repeatedly needs familiar ways to inspect the same authorized information: a compact
list, an individual form, dates on a calendar, or ranges on a Gantt timeline. Rebuilding those
primitives for every school module would duplicate accessibility, responsive behaviour, date
handling and visual conventions. Frappe- and Odoo-like view switching is useful, but copying their
runtime DocType/model administration would create a second domain and authorization system that
conflicts with [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md).

A reusable renderer also creates a dangerous temptation: infer a directory or editable form for
every resource merely because its fields exist. Some Chimwemwe resources are authority facts,
sensitive evidence, internal ledgers or exact workflow scopes. Their existence never implies that
they may be enumerated, edited or exposed in another view.

## Decision drivers

- Reuse accessible Calendar, List, Form and Gantt presentation primitives.
- Let each model, approved read dataset or workflow opt into only the views that make sense.
- Preserve named domain actions, exact tenant context and sensitive-enumeration boundaries.
- Support purposeful workflow screens where a generated read-only form would be inadequate.
- Keep model authority in code and PostgreSQL rather than in client metadata.
- Fail closed on unknown fields, view kinds, contract versions and incompatible definitions.

## Considered options

1. Build each view independently in every workflow. This preserves control but duplicates common
   interaction and accessibility work.
2. Automatically expose all resources through universal CRUD views. This is productive initially
   but creates parallel schema, authorization and workflow semantics and broadens enumeration.
3. Use a small, versioned, allowlisted view definition over an already authorized dataset, with
   explicit workflow overrides. This is selected.
4. Adopt a full runtime DocType/model designer now. Evidence does not justify the schema,
   migration, policy, retention and upgrade surface.

## Decision

Adopt an explicit governed view-set contract. A view set names one stable source reference, one
identity field, a bounded allowlist of display fields and types, its declared views, and its
default view. It does not discover resources, fields or actions at runtime. Each view is opt-in:

- **List** declares its visible columns.
- **Form** declares fields for a read-only record presentation. An owned workflow may replace this
  presentation with a purpose-built form that submits only its existing named actions.
- **Calendar** declares a title and date start, with optional end and status fields.
- **Gantt** declares a title, start, end and optional grouping field.

No model is entitled to all four views. A definition that declares only List and Form must not
acquire Calendar or Gantt through inference. A source without meaningful dates should not declare
date views. A sensitive or internal source may declare no general view at all.

The renderer accepts records only after an owned consumer has obtained an authorized, bounded
dataset. It cannot fetch a resource, enumerate definitions, invoke an action, select a tenant,
change placement, expand fields, or determine authorization. The server-side read and every write
remain responsible for the real actor, tenant, purpose, module gates, data classification and
domain authorization. Interface hiding and view definitions grant no authority.

View definitions use a Chimwemwe-owned schema version and stable references. Invalid versions,
missing identity fields, duplicate views, unknown fields, invalid reference syntax and non-date
Calendar/Gantt coordinates fail closed. A later link to the governed resource descriptor must pin
the exact compatible descriptor revision and cannot broaden the fields or read action approved by
the server definition.

### MV-1 bounded implementation

MV-1 adds a reusable client-side, read-only renderer to the local synthetic browser experience.
The Academic Calendar preparation workflow is its first visible consumer: its already-bounded
preview records can switch between Calendar, List and Gantt, while its existing named-action form
remains the explicit Form override. A neutral assigned-class definition in tests proves that a
second model can opt into only List and Form.

MV-1 does not add or modify a core resource, database table, migration, API route, public read,
stored governed extension, runtime metadata editor, custom field, generic action executor or
generic mutation. It does not connect the renderer to the Phase 1 governed-extension registry.
Those steps require separate authorization and evidence.

## Plain-English summary

### What this means

The same school information can be shown in different useful ways. Dates can appear on a real
calendar, rows can appear in a list, one record can appear as a form, and date ranges can appear on
a Gantt timeline. The module owner chooses which of those views are appropriate.

### What was agreed

Build the shared viewing pieces and prove them first with the synthetic Academic Calendar. Do not
turn every database model into an editable screen, do not expose hidden records, and do not replace
the named school workflows with generic save or delete buttons.

### Context

Calendar and timeline presentation are broadly reusable. The risk is that a convenient view
framework can accidentally become a second application framework with weaker privacy and business
rules. This decision keeps reuse on the presentation side of that boundary.

### Examples

- An academic period can appear as a List row, span many Calendar dates and become one Gantt bar.
- An assigned-class source may expose List and read-only Form only; it has no useful date axis.
- An attendance correction stays a purpose-built named workflow. A generic Form view cannot invent
  an update action for it.

## Consequences

### Positive

- Common view switching, date rendering, accessibility and responsive behaviour have one owner.
- Modules can add appropriate views without copying a universal CRUD framework.
- Workflow-specific forms remain possible without forking the surrounding view navigation.
- Explicit source and field references make later compatibility checks reviewable.

### Negative

- Every consumer still needs an owned view definition and authorization review.
- The renderer is deliberately less automatic than a runtime DocType system.
- Read-only Form is only a presentation primitive; editable workflows still require intentional
  domain actions, validation, recovery and evidence.
- Calendar and Gantt need further scale, localization and interaction evidence before broader use.

## Security, privacy, operability, and migration effects

MV-1 processes only the data already present in its owning local synthetic browser workflow. It
adds no network request, server authority, data store, migration or telemetry. A view change never
changes the record scope. Definitions and records are not trusted authorization inputs.

Future server-backed consumers must use explicit bounded reads, maintain tenant and actor context,
derive classification from the referenced fields, prevent cumulative sensitive enumeration, and
re-authorize named writes at the domain boundary. View definitions must never accept raw SQL,
private resource names, tenant/repository identifiers, arbitrary actions or executable content.

Dates use local-calendar parsing rather than browser-dependent UTC conversion. Calendar retains
numbered dates at narrow widths. Gantt includes exact dates outside its visual chart. Unsupported
definitions show a bounded unavailable state rather than partially rendering.

## Validation evidence

The [MV-1 implementation evidence](../phase-2/governed-model-view-renderer-evidence.md) records the
static contract checks, Academic Calendar integration, second opt-in model, responsive and
accessibility expectations, and exact repository verification result. This is technical local
synthetic evidence only; it is not representative-school, production-security or deployment
approval.

## Fallback and exit cost

Remove the view workspace wrapper and keep the existing Academic Calendar form and preview. No
stored data or server contract needs migration because MV-1 adds neither. If repeated consumers do
not validate the abstraction, retain workflow-owned screens and extract only smaller accessible
primitives.

## Review triggers

- Connecting a view definition to the governed-extension registry or a resource descriptor.
- The first new server read, view-definition persistence, tenant customization or public client.
- Any editable generic Form, generic action invocation, delete, bulk operation or cross-record
  selection.
- A sensitive collection, child record, safeguarding, attendance, finance or authority resource.
- More than bounded in-memory records, long-range Gantt use, recurrence, time-of-day events,
  localization or timezone conversion.

## Related records

- [Governed model-view architecture](../architecture/governed-model-views.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0028](0028-experience-design-system-and-governed-personalization.md)
- [Academic calendar authority](../architecture/academic-calendar-authority.md)
- [Threat model](../security/threat-model.md)
