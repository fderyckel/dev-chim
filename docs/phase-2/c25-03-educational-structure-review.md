# C25-03 educational-structure review across five contexts

- Status: Complete — `approve`; C25-03 closed for synthetic L1 only
- Date: 2026-10-03
- Accountable delegating owner: François — Project Owner
- Reviewer and delegated decider: Codex, using the requested Jamie board-review perspective
- Governing decision: [ADR 0034](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)
- Retained gate: C25-03-R, external representative validation before connected workflows, real data, or deployment

## Review authority and evidence

François expressly requested delegated C25-03 closure for synthetic L1, equivalent to:

> Use delegated Project Owner authority to complete C25-03 for synthetic L1 implementation.
> Preserve external representative validation before connected workflows, real data, or deployment.

Jamie is the requested board-review persona. Codex is the actual AI author and delegated decider;
this is not a claim of personal school-board service, professional credentials, or five real
representatives. The authority is François's explicit delegation. No further synthetic C25-03
ratification is required; real representative records remain separately required under C25-03-R.

Reviewed: ADR 0025's classifications, hierarchy, sites, named actions, and C25-03/C25-04 boundaries;
the packet's seven common questions and fifteen context questions; S1, S1P, S2S, and S2–S9;
LS-01–LS-10; Sources A–F and their temporal/mapping rules; IS-01–IS-21; TM-17/AC-18; ADRs 0018,
0021, 0023, and the C25-02 acceptance. The corporate lifecycle candidate is not evidence that
educational semantics, operator publication, or representative understanding have been verified.

Two official sources provide limited cross-checks, accessed on 2026-10-03:

- [UNESCO UIS's ISCED revision account](https://www.uis.unesco.org/en/methods-and-tools/isced/revision)
  concerns national education programmes and qualifications. The design inference here is to keep
  programme/level classification separate from organizational containment and local institution names.
- England's [Academy Trust Governance Guide](https://www.gov.uk/government/publications/academy-trust-governance-guide/academy-trust-governance-guide)
  distinguishes a trust's legal identity from its academies and distinguishes board/committee
  governance. This supports separation of educational, legal, and authority meanings in that
  context; it is not a universal rule for private schools, colleges, or other countries.

## Jamie's board judgement

**Approve the foundation for synthetic L1.** An institution should not need to rename a college,
fabricate a holding school, or duplicate a department to fit the software. Equally, a clean diagram
must not conceal who is accountable or which responsibilities remain unresolved.

The future-proof choice is a small educational identity model surrounded by separately owned
relationships. A board should be able to distinguish the institution, internal organization,
learning programme, delivery site, operator, and decision-making authority. The model should let
those meanings change independently while preserving what earlier records relied on.

| Board challenge | Accepted direction | Scope decision |
| --- | --- | --- |
| A familiar label can hide a different accountability boundary | Classify by educational role and accountability evidence, not "school", "college", "faculty", or depth | Include only `institution` and `organizational_unit`; reclassification is later governed work |
| A campus often mixes a place, local administration, and branding | Use a separate site and, only if justified, a separate educational unit; associate them explicitly | Include sites/associations without forcing every campus to become a unit |
| A shared course or programme can cross several departments | Later name admitting institution, programme owner, awarding body, delivering unit, and site separately | Defer academic and award relationships; do not add second canonical parents |
| A network or brand may have no single educational establishment at its top | Allow several roots and later explicit coordination relationships | Never create an "All Organizations" institution or infer an operator from a brand |
| Reorganization can change safeguarding, records, staffing, or access without moving a learner physically | Future moves must assess those downstream responsibilities independently | Initial synthetic placement is eligible; consequential moves wait for impact controls |
| Adult learners and children can attend the same college or shared site | Keep learner capacity, guardianship, safeguarding, and access in their own governed relationships | Neither institution label, education level, nor site establishes a learner's legal capacity |
| A group wants common practices but institutions need different calendars and language | Use explicit versioned adoption with visible provenance | No live inheritance from an educational ancestor |

## Accepted concept and relationship catalogue

All persistent identifiers and endpoints are tenant-qualified. Names, codes, translations, and
paths are never foreign keys or authorization inputs. All writes require named actions with
current tenant-defined capabilities, independent module gates, expected versions, exact replay,
and atomic state/audit/outbox. No fixed school job title grants a capability.

| Concept | Meaning, endpoints, and cardinality | Attributes/evidence | Non-inference and lifecycle | First-slice decision |
| --- | --- | --- | --- | --- |
| `InstitutionalUnit` classified `institution` | A governed educational establishment; may be a root or contained institution; educational identity remains separate from `LegalEntity` | Stable UUID, explicit classification, draft status, name profile, optional local code/label, explicit IANA time zone; synthetic scenario identifies the proposed educational accountability boundary | A root, name, registration-like label, or parent does not prove legal personality or operator standing. Publication requires C25-04. Initial classification cannot be edited into another meaning through a name change | Include unpublished synthetic identities |
| `InstitutionalUnit` classified `organizational_unit` | A structurally meaningful contained division, faculty, school, department, or similar unit; resolves through the nearest containing institution once validly placed | Same identity/profile contract; classification is code-owned, labels are localized presentation; evidence states organizational purpose and intended containing institution | Not a course, class, programme, cohort, employer, budget, or permission scope. An unplaced draft remains unresolved; it is not an independent published institution | Include synthetic draft identities |
| Canonical educational parentage | Child `InstitutionalUnit` → parent `InstitutionalUnit`; child has zero/one effective parent, parent may have many children; same tenant; cycles and self-parentage prohibited | Exact endpoints, effective Date basis/time zone, attributable establishment; organization evidence rather than an inferred label ladder | Initial placement grants nothing. A contained institution starts its own accountability boundary. Later moves preserve identity and require impact review; no automatic promotion, operator substitution, or reclassification | Include initial synthetic containment; defer moves/corrections |
| `Site` | A separate physical or virtual place; never a canonical institutional parent | Stable UUID, code-owned physical/virtual kind, non-sensitive synthetic name/profile; actual addresses, coordinates, URLs, and property documents are unnecessary here | No property ownership, licence, delivery authority, tenancy placement, capacity, or access inferred. Hybrid use is represented by explicit associations to the relevant places, not a third universal organizational class | Include minimal synthetic site identity |
| Unit/site association | `InstitutionalUnit` → `Site`; many-to-many, same tenant; one attributable association per pair/effective meaning; no duplicate overlap | Exact endpoints and effective Date basis; synthetic evidence of use; no inferred primary site | Shared site does not merge institutions or grant building/student access. No inherited association from a parent. Primary-site roles and reassociation/ending need separately bounded semantics | Include initial ordinary associations; defer primary-site roles and changes |
| Local terminology/profile | Explicit localized names/labels attached to exact unit or an explicitly selected compatible profile | Fixed structural classification plus locale and display value; requested locale → explicitly configured tenant default locale → canonical stored label, with visible fallback; no arbitrary ancestor lookup | Translation/label changes preserve UUID, classification, authority, and parent rules. Profile adoption does not follow later parent/profile changes silently | Include minimum explicit localized labels; broader reusable profile/adoption behavior follows its own bounded contract |
| Current optional code | Human lookup aid on an exact unit, unique among current siblings; roots use tenant root scope | Nonblank canonical code when supplied; trim surrounding whitespace, use Unicode NFC and case-sensitive exact comparison; retain display value and use UUIDs across interfaces | No tenant-wide or cross-locale identity guarantee. Duplicate sibling codes conflict; duplicates under different parents are valid. Source aliases stay qualified. Case-insensitive search must disambiguate rather than pick a unit | Include with explicit scoped uniqueness |
| `InstitutionalAffiliation` | Future code-owned cross-cutting meaning between reviewed endpoints; never a second parent | Each admitted type needs its own purpose, endpoint, cardinality, evidence, dates, cycle, lifecycle, and impact rules | `joint_programme` is not sufficient evidence of programme identity, ownership, or awarding authority; `shared_service` does not settle provider/service scope | Defer persistent types, including these two candidates; reject generic `related_to` shortcuts |

Legal entities, corporate units, operator assignments, programmes, courses, cohorts, teaching
groups, enrolments, staff appointments, calendars, qualifications, accreditation, buildings/rooms,
transport, geofencing, budgets, and report/access scopes retain their separate owning contracts.
An actual structure requiring another classification returns for a superseding decision; tenant
labels are not a runtime schema extension.

## Five context-specific review records

Each record below is a completed analytical perspective under the same delegation, dated
2026-10-03, authored by Codex in Jamie's board-review persona. None represents an interview or an
actual institution. The disposition for each is **approve for the included synthetic L1 contract**;
the exclusions are explicit scope decisions rather than unfinished synthetic approval questions.

### Primary and early-years

Reviewed S1, S1P, S5, S7, S8, LS-04, LS-06, and LS-10. Accept independent early-learning and primary
institution roots, optional contained age-phase divisions, and separately associated sites.

| Required question | Answer and decision |
| --- | --- |
| Are divisions understandable without fixed structural types? | Yes. Early-years and primary are local labels on meaningful educational units. A standalone early-learning establishment can instead be an institution. A nursery room, class, year group, or temporary teaching group is not automatically an organizational unit |
| Can curriculum, calendars, terminology, and workflows remain institution-specific despite shared operation/templates? | Yes. They have explicit owners and adoptions; shared operator or parentage supplies no default inheritance |
| Does the model avoid a universal guardian/legal-capacity assumption? | Yes. Structural records say nothing about a particular learner's guardians, consent, safeguarding contacts, or capacity. Those are later person/learner contracts |

Board challenge: do not let a combined school's convenient group label erase a separately
accountable early-years establishment. Before connected use, a representative must validate the
real registration/accountability distinction and vocabulary; no jurisdictional conclusion is made here.

### Secondary

Reviewed S2S, S2, S5, S7, S8, LS-04, LS-06, and LS-10. Accept a standalone secondary institution
with subject departments or meaningful divisions; a primary ancestor is unnecessary.

| Required question | Answer and decision |
| --- | --- |
| Are departments distinct from courses, programmes, sections, and timetables? | Yes. A mathematics department can be a unit; a mathematics course, examination programme, class section, and scheduled lesson remain separate academic/delivery records |
| Can divisions use different calendars, teaching days, periods, and cycles? | Yes as a future academic contract. Neither unit ancestry nor this approval supplies a calendar. ADR 0021 remains separately proposed |
| Can shared programmes/services cross divisions without a second parent? | Yes conceptually through explicitly owned relationships. Persistent affiliations are deferred here; the synthetic fixture can show the requirement without storing a generic edge |

Board challenge: a subject department's academic coordination must not be confused with line
management, budget authority, or access to every learner taking that subject. Real context review
must test this separation with an actual secondary timetable and reporting vocabulary.

### Combined education

Reviewed S2, S5, S7, S8, LS-04, LS-05, LS-08, and LS-10. Accept early-years, primary, and secondary
divisions under one institution without requiring every level or a fixed depth.

| Required question | Answer and decision |
| --- | --- |
| Can all age phases coexist without fixed depth? | Yes. Divisions can have additional reviewed organizational layers; age phase is not a required position in a universal tree |
| Is a division distinguishable from a separately operated contained institution? | Yes. The former resolves through its nearest containing institution; the latter is explicitly classified `institution`, even if it shares a brand, site, or operator with a parent |
| Are cross-level academic, sports, and support programmes outside containment? | Yes. A durable educational sports department may be a unit; a sports programme/team is not the same identity. Shared services and programmes need separate contracts |

Board challenge: moving a high-school division under a different institution may change legal
accountability and safeguarding/records responsibilities. That is not a harmless tree edit;
reparenting remains blocked until impact and C25-04 dependencies are satisfied.

### College and community college

Reviewed S4, S5, S6, S7, S8, LS-04, LS-07, and LS-10. Accept multiple institution roots, shared
sites, multiple delivery locations, and both adult and younger learner contexts without structural
merger or a fabricated umbrella institution.

| Required question | Answer and decision |
| --- | --- |
| Can campuses/institutions share sites, services, programmes, and operators without merger? | Yes at the logical level. Sites are explicit many-to-many associations; service/programme/operator relationships remain separately owned and gated. A campus label alone does not create another institution |
| Are independent and coordinated operations possible without one calendar/report scope? | Yes. Shared coordination does not imply common calendars, admissions, academic ownership, reporting visibility, or finance scope |
| Can operator transfer preserve learner, programme, and course identity? | Yes as the retained C25-04 invariant. The institution UUID remains stable, and downstream records retain their exact references. This review does not execute or accept that transfer workflow |

Board challenge: admitting, teaching, and awarding bodies can differ. A later learner/programme
model must name each responsibility; one `school_scope_id` or an affiliation label cannot settle
them. Work-based placement sites and professional accreditation also require separate domain review.

### University

Reviewed S3, S5, S6, S7, S8, LS-05, LS-06, LS-08, and LS-10. Accept faculties, schools, departments,
institutes, and contained institutions without a prescribed ordering or a universal meaning of
"college". Repeated names/codes in different parent scopes are legitimate.

| Required question | Answer and decision |
| --- | --- |
| Can mixed structures coexist without a fixed type ladder? | Yes. Classification records the institution/unit distinction. A separately incorporated establishment still needs evidence of its educational accountability; legal incorporation alone does not automatically create an educational institution |
| Can courses, programmes, research/support units, and sports cross structures without two parents? | Yes conceptually. Choose one canonical organizational home for a unit only when the evidence supports it; other purposes need exact typed relationships. If genuinely indistinguishable dual canonical homes remain, defer that case instead of duplicating the unit or choosing arbitrarily |
| Can calendars and academic responsibilities remain explicit at unit/programme scope? | Yes. Later academic domains own those meanings and must pin appropriate unit/programme references and revisions. No ancestor fallback or automatic institutional calendar is supplied |

Board challenge: departmental reorganization must not retrospectively reattribute historical
awards, grants, appointments, or financial results. Those consumers must pin the relevant identity
and historical basis and reconcile changes deliberately.

## Seven common answers across all five perspectives

| Question | Primary/early-years | Secondary | Combined | College | University |
| --- | --- | --- | --- | --- | --- |
| Q1 — distinguish identities | Yes: institution, division and site differ | Yes: department differs from course | Yes: division differs from contained institution | Yes: campus/site/institution distinguished by evidence | Yes: school/college labels do not decide classification |
| Q2 — operator clarity | Yes: explicit institutional boundary | Yes: standalone institution has its own boundary | Yes: nested institution stops ancestor resolution | Yes: one entity may operate several institutions | Yes: contained institution resolves independently |
| Q3 — responsibilities separate | Yes: operation/property/guardian meanings differ | Yes: governance/employment/academic coordination differ | Yes: shared branding/site is not shared accountability | Yes: delivery, funding and awarding responsibilities differ | Yes: corporate, academic and accounting views differ |
| Q4 — representability | Yes for S1/S1P, not a real institution attestation | Yes for S2S, with academic records separate | Yes for S2/LS-05 | Yes for S4, with matrix services deferred | Yes for S3; unresolved dual canonical homes remain excluded |
| Q5 — no implicit authority | Yes; no guardian or access inference | Yes; no subject-wide learner visibility | Yes; no inherited policy or operator | Yes; no shared-site access or reporting grant | Yes; no descendant visibility or academic authority |
| Q6 — identity/history | Accepted logical rule; lifecycle proof later | Same; course identity stays separate | Same; cross-institution moves require review | Same; operator transfer remains C25-04 | Same; historical academic/finance attribution stays explicit |
| Q7 — missing/unsafe concepts | Rooms, capacity and guardian rules deferred | Timetables, examinations and classes deferred | Cross-phase services and consequential moves deferred | Awarding/placement/accreditation contracts deferred | Joint programmes, complex reorganizations and reporting contracts deferred |

The answers do not claim present implementation or representative usability proof. Q2 approves
the logical boundary; it does not close operator workflow condition C25-04.

## Scenario, migration, and temporal dispositions

| Evidence | Completed educational-domain disposition |
| --- | --- |
| S1, S1P, S2S, S2, S3, S4 | Accept the five-context structural shapes, multiple roots, contained institutions, local labels, and shared sites. S4's shared-service requirement remains outside the first persistent affiliation catalogue |
| S5 | Accept identity/history separation; rename is not replacement, move is not correction, closure is not erasure. Non-initial lifecycle actions require their own qualified slice |
| S6 | Accept the need for matrix academic relationships; defer `joint_programme` persistence to the academic owner. No fabricated second parent, duplicate unit, or generic substitute |
| S7, S8 | Accept fail-closed cross-tenant/cycle/collision/unknown-impact behavior; require negative executable proof before implementation exit |
| S9 and LS-01–LS-03 | Retain separate legal, corporate, and educational identities; C25-02 governs legal meanings, not this approval |
| LS-04–LS-06 | Accept shared operators, separately accountable contained institutions, and split responsibilities as logical cases; operator persistence remains C25-04 |
| LS-07 | Accept stable educational identity during operator change as a requirement; defer operator action/approval and activation proof |
| LS-08–LS-10 | Accept independent reorganizations, invalid relationship denial, and zero implicit authority/enumeration; no current move or traversal implementation is certified |
| Source A — enterprise organization tree | Company is not automatically an institution. Department may be corporate or educational; branch/address may be a site. Preserve both parent candidates as unresolved; user defaults grant nothing |
| Source B — tertiary hierarchy | Preserve university/school/department identities and sibling-scoped codes. Programme is not a unit; quarantine cycles and missing/foreign parents. An unverified operator prevents publication, not compare-only identity staging |
| Source C | Preserve separate proposed institution, division, site, operator and property meanings; `company` is not enough to select an operator |
| Source D | Legal ownership and management parentage do not supply educational parentage, operator, or access |
| Source E | A separately accountable contained establishment is an institution; its department resolves through it, not past it to a higher educational ancestor |
| Source F | Unknown historical operator boundary remains unresolved. Snapshot/import times are not invented business dates; authority migration is separate |

Accept the ledger dispositions `mapped`, `split`, `merged_alias`, `unresolved`, `rejected`, and
`deferred_owner` with attributable successor mapping decisions. Preserve source system/snapshot,
identifiers, exact parent/type evidence, protected reference or permitted digest, mapping revision,
target UUID if resolved, reviewer, time, reason, and publication block. These fixtures authorize no
source import or real-data storage.

Profiles, classification, initial parentage, site associations, closure, correction, audit,
outbox, and migration provenance remain distinct. Effective Dates use inclusive start/exclusive
end and a declared stored IANA zone; writer recording time is UTC. For the first synthetic
persistence proof, use explicit `UTC` institution/association fixtures, so a cross-zone assumption
cannot silently enter temporal cycle or overlap checks. Do not inherit the zone from a newly
selected parent or reinterpret earlier intervals when a profile changes. Actual cross-zone moves,
instant-precision sources, and historical corrections remain later contract/qualification work.

## Implementation admission and mandatory negatives

C25-03 is an accepted synthetic entry decision, not completion evidence. The first eligible work
is unpublished educational identity/profile qualification under 2.1-D; initial parentage,
sites/associations and minimal terminology follow under 2.1-E after applicable prerequisites.
An unresolved draft unit may be staged but cannot masquerade as a published institution. All
operator assignment/transfer persistence and institution publication remain unavailable while
C25-04 is open. No generic status update, fixture seed, raw writer, or label change may bypass it.

An implementation must provide positive cases plus at least these negatives where applicable:

1. Missing actor, tenant, purpose, capability, module gate, or current routing fails before access.
2. Every parent, site, association, profile/history reference, and future operator endpoint rejects
   foreign-tenant identifiers without existence disclosure.
3. Self-parent, direct/indirect cycles, reciprocal concurrent edges, and overlapping parents fail
   on the writer and alternate database paths, not only in the interface.
4. Initial placement cannot quietly reparent an already placed unit; profile revision cannot
   change classification, parentage, site, operator, or authority.
5. Exact retry replays its original result; changed actor/input and stale versions conflict;
   injected failure leaves no partial state, successful audit, outbox, or completed replay claim.
6. Sibling code collisions fail, including concurrent writes; the same code under distinct parents
   succeeds; UUID identity survives name/code/locale changes.
7. A nested institution remains an accountability boundary even if its eventual operator equals
   its parent's; ordinary units never resolve past the nearest institution.
8. Unplaced organizational units and missing/unverified operators cannot publish. The first
   draft-only slice must reject publication/operator writes entirely while C25-04 is open.
9. Site association does not grant property rights, room capacity, access, placement, or implicit
   associations to descendants; multiple units can share a site without merging.
10. Unsupported classification/affiliation, course-as-unit shortcuts, and label-driven promotion
    are rejected. Translation changes no allowed-parent rule or permission.
11. Exact reads require their own capability and do not become collection/traversal endpoints.
    Visible parents/selectors disclose no hidden descendants or totals.
12. Hierarchy changes cannot implicitly adopt calendars, configuration, reports, modules, legal
    responsibility, or grants; unknown impact prevents a consequential move.
13. Time-zone changes cannot reinterpret established effective facts; overlapping/different
    temporal bases and exact-time evidence are rejected where unsupported.
14. Events/logs contain only the approved minimum; labels, addresses, people, documents, and
    sensitive relationship graphs do not leak. Inactive modules deny ordinary actions.

The implementing slice must also inspect generated migrations, rollback/retained-data behavior,
indexes, constraints and tenancy; measure its explicit processing bounds; and pass the repository
gate. No fixed business-depth ladder is introduced, but a bounded operation must refuse excessive
work rather than silently truncate an invariant check. No code or migration is changed here.

## C25-03-R external representative validation

**Open before connected use, including synthetic L2; before real data/import, pilot, or deployment.**
François owns obtaining the records. Retain the packet's 2026-12-15 review date or the first
affected boundary, whichever is earlier. A missed date leaves the boundary closed.

For each of the five contexts, obtain a real named reviewer with documented current/recent
operating knowledge. One person may cover multiple contexts only with explicit relevant experience
for each. The record must include organization/context (a privacy-preserving descriptor is
acceptable), review date, assigned scenarios, seven common answers, three context-specific
answers, actual vocabulary/accountability/site mappings, missing cases, concerns, conditions with
owner and gate, and `approve`, `approve with condition`, or `do not approve`.

The educational-domain owner must consolidate those findings. Every blocking objection is resolved
before the dependent workflow; a challenge to a stable invariant requires a superseding ADR. This
does not complete C25-05 representative comprehension/accessibility or C25-06 security/records
acceptance. Jamie is not a substitute name for an actual external participant.

## Completed delegated review record

| Field | Recorded value |
| --- | --- |
| Reviewer | Codex, using Jamie's requested board-review perspective |
| Relevant capacity | AI domain analysis under François's express delegation; no personal board-service or representative-interview claim |
| Accountable owner | François — Project Owner |
| Date | 2026-10-03 |
| Contexts covered | Primary/early-years, secondary, combined education, college/community college, university; all five synthetic perspectives approved |
| Evidence | Packet, ADR 0025, educational and linked scenarios, Sources A–F, temporal/control matrices, and limited official-source cross-checks listed above |
| Answers | Seven common questions across five contexts and all fifteen context-specific questions completed |
| Educational-domain disposition | Approve the included classifications, initial containment, sites, ordinary associations, scoped codes, and terminology; defer explicit excluded contracts |
| Missing/unsafe meanings resolved | Campus ambiguity, nested institution accountability, course/department confusion, implicit inheritance, code identity, matrix links, and operator-publication dependency are explicitly bounded |
| Accepted residual risk | No actual representative testimony yet; synthetic Date/locale and draft-only scope cannot establish country-specific or operational correctness |
| Remaining gates | C25-03-R external validation; C25-04 operator/publication; C25-05 connected experience; C25-06 real-data/deployment; implementation exit checks |
| Disposition | **approve — C25-03 closed for synthetic L1 under delegated Project Owner authority** |

## Verification

The documentation checks and required `make check` result are recorded here after execution.
