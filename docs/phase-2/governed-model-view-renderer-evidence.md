# Governed model-view renderer evidence

- Date: 2026-10-08
- Owner: Product experience and platform engineering
- Authority: Project Owner's “go ahead” after the reusable-view proposal
- Governing record: [ADR 0043](../adr/0043-governed-model-and-workflow-views.md)
- Status: MV-1 local synthetic candidate technically verified; repository-wide gate blocked by unrelated concurrent documentation
- Boundary: Client-side presentation only; no new server, core, data or production authority

## Delivered slice

MV-1 adds a small validated view-set contract and reusable Calendar, List, read-only Form and Gantt
renderer to `clients/web`. A consumer declares only its meaningful views and allowlisted fields.
Invalid versions or field/date references fail closed.

The local synthetic Academic Calendar preparation workflow is the first visible consumer. Its
prepared terms and closures use Calendar by default, can switch to List or Gantt, and retain the
existing purpose-built editor as the Form view. The Calendar shows actual numbered dates and links
date selection to the existing date-resolution explanation. Gantt provides both a visual timeline
and exact textual ranges.

A neutral assigned-class definition exists only in unit tests and declares List and Form. It proves
that compatible-looking data does not automatically receive Calendar or Gantt.

## Retained boundaries

- No core resource, database, migration, HTTP route, OpenAPI contract or generated API type changed.
- No new read, collection, search, pagination, export or sensitive enumeration exists.
- No generic create, update, delete, save button or action executor exists.
- No runtime DocType, custom field, schema designer or tenant-authored view definition exists.
- The Phase 1 governed-extension registry remains metadata-only and unconnected to this renderer.
- Academic Calendar's existing named writer actions, local synthetic disclaimer and connected
  session boundary remain unchanged.
- This slice does not authorize a classroom view, real record, production client or deployment.

## Focused evidence

The unit contract covers:

- Calendar as an explicit default with a visible `15 Oct 2026` date and overlapping range/event;
- selected-date changes move the Calendar to the matching month;
- switching the same records to List and Gantt;
- left/right keyboard navigation moves focus and selection between declared view tabs;
- Gantt exact-date fallback and accessible chart description;
- a second model with only List and Form and no inferred date views;
- fail-closed rejection when a Calendar start field is not date-valued;
- Academic Calendar editing, validation, reset and date resolution after the Form override; and
- automated accessibility scans for both the reusable workspace and workflow integration.

The browser contract covers Calendar as the initial Academic Calendar presentation and explicitly
switches to Form before exercising the existing connected writer flow.

## Verification

Results on 2026-10-08:

| Check | Result |
| --- | --- |
| TypeScript typecheck | Passed |
| Focused model-view and Academic Calendar unit tests | 4 passed; includes two automated accessibility scans |
| `CHIMWEMWE_UI0_SYNTHETIC=true npm run check` | Passed; formatting, JavaScript and CSS lint, design-system contract, types, 8 token tests, 30 unit tests and production build |
| Academic Calendar browser workflow | 1 passed against the actual local HTTPS, session and PostgreSQL workflow; 1440, 768 and 320 pixel widths, no horizontal overflow and zero axe violations |
| Manual screenshot inspection | Calendar dates and selected date were clear at desktop and phone widths; phone view tabs were tightened so all four labels remain visible |
| Repository `make check` | Started and stopped at documentation validation because the separately owned untracked ADR 0042 lacks the required Consequences and Security/privacy/operability/migration headings; no MV-1 document error was reported |
| Repository tools | Ruff formatting and lint passed; 3 of 4 documentation-tool tests passed, with the repository-document test failing only for the same ADR 0042 omissions |
| Core gate | Not run because another task held the `core-test` verification lock; MV-1 changes no core code or contract |
| Repository tooling and `git diff --check` | Passed |

The first connected browser attempt exposed a stale concurrent test build in which an existing
organization/legal module was temporarily unavailable. A normal test compilation restored that
existing module; the rerun and the final post-style-change rerun both reached the workflow, with the
final run passing. Concurrent uncommitted OIDC work emitted module-redefinition warnings but did not
fail MV-1 verification.

The repository as a whole is not declared green. Failures caused by unrelated concurrent work are
reported separately rather than converted into an MV-1 failure or a green repository claim.
Automated checks are technical evidence only; representative school-user, independent security,
real-data, identity-provider and production-release review remain open.

## Next gates

Before a second real consumer, review whether the contract removes enough duplication without
flattening its workflow. Before stored or tenant-customized view definitions, authorize and verify
an exact adapter to the resource descriptor and governed-extension compatibility boundary. Before
any editable general Form, design the named-action, authorization, validation, concurrency,
idempotency, audit and recovery contract as a separate slice.
