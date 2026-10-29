# Local demo application shell evidence

- Date: 2026-10-24
- Status: Implemented and qualified locally; later combined integration passed
- Governing record: [ADR 0048](../adr/0048-local-demo-application-shell.md)
- Authorization: Project Owner approved the first Home, Apps and workspace shell on 24 October 2026

## Implemented boundary

The existing fictional institution viewer now has global Home and Apps destinations, an explicit
three-app catalogue and bounded workspace navigation. Students contains the existing student
and contact directories. Educators/Instructors and Calendar retain their existing pages. Home
retains institution counts and academic periods, rather than inventing personal tasks.

The catalogue has stable local identifiers, code-owned routes and institution-specific labels.
Only `/demo/apps` extends the route allowlist. Search matches catalogue labels and synonyms,
never records, and its results only navigate. The local metadata is not connected to core
module or authorization registries. Existing guards, source adapters, record distinctions and
core qualification routes remain separate. No persistence, authentication, API, domain resource,
migration, real data or release is introduced.

Desktop uses local workspace navigation beside the page. Phones use native disclosure with
the active workspace/page named in its closed summary. Global Home and Apps remain visible.
The institution, fixed example date, academic year and zone remain visible. The existing GET
selector retains its current route; section changes discard unsubmitted selector choices.

Lucide React 1.61.0 supplies statically imported, labelled decorative icons. Its registry and
installed package report ISC licensing and React 19 compatibility; its package adds no runtime
dependency beyond existing React and optional React types. Version and integrity are pinned in
the web lockfile. Existing dependency audit findings are tracked separately below.

## Specialist checkpoint

The three relevant [authorized profiles](../development/specialist-review-team.md) reviewed the
bounded plan independently and read-only. Admissions was not re-instantiated because no
admissions capability or meaning changes in this increment.

| Profile | Disposition | Condition and owner functions | Coordinator response |
| --- | --- | --- | --- |
| Primary education | Approve with conditions | Make family contacts discoverable under Students; describe teaching-staff scope; preserve non-authority wording and fixed dates. Education product/client engineering | Accept; tile descriptions, local labels and existing contact qualifications retained |
| Secondary education | Approve with conditions | Preserve register/subject/college distinctions, exact institution context and read-only institutional Home. Education product/client engineering | Accept; existing dataset and detail rendering unchanged |
| UI and interaction | Approve with conditions | Use Educators/Instructors instead of ambiguous People; name current phone workspace/page; explicitly allow Apps and limit search to destinations. Product experience/accessibility engineering | Modify; concrete labels, route allowlist and native disclosure adopted |

These are AI design checkpoints, not representative observations or production approval.
Rendered review and executed checks are recorded below. The architecture
Advisor route was unavailable because its parent runtime could not be verified; no Advisor
approval is claimed.

## Verification

The shared checkout changed concurrently during this work. Existing institution-selector
history coverage was preserved and adapted to the two navigation levels. Calendar evidence,
COMM-1 and credential/account work were not reset, formatted, committed or absorbed into this
shell change.

Final web qualification used a temporary source copy of the baseline plus exactly fourteen
scoped web files: the demo section route; web package/lock; DemoApps, DemoShell and the existing
viewer; navigation definitions; the existing server entry; demo CSS; navigation test helper;
shell, institution and selector browser tests; and navigation unit tests. All fourteen files
were compared byte-for-byte with the working checkout after the final browser run and matched.
This excludes the concurrent account screens; it does not certify their integration.

| Exact check and scope | Actual result |
| --- | --- |
| Shared checkout `make check` | Failed, exit 2, at the web application's dependency audit: high-severity affected packages `undici` and `zod`, plus moderate `fast-uri` |
| `make check` → documentation/repository tooling | Passed documentation validation, Ruff format/lint, 4 docs-tool tests, four pack validations, 23 demo-data tests and 6 instance tests |
| `make check` → core | Passed all nine stages, including formatting, compilation, API/migration drift, Credo, dependency audit, Dialyzer and 336 tests at that command's checkout state |
| `make check` → generated web contracts/generator audit | Passed both contract drift checks; generator audit found zero vulnerabilities |
| Shared checkout `CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run check` before the last tile-layout refinement | Passed formatting, lint, types, 8 token tests, 5 dependency-guard tests, 54 unit tests and production build |
| Subsequent shared-checkout web checks | Blocked by concurrent unformatted `staff-login.tsx`/`staff-shared.tsx` and then missing account/preferences components and generated staff schema; none was edited as part of this shell |
| Scoped Prettier check on the fourteen changed/new web paths | Passed for source/test paths; package and lock formatting also passed in the isolated full check |
| Final isolated `CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run check` | Passed full formatting, lint, style contract, types, 8 token tests, 5 dependency-guard tests, 54 unit tests and production build |
| Shared checkout `CHIMWEMWE_DEMO_E2E_PORT=3060 mise exec -- npm run test:e2e:demo`, under the web verification lock | 40 passed before final tile compaction and the additional unsubmitted-choice case |
| Final isolated `CHIMWEMWE_DEMO_E2E_PORT=3080 mise exec -- npm run test:e2e:demo`, under the web verification lock | 44 passed across all four institutions; 1440/768/320 reflow, zero automated axe violations, native disclosure keyboard paths, catalogue search, invalid selection/unknown route refusal, institution reset, direct routes, calendar and Back/Forward cases |
| `make check-tooling` | Passed separately; the integration command did not reach this stage |
| `make docs-check` | Passed after adding the implementation records; the final repeat was blocked by concurrently added ADR 0051 linking to its not-yet-present account-principal-binding evidence |
| `git diff --check` | Passed after recording the final results |
| UI-0, UI-1A and classroom browser suites through `make check` | Not reached because the web dependency audit failed; not independently rerun for this demo-only increment |
| Representative human usability, live assistive-technology sessions, connected navigation and release checks | Not run; separate later gates |

The initial local formatting/specificity failures were corrected before qualification. The
dependency advisories and concurrent integration failures remain unresolved by this slice.
No repository-wide green status is claimed.

### Later combined integration

On 25 October 2026, after the concurrent staff and People changes were stable,
`CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_again_20261025 make check` passed the combined checkout.
The run included the final shell sources and passed **452 core tests**, **54 web unit tests** and
**91 browser tests**, including this shell's 44 demo tests. Both npm audits reported zero
vulnerabilities. The failures and isolated results above remain historical evidence of this
slice's development; they are not the current repository integration state.

## Rendered review

The final isolated browser run captured Apps at 1440, 768 and 320 pixels and workspace pages at
those widths. Twelve selected desktop/phone captures for all four institutions were copied to
the ignored local `clients/web/playwright-report/synthetic-shell/` review directory. A separate
in-app browser walkthrough verified Home and captured desktop/320-pixel examples. These are
actual software captures, not generated design images.

| Profile | Final disposition and observed evidence | Coordinator response |
| --- | --- | --- |
| Primary education | Approve after source and four screenshot reviews: family contacts are discoverable; authority qualification, fixed dates, institution summary and readable phone location remain explicit | Accept; earlier conditions satisfied within the local scope |
| Secondary education | Approve after source and six screenshots: college Instructors/Contacts, school register/subject and college section distinctions remain; no personal task or hierarchy inference | Accept; minor future copy refinement is to avoid a family-specific search example for the college |
| UI and interaction | Approve after source and twelve screenshots: labelled icon tiles, readable group headings, explicit institution/current phone page and visible focus; no material task blocker | Accept; actual checks and limitations recorded as requested |

The demo's phone institution/switch block remains deliberately explicit and uses substantial
vertical space; revisit density before a later daily-use workflow. Reviewers inspected images
and source, and did not independently rerun the coordinator's checks. Screenshots and axe do
not establish representative comprehension, live screen-reader acceptance or production access.
