# ADR 0048: Local demo application shell

- Status: Proposed
- Date: 2026-10-24
- Accountable owner: Product experience and client engineering
- Deciders: François — Project Owner
- Implementation authority: François authorized the first synthetic shell on 24 October 2026 and the in-memory app-group/personal Home editors on 25 October 2026; all four institutions, existing pages and phone navigation remain required
- Supersedes: None

## Context

The fictional institution viewer has a flat navigation list that cannot grow into a coherent
education product. The [navigation proposal](../plans/application-navigation-and-workspaces-proposal.md)
separates Home, app discovery and contextual workspaces. The Project Owner authorizes only its
first local synthetic presentation increment. Existing qualification clients and their core
connections remain separate.

## Decision drivers

- Familiar discovery without accumulating global tabs.
- Direct access to existing read-only directories and calendar.
- Clear institution context, stable routes and safe browser history.
- Intentional phone navigation and accessible labelled controls.
- Presentation reuse without another domain or authorization registry.

## Considered options

1. Continue adding global tabs: does not establish the proposed growth model.
2. Replace every entrance with a tile grid: adds repeated navigation to familiar work.
3. Keep global Home and Apps, then show only the active app's navigation: selected for the
   bounded proof.
4. Generate a menu from core resources or build a runtime app editor: outside the authorized
   presentation boundary and unsupported by the current need.

## Decision

Implement a local, code-owned demo catalogue for three existing presentation areas: Students
(Students and Families & guardians, or college Contacts), Educators/Instructors, and Calendar.
Use the institution's existing teaching-staff label rather than a broad People app that might
promise a directory not present in the viewer. These groupings do not establish backend module
ownership.

The catalogue owns stable local app/destination identifiers, labels, descriptions, search
synonyms and route references. Home and Apps are global destinations. The active app supplies a
bounded workspace menu. Desktop presents it beside the page; phones use an ordinary native
disclosure with the current location visible. App icons always have text labels.

Home retains existing institutional counts, fixed example dates and academic periods. It does
not fabricate personal tasks, My classes, live attendance or account responsibility. Apps shows
only the three working areas. Its local search matches declared destinations and synonyms,
never person records or future actions. Search results navigate; they cannot perform a write.

Add only `/demo/apps` to the existing demo section allowlist. Existing URLs remain unchanged.
Every destination carries the selected allowlisted fictional pack. Institution switching keeps
the page and remounts institution-specific state. Invalid/repeated selection, Host, digest,
startup and row-tenant checks remain in the existing server adapter under ADR 0046.

No catalogue field is an authority assertion. A later connected navigation consumer requires a
separate contract referencing current server-owned module gates and actor authorization. This
demo does not implement that contract or attach the local catalogue to the platform registry.
There is no persistence, global record search or generic domain renderer. The later authorized
memory-only presentation editor is bounded below.

### Navigation agility amendment on 25 October 2026

The Project Owner requested an amended proposal for configurable group headings/membership and
educator-owned landing screens. The wider [personal Home design](../plans/application-navigation-and-workspaces-proposal.md#configurable-organization-and-personal-home)
separates stable product destinations, institutional navigation profiles and personal layouts.
Teaching & learning and Students & support are editable default labels, not permanent domain
boundaries. Moving or aliasing a destination never changes its record scope or authorization.

The code-owned grouping above records the implemented first proof only. The amendment initially
changed documentation only; François subsequently authorized the memory-only editor below.

### Authorized memory-only editor

Organize apps changes a local institution-layout preview; Customize my Home changes a separate
personal landing arrangement. Both use short plain-text section names and ordered references
to only Students, Contacts/Families, Educators/Instructors and Calendar. A reference may appear
in several sections; search retains one canonical result per destination. An All available
pages fallback remains accessible even when a customized catalogue is empty.

The shared section editor provides add/remove, rename, move up/down, move to section, preview,
Apply layout and Cancel. A scoped reset confirmation changes only its current layout. A small
set of named Home layouts and a chosen starting layout are presentation preferences only.
Institution app-group changes never overwrite personal Home layouts or change school data.

A demo-only React provider in the root layout retains these references across client-side
page navigation. Its URL-derived scope key discards presentation state when selection changes;
the server adapter remains the sole source of validated demo data. The rendered pack must match
the provider's scope. Reload, institution switch and restored full-page history discard the
temporary arrangements. No cookie, browser storage, file, API write or global server store is
used. A clear preview-only/reset notice remains visible beside the editors.

Labels and layout references are bounded and validated before application. Layouts carry no
record payload, learner/class identifier, capability or URL supplied by the editor. They cannot
create a workflow, broaden a read, change a named action or imply a teaching assignment. Existing
institution summary, calendar, record distinctions, local guards and qualification clients are
preserved. This authorization does not add durable preferences, account integration, sharing,
new views, authentication or connected navigation.

## Plain-English summary

### What this means

Home shows the selected fictional institution. Apps makes its available areas easy to find.
Inside each area, a short menu contains only the relevant pages. Phone navigation uses the same
destinations with a compact layout.

### What was agreed

The Project Owner authorized this synthetic implementation, while the wider product architecture
remains Proposed. No school module, real account, record policy or release is accepted here.

### Context

The current demo needs to prove navigation that can grow without presenting unimplemented work
as available functionality.

### Examples

- Students opens the current student directory; its workspace also offers family contacts.
- A college sees Instructors and Contacts rather than forced school terminology.
- Switching institution on Apps retains Apps and updates every destination to the new pack.

## Consequences

### Positive

- Existing content gains a coherent shell with an explicit, reversible contribution seam.
- New global destinations do not duplicate or reinterpret the data sources.
- The phone layout avoids a permanently expanded desktop menu.

### Negative

- One-destination workspaces are intentionally small until supported content exists.
- The catalogue proves presentation composition, not production capability discovery.
- Familiar labels and responsive mechanics still need rendered and representative review.

## Security, privacy, operability, and migration effects

Keep ADR 0046's loopback-only synthetic adapter and all four pack guards unchanged. The current
institution selector is not a production tenant or placement selector. Contact links retain
their explicit non-authority wording; applicant, enrolment, register, teaching-group and college
session distinctions are unchanged. No core files, resources, API, migrations, storage or
external service are introduced. Relevant threats remain TM-01/TM-02, TM-04, TM-09, TM-13,
TM-16 and TM-17 in the [threat model](../security/threat-model.md).

## Validation evidence

The [shell evidence](../phase-2/local-demo-shell-evidence.md) records actual checks and specialist
dispositions. Required evidence includes all four institution selections; existing direct
routes; Home/Apps/workspace navigation; switch/refresh/Back/Forward; invalid selection refusal;
search isolation; keyboard/disclosure behaviour; 320-pixel phone reflow; automated accessibility;
screenshots and the required repository checks. Planned or AI-reviewed trials do not constitute
human usability evidence.

The subsequent [layout editor evidence](../phase-2/local-demo-layout-editor-evidence.md) records
draft/apply/reset, alias/search, state lifetime, named Home layouts and rendered keyboard/phone
qualification independently of the original shell's historical results.

## Fallback and exit cost

Remove the shell/catalogue and restore the previous view navigation. Existing page routes and
source adapters remain, so no data migration or domain rollback is needed.

## Review triggers

- Any connected navigation metadata, persistence, role-based menu logic or runtime editor.
- New app destinations, personal task claims, records, writes or production exposure.
- A context/history error, inaccessible phone flow or sensitive metadata disclosure.

## Related records

- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0028](0028-experience-design-system-and-governed-personalization.md)
- [ADR 0043](0043-governed-model-and-workflow-views.md)
- [ADR 0046](0046-selected-local-demo-institution.md)
