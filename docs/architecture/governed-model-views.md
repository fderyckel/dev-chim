# Governed model and workflow views

- Status: MV-1 local synthetic renderer implemented; wider architecture remains Proposed
- Owner: Product experience and platform engineering
- Governing record: [ADR 0043](../adr/0043-governed-model-and-workflow-views.md)
- Related authority boundary: [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)

## Purpose

Provide reusable Calendar, List, Form and Gantt presentation without creating automatic CRUD,
runtime schema design or an alternative authorization system. This guide explains the contract;
ADR 0043 owns its decision status and authorized scope.

## Authority flow

The direction is one way:

1. code-defined domain model and named actions own fields, behaviour and policy;
2. an owned server workflow obtains an authorized, bounded read result;
3. a compatible allowlisted view definition selects presentation fields and view types; and
4. the client renderer changes presentation only.

The renderer cannot travel backward through that flow. It cannot make a private field public,
turn a read into a write, enlarge a collection, choose another tenant or infer an action.

## View-set contract

An MV-1 definition contains:

| Element | Meaning | Authority it does not have |
| --- | --- | --- |
| `schemaVersion` | Exact supported view schema, currently `1` | No model or migration version |
| `sourceRef` | Stable Chimwemwe-owned reference to the supplied record shape | No fetch or resource lookup |
| `identityField` | Declared stable row identity | No direct record access |
| `fields` | Bounded references, labels and display types | No private-field discovery |
| `views` | Explicit List, Form, Calendar and/or Gantt configurations | No automatic view eligibility |
| `defaultView` | First declared presentation | No user authority or preference storage |

References use lower-case dotted or underscore names. Definitions have at most 32 fields, unique
fields and unique view kinds. List and Form name their fields. Calendar and Gantt must reference
declared date-valued start/end fields. Any incompatible definition fails closed.

MV-1 definitions are static, reviewed TypeScript owned by their consumer. They are not stored
tenant metadata and are not derived from the Phase 1 extension registry. A later stored-definition
integration must add exact resource descriptor and content revision compatibility, server-side
validation and the separate authorization described by ADRs 0019 and 0043.

## View behaviour

### List

Displays the supplied bounded records using only declared columns. It does not add search,
pagination, export, cross-page selection or a collection endpoint.

### Form

The default Form is a read-only field/value presentation for the first supplied record. A workflow
may provide an explicit override, as Academic Calendar does, but that form keeps its own named
action, validation, concurrency, idempotency and recovery contract. The renderer supplies no save,
delete or generic update behaviour.

### Calendar

Displays actual numbered dates in a month grid. One-day records use the same start and end date;
ranges cover every local date inclusively. Date selection may notify the owning workflow but grants
no fetch or mutation authority. Local dates are parsed as calendar dates, not JavaScript UTC
timestamps, avoiding timezone-dependent day shifts.

### Gantt

Displays supplied inclusive date ranges on a proportional read-only timeline. Exact textual dates
follow the visual chart and remain available when the chart is hidden on narrow screens. MV-1 does
not provide dependency links, drag-to-reschedule, critical path, resource allocation or writes.

## Consumer requirements

Before adopting the workspace, a consumer must establish all of the following:

- the dataset already has a named owner and an authorized bounded read path;
- each declared field is appropriate for the actor, purpose, classification and cumulative scope;
- every view is meaningful for that source and does not imply an unauthorized workflow;
- editable behaviour uses explicit named actions rather than renderer-generated mutation; and
- empty, invalid, narrow-screen and keyboard behaviour have focused tests.

Sensitive collections remain subject to
[ADR 0023](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md). An internal
resource, outbox, authority fact, audit record or temporal ledger does not become a view candidate
because it has compatible fields.

## MV-1 consumer

The local synthetic Academic Calendar screen flattens its already-authorized prepared periods and
closures into one static display shape. Calendar is the default; List and Gantt reuse the same
records; Form is the existing purpose-built editor. Selecting a Calendar date updates the existing
date-resolution control. No API or core contract changes.

A neutral assigned-class definition exists in unit tests only. It declares List and Form, proving
that the renderer does not infer Calendar or Gantt. It does not add another classroom interface or
authorize class enumeration.

## Expansion sequence

1. Qualify MV-1 locally with Academic Calendar and the neutral second contract.
2. Review whether a second real workflow removes enough duplication to retain the abstraction.
3. If authorized, design a server-owned compatible definition adapter over the governed resource
   descriptor without changing read or action authority.
4. Qualify each new view and each sensitive dataset independently before any tenant customization
   or public release.

Generic CRUD, runtime fields, runtime resources, arbitrary workflow composition and universal
model administration are not steps in this sequence.
