# Private staff-audience source checkpoint

- Successor: [People-owned write-fence checkpoint](people-source-write-fence-evidence.md),
  authorized under ADR 0053 on 2026-10-25. Its foundation comparisons pass within 20%; actual
  attendance admission failures leave complete qualification blocked. Historical results below
  precede that fence and remain unchanged.
- Status: **Not qualified — functional candidate implemented; classroom-impact acceptance failed**
- Updated: 2026-10-25
- Authority: François selected the binding approach and authorized its prerequisite, remaining
  source qualification and specialist review before publication. Coordination with the binding
  and directory/login chats is explicitly authorized; `make check` remains deferred.
- Contract: [ADR 0052](../adr/0052-private-staff-audience-source-capture.md), Accepted ADR 0045,
  ADR 0047 and the separately implemented [binding prerequisite](account-principal-binding-evidence.md)
- Engineering custodian: Coordinator for these local synthetic runs

## Implemented source boundary

`People.StaffAudience` owns a private writer transaction for a startup-selected exact institution,
the server purpose `communications.staff_audience` and dedicated source capability. It holds the
current acting opaque external session and its active exact origin, People/dependency lifecycle
fences, source parents/rows, bounded reachable authority graph and complete recipient actor fence.
Recipient accounts are ordinary MVCC reads after actor fencing; no account row lock is added then.
Participation locks precede institution locking to match the existing classroom writer; recapture
after the institution parent fence includes any insertion committed before that fence.

The source captures current exact-institution staff, deduplicates by person, and separately binds
the original verified association, participation, membership, account, actor and principal marker.
It requires no recipient session. The original intended denominator is preserved through current
eligibility changes; initially absent/pending/suspended admission cannot be backfilled. Current
notice permission is independent from the original active-account identity admission.

The private proof has redacted inspection and no browser route. Canonical source/draft/receipt
digests and the earlier of five writer-clock minutes or local midnight control recheck. A two-second
server transaction budget begins before locks and is shortened at acting-session/local-midnight
expiry. All locks remain through the owner callback. Dependency failures never imply publication
or a proven outcome for a hypothetical lost commit response. Durable preparation, approval,
publication, notice reads, receipts and public metrics remain unimplemented.

## Functional and race evidence

Forty source tests passed in the scoped run on `chimwemwe_staff_source_20261024_02`, seed 29,
after fixture corrections. A final additional negative check requires the acting session to retain
its exact live membership-to-actor binding even if the actor obtains a replacement membership;
that check is included in the final combined run below. They cover:

- original absent/pending/suspended accounts, later provisioning/activation and current suspension;
- same-principal credential replacement versus actor A → B → A;
- revocation, new verified association and replacement membership;
- independently ended still-linked staff, future-dated staff and staff-plus-student deduplication;
- student-only permitted accounts and same-tenant other-institution staff exclusions;
- current direct and nested/renamed-role notice permission, removal and frozen denominator;
- changed draft/body/title/version/receipt basis, expiry and closed input;
- missing/wrong actor/tenant/purpose/session/support/placement/institution denials;
- dedicated source capability and independent dependency-version/session logout denial;
- intended 0/1/25/26, 100/101 participation rows, 64/65 reachable roles and authority traversal overflow;
- observed PostgreSQL blocking for staff insertion/ending, association revocation, absent-account
  provisioning, account suspension/rebinding, assignment insertion, grant deletion, role inclusion/
  rename, acting-session logout, connection suspension and module deactivation;
- whole-callback rollback, actual two-second/short-session deadline rollback and deterministic
  institution-local date/DST/midnight/five-minute calculations.

These checks exercise source-stage outcomes, not durable publication preparation or notice access.
An earlier 11-client workload exceeded the fixture's existing six-slot admission limit and was
correctly rejected. That harness was corrected to six clients without changing runtime/source caps.
Other discarded harness issues included an invalid same-day end, fixture cleanup/name collisions,
unpinned backend observation and timestamp precision. Concurrent local-session additions initially
required their separately owned migration before the unchanged external-session fixture could run.

An initial combined regression passed 137/138 tests: the existing standalone account-truncate
assertion expected its row trigger but the new login foreign key rejected truncation earlier. The
binding owner made the narrow test correction, preserving exact malformed-lock assertions and
the isolated trigger proof. The next combined run passed **139 tests** on fresh database
`chimwemwe_staff_source_20261025_04`, seed 29. Final post-hardening results are recorded below.
No broader repository-green claim follows from these focused checks.

## Three-repeat mixed workload

Initial complete measured run: `chimwemwe_staff_source_20261024_02`, PostgreSQL 18.6 Homebrew,
Mac17,3, 10 CPUs, 24 GiB RAM. Existing fixture configuration: six pooled connections, per-tenant
admission six, placement admission twelve. The shared development machine had concurrent project
work; these values do not establish production capacity.

Each baseline has four concurrent classroom readers (30 exact real class reads each) and one
classroom writer (30 real class-creation/teacher-assignment pairs). Mixed adds one concurrent source
reader performing five complete 25-person captures, for five reader clients plus one writer total.
The harness warms both paths, uses a common start barrier, holds fixture/hardware/configuration
constant and records whole application-call milliseconds. No synthetic delay is added to improve
the baseline. Publication/correction/receipt burst and browser measurements are not run.

| Repeat | Classroom read p95 baseline → mixed ms | Read change | Writer p95 baseline → mixed ms | Write change | Source max ms | Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 5.247 → 9.093 | +73.30% | 10.461 → 17.852 | +70.65% | 10.385 | Fail |
| 2 | 4.338 → 9.584 | +120.93% | 8.476 → 18.533 | +118.65% | 9.720 | Fail |
| 3 | 4.367 → 9.174 | +110.08% | 8.632 → 18.046 | +109.06% | 9.958 | Fail |

All 360 mixed classroom reads, 90 writer pairs and 15 source captures completed with no operation
failure. Read p99 max was 12.427 ms; writer-pair p99 max was 20.295 ms. Absolute response targets
were met, but **every repeat exceeds the retained classroom p95 degradation limit of 20%**. This
is failed qualification. The first measurement collector exited successfully because recording
finished; its `accepted:false` values are the actual gate result. The retained explicit qualifier
now records all repeats and exits unsuccessfully if any acceptance result fails.

Reproduce under `core-test` on a fresh migrated synthetic database:

```sh
mise exec -- env MIX_ENV=test mix run tools/qualify_staff_audience_workload.exs
```

The qualifier is separate from ordinary functional tests; a passing test count cannot hide the
failed performance criterion. No limits, accepted target or source consistency rule was weakened.

The explicit confirming qualifier ran on fresh database
`chimwemwe_staff_source_workload_20261025_05`, ExUnit seed 244413, with the same hardware,
configuration and workload. All operations again completed. Its three repeats recorded:

| Repeat | Read p95 baseline → mixed ms | Read change | Writer p95 baseline → mixed ms | Write change | Source max ms |
| --- | --- | --- | --- | --- | --- |
| 1 | 4.906 → 8.591 | +75.11% | 9.291 → 16.906 | +81.96% | 9.156 |
| 2 | 4.156 → 8.480 | +104.04% | 8.109 → 16.844 | +107.72% | 9.387 |
| 3 | 4.119 → 8.790 | +113.40% | 8.062 → 16.778 | +108.11% | 9.313 |

This command exited **2**, with the explicit assertion that the retained 20% target failed.
Thus both independent three-repeat measurements fail; this is not a passing performance test.

## Stop disposition and follow-up

Publication remains unavailable. The candidate is retained privately as functional evidence and
is not a qualified source API for publication. The
[bounded contention follow-up](../plans/communications-source-lock-contention-proposal.md)
recommends measuring lock waits and, only with separate authorization, qualifying a People-owned
write-boundary fence before removing classroom-conflicting reader locks. This is a proposal, not
an implemented remedy or a promise of performance. No source writer or trigger was changed here.

Real records, representative testimony, independent security/privacy assurance, connected use,
production recovery and release retain all existing gates. `make check`, browser/web checks and
publication workload were not run in this increment.

## Final focused verification

The final post-hardening run on fresh `chimwemwe_staff_source_20261025_06` passed **140 tests**,
including **41 source tests**, seed 29. The added final denial requires the acting session's exact
locked membership to remain bound to the caller; obtaining a newly capable replacement membership
cannot revive that old session. All source changes are in the private source files and test fixture;
the binding and directory/login chats retain ownership of their prerequisite/runtime changes.

Exact final functional command, under the repository `core-test` verification lock:

```sh
CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_source_20261025_06
export CHIMWEMWE_TEST_DATABASE
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/people/staff_audience_test.exs \
  apps/chimwemwe_core/test/chimwemwe/people/staff_audience_race_test.exs \
  apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs \
  apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs \
  apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs \
  apps/chimwemwe_core/test/chimwemwe/classroom/foundation_test.exs \
  apps/chimwemwe_core/test/chimwemwe/classroom/attendance_test.exs --seed 29
```

The expected transaction-timeout disconnection is an executed rollback negative control, not a
successful operation. Generated migration drift and strict Credo passed on the shared checkout
before the final narrow session-membership guard. Targeted formatting and `git diff --check`
passed after it, and repository documentation validation passed. Exact static commands:

```sh
cd apps/chimwemwe_core
mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
mise exec -- mix credo --strict
cd ../..
mise exec -- mix dialyzer
mise exec -- uv run python tools/check_docs.py
git diff --check
```

Dialyzer initially failed with two unreachable fallback clauses in the separately owned
`identity/public_session_adapter.ex` and `identity/staff_directory.ex`. The directory/login owner
subsequently reported repairing those clauses and began its separately user-authorized integration
check. That result is not assumed here. This increment did not run `make check`, browser/web checks,
the actual attendance workload or publication/correction/receipt workload. The latter workloads
remain required before their corresponding qualification claims; foundation read/write timing
does not establish daily attendance impact. No current repository-green claim is made.

Final ten-file source/test/qualifier candidate SHA-256:
`b88c5808751962ffc7224f9d9acc4a5576991c0ddcb1fabb54978e6cd86d0e0c`.
Computed from sorted repository-relative paths, NUL, file bytes and NUL for `staff_audience.ex`,
`people/error.ex`, the four `people/staff_audience/*.ex` helpers, `staff_audience_fixture.ex`, the
two `staff_audience*_test.exs` files and `tools/qualify_staff_audience_workload.exs`.
Isolated databases are retained; no commit, push, deployment or decommission was performed.

## Final delegated specialist review

All four specialists reviewed the source, actual reported test/measurement evidence, stop
disposition and bounded follow-up. They also confirmed the final session-membership guard and
140-test/41-source result. They did not independently reproduce runtime checks. Initial review
conditions led to the explicit pending/suspended activation, independent staff-ending,
association/membership replacement, inherited-role and student/other-institution denial cases.

| Profile | Final disposition and evidence | Coordinator disposition |
| --- | --- | --- |
| Primary education | Approve retaining private functional evidence and stopping qualification/publication. Initial semantic conditions are addressed; failed classroom impact cannot be waived by low absolute times. The measured follow-up is a reasonable recommendation only. | Accept. Preserve original denominator/admission, record final checks and require authorization/ADR before writer changes. |
| Secondary education | Approve-stop; challenge any claim of complete source qualification. All semantic conditions are addressed, including offline recipients and replacement acting-membership denial. Foundation timings do not establish actual attendance impact. | Accept. Keep the performance condition unresolved, include the real attendance journey in diagnosis, retain all caps/deadlines and repeat review before publication. |
| School/college admissions | Approve not-qualified checkpoint and publication stop. Student-only and other-institution exclusions, pending/suspended non-backfill, relink/replacement and current acting-membership checks are evidenced. No remaining material admissions challenge to this disposition. | Accept. No applicant/family/guardian/college authority is inferred; the follow-up remains a separate decision. |
| UI | Approve-stop. Source counts/private proof remain distinct from publication/receipt metrics; no screen or usability claim is made. Passing functional counts cannot qualify the failed source. | Accept. Preserve visible changed/expired/blocked and uncertain-publication wording for any future UI; make no unobserved integration claim. |

No specialist approves publication or the new write-boundary implementation. The unresolved
performance condition returns to François with the concrete follow-up linked above. AI review
does not replace representative evidence or independent safeguarding/security/privacy assurance.
Advisor preflight returned `parent_runtime_unavailable` before implementation and at completion;
no isolated Advisor consultation or approval is claimed.

## Subsequent integration and ownership handoff — 25 October 2026

The separate directory/login integration run exposed two test-isolation assumptions beyond the
fresh focused run above: other suites can retain an active global account for the shared fictional
acting actor, and these source suites left their invitation/session/link chain for later suites.
The runtime audience result was correct; the baseline fixture's account-absence assumption was not.

The source fixture now revokes only the new acting-staff association it just created, using the
existing named People action. This makes the intended baseline explicitly unlinked regardless of
any retained global account; no retained account is deleted, suspended, reissued or changed.
Both source suites now invoke shared fixture cleanup through a fresh cleanup runtime in their
teardown, so their invitation/session/link chain cannot leak into later role cleanup.
Formatting and whitespace checks passed. The 140-test result and candidate hash above **precede
these final fixture-only repairs**; their runtime verification awaits the coordinated integration
run. They change no source authorization, recipient rule, lock, cap or performance target.

François subsequently authorized the scoped People-owned write-boundary follow-up in the
coordinated education-review chat: ADR, implementation/tests, unchanged 20% classroom-impact
trials and four specialist reviews, with publication and `make check` still excluded there.
That chat now owns the source/guard/test/qualifier changes and checkpoint supersession; the
directory/login chat owns its separately authorized integration gate. No competing source edits
or core verification runs are started here. The source remains not qualified until the successor
checkpoint provides its actual evidence and review; this handoff grants no publication authority.

## Integration deadline correction — 25 October 2026

The directory/login owner's fresh integration run first passed all 434 core tests, including the
fixture repairs above. A repeated full run (seed `187949`) then exposed a real deadline gap: the
callback wrote a marker, slept for 2.1 seconds and returned success. The PostgreSQL timer had not
interrupted it, and the source checked only the longer session/local-midnight boundary after the
callback. The repeated run therefore passed 433 of 434 tests; the earlier full pass did not close
this gap.

With the successor source owner holding its runtime changes, this chat retained only the clock,
source callback wrapper and existing deadline-test cases for a narrow correction. The server
timeout remains enabled. An independent monotonic deadline now includes the transaction's age
before source preparation, preserves a shorter pre-existing timeout, and refuses over-budget
work before/after the callback and before returning to the owner. This is an enforced pre-commit
check, not a claim about commit latency or recovery from an unknown commit outcome.

Three added negative controls prove whole-transaction rollback when server interruption is
deliberately disabled in the trusted test callback, when an existing timeout is shorter than two
seconds, and when earlier work has already consumed part of the transaction budget. A fresh
capture after the first rollback also proves lock release. No threshold or recipient rule changed.

On fresh `chimwemwe_staff_deadline_20261025_01`, under `core-test` and seed `187949`:

- The same seven-file regression command listed above passed **143 tests**.
- Two additional complete source-race-suite repetitions each passed **21 tests**.
- Compilation with warnings as errors, targeted formatting, strict Credo, documentation validation
  and `git diff --check` passed.

Logs: `/tmp/chimwemwe-staff-deadline-20261025-01.log` and
`/tmp/chimwemwe-staff-deadline-static-20261025-01.log`. PostgreSQL timeout disconnections in these
runs are expected negative-control outcomes. This chat did not run `make check`, browser checks
or new performance trials for the correction. The directory/login owner retains the separately
authorized full integration check; the education-review owner retains ADR-0053, the People/source
lock changes, unchanged 20% classroom-impact qualification and subsequent specialist review.
The corrected files are released to those coordinated owners. Publication remains stopped.

## Completed shared integration — 25 October 2026

After the deadline correction, the directory/login owner ran
`CHIMWEMWE_TEST_DATABASE=chimwemwe_staff_full_20261025_04 make check` against the held shared
checkpoint and reported exit 0. The retained log was inspected here: **437 core tests**, **54 web
unit tests** and **91 browser tests** passed, alongside the required formatting, contracts,
migration drift, strict Credo, Dialyzer, dependency audits, build and repository tooling checks.
No required `make check` step was skipped. This includes the final fixture cleanup/unlink repairs
and all three new deadline controls. Full boundary details are recorded in the coordinated
[directory/login evidence](staff-directory-connected-login-evidence.md); the retained log is
`/tmp/chimwemwe-staff-full-20261025-04.log`.

This verifies the shared checkpoint before the successor People-owned fence changes. It does not
reverse the failed classroom-impact qualification or authorize publication. The integration owner
released the held runtime window to the education-review owner, who retains the authorized
ADR-0053 implementation, unchanged 20% impact trials and subsequent specialist review. No new
runtime changes or competing verification run were started here.

## People-owned fence successor — 25 October 2026

The education-review owner implemented ADR 0053's actual-write fence and removed only redundant
People reader locks. Controlled probes show teacher assignment and actual attendance preparation
now complete while the source remains held. Three unchanged foundation workload repeats pass
within the original 20% criterion. Three additional actual-attendance comparisons reject work
under the existing admission limit, including baseline; they are invalid latency comparisons,
not passing qualification. The [successor evidence](people-source-write-fence-evidence.md) records
the complete failures, migration trials, regression and specialist review. Publication and this
increment's `make check` remain deferred. The earlier full integration is pre-fence evidence only.

## Combined post-fence integration — 25 October 2026

The later repository closeout ran
`CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_again_20261025 make check` after the People fence and its
rollback-race correction were stable. Exit 0 covered **452 core tests**, **54 web unit tests** and
**91 browser tests**, all formatting/static/contract/migration/build/tooling checks, and zero
findings from both npm dependency audits. No required step was skipped.

This current integration result supersedes only the earlier repository-check deferral. It does not
supersede the failed source qualification: the actual-attendance comparison still contains rejected
operations in baseline and mixed runs, so publication remains stopped.
