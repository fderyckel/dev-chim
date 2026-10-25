# People-owned source write-fence checkpoint

- Status: **Fence implemented and tested; complete source checkpoint not qualified**
- Date: 2026-10-25
- Governing record: [ADR 0053](../adr/0053-people-owned-source-write-fence.md)
- Authority: François authorized the scoped fence, implementation, tests, unchanged 20%
  classroom-impact trials and four-agent review; publication and `make check` remain deferred
- Prior evidence: [failed source checkpoint](staff-audience-source-evidence.md)

## Scope and current state

This increment qualifies the People write boundary and only its redundant source row locks.
Independent authority, session, account, module and institutional stability remain protected.
All caps, original admission identities, temporal limits and failure semantics remain binding.
No publication, new module, public route, connected or real-data use is added.

The prior source results and fingerprint predate this increment and subsequent fixture-only
integration repairs. They remain historical evidence. The directory/login chat's separately
authorized full integration passed 437 core, 54 web unit and 91 browser tests before these fence
changes; that is not verification of this patch. The source owner's monotonic deadline correction
was included before this increment. Isolated Advisor preflight is unavailable
(`parent_runtime_unavailable`); no isolated assurance is claimed.

## Implemented boundary

The People resource declares a private `people_source_lock(uuid)` and three separate
`people_00_source_fence` row triggers, ordered before the existing semantic/classroom guards.
They take the exact existing tenant `people.core` lifecycle transaction advisory key on ordinary
INSERT/UPDATE/DELETE. UPDATE locks sorted distinct old/new tenants; existing guards still reject
tenant movement and deletion. Missing tenant fails closed. No authorization, ID, source version,
retained data, index, foreign key, audit/outbox fact or writer isolation policy changed.

The source explicitly calls the new primitive after its existing module gates, so an old schema
cannot silently supply unfenced results. People records are plain MVCC reads under that fence;
the institution is captured once with a compatible `FOR SHARE` lock. All independent account,
authority, module, origin and acting-session locks remain. No People row lock follows the owner
fence. TRUNCATE remains an operator action serialized by retained relation locks; the tests
probe it only inside transactions that always roll back.

## Controlled before/after diagnosis

`tools/diagnose_people_source_locks.exs` holds a full 25-person source check and independently
executes real teacher assignment and `Attendance.prepare`. Before the patch, both callers were
observed in PostgreSQL waiting on the source's participation locks. Afterward, both completed
while the source callback was still held. These are message/transaction barriers and observed
blockers, not timing inferred from a sleep. The diagnostic uses a second explicitly created
opaque external session for attendance and restores only the fixture's verified staff association.

Executed with `PEOPLE_FENCE_PHASE=before` on `chimwemwe_people_fence_before_20261025_01` and
`PEOPLE_FENCE_PHASE=after` on `chimwemwe_people_fence_20261025_01`: **one test passed each**.

Ten complete captures in each phase reported aggregate query times:

| Category | Before queries / total ms | After queries / total ms |
| --- | --- | --- |
| People | 40 / 3.442 | 40 / 2.822 |
| Authority and modules | 480 / 40.180 | 480 / 41.332 |
| Institution | 10 / 0.403 | 10 / 0.394 |
| Accounts | 10 / 0.717 | 10 / 0.847 |
| Session and origin | 30 / 2.862 | 30 / 2.633 |
| Clock and other | 180 / 7.436 | 180 / 6.684 |

Whole-call capture means were 9.0943 ms before and 8.7252 ms after. This identifies the removed
blocking path; it does not attribute every elapsed millisecond or qualify production capacity.
Only operation counts, categories and timings are retained, never SQL parameters, source rows,
identities, proofs, tokens or credentials.

## Write-boundary and migration evidence

`source_write_fence_test.exs` passed **15 tests**, seed 29, on
`chimwemwe_people_fence_20261025_01`. Positive/negative controls cover:

- Named source captures against ordinary SQL person insert/revision, staff insert/ending and
  association insert/revocation; PostgreSQL reports advisory blocking until source release.
- All three retained-history DELETE refusals after fence acquisition; existing guards stay enabled.
- Catalog ordering ahead of every existing guard; missing tenant denial; invalid tenant movement
  takes both old/new keys before the unchanged semantic refusal.
- Unrelated-tenant progress while another tenant source is held.
- Rollback-only TRUNCATE CASCADE waits for retained source relation locks and preserves row counts.
- Deliberate reverse row/advisory ordering: one PostgreSQL deadlock victim, no partial owner marker,
  and a typed whole-operation dependency failure if the source owner is the victim.

The first combined run passed 156/158: two new harness assertions used the wrong Postgrex
`regclass` parameter encoding and an invalid capability key containing UUID hyphens. A targeted
rerun passed 14/15 because its catalog assertion omitted the pre-existing participation classroom
guard. These harness issues were corrected without changing the runtime contract; the next
targeted run passed all 15. Final broad regression is recorded below.

The generated migration `20261025091633_people_source_write_fence.exs` and resource snapshot
`people_persons/20261025091634.json` add only functions/triggers. Up/down use a two-second DDL
lock timeout. No retained sources are rewritten. Executed
`tools/qualify_people_source_fence_migration.exs` on three fresh databases with prefix
`chimwemwe_people_fence_migration_20261025_01_`:

| Trial suffix | Executed result |
| --- | --- |
| `empty` | Up, empty down and reapply passed; existing semantic guards remain |
| `retained` | Old-schema reader fails closed; retained row digests unchanged by up; capture and old named/SQL writes work; retained down refuses before removing protection |
| `contended` | An old-shape writer delays trigger installation; DDL times out atomically, no partial functions/triggers/version remain; release and forward reapply preserve retained rows |

All three trials exited successfully; disposable databases are retained. Reusing the generated
migration module for up/down/reapply prints expected module-redefinition warnings.

A final rollback review found a check/use race in the first down candidate: a concurrent insert
could commit between the empty-data check and trigger removal. Down now takes all three relation
locks before checking emptiness, under the same two-second DDL budget. The resource, generated
migration and snapshot agree. All three modes were repeated on fresh databases with prefix
`chimwemwe_people_fence_migration_20261025_02_`, plus a fourth `rollback_race` mode. **All four
passed**. The new mode observes bounded rollback refusal while an insertion is held, preservation
of the guards/version, then retained-data refusal after the writer commits. Log:
`/tmp/chimwemwe-people-fence-migration-20261025-02.log`. Runtime up/source semantics are unchanged.

## Unchanged foundation workload: three passes

The original `tools/qualify_staff_audience_workload.exs` is unchanged. On fresh
`chimwemwe_people_fence_workload_20261025_01`, seed 299080, it used the same six-connection pool,
tenant admission six, placement admission twelve, four readers × 30 exact class reads, one writer
× 30 real class-create/teacher-assignment pairs, and five complete 25-person source captures in
the mixed run. Common start barrier, warmup, baseline then mixed; no delays, retries, capacity
increase, source truncation or limit change. All three repeats passed and the qualifier exited 0.

| Repeat | Read p95 baseline → mixed ms | Change | Writer p95 baseline → mixed ms | Change | Source max ms |
| --- | --- | --- | --- | --- | --- |
| 1 | 4.710 → 4.699 | −0.23% | 9.179 → 8.554 | −6.81% | 10.101 |
| 2 | 4.437 → 4.329 | −2.43% | 8.450 → 8.395 | −0.65% | 9.990 |
| 3 | 4.212 → 4.561 | +8.29% | 8.168 → 8.858 | +8.45% | 9.702 |

All 360 mixed reads, 90 writer pairs and 15 captures succeeded. Mixed read p99 max was 5.203 ms;
writer p99 max 8.940 ms. Each read/write p95 change is at most the retained **20%** limit, and
the original absolute response/deadline targets pass. These local measurements do not establish
selected-deployment capacity or repair a failed actual-attendance comparison.

## Actual attendance workload: qualification blocked

The additional `tools/qualify_people_fence_attendance.exs` exercises `Attendance.prepare` and
real prepare-plus-correction writes. It keeps four readers × 30 calls, one writer × 30 correction
attempts, five full source captures, and the same pool/admission configuration. Each repeat uses
an identical fresh fixture, seven classes with distinct enrolled students and independently valid
teaching assignments. One reader class and six writer classes keep every submission at or below
the unchanged ten-correction cap; only seven classes/people are exposed, below 12/720. Warmup
uses the reader class. No runtime cap is reset or relaxed within a comparison.

Two setup attempts are not passing performance evidence: the first tried to place one student
in several simultaneous homerooms and was correctly refused; the corrected fixture then stopped
at the first denied concurrent operation. The collector was changed to retain **all attempted
operations and error counts**, not retry, suppress or count errors as successful work.

On fresh `chimwemwe_people_fence_attendance_20261025_03`, seed 761094, with raw aggregate log
`/tmp/chimwemwe-people-fence-attendance-20261025-03.log`, three complete
comparisons recorded:

| Repeat | Baseline read / write failures (of 120 / 30) | Mixed read / write failures (of 120 / 30) | Baseline / mixed tenant admission rejections | Mixed source successes |
| --- | --- | --- | --- | --- |
| 1 | 35 / 30 | 83 / 23 | 65 / 106 | 5 / 5 |
| 2 | 34 / 30 | 88 / 12 | 64 / 100 | 5 / 5 |
| 3 | 39 / 30 | 71 / 30 | 69 / 101 | 5 / 5 |

No placement rejection occurred. All 15 source captures completed (maximum 9.577 ms). Attendance
failures were `rate_limited` or `forbidden`; all three records have `impact_comparison_valid:false`
and `accepted:false`. Timings in the raw log include rejected attempts and **cannot support a
successful-call 20% comparison**. The explicit qualifier exited 2. A passing foundation workload
cannot hide this separate failure, and none of these samples is dropped or reclassified as green.

Code inspection identifies a separate admission composition: the outer classroom writer acquires
a permit, then `SessionFoundation.validate` calls its own writer and requests another permit
before the existing session/lifecycle serialization. Admission counters confirm rejections at
the unchanged six-slot limit, including baseline without source captures. Some nested denials
are mapped to `forbidden` by attendance's current validation branch. The fence did not add this
nesting. Removing independent session/authority protection or increasing limits would exceed
this increment. This is an evidence-backed diagnosis, not an implemented correction or proof
that a permit change alone will satisfy the impact limit.

## Disposition and next bounded decision

Retain the People fence and its correctness/migration evidence privately. The original measured
row-lock contention is removed and the unchanged foundation workload now passes. **The complete
source checkpoint remains not qualified** because the required actual-attendance comparisons
cannot complete successfully under the current admission contract. Publication stays stopped.

Recommended next decision: separately scope an ADR and a same-writer nested-admission contract
for existing session validation. It must reuse a permit only for the same current validated
tenant, placement, runtime, process and writer transaction; preserve route revalidation, capacity
accounting, session checks/refresh and whole-transaction rollback; refuse mismatches and spawned
work. This is a proposal for review, not authorization or implementation. Keep the six-slot limit,
source caps, all independent locks and the 20% requirement; rerun all three comparisons afterward.

No publication, browser/UI, connected records, representative sessions, independent security/
privacy review or production/restore qualification was introduced. `make check` was explicitly
not run for this increment. Full repository readiness is not claimed.

## Final verification and delegated review

On fresh `chimwemwe_people_fence_regression_20261025_01`, under `core-test`, compilation with
warnings as errors, database creation/migration and `mix test --seed 29` passed: **452 tests**.
This includes all existing core tests, the 44 source checks and the 15 new write-fence controls.
Log: `/tmp/chimwemwe-people-fence-regression-20261025-01.log`. This is a core regression result,
not, by itself, `make check` or full repository green.

The final 16-file runtime/test/tooling candidate matches the retained manifest at
`/tmp/chimwemwe-people-fence-candidate-20261025-02.sha256`; its manifest SHA-256 is
`fcb592bb3bd4884e333c58d47c01993fb4d46c994d92f700e965ae5024783b8c`.

All four delegated specialists completed read-only review of the implemented boundary and the
reported evidence:

| Profile | Disposition | Retained condition |
| --- | --- | --- |
| Primary education | Approve the private fence and explicit stop | Successful attendance preparation/correction remains required; a capacity rejection is not an authority denial |
| Secondary education | Approve the private fence and explicit stop | Any same-writer admission reuse is a separate decision and must preserve session, route, accounting and rollback guarantees |
| Admissions | Approve the limited synchronization change | Applicant, guardian, referee and external-college relationships gain no identity, audience or delivery authority |
| UI and interaction | Approve with the historical wording correction now applied | Keep status concise: the People fence is tested, attendance impact is unqualified and publication is unavailable |

The reviews do not authorize the proposed nested-admission change, complete source qualification,
publication, connected use, representative evidence or release. Their static-check condition is
closed by the combined verification below; their attendance condition remains open.

## Combined repository closeout — 25 October 2026

After all fence changes and evidence corrections were stable, the coordinator ran
`CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_again_20261025 make check`. It passed with exit 0:

- documentation validation, repository tooling and all four fictional demo-pack checks passed;
- formatting, warnings-as-errors compilation, all three OpenAPI drift checks, migration drift,
  strict Credo, core dependency audit and Dialyzer passed;
- **452 core tests** passed;
- both npm audits reported zero vulnerabilities; formatting, lint, style contracts, TypeScript,
  generated clients and the production build passed;
- **54 web unit tests** and **91 browser tests** passed; and
- ShellCheck, verification-routing dry runs and final whitespace checks passed.

No required `make check` step was skipped. This verifies the combined checkout, including the
People fence. It does not convert rejected attendance attempts into valid performance samples or
change the disposition above: the complete audience source remains not qualified and publication
remains stopped.
