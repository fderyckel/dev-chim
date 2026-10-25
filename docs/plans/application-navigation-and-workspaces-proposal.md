# Application navigation and workspaces proposal

- Status: Proposed product architecture; first local synthetic shell authorized on 24 October 2026
- Date: 2026-10-24
- Amendment: 2026-10-25 — configurable navigation groups and educator-owned landing layouts
- Decision authority: François — Project Owner
- Owner functions: product experience, education-domain design and platform engineering
- Implementation authority: first synthetic Home, Apps and workspace shell only, under [ADR 0048](../adr/0048-local-demo-application-shell.md)

## Recommendation

Give Chimwemwe three complementary entrances: a personal **Home** for daily work, an **Apps**
launcher for discovering the available capabilities, and **workspaces** for completing related
tasks. Use familiar labelled app tiles and workspace navigation, with an education-specific
experience around a class, learner, programme or application.

Treat group headings and their contents as configurable presentation. Schools can organize
their shared catalogue, while each educator can build a personal Home with their own section
labels and chosen workflows. The example headings below are starting points, not fixed product
categories. Stable workflow identity, action meaning and authorization remain product-owned.

The app grid is the map of the product. Home and contextual workspaces are where people work.
A teacher should be able to open a class, take attendance and continue to another permitted
class task without repeatedly returning to an app catalogue or selecting the class again.

This is the wider product-navigation proposal. Its first synthetic shell is now authorized
under ADR 0048; [implementation evidence](../phase-2/local-demo-shell-evidence.md) records that
bounded result. Future app examples remain a capability map, not implementation approval or the
next delivery order. Core, identity, public and release boundaries retain their existing gates.

## Current foundation

The fictional institution viewer originally had a flat list of directories and Calendar. Its
implemented first shell now has Home, Apps and a local workspace menu, with Students,
Families & guardians or Contacts, Educators or Instructors, and Calendar retained in
[`demo-instance-view.tsx`](../../clients/web/src/components/demo-instance-view.tsx). The current
[`demo catalogue`](../../clients/web/src/lib/demo-navigation.ts) still supplies its groups from
code; there is no layout editor or persisted personal Home yet.
The separate qualification shell already has a sidebar in
[`app-shell.tsx`](../../clients/web/src/components/app-shell.tsx).
Neither should acquire an ever-growing top-level link for every new school capability.

The platform already separates modules, their lifecycle and domain authority under
[ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md). Its
[four independent gates](../architecture/module-activation-and-lifecycle.md) remain authoritative.
The presentation boundary in [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md),
device-specific experience in [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md),
proposed design system in [ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md)
and explicit views in [ADR 0043](../adr/0043-governed-model-and-workflow-views.md) supply the existing
direction. This proposal extends their product organization without replacing those contracts.

## What to take from Frappe and Odoo

Frappe's current documentation distinguishes an apps screen, an app's modules and a module's
sidebar. Workspaces collect useful shortcuts and views. Its navigation documentation explicitly
separates hiding entries from permission. Odoo documents a command palette for reaching apps,
modules and menus without traversing the interface.

These are useful conventions: discoverable labelled apps, a smaller local navigation, reusable
views and fast destination search. Chimwemwe should own the education workflows, terminology,
context and visual language. This proposal does not select either framework or a runtime model
builder. It does not copy an installation marketplace into routine staff navigation.

Sources checked on 24 October 2026:

- [Frappe desktop and apps screen](https://docs.frappe.io/framework/user/en/desk/navigation/desktop)
- [Frappe sidebar](https://docs.frappe.io/framework/user/en/desk/navigation/sidebar)
- [Frappe workspaces](https://docs.frappe.io/framework/user/en/desk/navigation/workspace)
- [Odoo keyboard navigation and command palette](https://www.odoo.com/documentation/19.0/applications/essentials/keyboard_shortcuts.html)

## Navigation structure

| Layer | Purpose | Proposed behaviour |
| --- | --- | --- |
| Global shell | Know where I am and reach another area | Home, a visibly labelled Apps control, current institution, destination search and account controls |
| Personal Home | Start the work I have chosen to put first | Educator-owned sections, ordering and approved workflow shortcuts or view blocks, with a useful default |
| Apps launcher | Find an unfamiliar or occasional capability | Labelled tiles with square icons, grouped under visible headings; category headings do not require another click |
| Workspace navigation | Work within an area | A short sidebar with section headings and destinations; avoid arbitrary nested menu trees |
| Contextual workspace | Continue work on a class, learner, programme or application | Clear context and independently authorized task links across the owning areas |
| Page or record | Complete one task | A clear heading, named actions, visible outcome and only the views declared for that dataset |

Home and Apps are always reachable. Frequent users can bookmark an owned workspace directly.
People explicitly control their Home sections and ordering; their arrangement stays stable
until they change it. Neither usage statistics nor a new institutional default silently
rearranges a personalized screen. Personalization preserves essential labels and authority.

The desktop shell should give most space to the task. Apps opens a searchable catalogue, rather
than leaving a wall of icons permanently beside a large sidebar. Opening an app replaces the
workspace navigation; it does not accumulate another full menu. Breadcrumbs explain location,
while browser Back and direct links preserve the relevant context.

Phone layouts should prioritize Home, the main daily task and Apps, with a compact navigation
sheet where needed. They should not compress the permanent desktop sidebar into a narrow rail.
Younger learners and families need smaller, purpose-designed task surfaces in later authorized
work, rather than the adult administrative catalogue by default.

## Configurable organization and personal Home

### Separate the two editing scopes

**Organize apps** changes an institution's shared presentation defaults. **Customize my Home**
changes only the current person's landing screen. Each editor states its scope explicitly;
moving an item never moves a school record or changes who may use it.

| Layer | What can change | What remains stable |
| --- | --- | --- |
| Product catalogue | Reviewed releases add or evolve approved apps, tasks and view definitions | Stable identifiers, canonical workflow titles, named actions, owner, data and permission contracts |
| Institution navigation profile | Create, rename and order navigation groups; place, move or alias approved app/task links; publish a default arrangement | Tenant boundary and separate administration capability; grouping grants no actor access |
| Personal Home layout | Create and name personal sections; add, remove and reorder available workflow links or approved view blocks; choose a default landing layout | Real actor and institution context, available workflow contracts and product accessibility rules |
| Explicitly adopted template | Start from an approved institution or team arrangement, then personalize the copy | No inherited roles, assignments, records, access decisions or automatic organizational-parent adoption |

Use **navigation group** or **Home section** in editing controls. Its membership contains links
or blocks, not students, staff or teaching groups. A school could rename Teaching & learning to
Classroom work and place Calendar there. Another could place Calendar under Planning. An
educator could use Morning, Class preparation and School information on their Home, combining
destinations from several apps without following the institution's catalogue headings.

One destination may appear in more than one group as an explicit shortcut. These are placements
of the same stable reference, not duplicated apps or records. Search deduplicates by destination
identity and retains the canonical workflow title; personal group names can aid lookup without
obscuring the destination. Opening a shortcut still shows its owned task name and exact scope.
An alias may add a caption, but cannot replace a named action's purpose or consequence.

### What educators can build

Customization is a normal, optional product capability, not merely a favourites list. A working
Home is provided immediately, and an educator can make a small change without rebuilding it.
They can add or rename sections, choose from the currently available workflow catalogue, move
items between sections, change their order and remove optional items. Later authorized view
blocks may include an assigned-classes view or an owned calendar view; their data scope,
permitted view modes, loading, error and saved/blocked states remain with the owning workflow.

Multiple named layouts can support different arrangements, such as Teaching or Pastoral. One
can be chosen as that person's default landing layout in the current tenant context. Changing
layout changes arrangement only: it cannot select a tenant, impersonate a role, switch the
institution, merge a register with a subject group or silently choose a class or academic year.
A personal heading such as My class is never evidence of an actual teaching assignment.

Home, Apps, institution context, canonical task/action meaning, accessible focus and necessary
workflow consequences/status stay available. Users can remove optional blocks; they cannot
hide required state within an active workflow or make an unavailable action appear usable.
An empty personal layout offers Add a section and Reset Home layout, with Apps still reachable.

### Editing and recovery

Keep reading/browsing separate from editing. Customize my Home opens a draft. Preview shows
the arrangement before application; Cancel restores the arrangement present when editing began.
Move up/down and Move to section controls support keyboard and touch alongside optional drag
and drop. Announce the new position/section and return focus meaningfully after movement or
removal. Phone order follows the same explicit sequence rather than a different automatic sort.

For a memory-only proof, use **Apply layout** and a visible **Preview only · resets on reload**
state. The applied arrangement can survive navigation within the mounted proof session; reload
and institution switching reset it as disclosed. Do not use Saved to describe this temporary
state. Later durable preferences use **Save Home layout** and a confirmed **Saved** result.

Reset Home layout previews that it replaces only the current personal layout with the current
compatible default. It does not reset school settings, other layouts, appearance choices or
domain records. Publishing a revised institution template does not overwrite personal choices.
Offer Preview new default and an explicit adoption action; record the adopted template revision
so a later comparison can explain what would change. Removed permission still takes effect
immediately, regardless of whether a new template is adopted.

### Templates and privacy

Templates copy approved presentation structure and destination/view references only. They do
not copy selected children or classes, record-bearing URLs, source filters containing record
identifiers, counts, cached records, audience lists, assignments or access assertions. The
recipient receives only the definitions currently available to them. A template cannot disclose
the name or existence of a restricted case through an omitted block or its caption.

Publishable templates use reviewed, neutral labels. Personal layouts and their free-text labels
are private by default; sharing or exporting them is separate later work. A plain-text field
cannot guarantee that someone never types a child's name. Treat custom labels as potentially
sensitive user content: prohibit record-derived headings, omit labels from logs and telemetry,
and settle classification, retention and removal before connected persistence. Do not claim
that simple validation proves a label contains no child information.

Use a small approved block catalogue, with each block owning its permitted presentation options
and context resolver. Layout editing cannot invent a query, a new form, an action, a field or
an alternative record policy. There is no raw HTML, CSS, SQL, script, arbitrary component,
external URL or unrestricted filter builder. Colours, status meaning and accessibility stay
within the existing design system.

### Storage and compatibility direction

Keep three separate, versioned records in the proposed design: the code-owned destination/block
catalogue, an institution navigation/default-template profile, and a personal Home layout. A
layout contains section IDs, short plain-text labels, ordered approved references, its schema
version and template/revision references. Store no record payloads, child identifiers, cached
counts or previously resolved permission in this first layout format. A future fixed-record
shortcut requires its owning domain's separate privacy/context contract.

Personal state is tenant-and-actor qualified, with any institution-specific variant explicitly
identified. Shared profile administration and editing one's own Home are separate named actions
and capabilities; a job title is never a permission check. Do not graft a layout payload into
the concurrent staff-account/preference work without a reviewed integration contract.

A future server resolves available references under the current four module/actor gates before
rendering or previewing a layout, then the destination rechecks its own access. Expired cover,
revoked capabilities and inactive modules cannot survive in saved shortcuts, cached titles or
counts. Stale/incompatible references produce a concise safe recovery state; never guess a new
destination from its label. A corrupt layout may fall back to the compatible default within the
same trusted context, not to another institution.

Durable save/reset/publication uses named actions, revision checks and the existing audit/outbox
rules for applicable side effects. Concurrent edits show a conflict instead of silently losing
changes. Template adoption and schema upgrades are explicit; rollback/reset preserves the
underlying school records. Browser storage, if proposed later, is never an authority source.

This is a composition of approved presentation, consistent with ADRs 0019, 0020, 0028 and 0043.
It is not a runtime workflow/model designer. A connected persistence or public consumer still
requires its own Proposed ADR, implementation scope and qualification.

## Proposed capability map

These are presentation groups, not organizational parents, authorization scopes, packages or
mandatory modules. A small institution may see only a few apps and no empty group headings.
The table below is one editable default arrangement. Groups can be renamed and their link
membership changed; explicit aliases may place a destination in several groups. Reviewed
terminology and placement can vary while stable workflow identities remain the same.

| Group | Illustrative apps | Distinction to preserve |
| --- | --- | --- |
| Admissions & enrolment | Admissions; Enrolment & placements | Enquiry, application, offer, enrolment and placement have separate lifecycles |
| Teaching & learning | Classes; Curriculum & courses; Assessment & reports; Timetable | A register, teaching group, course, programme and scheduled lesson are different things |
| Students & support | Students; Attendance; Learning support; Wellbeing; Health; Safeguarding; College & careers | Shared identity does not make confidential cases or references generally visible |
| Community & engagement | Communications; Activities & trips; Family engagement | Contact relationships do not establish accounts, recipients or disclosure authority |
| Institution operations | Fees & billing; Finance; People & HR; Library; Facilities; Procurement & inventory; Transport; Meals | Operational domains keep their own state, approval and access rules |
| Organization & administration | Institutions & sites; People directory; Accounts & access; Configuration; Integrations | Institutional hierarchy, employment, account lifecycle and authorization remain separate |

The broad map is deliberately more extensive than the first implementation. Specialist areas,
including research administration or residence operations, can be added when a supported
institutional need establishes their domain contracts. They do not require a new navigation model.

Do not use **Learning services** as the universal default label: it could mean teaching,
additional support, tutoring or accommodations. Prefer specific task names; adopt a local term
only with reviewed meaning and useful search synonyms. Likewise, distinguish incoming
**Admissions** from outbound **College & careers** applications and confidential references.

Reports normally belong beside the work they explain. Assessment reports, fee reports and
attendance reports need not share a giant undifferentiated Reports app. A later cross-domain
reporting surface requires its own governed datasets and authority; navigation does not add one.

## Education workspaces

**My classes** is an entry for assigned work, not a permanent role or a technical module. A
primary educator might see their register and today's tasks. A secondary educator might see
several teaching groups plus a pastoral register, with the group type visible. A substitute sees
only currently permitted cover work. The classroom workspace links to the correct attendance,
learning, assessment and communication tasks without inventing new permissions or submissions.

**A learner workspace** is a bounded view of permitted information and actions. It is not a
combined dossier that gathers every domain's records or advertises inaccessible cases. Different
people can see different permitted panels for the same learner. Knowing or teaching someone
does not imply access to health, safeguarding, confidential admissions or counselling records.

**An admissions workspace** gathers applications, missing documents, deadlines and decisions.
An accepted offer can lead to an explicit enrolment handover with visible prerequisites. It
cannot silently create participation, a class placement, an account, capabilities or family
access. A shared person reference is reused only where identity and policy establish the match;
navigation must not invent automatic identity matching or record merging.

**A programme workspace** can connect curriculum, courses, cohorts and relevant calendars without
pretending they form one institution-to-year-to-class tree. A college programme, the department
delivering a course and the site hosting a lesson may differ.

Home composes only the tasks supplied by authorized workflows. It does not create a new generic
task engine, inbox, scheduler, notification service or analytics plane. Until a task exists,
the live Home must not fabricate counts, deadlines or actions for it.

## App and module boundaries

| Concept | Owns | Does not imply |
| --- | --- | --- |
| Domain module | State, invariants, named actions, policy and lifecycle | One tile, one database, one service or one deployment |
| App | A coherent user-facing area with an accountable experience owner | A separately installed module or a broad permission grant |
| Workspace | A useful arrangement of related tasks and permitted views | Another copy of records or an independent business model |
| View | One explicitly declared presentation of an authorized dataset | Enumeration, editing or automatic eligibility for every view kind |

The mapping can be many-to-many but must be explicit. Classes can link to attendance and
assessment owned elsewhere. One module may supply several audience-specific destinations. Each
task still calls its owning domain contract; a workspace cannot reach around that boundary.
Keep the existing modular monolith. No microservice or generic runtime app builder is needed to
make the menu scale.

Before a later navigation implementation changes a stable boundary, create a Proposed ADR for
the navigation contribution contract and review its compatibility and privacy effects. A minimal
code-owned contribution should identify:

- a stable app and destination identifier, independent of translated labels and route spelling;
- its product owner, canonical title/localization keys, icon and suggested default placement;
- its landing destination and bounded sidebar/task destinations;
- references to the existing module and named-read/action contracts on which each destination
  depends; and
- context requirements, declared view sets and compatible contract versions.

These contributions are presentation metadata. They must reference existing authority rather
than duplicate entitlement rules, dependency graphs, policies or production role names. A future
connected shell receives only the navigation metadata it may disclose in the current trusted
actor and tenant context. It may show an app when at least one permitted destination remains;
it must not hide an entire useful app because another optional task is unavailable.

Start with explicit owned declarations and a small composer. Institution profiles and personal
layouts reference these declarations through bounded presentation editors. Do not auto-generate
apps from tables or Ash resources, publish private resource names or introduce arbitrary tenant
scripts. Editing group membership never becomes a domain-model or permission editor.

## Context, search and confidentiality

The header keeps the institution visible. The task displays the specific class/group, date,
programme, academic year or calendar it actually requires. There is no mandatory global academic
year filter for finance, HR or every college session. A context selector selects only a currently
permitted context; it does not select tenant placement or grant scope.

Cross-app links carry useful context as input to a fresh destination check. They must not turn
an organizational parent, a staff title, an enrolment, a household or a known record identifier
into authority. Where compatible context cannot be resolved, request an explicit selection or
show a clear unavailable state rather than silently choosing another class or calendar.

Context changes must clear stale records, navigation, search results and selection. Handle
unsaved work through the owning workflow before leaving it. Direct links, Back, refresh,
multiple tabs and expired assignments must obey the same rules. A saved pin cannot preserve
revoked access.

Initial search finds available **destinations and tasks**, including reviewed terminology
synonyms. It does not enumerate people, applications or cases. A result opens the owned workflow;
it never executes a save, send, delete or other state change. Broad record search is separate
future work under [ADR 0023](../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md).

Inaccessible records must not leak through tile badges, task counts, recent items, breadcrumbs,
cached titles or search suggestions. A generally visible learner page must not reveal that a
restricted safeguarding case exists. Module deactivation blocks ordinary work while retained
record access continues only through its separately authorized lifecycle paths. App management
belongs in separately authorized administration, not an Activate control on a routine app tile.

These conditions preserve TM-01/TM-02 (tenant and authority), TM-04 (stale copies), TM-09
(sensitive evidence), TM-13 (module lifecycle), TM-16 (experience metadata) and TM-17
(structure-derived scope) in the [threat model](../security/threat-model.md).

## Options and tradeoff

| Option | Benefit | Cost | Recommendation |
| --- | --- | --- | --- |
| Continue adding top tabs | Simple while there are few pages | Crowds quickly; mixes records, domains and tasks | Retire as the growth model |
| Make the app grid the main daily screen | Familiar discovery and room to grow | Repeated app switching and context selection | Use as the catalogue |
| Put every destination in one sidebar | Persistent access | Long menus and deep nesting | Keep only local workspace navigation |
| Home, Apps and contextual workspaces | Discoverable product plus direct daily work | Requires explicit composition, context and ownership | Recommended |
| Invent a novel spatial or conversational primary navigation | Distinctive appearance | Adds a learning burden and weakens predictable lookup | Do not select without concrete evidence |

The principal cost of the recommendation is deliberate cross-domain composition. Accept that
cost only when a workspace removes repeated work; do not duplicate every app page on Home.
Education-specific tasks and context should supply Chimwemwe's distinction, while ordinary
navigation remains recognizable.

## Proposed first increment

Authorized on 24 October 2026: prove a reversible local synthetic shell around the existing fictional
institution viewer. Keep the current pages and data sources, demonstrate Home, Apps, workspace
navigation and direct contextual links, and preserve all four institution selections. Map
Students and Contacts/Families into a student-facing administrative area, place
Educators/Instructors in a clearly labelled teaching-staff area, and keep Calendar directly
reachable from Home and its owned workspace. The specialist checkpoint selected the concrete
Educators/Instructors labels over People for this first proof.

Only current destinations should function in that proof. Show the full future catalogue in a
separate clearly labelled design concept, not as dozens of disabled or apparently working apps
in the everyday demo. Do not fabricate My classes from the unrelated directory packs or connect
them to the separate core-backed attendance qualification. Each existing qualification flow
retains its source and authorization boundary.

Exclude persistent pins/preferences, broad record search, runtime menu editing, new core
resources, modules, API reads, identity paths, real data and deployment. A subsequent class
workspace increment needs an explicitly authorized source and its own scope. This sequence
preserves the classroom-first delivery priority and the separately bounded COMM-1 work.

Those exclusions describe the implemented first shell. The 25 October amendment makes a bounded
presentation editor the next proposed increment; it does not retrospectively claim that the
current shell already has one or that durable preferences are implemented.

## Proposed personalization increment

Prove the two editing scopes over the existing three-app synthetic catalogue. Keep the
immutable workflow/destination declarations separate from editable group definitions and
ordered placement references. Rename Teaching & learning, add a navigation group, move a link,
and place Calendar in two sections without changing its source or URL identity. Provide a
personal Home arrangement independent of the shared catalogue defaults.

The first proof uses route shortcuts to existing Students, Contacts/Families, Educators/Instructors
and Calendar pages. Preserve their current data, Home summary, calendar and all four institution
selections. Do not fabricate My classes, attendance, assessment, messages or personal assignments.
Additional movable view blocks require an explicit approved block definition and source; the
existence of a resource or a view renderer does not make it a Home block automatically.

Use memory-only profile/layout drafts, Apply layout, Cancel and Reset Home layout, with visible
temporary-state wording. Keep changes while navigating within the mounted demo session, then
reset on reload or institution switch. The institution editor is explicitly a local layout
preview, not simulated authority to administer a real institution. Preserve direct links,
history, readable phone reflow and the distinction between a navigation group and a class.

This turn amends the proposal and its current-shell ADR only; no editor, preference schema,
account integration or runtime data change is implemented. Before an implementation increment,
record its bounded authority in the Proposed ADR. Connected persistence, public access,
fixed-record shortcuts and template sharing require their own reviewed contracts and evidence.

## Review record

All four reviews were independent, read-only AI paper reviews on 24 October 2026 using
the [authorized profiles](../development/specialist-review-team.md). They reviewed the proposed
structure and current source, not a rendered candidate. Their trials below remain not run.

| Profile | Disposition and strongest concern | Required condition and owner functions | Coordinator disposition |
| --- | --- | --- | --- |
| Primary education | Approve with conditions: an app grid could fragment a class teacher's morning | Direct My class tasks; bounded substitute handover; simple younger-learner/family entrances; no sensitive case indicators. Education product and domain authorization | Modify: explicit contextual workspaces and audience-specific entrances incorporated |
| Secondary education | Approve with conditions: subject teaching, pastoral registers and college structures could collapse into one class hierarchy | Preserve group types, calendars and programme/site distinctions; keep context across tasks. Education product and client/platform engineering | Accept: distinct identities and explicit context requirements incorporated |
| Admissions | Approve with conditions: applicant-to-student navigation could falsely imply a complete handover | Incoming admissions separate from outbound applications; explicit enrolment prerequisites; confidential references and family boundaries. Admissions, records and identity functions | Accept: handover and confidentiality requirements incorporated |
| UI and interaction | Approve with conditions: the catalogue could become another taxonomy users must learn | Home for daily work; labelled tiles; no category intermediary screens; stable ordering; destination-only search; purposeful phone layout. Product experience and accessibility functions | Accept: simpler hierarchy and bounded first proof incorporated |

No unresolved material specialist disagreement remains at this paper-design level. Their
agreement does not accept an ADR, authorize new work, establish institutional policy, or replace
representative education, accessibility, safeguarding or independent security/privacy evidence.
The isolated architecture Advisor consultation was unavailable because the parent runtime could
not be verified; no Advisor approval is claimed.

### Agility amendment review on 25 October 2026

The three relevant profiles independently reviewed this paper amendment. Their new editor and
connected-preference trials are proposed, not run; the prior shell's screenshots/checks do not
validate an editor. Admissions was not re-instantiated because no admissions meaning changes.

| Profile | Disposition and strongest concern | Conditions and owner functions | Coordinator response |
| --- | --- | --- | --- |
| Primary education | Approve with conditions: a personal My class heading or copied template could imply a real assignment | Optional editing with a working default; clear navigation-group vocabulary; exact workflow scope; templates carry no records/targets/private labels. Education product and privacy ownership | Modify: distinguish group meaning and constrain template content; use Apply layout for the temporary proof |
| Secondary education | Approve with conditions: custom headings/layouts could merge subject, pastoral and college contexts or appear to change authority | Preserve canonical task/context; explicit template adoption; treat free-text labels as potentially sensitive; no inferred role or calendar. Education product, platform and privacy ownership | Accept: context and label-classification conditions incorporated; Save Home layout reserved for durable state |
| UI and interaction | Approve with conditions: institutional regrouping and personal Home editing could confuse orientation | Separate Organize apps/Customize my Home; stable identities with deduplicated aliases; move-to-section controls; explicit update/reset behaviour. Product experience and accessibility ownership | Accept: fixed-placement wording replaced and temporary-apply semantics made explicit |

No material design objection remains unresolved at proposal level. The simple editor still
needs implementation and rendered/interaction review. Architecture Advisor consultation was
unavailable because the parent runtime could not be verified; the user-authorized specialist
reviews are separate AI design evidence.

## Acceptance before adopting the shell

The prototype and later connected navigation require separate evidence. Proposed acceptance:

1. Findability trials cover attendance, an unfamiliar app, a course, missing application
   documents, support work and settings. Compare first choices and wrong turns against the flat
   navigation baseline; set success/time targets before representative sessions.
2. A class teacher reaches the correct register directly. A secondary educator distinguishes a
   teaching group from a pastoral register and continues to another permitted task without
   reselecting context. A substitute loses access when cover ends.
3. A college example keeps programme owner, delivering department, site and overlapping academic
   sessions distinct. A kindergarten example does not acquire invented adult workflows.
4. An offered but unenrolled applicant remains an applicant. Enrolment handover does not create
   account or family access. Outbound college references remain outside incoming Admissions and
   general student views.
5. A person who is both staff and family receives only independently authorized tasks. Adult
   learners receive no inferred guardian path. Restricted cases do not leak through counts,
   search, pins, titles or learner panels.
6. Direct link, Back, refresh, institution switch and stale bookmark trials preserve or clearly
   reject context. Pending/unsaved work and revoked/inactive destinations have visible recovery.
7. Keyboard, focus return, touch, screen-reader labels, text enlargement and 320-pixel reflow
   work across the supported design profiles. Icons always have labels; essential state is not
   hidden in help. Secondary help is available by focus and touch as well as hover.
8. Registry tests reject duplicate identifiers, invalid or incompatible references and accidental
   future destinations. Connected tests independently cover missing actor/tenant, cross-tenant,
   revoked capability, absent entitlement, inactive module and partial-app availability.
9. Existing demo and qualification routes remain valid. Run the relevant focused checks,
   `git diff --check` and `make check`, reporting exact results and skipped checks. Software
   verification alone does not count as representative usability or release approval.
10. Rename a navigation group, move Calendar and add a second placement. Both links resolve the
    same destination and dataset; search shows one canonical result. No code/role/module changes
    occur, and an institution profile never changes another person's layout silently.
11. Build Morning and School information Home sections using existing destinations. Move an
    item between sections without dragging, then preview, cancel, apply and reset with keyboard
    and touch. Phone order matches the chosen sequence; focus and position announcements are clear.
12. The memory-only proof states that reload/institution switching resets the layout. Applying
    it never claims a durable save. A later persisted layout shows an actual save outcome and
    revision conflict when another edit wins.
13. Default updates leave personal changes intact until an explicit preview/adoption. An empty
    or incompatible layout has a working Home/Apps recovery path, with reset scoped to one layout.
14. Template serialization includes only approved structure, references and neutral labels; no
    target record IDs, record-derived names, counts, raw URLs or arbitrary filters travel to a
    recipient. Recipient filtering must not expose the title of an omitted restricted item.
15. Later connected positive and negative tests cover own-layout editing versus shared-profile
    administration, missing actor/tenant, cross-tenant/cross-actor access, revoked capabilities,
    ended assignments, inactive modules and stale reference versions. Every destination still
    refuses unauthorized invocation independently of its Home placement.
16. Later classroom trials distinguish a personal section named My students from the actual
    authorized register, teaching group or college session. Changing layout never switches that
    context, and custom labels never enter logs or preference telemetry.

## Fallback and review triggers

Keep the existing workflow pages and domain interfaces so a shell prototype can be removed
without migrating records. If users find the catalogue confusing, revise labels, grouping and
shortcuts before adding more navigation levels. If a contextual workspace becomes a crowded
dashboard, reduce it to the demonstrated daily tasks and direct links.

Revisit the design when a new institution type cannot find its work, placements or aliases
obscure a destination's meaning, users repeatedly lose context, a confidential item leaks metadata,
or the first connected navigation consumer proposes a new authority or persistence boundary.

## Proposal-stage verification

Checks executed on 24 October 2026 cover a documentation-only proposal. Concurrent changes in
the institution-selector browser test and calendar evidence were preserved; this record does
not attribute or qualify those changes.

| Exact check | Result |
| --- | --- |
| `make check` | Failed, exit 2, at the web application's `npm audit --audit-level=high`: two high-severity affected packages, `undici` and `zod`, plus one moderate affected package, `fast-uri` |
| `make check` → `check-docs` | Passed; repeated after writing this proposal |
| `make check` → `check-repository-tools` | Passed Ruff format/lint, 4 documentation-tool tests, four fictional-pack validations, 23 demo-data tests and 6 demo-instance tests |
| `make check` → `check-core` | Passed all nine stages, including compilation, formatting, contract/migration drift, Credo, dependency audit, Dialyzer and 335 tests |
| `make check` → generated web contracts and generator audit | Passed drift checks and the generator dependency audit |
| Web application formatting/lint/types/unit/build and browser suites | Not reached because the web dependency audit failed |
| `make check-tooling` | Passed separately; the integration command did not reach this stage |
| `make docs-check` and `git diff --check` | Passed after writing the proposal |
| Rendered prototype, representative sessions and connected-navigation checks | Not run; no interface implementation is part of this proposal |

The failed integration command does not establish a green repository. Dependency remediation is
outside this documentation proposal and was not applied.

## Agility amendment verification on 25 October 2026

This amendment changes only this proposal and the Proposed ADR 0048 clarification. The existing
shell, all runtime code, staff-account/preferences work, communications work and other chats'
records are preserved. The editor and persisted personal Home remain proposed, not implemented.

| Exact check | Current result |
| --- | --- |
| `make docs-check` | Passed after the amendment |
| `git diff --check` | Passed after the amendment |
| Web `mise exec -- npm audit --audit-level=high` | Passed; zero vulnerabilities. The 24 October dependency-audit blocker above is historical, not the current audit state |
| `make check`, first attempt | Refused a competing run while another chat owned the live integration lock. Outer make exited 2; verification-lock refusal 75. Its lock and owner were preserved |
| `make check`, retry after the owner finished | Acquired the lock; failed in core tests, exit 2: 433/434 passed. The staff-audience race test `two-second callback deadline aborts the entire owner transaction` expected `retryable_dependency` but received `{:ok, :must_not_commit}`. The test and implementation were not edited |
| Retry → documentation/repository tooling | Passed documentation validation, Ruff format/lint, 4 documentation-tool tests, four demo-pack validations, 23 demo-data tests and 6 instance tests |
| Retry → core checks before tests | Passed formatting, compilation, API/migration drift, Credo, dependency audit and Dialyzer |
| Retry → core final whitespace, web application/browser and shell stages | Not reached after the core test failed; no repository-green claim |
| Personalization editor, connected preference and human usability trials | Not run; implementation and later qualification remain separate |

The lock blocker cleared. The remaining integration blocker is the staff-audience transaction
deadline test in the concurrent work, at
[`staff_audience_race_test.exs`](../../apps/chimwemwe_core/test/chimwemwe/people/staff_audience_race_test.exs).
A successful dependency audit or the prior shell's isolated checks do not substitute for the
failed full current-checkout run. No previous dependency, incomplete-staff-file or broken-link
blocker is asserted as current without fresh evidence.

## Later repository reconciliation — 25 October 2026

After the separately owned callback-deadline repair and People-fence work were complete, the
coordinator ran `CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_again_20261025 make check` on the combined
checkout. It passed with exit 0: **452 core tests**, **54 web unit tests**, **91 browser tests**,
zero findings from both npm audits, and all documentation, formatting, static analysis, contract,
migration, build and tooling stages. No required step was skipped.

This closes the proposal's historical repository-integration blocker. It does not implement the
proposed personal Home editor, authorize connected preferences, or qualify COMM-1 publication.
