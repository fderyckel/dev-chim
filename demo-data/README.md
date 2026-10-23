# Fictional institution demo data

- Status: Local synthetic fixture catalogue; no database import or release authority
- Version: 1
- Reference date: 2026-10-23
- Owner: Project Owner, with implementation checks maintained by platform engineering

Four complete, related JSON packs are checked into [packs](packs). They borrow public educational
patterns and vocabulary, with fictional institutions, people, contacts, counts, events and policies.
They are sample populations for walkthroughs, not full-sized school replicas or capacity evidence.

| Pack | Fictional institution | Learners | Staff | Family/contact links | Applicants |
| --- | --- | ---: | ---: | ---: | ---: |
| [Bangkok international school](packs/bangkok-international.json) | Lotus Grove International School | 112 | 18 | 142 | 8 |
| [US community college](packs/us-community-college.json) | Cedar Coast Community College | 97 | 16 | 8 | 8 |
| [Hong Kong kindergarten](packs/hong-kong-kindergarten.json) | Harbour Lantern Kindergarten | 72 | 12 | 92 | 8 |
| [England independent school](packs/england-independent.json) | Alder Mere School | 84 | 16 | 107 | 8 |

Learner counts include ended and future enrolment examples. A college instructor also studies,
so the college learner and staff counts overlap by one person. Relationship counts are links,
not unique guardians or qualified recipients. Applicant-only people are never enrolled.

## Prepare an instance

```sh
make demo-data
make demo-data-check
make demo                         # interactive selection
make demo DEMO=england-independent
```

The first command validates the shipped catalogue and creates a fresh directory under
`tmp/demo-instances/instance-*`, containing every pack, source provenance, hashes and an instance
manifest. No database is contacted. Existing directories are refused rather than reset.

The standard `make classroom-demo`, `make auth-demo`, `make legal-demo`, `make web-dev` and
`make web-core-dev` commands prepare all four packs before starting their existing demo. They
print the directory and pass it to the process as `CHIMWEMWE_DEMO_DATA_DIRECTORY`. Directly
invoking an older underlying launcher bypasses preparation; use the stable Make commands or
`bin/with-demo-data command ...`.

**`make demo` loads the chosen institution into the browser app.** The startup menu offers the
four institutions; `make demo DEMO=england-independent` bypasses the menu. Open
`http://127.0.0.1:3000` for Overview, Students, Families & guardians (college Contacts), Educators
(college Instructors), and Calendar. `DEMO_PORT=3035` selects a different local port. Stop with
Control-C and restart to choose another institution; each run gets a fresh retained instance.

The app server reads the selected prepared pack, verifies its code-owned digest and tenant,
and projects only that institution's records. Startup pins the selected pack ID in the process
environment and tenant in the instance manifest. A URL cannot switch them. Invalid mode, Host,
selection, tenant, digest or missing file produces `Demo unavailable`; no other pack is substituted.

Search people by name or visible reference (for example `S003`), filter school year levels and
page through all records. Expand a student for dated enrolment, daily register, subject/course
groups and actual contact links. Expand a contact for its explicit linked learners, or an educator
for dated register and subject responsibilities. Calendar shows teaching periods, student closures
and scoped events separately. Reference dates and time zone stay visible; these are fixed examples.

This is an actual fixture-backed browser demo, with no database import or operational write.
The earlier `make web-dev`, bridge, authentication, legal and classroom-writer qualification
commands retain their existing fixtures. Future operational consumers must use named actions
and applicable tenant, permission and module gates. No production guardian, admissions,
course-registration, boarding, messaging or account feature is authorized by viewing the fixtures.

For a deliberately named, new destination:

```sh
mise exec -- uv run python tools/demo_data.py prepare \
  --environment local-synthetic --destination tmp/my-new-demo
```

There is no production preparation mode, runtime network dependency, real account or password in
the catalogue. The wrapper does not change the authentication or access of its child process.

## Contents and conventions

Each pack includes a schema version, distinct stable tenant UUID, source references, fixed
reference date, assumptions, empty account/grant lists, and tenant-qualified record collections:

- Institutions, educational divisions, sites and programmes.
- Academic years, ordered primary periods, student closures and separately scoped events.
- Fictional people, learners, educators and dated family/contact relationships.
- Enrolments, daily registers, dated placements and teaching responsibilities for school packs.
- Separate calendar sessions, subject/course sections and section registrations where relevant.
- Applicant examples, mixed-group activities and English day/boarding context.

This is a **fixture schema**, not a database/resource schema or a generic import API. Only a name
subset resembles the current People contract; dates of birth, contact details, relationships,
programmes, applications, course sections, activities and boarding are inert scenario data.
Current [People](../docs/adr/0036-minimal-people-participation-and-staff-account-association.md),
[Classroom](../docs/adr/0037-class-register-enrolment-and-placement.md) and
[Calendar](../docs/architecture/academic-calendar-authority.md) contracts retain precedence.

Calendar dates use inclusive starts and ends. Participation, relationship, enrolment, placement
and assignment intervals use `[effective_from, effective_until)`. Every academic year declares
its IANA time zone. The fixtures stay fixed at 2026–27 when started later; they are not silently
shifted to today and do not create historical audit or attendance facts. Weekdays and holiday
choices are illustrative and do not claim jurisdictional compliance or school-policy fidelity.

All contacts use the reserved `example.test` domain. Missing contacts, duplicate display names,
different surnames and shared email addresses are intentional. Names, languages and birthdays
never determine identity, nationality, admission, placement or permission. A relationship label
confers no account access, disclosure, collection authority or notice-recipient status. There are
no medical, safeguarding, credential, financial, national-identity, address or phone records.

## Educational coverage

- Bangkok spans Pre-K, Kindergarten and Grades 1–12, separated into elementary, middle and high
  school, with illustrative standard, IB and AP senior pathways. Registers and subject groups
  remain different records.
- The college includes adult and returning learners, part/full-time intentions, associate/transfer,
  certificate and noncredit goals, daytime/evening sections, winter/summer sessions and overlapping
  fall blocks. Session-specific fictional deadlines are events. Course sections are never converted
  into the current single-register placement contract.
- Hong Kong uses the generic EDB K1/K2/K3 pattern with disjoint AM and PM cohorts, age-plausible
  children, classroom support and play activities. ESF inspires inquiry/play only: its K1/K2
  structure is not evidence for a third ESF year. Whole-day/session scheduling remains unsupported.
- England covers Years 7–13, Lower/Middle School and Sixth Form, IB senior study, three terms,
  half-term breaks, and separately dated day/boarding context. Boarding return is an event and
  does not open or close instruction.

Boundary examples include a late arrival, a future start, an ended enrolment, an adjacent class
transfer, an ended substitute and replacement, a subject-group change preserving the daily
register, shared/missing family endpoints, staff/guardian and staff/learner overlaps, and enquiry,
submitted, missing-document, offered, accepted-offer, deferred, withdrawn and waitlisted applicants.
An offer or accepted offer creates no enrolment or access. Events never send messages.

## Public evidence and limits

[sources.json](sources.json) records the URLs, retrieval date, influence and limits. Research used
[ISB curriculum](https://www.isb.ac.th/curriculum-academics-learning/the-isb-curriculum) and
[calendar](https://www.isb.ac.th/calendar),
[Santa Monica College dates](https://www.smc.edu/academics/classes/dates-deadlines.php) and
[programme types](https://www.smc.edu/student-support/academic-support/transfer-center/areas-of-study/associate-degrees/),
[Hong Kong EDB kindergarten context](https://www.edb.gov.hk/en/edu-system/preprimary-kindergarten/overview/),
[ESF Tsing Yi's profile](https://join-us.esf.edu.hk/schools/esf-tsing-yi-international-kindergarten/) and
[ESF's provisional calendar](https://www.esf.edu.hk/wp-content/uploads/2025/10/ESF-Calendar-2026-2027_V1.pdf),
plus [Sevenoaks curriculum](https://www.sevenoaksschool.org/academic/our-curriculum/overview/) and
[term dates](https://www.sevenoaksschool.org/wp-content/uploads/2025/09/2026_27-Term-Key-Dates2.pdf).
No school's people, contact directory, branding, private data, calendar feed or narrative is copied.
Public evidence establishes patterns, not internal rules, representative testimony or endorsement.

## Maintenance and review

Edit the code-owned [profiles](../tools/demo_data_profiles.py) and
[builder/validator](../tools/demo_data.py), then run `make demo-data-build` and
`make demo-data-check`. [manifest.json](manifest.json) pins counts and SHA-256 hashes. The full
`make check` includes fixture drift, scenario checks and preparation tests. A schema or identity
change needs an explicit version decision; ordinary regeneration is deterministic and offline.

The 2026-10-23 read-only AI reviews used the repository's
[primary, secondary and admissions profiles](../docs/development/specialist-review-team.md).
All approved the proposed fixture-only scope with conditions. The coordinator accepts the
separation of family links from authority, college sections from registers, applicants from
enrolments, events from closures, and future scenario objects from implementation. The generic
K1/K2/K3 choice deliberately combines EDB context with ESF play/inquiry inspiration. These are AI
design reviews, not school testimony, safeguarding/security assurance or release acceptance.
The Advisor preflight was unavailable (`parent_runtime_unavailable`); no Advisor approval is claimed.

Final specialist inspection on 2026-10-23:

| Profile | Final disposition | Coordinator decision and closure evidence |
| --- | --- | --- |
| Primary education | Approve for fixture use | Accept: age-plausible disjoint kindergarten cohorts, family authority flags, separate calendar meanings and honest preparation limit inspected |
| Secondary education | Approve after repairs | Accept: ordinary subject groups now have explicit matching years; the tagged subject transfer preserves one daily register; IB Diploma is limited to Grades 11–12 |
| Admissions | Approve after repairs | Accept: applicants' ages match intended programme/year at entry; college advising addresses learners, with no inferred family recipients |

These were read-only AI source/fixture inspections. The implementer owns the software checks;
the reviewers did not independently run the repository suite. All raised material conditions are
closed for this fixture-only scope. No UI was changed, so a visual/interface specialist review
was not required.

Verification: `make demo-data-check` passed all 23 fixture/preparation tests, `make demo-data`
prepared all four packs, and `shellcheck bin/with-demo-data` plus `git diff --check` passed.
The required `make check` passed all stages: documentation, repository tools, fixture drift,
23 fixture/preparation tests, core formatting/compilation/contracts/migrations/lint/audit/type
analysis, 309 core tests, web formatting/lint/types/build/dependency checks, 31 web unit tests,
43 browser tests (33 fixture UI, 6 bridge, 1 unavailable-backend and 3 classroom/calendar), and
shell tooling. No required stage was skipped. Documentation and whitespace checks were repeated
after recording this result. Real-data, independent review, adoption and production gates remain
unchanged.

## Selected browser demo follow-up

The Project Owner subsequently authorized actual selected-pack browser loading, recorded in
[ADR 0046](../docs/adr/0046-selected-local-demo-institution.md). The selected pack now supplies
the app's home and its people/calendar views. This supersedes the earlier file-preparation-only
limitation for `make demo`, while the existing operational qualification fixtures remain separate.

All four specialists approved the implemented viewer on 2026-10-23. Primary and secondary review
confirmed separate enrolment/register/subject meanings, dated family links and fixed-date status.
Admissions confirmed college vocabulary and exclusion of applicant-only people. UI review
inspected actual wide and narrow screenshots, identity references, expansion, navigation,
contacts and pagination. The coordinator accepts all recommendations; no material condition is
open. Optional wording polish for college responsibilities and empty sections was applied.
These are AI source/screenshot reviews, not independent safeguarding or human usability evidence.

Executed focused evidence: six startup tests, nine loader/projection tests and eight browser
tests across all four selected packs. The browser tests cover actual people/relationship/calendar
navigation, search, pagination, keyboard, accessibility checks and 1440/768/320-pixel reflow.
The coordinator also opened the live local app and inspected a student with its actual register
history and family links. Screenshot copies are retained under `tmp/demo-instance-view-review`.
The first full gate stopped at an already-held browser verification lock; it was retried after
the other run ended. The retry passed every required stage: documentation and repository tooling;
4 documentation-tool tests, 23 data-pack tests and 6 startup tests; core compilation, contracts,
migrations, lint, dependency audit, type analysis and 309 core tests; both web dependency audits,
formatting, lint, type checking, 40 unit tests and the production build; 54 browser tests across
the local, bridge, unavailable-backend, classroom and four selected-pack variants; and shell
tooling. No required stage was skipped.

The separate Advisor preflight again reported `parent_runtime_unavailable`; no Advisor sign-off
is claimed. Existing production, real-data and independent-review gates retain precedence.
