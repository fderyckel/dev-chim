# Same-writer admission and attendance-impact evidence

- Status: **Bounded local staff-source prerequisite qualified; publication unimplemented**
- Date: 2026-10-25
- Governing record: [ADR 0054](../adr/0054-same-writer-nested-admission.md)
- Authority: François asked to address the invalid attendance-impact qualification
- Prior checkpoint: [People-owned write fence](people-source-write-fence-evidence.md)

The bounded correction removes duplicate admission only for synchronous work already inside
the exact current writer transaction. Limits, source caps, session/authority checks and the 20%
impact criterion remain unchanged. No publication action is implemented by this prerequisite.

The prior checkpoint's rejected attendance attempts remain failed evidence. Publication is not
implemented and remains blocked pending completed impact qualification and specialist review.

Advisor preflight returned `parent_runtime_unavailable`; no isolated Advisor assurance is claimed.

## Correction and initial functional evidence

Persistence records a private synchronous writer scope and revalidates the current route before
exact context/owner/runtime/repository matching and an active-transaction check. Only the outer
writer acquires/releases admission. No DatabaseAdmission counter, capacity, session validation,
source lock or recipient rule changed. Scope and dynamic repository are restored on all exits.

On fresh `chimwemwe_nested_admission_20261025_01`, compilation with warnings as errors and the
platform-persistence/attendance suites passed **40 tests**, seed 29. Ten new tests cover one-slot
reuse on the same backend/transaction; changed actor/tenant/placement/purpose/correlation/locale,
runtime/repository, stale route, no transaction and spawned work; permit restoration after
exception/exit/rollback; one-permit real attendance; and nested session-refresh rollback. The
existing actual late correction failure now also checks unchanged session version/idle expiry
before its successful retry. The final 40-test repeat below also verifies successful refresh.
Log: `/tmp/chimwemwe-nested-admission-20261025-01.log`.

The one-slot attendance test proves that **outer** tenant saturation remains `rate_limited`.
This patch does not redesign Attendance's pre-existing blanket mapping of nested session
validation failures to `forbidden`; an ambiguous dependency failure is not evidence of a teacher
losing permission. Qualification must contain no such rejected operations.

## First unchanged impact trials: valid attendance calls, failed timing gates

Both qualifiers were run unchanged, with pool/tenant admission six, placement admission twelve,
four readers × 30, one writer × 30, and five full 25-person source captures per mixed run.
The foundation writer performs real create/assignment pairs; the attendance writer performs
prepare-plus-correction across its original six classes, retaining correction/exposure limits.

| Workload | Repeat | Read p95 baseline → mixed ms | Change | Write p95 baseline → mixed ms | Change | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Foundation | 1 | 8.356 → 8.303 | −0.63% | 14.638 → 14.232 | −2.77% | Pass |
| Foundation | 2 | 6.841 → 7.529 | +10.06% | 12.546 → 12.993 | +3.56% | Pass |
| Foundation | 3 | 6.433 → 8.959 | +39.27% | 11.379 → 15.617 | +37.24% | Fail |
| Actual attendance | 1 | 8.776 → 9.372 | +6.79% | 17.112 → 18.271 | +6.77% | Pass |
| Actual attendance | 2 | 8.802 → 9.485 | +7.76% | 16.874 → 17.715 | +4.98% | Pass |
| Actual attendance | 3 | 11.672 → 13.680 | +17.20% | 20.376 → 24.921 | +22.31% | Fail |

Fresh databases: `chimwemwe_nested_foundation_20261025_01` and
`chimwemwe_nested_attendance_20261025_01`. Logs: `/tmp/chimwemwe-nested-impact-20261025-01.log`
and `/tmp/chimwemwe-nested-attendance-20261025-01.log`. Both explicit qualifiers exited 2.
All attendance attempts succeeded: each baseline admitted 180 outer calls and each mixed run
185, with zero tenant/placement rejections. All 15 source captures succeeded. The samples are
valid comparisons but do not pass the unchanged 20% criterion. They are retained as failures,
not omitted or reclassified because absolute latency is low or other activity might explain it.

Before additional measurements, the coordinator fixed a reproducibility plan: hold the shared
integration, web and core-test lanes; run both unchanged qualifiers in two further independent
fresh-database batches; retain every result; require all six comparisons for each workload to
pass rather than selecting favorable repeats. Any new failure leaves qualification open and
requires further diagnosis. No delays/retries/cap changes are added inside either workload.

## Controlled repeats and neutral diagnosis

The predeclared two-batch plan did not pass. Foundation batch 02 passed its three repeats;
attendance batch 02 failed repeat 2 at +31.30% read p95. Foundation batch 03 failed repeats 1/2
at +136.36%/+133.24% read and +85.93%/+58.78% write. Attendance batch 03 passed all three.
All attendance attempts in these batches still succeeded with zero capacity rejections. These
results do not satisfy the all-six rule. The four full aggregate logs are retained at
`/tmp/chimwemwe-nested-{foundation,attendance}-20261025-{02,03}.log`; the outer execution record
is `/tmp/chimwemwe-nested-controlled-20261025.log`, exit 2.

A separate **diagnostic, not qualification**, compared baseline against baseline with no source
captures in either measured phase. Temporary copies of the unchanged qualifiers changed only
the second workload's source flag to false, expected source count to zero, and output label to
`NEUTRAL_*_CONTROL`. Foundation's three comparisons stayed within 20%. Attendance repeat 3
jumped from 20.094 to 304.140 ms read p95 (+1413.59%) and 37.752 to 498.993 ms write p95
(+1221.77%) with no measured source work and zero rejected attempts. Logs:
`/tmp/chimwemwe-neutral-{foundation,attendance}-20261025-01.log`. This falsifies attribution of
all observed timing swings to source contention. The shared PostgreSQL instance also reported an
active checkpointer when inspected; this is a possible confound, not proof of the cause of each
individual spike. None of the prior source-enabled failures is relabelled as a pass.

The successor measurement environment is a private local PostgreSQL 18.6 instance with no TCP
listener and no unrelated databases/workloads. Its settings retain `fsync=on`,
`synchronous_commit=on`, `max_connections=100`, `shared_buffers=128MB`, default five-minute
checkpoint interval and 1GB WAL limit. The six-connection application pool, six/twelve admission
limits and every workload/capture/receipt bound remain unchanged. No scheduler or CPU-priority
tuning is applied. Both original qualifiers will run without source edits in two independent
fresh-database batches, under shared integration/web/core locks. Require all six comparisons per
workload to pass, all attempts to succeed, and checkpointer counters to remain unchanged across
the measured scripts; otherwise qualification remains open. A private-instance `CHECKPOINT` and
one-second statistics barrier run after migration and before each complete qualifier script,
outside every measured workload. Shared-server configuration and checkpoint scheduling are not
changed. This isolates the database workload
and records the environment; it does not establish selected-deployment performance.
The machine and filesystem are still shared; a private database is not complete hardware
isolation. These short comparisons do not qualify checkpoint-period or sustained-load behavior.

All four delegated profiles reviewed this predeclared method and approved it with conditions:
preserve the original workload/durability/limits, retain every result, require all six comparisons
per workload and zero failed attempts, disclose setup/counters and limit any pass to this recorded
local environment. This is method review only; final measured results and integration review
remain pending.

The [aggregate result artifact](same-writer-admission-impact-results.json) retains all recorded
source-enabled and neutral comparisons, explicitly separating diagnostics from qualification.
It contains only operation counts, errors, timing summaries and environment metadata. The original
qualifiers remain byte-identical: foundation SHA-256
`cdf68adbffc35db205f6071923bee85a876fda652d77d1a7bb5a8725f67c56ca`;
actual attendance `59a0a509a5260165b3db26a9b04bc11a32ce4da7db557529ebc6f463bafd1c6b`.

## Initial dependency baseline: all twelve isolated comparisons pass

The predeclared private-instance run exited **0**:
`/tmp/chimwemwe-isolated-impact-20261025.log`. Both original qualifiers passed their three
comparisons in **each** of two fresh batches. No failed repeat was omitted or retried. Exact
pre/post checkpoint counters, admission counters, database references and every aggregate result
are retained in the linked JSON artifact above.

| Workload | Batch/repeat | Read p95 baseline → mixed ms | Change | Write p95 baseline → mixed ms | Change |
| --- | --- | --- | --- | --- | --- |
| Foundation | 01/1 | 9.091 → 8.508 | −6.41% | 16.710 → 16.949 | +1.43% |
| Foundation | 01/2 | 6.826 → 7.163 | +4.94% | 13.079 → 14.444 | +10.44% |
| Foundation | 01/3 | 7.012 → 7.070 | +0.83% | 13.821 → 13.890 | +0.50% |
| Foundation | 02/1 | 8.606 → 7.901 | −8.19% | 15.050 → 14.032 | −6.76% |
| Foundation | 02/2 | 6.907 → 7.276 | +5.34% | 13.610 → 13.976 | +2.69% |
| Foundation | 02/3 | 6.587 → 7.013 | +6.47% | 12.878 → 13.736 | +6.66% |
| Actual attendance | 01/1 | 15.184 → 15.676 | +3.24% | 28.832 → 29.982 | +3.99% |
| Actual attendance | 01/2 | 15.103 → 15.672 | +3.77% | 28.944 → 29.438 | +1.71% |
| Actual attendance | 01/3 | 15.054 → 15.686 | +4.20% | 28.903 → 29.771 | +3.00% |
| Actual attendance | 02/1 | 16.194 → 15.798 | −2.45% | 29.888 → 29.749 | −0.47% |
| Actual attendance | 02/2 | 17.950 → 15.981 | −10.97% | 33.094 → 30.790 | −6.96% |
| Actual attendance | 02/3 | 15.592 → 15.924 | +2.13% | 29.764 → 30.217 | +1.52% |

Every baseline and mixed attendance attempt succeeded. Each comparison admitted exactly 180
baseline and 185 mixed outer calls with zero tenant/placement rejections. Each workload completed
720 mixed reads, 180 mixed writer operations and 30 full source captures across its six comparisons,
plus the corresponding complete baseline operations. Every original absolute p95/p99 target and
the source's two-second bound passed; the largest source call was 17.740 ms. Neither qualifier,
workload, pool, admission limit, durability setting, cap nor 20% criterion was weakened.

The current final functional repeat on fresh `chimwemwe_nested_admission_20261025_02` passed
**40 tests**, seed 29, including the successful-refresh and actual-correction rollback assertions.
Log: `/tmp/chimwemwe-nested-admission-20261025-02.log`. Full repository verification and final
specialist dispositions are recorded below when complete. The source-stage impact gate passes
in this recorded local environment; the earlier shared-instance failures remain failed evidence.

## Integration compatibility correction

The first full command, `CHIMWEMWE_TEST_DATABASE=chimwemwe_nested_full_20261025_01 make check`,
stopped at **448/462 core tests passed**, with 14 failures. Static/core contract checks had
passed; web/tooling stages after core were not reached. Log:
`/tmp/chimwemwe-nested-full-20261025-01.log`. No repository-green result is inferred from it.

The failures exposed older test wrappers that created a fresh correlation context for a nested
named action, or used another purpose for a wrapped logout. Exact-context refusal was correct.
The affected source/account-race and timezone/snapshot probes now establish one context per
logical operation and pass it through their outer transaction and nested action. The existing
lock diagnostic uses the operation's same context too. All original blocking, identity, clock,
snapshot, error-code and rollback assertions remain. The new changed-correlation/purpose denial
tests remain intact. No runtime guard or measured qualifier was weakened or changed.

On fresh `chimwemwe_nested_compat_20261025_01`, the four affected suites passed **67 tests**,
seed 29, and the updated lock diagnostic passed **one test**, phase `after`. Both real classroom
assignment and attendance completed while the source callback was held. Log:
`/tmp/chimwemwe-nested-compat-20261025-01.log`. This is compatibility/functional evidence, not a
new impact comparison. The sole production-code change is still `platform/persistence.ex`,
byte-identical to the twelve passing isolated comparisons.

## Resumed integration and dependency-audit maintenance

The second complete run passed **462 core tests**, **59 web unit tests** and **106 browser
tests**, then stopped because the final staff browser fixture's fixed port was occupied by a
separate retained reviewer preview. Its final staff test and subsequent tooling stage were not
run. The preview was left untouched. After the interrupted turn resumed, those ports were free.

The eight-file candidate still matched manifest SHA-256
`6a6ae74436073f4edffefb6615c5aaeaa6f62786c93421d183d533fbbd44c360`.
The durable aggregate JSON and qualifier hashes also matched. Earlier temporary logs and the
stopped temporary PostgreSQL cluster were no longer available on resumption; the recorded
aggregate results remain available in this repository. Do not treat temporary paths above as
current evidence custody. Subsequent run logs/data use a private durable qualification directory.

The fresh third `make check` stopped at its live dependency audit: the pinned Ash 3.34.6 and
AshPostgres 2.13.1 were now listed by advisories published on 25 October. It did not reach the
core regression or web stages. The upstream fixes are:

- [Ash through-relationship load](https://github.com/ash-project/ash/security/advisories/GHSA-g2h4-xp57-q863): Ash 3.37.1.
- [AshPostgres tenant-qualified joins](https://github.com/ash-project/ash/security/advisories/GHSA-gr2r-f49c-9gm2): AshPostgres 2.15.2.
- [AshPostgres skipped-upsert lookup](https://github.com/ash-project/ash/security/advisories/GHSA-36hg-wwp2-fg8w): AshPostgres 2.15.2.

The bounded maintenance update pins those two fixed releases and their required AshSql 0.8.4.
Four unrelated resolver upgrades were restored to their original locked versions. No audit
exception, ignored advisory, schema change, route or application authorization change is added.
The admission/source code stays unchanged. Full verification and the exact same predeclared
two-batch isolated qualification are repeated for this final dependency set; earlier performance
results are not silently attributed to the upgraded libraries.

## Final dependency baseline: repeated isolated qualification

The original two-batch plan was repeated after the dependency update. All twelve comparisons
passed with zero failed attendance attempts or capacity rejections, unchanged checkpoint counters,
unchanged workload/qualifier hashes and the same durability/connection/acceptance settings.
The current baseline is Ash 3.37.1, AshPostgres 2.15.2 and AshSql 0.8.4.

| Workload | Passing comparisons | Maximum read p95 increase | Maximum write p95 increase | Maximum source ms |
| --- | --- | --- | --- | --- |
| Foundation | 6/6 | +16.78% | +7.75% | 10.795 |
| Actual attendance | 6/6 | +8.10% | +14.23% | 9.300 |

Durable run directory:
`/Users/francois/.local/share/chimwemwe/qualification-runs/2026-10-25-ADR0054.ut9AuN`.
It contains the exact reproduction runner, all four raw aggregate logs, `impact-execution.json`,
the candidate manifest, private database files and the final full-check log. The application pool
remains six, tenant/placement admission six/twelve; each mixed comparison still resolves five
complete 25-person captures beside 120 reads and 30 writes. Each attendance baseline/mixed
comparison admits 180/185 outer calls with zero rejections. Every original absolute response bound
and two-second source deadline also passes. These are local source-stage results, not publication,
sustained-load, checkpoint-period or deployment evidence.

The final ten-file runtime/test/dependency manifest SHA-256 is
`d51443a79933934538beedb6fadf415e9a3f38cb014fe7b9ba744e108be435ec`.
No application authorization, session, source cap or lock was relaxed. Both the required Hex
audit and an independent OSV version query report no advisory for the three updated packages.
Final integration and specialist closeout are recorded below.

## Final integration and delegated closeout

`CHIMWEMWE_TEST_DATABASE=chimwemwe_nested_full_20261025_04 make check` completed with **exit 0**
on the final frozen candidate. Durable log: `full-04.log` in the run directory above.

- Documentation, Ruff format/lint, four documentation-tool tests, 23 fictional-data tests and
  six demo-instance tests passed.
- Core formatting, warnings-as-errors compilation, all three OpenAPI checks, migration drift,
  strict Credo, Hex audit, unused-lock check and Dialyzer passed; Dialyzer reported zero errors.
- **462 core tests** passed, including source/account/tenant/session denials, writer races,
  one-slot nesting, transaction rollback and the corrected legacy context probes.
- Both web dependency audits reported zero vulnerabilities; formatting, lint, style contracts,
  TypeScript, generated clients, token/dependency guards, production build and **59 web unit
  tests** passed.
- **107 browser tests** passed: UI-0 36, UI-1A six, unavailable-core recovery one, classroom three,
  fictional institution/demo layouts 60 and connected staff one.
- ShellCheck and verification-routing dry runs passed. No required `make check` step was skipped.

The final manifest was checked again after the command; all ten files match. The sole application
behavior change is exact-scope nested admission in Persistence; the three dependency upgrades
are the separately recorded audit prerequisite. The private PostgreSQL server was stopped after
measurement; its durable data, logs, runner and aggregate results remain available for review.

All four profiles reviewed the final dependency-specific measurements and source behavior,
without rerunning the tests themselves. Their remaining condition was a complete observed
`make check` exit 0 on the frozen candidate; the result above closes that condition.

| Profile | Final disposition and evidence | Coordinator disposition |
| --- | --- | --- |
| Primary education | Approve with conditions; successful refresh, actual correction rollback and all twelve final comparisons satisfy the attendance requirements. Keep the dependency-error mapping limitation explicit. | Accept; full check passed and the limitation remains documented. No unresolved primary-education repair remains for this prerequisite. |
| Secondary education | Approve with conditions; zero rejected attempts and all comparisons meet unchanged bounds on the final libraries. Retain shared-host, checkpoint-period and sustained-load limits. | Accept; full check closes the last condition. Those broader performance/release limits remain outside this local source-stage claim. |
| School/college admissions | Approve with conditions; permit reuse grants no identity or recipient authority, and staff/account/membership/context boundaries remain intact. | Accept; full check passed. Applicant, guardian, family and college-contact access remains outside this proof. |
| UI and interaction | Approve with conditions; label the result as local source-stage qualification, retain earlier failures/custody limits, and claim no new screens or usability evidence. | Accept; full check passed and current status is synchronized. No UI, publication or production approval is inferred. |

Initial and completion Advisor preflights returned `parent_runtime_unavailable`; no isolated
Advisor assurance is claimed. AI review is not representative testimony or independent
security/privacy/safeguarding assurance. Publication, its durable preparation/approval/manifest,
notice reads, correction/receipt workload, consumers, real records and release remain separate.

This closes the attendance-impact blocker for the authorized local source prerequisite. It does
not complete COMM-1's end-to-end publication proof. The shared runtime/test lanes were released
to the separately authorized ADR-0055 reviewer repairs after this checkpoint; later changes must
not inherit this full-check result without their own verification.
