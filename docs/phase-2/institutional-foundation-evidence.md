# CF-1 institutional identity and initial publication foundation

- Status: Implemented private synthetic L1; functional verification passes, full gate blocked by existing web dependency advisory
- Date: 2026-10-03
- Verification refreshed: 2026-10-04 on the combined calendar/institutional checkout
- Owner: Product and platform engineering
- Authorization: François's “go ahead” for CF-1 after assigning calendar work to another agent
- Governing decisions: ADRs 0025, 0034 and 0035; the classroom-first six-week plan
- Review trigger: calendar integration, further institutional lifecycle work, or connected/real use

## Delivered boundary

`Chimwemwe.InstitutionalStructure.Foundation` provides four named internal operations:

| Operation | Input and result |
| --- | --- |
| `register_institution/3` | Display name, explicit PostgreSQL-recognized time zone, idempotency key and causation ID; returns stable institution ID, draft state and version 1 |
| `assign_initial_operator/3` | Exact institution/version, legal entity/version, protected evidence UUID and local effective date; verifies the initial basis and returns draft version 2 |
| `publish_institution/3` | Exact institution/version plus replay keys; rechecks the current legal entity and freshly verifies evidence/impact, then returns published version 3 |
| `current_institution/3` | Exact UUID under current read authority; returns a minimal institutional view, including assignment and publication references, without protected evidence |

All writes require `idempotency_key` and `causation_id`. Tenant, actor, placement, correlation and
authority come from validated execution context. Unknown action-input fields are rejected.
Release availability, entitlement, activation, the compatible legal-module dependency, and the
operation's separate capability are checked on the writer before execution or replay.

The initial capability keys are `institution.structure.institutions.register`,
`institution.structure.operators.assign_initial`, `institution.structure.institutions.publish`,
and `institution.structure.institutions.read`. They are code-owned task keys assigned through
tenant-defined roles, not institutional job-title constants. Legal-module authority never supplies
these permissions implicitly. The released module is `institution.structure` version `1.0.0`,
depending on the existing compatible `organization.legal` declaration.

This increment registers independent root institutions only, with classification `institution`.
It does not create ordinary units, parentage, sites, hierarchy reads, people, classes, calendar
records, operator transfers, correction, revocation workflows, a public endpoint, or a browser
screen. Several roots may share one operator. There is no artificial tenant root or fixed-depth
hierarchy. Later increments preserve the stable `institutional_unit_id` reference.

## Evidence and publication boundary

Trusted application composition creates `InstitutionalStructure.Runtime` from the existing
persistence runtime and one records-verifier module/source. The action input cannot select that
adapter or submit a verification flag. There is no default adapter or production connector.
The only supplied executable adapter is a test-only synthetic source.

The verifier is called inside the writer transaction both at initial assignment and publication.
It must perform read-only checks against its current sources and return exactly the typed contract
validated by `OperatorVerification`. The request binds tenant, institution/version, legal
entity/version, protected evidence reference, effective date and a fresh writer timestamp.
The result also supplies operative evidence/issuer/verifier references, evidence version,
applicable dates, current-status check date, conditions, and accepted impact reference/policy.
Missing, revoked, inaccessible, stale, wrong-scope, extra-field or unknown-policy results fail
closed. No full document, sensitive URL or evidence payload enters audit/outbox results.

Only the fictional `ZZ` / `synthetic.cf1.initial_operator.v1` policy is admitted. It requires an
operative-instrument proof, not incorporation alone, status verification at most 30 local dates
old with no future timestamp, satisfied conditions and unexpired applicability. Publication
performs the check again rather than trusting the assignment's stored outcome.

The sole impact policy is `cf1.initial_unpublished_root.v1`: a new root with no dependent records
or external side effects. Nonempty or unclassified consumer impacts are refused. Calendar and
later modules must not attach operational records to an unpublished institution or treat this
policy as approval for a transfer. Any broader effect requires the next reviewed impact contract.

Initial assignment may prepare a future local start date. Publication must occur on that exact
institution-local date; it cannot backdate activation, start a future relationship early or use
time passing as an activation action. Assignment and publication proofs are immutable domain
facts; replay returns the original minimal action result without re-running a completed effect.

`published` reports recorded lifecycle, not a perpetual assertion that evidence remains valid.
The read exposes the exact publication identity. Post-publication monitoring, revocation cases,
continuity policy and transfer are later increments; this proof cannot be used as real operating
eligibility or substituted for C25-03-R/C25-05/C25-06 and the retained legal-adoption reviews.

## Storage and migration review

Three generated resources/tables separate stable institutional identity, the immutable initial
operator assignment, and the immutable publication proof. Tenant keys are non-null. Compound
foreign keys reject cross-tenant institutional, legal and assignment references. Unique
institution/tenant indexes permit only one initial assignment and one first publication.

The reviewed generated table migration creates the institutional destination columns and compound
index before dependent foreign keys. The generated guard migration installs each function/trigger
as a separate statement. Deferred consistency triggers require assignment/publication facts and
the institutional version to agree at commit, including the exact institution of the selected
assignment. Immediate guards prevent identity mutation, fact edits/deletion, publication bypass,
and returning a published institution to draft. A further evidence guard binds the structured
proof to the exact institution, assignment, legal version and applicable dates. This database
consistency check does not replace fresh verification by the trusted records adapter.

All institutional down paths refuse rollback while institution rows or associated audit/outbox/idempotency
facts remain. Empty rollback/reapply is development evidence only. These are additive tables with
no existing-data backfill or destructive production step. Selected-deployment lock budgets,
mixed-version operation and real records retention remain later qualification.

## Calendar integration handoff

Use the exact `institutional_unit_id`; `institutional_units` has a unique `(id, tenant_id)` key
for a reviewed compound foreign key. The current view includes `id`, `classification`,
`display_name`, `time_zone`, `status`, `lock_version`, `legal_entity_id`,
`operator_assignment_id`, `effective_from` and `publication_id`.

The institutional time zone governs the operator date. A calendar still owns its explicit time
zone and must not silently inherit changes. A calendar action checks its own capability and
module gates; the institutional read or legal operator link grants no calendar authority.
Calendar persistence remains owned by the separate calendar increment. The shared checkout now
contains that increment; its existing institution-table migration is retained, with the CF-1
guard migrations added after it. No duplicate institution-table migration is introduced.

## Verification

The focused `FoundationTest` suite passes 18 tests, covering the complete three-action
journey, exact reads/replay, private resource contracts, malformed input, denied/missing context,
cross-tenant non-disclosure and references, independent module gates, separate publication
authority, current legal versions, fresh evidence and impact checks, effective dates, concurrent
registration/assignment/publication, immutable facts, empty-proof rejection, dates across the international date line, and injected
post-outbox completion failure.

Verification results for the combined shared checkout:

| Command/check | Result |
| --- | --- |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_cf1_combined_test make check` | **Failed** at the existing web `npm audit --audit-level=high` gate; documentation, repository-tool tests, core checks and OpenAPI client drift checks passed before it |
| Core suite within that command | 215 tests pass, including the 18 CF-1 tests; format, strict lint, compilation, migration drift, dependency audit and type analysis pass |
| `CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run check` in `clients/web` | Pass: formatting, lint, types, 8 token tests, 27 unit tests and browser build |
| `CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run test:e2e` | 33 pass |
| `mise exec -- npm run test:e2e:ui1` | 6 pass |
| `mise exec -- npm run test:e2e:ui1-unavailable` | 1 pass |
| `make check-tooling` | Pass, run separately after the full command stopped |
| `git diff --check` | Pass |
| `mix ecto.create --quiet`, `mix ecto.migrate --quiet`, `mix ecto.rollback --step 4 --quiet`, then migrate again, with `MIX_ENV=test` and `CHIMWEMWE_TEST_DATABASE=chimwemwe_cf1_combined_migration` | Pass on the empty synthetic database, including the retained calendar and institution table migrations and both new guards |
| `mix ecto.rollback --step 1 --quiet` after inserting a synthetic draft in that migration-check database | Expected refusal; the row, both proof triggers and all four migration records remain intact |

The unchanged web tooling dependency chain reports nine high-severity audit entries rooted in
[`braces` GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
The advisory lists no patched release; npm's proposed forced downgrade is not a compatible fix.
No audit suppression or forced dependency downgrade was applied. Therefore the repository is
**not fully green**. Suites that the failed full command did not reach were run separately as
listed above; no remaining verification suite was intentionally skipped.

During integration, the shared browser-test database still held the isolated candidate's three
institutional migrations. Its institution and related audit/outbox tables were confirmed empty;
those candidate migrations were rolled back under the verification lock, and the retained
calendar/institutional sequence was applied. The connected and unavailable browser suites then
passed on that aligned database. No application table migration was duplicated or rewritten.
No real representative review, connected workflow, real identity provider or deployment result is
claimed by the tests.

## Related records

- [Classroom-first six-week plan](../plans/classroom-first-six-week-plan.md)
- [Educational contract acceptance](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)
- [Primary-operator contract acceptance](../adr/0035-c25-04-delegated-primary-operator-acceptance.md)
- [Threat model](../security/threat-model.md), especially TM-01, TM-02, TM-09–TM-15 and TM-17
- [Migration discipline](../development/migrations.md)
