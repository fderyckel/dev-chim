# CF-4A people and participation foundation

- Status: Implemented private synthetic core; functional verification passes, repository gate blocked by the existing web dependency advisory
- Date: 2026-10-04
- Owner: Product and platform engineering
- Authorization: François's “green light on next slice” after CF-1
- Contract: [ADR 0036](../adr/0036-minimal-people-participation-and-staff-account-association.md), Proposed; implementation authorization is not wider architectural or representative approval

## Delivered boundary

`Chimwemwe.People.Foundation` provides these private named operations:

| Operation | Outcome |
| --- | --- |
| `register_person/3` | Creates one tenant-owned person with a display name; no account is needed |
| `revise_person_name/3` | Corrects the current display name with expected version and the explicit `name_correction` reason |
| `record_student_participation/3` | Records student participation at one exact published institution |
| `record_staff_affiliation/3` | Records staff participation independently of student participation and permissions |
| `end_participation/3` | Prospectively ends an open participation interval without deleting it |
| `associate_staff_account/3` | Links effective staff participation to an existing tenant membership after a fresh exact-bound account/person verification |
| `revoke_staff_account_association/3` | Records one irreversible revocation, preserving the association and allowing a new separately verified link |
| `current_person/3`, `current_participation/3` | Reads one exact authorized record with minimal fields |
| `current_staff_account/3` | Resolves one membership only while the association is unrevoked, the actor still matches and staff participation is effective |

The released synthetic module is `people.core` v1.0.0, with an explicit dependency on
`institution.structure`. Capability keys use the `people.core.` prefix followed by
`persons.register`, `persons.revise_name`, `persons.read`, `participations.record_student`,
`participations.record_staff`, `participations.end`, `participations.read`, `accounts.associate_staff`,
`accounts.revoke` or `accounts.read`. They are task permissions assigned through tenant-defined
roles. No person, participation or account-link action writes memberships, grants or sessions.

Every write requires a causation ID and idempotency key. Existing-state changes require the exact
expected version; participation creation and account association also check the person version.
All context, authority, placement and module decisions are revalidated on the authoritative writer,
including exact replay. Unknown input fields and caller-supplied verification/authority flags fail
closed. Duplicate names are allowed; they never supply an identity match.

The startup-composed `People.Runtime` requires an explicit verifier module/source. No production
adapter or permissive default exists. The only supplied adapter is test support. The proof binds
the exact tenant, person/version, participation/version, membership/actor, protected evidence UUID
and writer timestamp under the synthetic human-account-match policy. A random reference, email,
provider profile or a prior successful verification cannot verify a new association.

## Persistence and event evidence

Three Ash resources generate the authoritative schema intent: `people_persons`,
`people_participations`, and `people_staff_account_associations`. Every row has a non-null tenant
key. Compound foreign keys preserve person, institution, participation and membership tenancy.
The association guard additionally checks that the selected participation belongs to the selected
person and is effective staff participation at a published institution.

Unique indexes prevent duplicate person/institution/participation-meaning records and competing
unrevoked associations for one person or membership. Date intervals are inclusive-start and
exclusive-end in the exact institution's time zone. Database guards reject identity changes,
record deletion, in-place association changes, reopened participation, reactivated links, and
unbound/empty proofs. Display names are explicitly current operational profile data; this slice
makes no name-history claim.

State, minimized audit, exact idempotency result and outbox fact commit atomically. People events
are Restricted and contain only the stable aggregate ID and version. Names, source references and
verification metadata do not enter the event payload or ordinary audit change summary.

The outbox schema previously admitted only Internal events. The reviewed additive constraint now
admits Restricted events for the three exact people aggregate types and prohibits their downgrade;
existing non-people events retain their Internal boundary. Existing dispatch and consumption remain
Internal-only. A real claim test confirms that even a matching subscription cannot claim a people
event. These facts remain a durable backlog until a Restricted-data consumer is qualified; this
slice does not claim automatic delivery or an end-to-end classroom workflow.

## Migration and recovery review

The generated table migration creates destination tables and tenant-qualified indexes before
referring foreign keys. Functions and triggers are separate DDL statements. The second generated
migration changes only the reviewed outbox classification constraint. There is no data backfill,
partitioning, additional service, or destructive up step. The ordinary application remains private;
selected-deployment lock budgets and mixed-version operation are not qualified by local tests.

Both down paths refuse retained people rows or corresponding durable action evidence. Empty
rollback/reapply succeeds. With a retained synthetic person, rolling back the classification
migration is refused; the row, all three people guards and the classification constraint remain.
Older temporal and legal/institution test cleanup lists were extended for the new referring tables,
without using an unrestricted cascading cleanup.

## Verification

The 21 focused people tests pass. They cover the no-account student, overlapping staff/student,
exact reads, all-action missing-context/permission denial, cross-tenant non-disclosure, independent
module gates, fresh verified association, human-account mismatch, stale proofs and versions,
identity-preserving name correction, duplicate names, duplicate participation, future/exclusive-end
staff dates, institution-local dates, UTC recording under a non-UTC database session, retained ending and revocation, concurrent registration and
competing links, Restricted event handling, direct-write guards, and failure after the outbox write.

| Command/check | Result |
| --- | --- |
| `mise exec -- env MIX_ENV=test CHIMWEMWE_TEST_DATABASE=chimwemwe_people_test mix test apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs` | 21 pass |
| `CHIMWEMWE_TEST_DATABASE=chimwemwe_people_test make check` | **Fails** at the existing web `npm audit --audit-level=high` gate; the preceding repository and core checks pass |
| Core suite within `make check` | 236 tests pass; compilation, formatting, strict lint, migration/OpenAPI drift, dependency audit, and type analysis pass |
| Repository-tool suite within `make check` | 4 tests pass; Python checks pass |
| `make check-tooling` | Pass, run separately after the full command stopped |
| `mix ecto.create --quiet`, migrate, `mix ecto.rollback --step 2 --quiet`, then migrate again, with `MIX_ENV=test` and `CHIMWEMWE_TEST_DATABASE=chimwemwe_people_migration` | Pass on an empty synthetic database |
| `mix ecto.rollback --step 1 --quiet` after inserting a synthetic person in that migration-check database | Expected retained-data refusal; guards and the classification constraint remain |
| `git diff --check` | Pass |

The browser suites were run separately under the shared verification lock after the full command
stopped. `CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run check` passes formatting, lint, types,
8 token tests, 27 unit tests and the build. `npm run test:e2e`, `npm run test:e2e:ui1` and
`npm run test:e2e:ui1-unavailable` pass 33, 6 and 1 browser tests respectively, each through
`mise exec` in `clients/web`. These are regression checks of the existing experience, not a people
screen or connected people workflow. No remaining suite was intentionally skipped.

The unchanged web tooling chain
reports nine high-severity audit entries rooted in
[`braces` GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
No audit suppression or forced downgrade was applied, and the repository is not fully green.

## Handoff to enrolment and classroom work

Use the exact tenant-qualified person and participation IDs; do not replace them with names,
accounts, a role label, or an institution hierarchy path. Students need no account. Staff
association supplies an identity match, never a teaching assignment or permission grant. The
current staff-account read deliberately refuses ended/future participation and revoked links;
later classroom actions must independently check current teaching assignment and capability.

Year enrolment, class/register membership, teaching assignment, placements and attendance are
separate records and actions. This increment contains no general directory, public API, browser
preparation screen, guardian relationship, employee/payroll data, person merge, retrospective
participation correction, re-entry lifecycle, real identity connection or real personal data.
The classroom plan's connected-experience, representative-review and records/privacy gates remain.

## Related records

- [ADR 0036](../adr/0036-minimal-people-participation-and-staff-account-association.md)
- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [Institutional foundation](institutional-foundation-evidence.md)
- [People and identity proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [Threat model](../security/threat-model.md)
