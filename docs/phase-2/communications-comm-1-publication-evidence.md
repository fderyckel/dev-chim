# COMM-1 local synthetic publication evidence

- Status: Local synthetic publication and attendance-impact checkpoint qualified
- Recorded: 2026-10-27
- Authority: François explicitly authorized bounded local synthetic publication, four specialist
  reviews and `make check`; no connected, real-data, pilot or production use
- Governing decisions: [Accepted ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md),
  [bounded proposal](../plans/communications-comm-1-staff-announcement-proposal.md),
  [ADR 0056](../adr/0056-local-synthetic-communications-publication.md)
- Prerequisite: [qualified account/source/admission checkpoint](same-writer-admission-evidence.md)
- Engineering run custodian: this chat's coordinator; François retains project and decommission
  authority. AI review is delegated design review, not representative testimony or independent
  security/privacy/safeguarding acceptance.

## Implemented boundary

The disabled-by-default proof owns plain staff notices, immutable preparations and revisions,
independent approval, optional exact-version receipt, explicit opening, correction and terminal
withdrawal. Named actions run in one authoritative tenant/institution writer transaction.
Closed Ash resources expose no generic read/write actions. The loopback adapter fixes one
institution at startup; request input cannot choose an audience, tenant, placement, person,
account, classification or rendering. The test-only persona seam supplies fictional sessions,
not a real login or human identity assurance.

The original intended population and admitted account/principal/membership/association set stay
frozen. A correction recalculates eligibility only within that original set. Later activation,
replacement membership, relinking, rejoining or account A→B→A does not restore admission.
Same-principal credential rotation preserves original admission but still requires a currently
valid independent session and current access.

A currently capable person different from each operation's proposer approves the exact submitted
preparation. The approver need not be an intended recipient. Current proposer authority is
rechecked under the source fence. The population digest excludes caller-only authority while
the union of relevant actor/recipient authority is locked in a stable order. Stale content,
source, expected version, expiry, local date or approval basis refuses the entire operation.

Each institution is limited to five notice identities, 25 intended staff and two published
revisions per notice; separately approved terminal withdrawal still works after revision two.
Title/body/reason bounds are 120/2,000/240 Unicode codepoints. Preparation expires in five minutes
or at local midnight, whichever is earlier. The two-second transaction budget and original
pre-refresh session deadline remain enforced through the successful operation.

Successful state, exact actor/action/input/target idempotency, audit and Restricted outbox fact
commit atomically. Failure after evidence insertion rolls everything back, including session
refresh. The Internal-only dispatcher refuses these Restricted facts; no delivery consumer,
provider, notification, fan-out, reminder, scheduler, survey, attachment, comment, reaction,
student/family/admissions workflow or production application child is added.

## Receipt, access and recovery

The fixed statement is **I acknowledge receipt of this notice.** It records receipt of that
exact version; it makes no reading, agreement, delivery or safeguarding claim. A changed version
requires a fresh receipt. Recipient GET/status and prefetch return no notice body or opening
fact. Authorized author/approver previews show text without recording recipient openings.
Opening is an explicit POST; same-key opening replay and command outcomes contain metadata only.
Viewing content again requires a fresh explicit opening. The screen identifies the exact opened
notice before revealing its confirmation statement/action; this UI sequence adds no server
prerequisite that an opening fact exist.

Recipient status, opening, confirmation and own history all pass the People owner's full current
session/origin/actor/tenant/membership and original-binding check before any protected result,
claim or mutation. They perform one session refresh. The outer writer retains the pre-refresh
deadline; its server-only communications policy check runs after session validation and before
People source locks, preserving identity → communications → People ordering. Authoring,
approval, metrics and outcome paths retain outer full validation. No validated view is cached.

Interrupted writes retain opaque command references and a client input digest in a URL fragment,
without notice text, source proof or session secret. These untrusted hints never grant authority
or automatically write. Outcome lookup rechecks current access. Absence is not proof a delayed
original cannot arrive: retries keep the same action/key/causation/version references, and
reloaded content commands require exact original-text re-entry. Navigation/persona controls
remain blocked while unresolved. Denied retries clear protected content but retain the unresolved
identity. Malformed success/outcome replies and capacity refusal remain uncertain.

## Workload method and failed attempts

The original shared gate (one active, 32 waiting) matched the browser and qualifier. Its first
complete comparison passed, but its second failed attendance-write impact at +30.70%.
Removing duplicate recipient session refresh preserved authority but the next complete comparison
still failed at +32.63% read / +20.16% write impact. These remain failed evidence; thresholds and
pool/tenant/placement limits were never raised. Two earlier setup failures (issuer spelling and
checkpoint repository selection) executed no measured comparison and remain separately retained.

Both education profiles challenged a qualifier-only client lane before implementation. They
subsequently approved an actual bounded service policy: communications waits while the existing
runtime reports already-admitted database work, then enters ordinary admission. The same
`LocalRequestGate` runs before Router/SessionPlug in the loopback adapter and before the direct
named actions in the qualifier. It checks an observed opportunity, not an atomic reservation.
New work can arrive immediately afterward; unrelated tenant/placement work can delay this local
lane. There is no tenant-fairness or production-priority guarantee.

All drain and FIFO wait shares the original two-second arrival deadline. Monotonic expiry is
checked at grant even if a timer message is delayed. No database permit, transaction, connection
or source lock is held while waiting. Overflow, continuous-work expiry, owner/queued cancellation,
exceptions, exact synchronous reuse and scope mismatch have controlled tests. A real queued
receipt is denied after independent named session revocation, with no engagement or waiting
database permit. A PostgreSQL-observed concurrency control verifies identity precedes the
communications lifecycle lock against an independent revocation/membership writer.

The workload starts every logical client together, without waiting for classroom completion:

- Four actual-attendance reader streams × 30 prepares and one writer × 30 real corrections over
  six writer classes; each class has exactly five baseline and five mixed corrections.
- Five concurrent logical communications reader streams × 30 current status requests.
- Twenty-five distinct current recipients confirming one published version.
- Two legitimate competing approvals on separate notices: initial publication and correction.
- Pool six, tenant admission six, placement admission twelve; one active communications request,
  at most 32 waiting, two-second queue limit and two-second transaction budget.

Every paired run contains 477 timed logical operations and 537 outer database admissions
(baseline 180, mixed 357). Queue wait is included. These are **named-action application timings**;
Router/SessionPlug/TLS/browser overhead is not measured by this qualifier. Browser correctness
and accessibility checks are separate.

The first priority cohort passed three fresh comparisons (09–11). Startup guards were then added
to refuse populated/nonlocal qualification databases and unconditional raw-attempt recording was
added before convergence assertions; measured operations and runtime stayed unchanged. A second
fresh three-comparison cohort (12–14) verifies that final runner. All earlier passing and failing
attempts remain available. Full [aggregate results](communications-comm-1-impact-results.json).

Final three comparisons: zero failed operations, admission rejections or leftover queued/active
requests; 25 receipts per run. Read p95 changes were −44.18/−45.83/−47.02%; write p95 changes were
−22.31/−29.23/−26.56%. These negative differences make no speedup or causal-performance claim.

| Measured group | Maximum final p95 ms | Maximum final p99 ms | Retained limits p95/p99 ms |
| --- | ---: | ---: | ---: |
| Attendance read | 8.319 | 19.917 | 300 / 750 |
| Attendance correction | 16.085 | 24.767 | 750 / 2,000 |
| Communications read, including wait | 169.368 | 340.199 | 300 / 750 |
| Receipt, including wait | 467.092 | 472.640 | 750 / 2,000 |
| Approval, including wait | 461.843 | 461.843 | 750 / 2,000 |

The 373-file runtime/workload manifest SHA-256 is
`45473e4d4868ce19e9c32c7f70338a14cf1ef38006fa56cf3a96b9047a6ae526`.
It was rechecked after integration fixture/formatting repairs: no measured runtime/helper path
changed. The private cluster settings and all raw samples remain in the run custody below.

## Migrations, restore and browser evidence

Three generated, inspected additive migrations establish complete tenant-qualified tables and
indexes before compound foreign keys; add bounded disjoint eligibility constraints; and require a
non-null exact receipt statement even for alternate SQL writes. Up/down operations have finite
lock waits. Retained-history rollback refuses destructive removal; forward repair preserves facts.
Empty apply/down/reapply converged to the identical canonical schema. Retained-history down was
refused and forward migration preserved the schema. Migration drift and the final repository
gate remain separately recorded below.

The retained restore proof uses one notice, two revisions, three preparations and three engagement
facts (two receipts and one explicit opening), then terminal withdrawal. A private custom archive
restores into a separately created fresh database. Counts and deterministic row fingerprints for
all four communications tables plus audit/outbox/idempotency converge. Both runtimes share the live
test process HMAC configuration; key/bootstrap recovery and server-restart reauthentication were
not exercised. The restored named boundary
rechecks current access, returns exact own receipt history and safe receipt outcome, and refuses
new opening/receipt after withdrawal without changing retained facts. Earlier harness assertion
repairs and their databases remain retained.

The browser journey exercises author submission, denied self-approval, independent approval,
zero preview openings, plain-text rendering, optional receipt, corrected time with fresh receipt,
lost approval and receipt responses across reload, terminal withdrawal, receipt-off, stale source
and capacity refusal. Component fault tests additionally cover malformed confirmation/committed
outcome, denied retry, lost create and exact original-text same-key recovery. A delayed-original
core test proves absence plus same-key retry creates only one notice.

Screenshots cover draft, review, approval, denied, pre-opening, confirmed, corrected, uncertain,
withdrawal, receipt-off, stale and capacity states at 320/1,280 pixels. Automated axe, keyboard,
reflow and text-scaling checks are evidence about this synthetic browser, not human usability
or screen-reader testimony.

## Verification and specialist closure

All four specialists have completed read-only review of source and recorded evidence; they did
not independently execute tests or supply human testimony. No material design repair remains.
The final full repository gate passed with exit 0; all review conditions are closed within this scope.

| Profile | Final reason/disposition | Coordinator disposition |
| --- | --- | --- |
| Primary education | Approve with conditions: exact receipt/correction/withdrawal semantics, immutable admission, recovery and measured limits supported; distinguish authorized previews from bodyless recipient GET. | Preview wording corrected. Scope and evidence limits retained; full gate passed. |
| Secondary education | Approve with conditions: raw final logs match aggregate counts and fixed targets; current authority, deadline, independent writer/race and recovery controls addressed. | Accept; no further education runtime repair. Full gate passed. |
| School/college admissions | Approve with conditions: exact non-null statement fixed; staff scope, frozen admission, current access and no directory/admissions expansion supported. | Accept; full gate passed. |
| UI and interaction | Approve after refreshed screenshots: confirmation follows exact opening, badge no longer obstructs actions, denied scope is truthful; recovery/reflow/touch/keyboard evidence supported. | All three rendered repairs closed; full gate passed. |

Executed focused checks: **76 core/API/gate tests**, **13 communications component tests**, and
**one complete browser journey** (browser-10, 22.7 seconds), plus the separate migration,
retention/restore and final three workload comparisons above. Earlier failed focused/harness
attempts remain in private custody. Full integration attempt 1 passed maintained pre-test stages
but failed 84/559 core tests: 83 legacy cleanup foreign-key failures and one domain-inventory
expectation. Attempt 2 passed 558/559 tests after cleanup synchronization and retained the one
inventory expectation failure; that authorization-domain inventory now includes Communications
and explicitly checks always-authorization/actor requirements. These repairs affect tests only.
Generated communications browser directories are excluded from formatting/lint. Client checks
also repaired expiry rendering through an external-clock effect and preserve full-document new
notice reset through the design-system ActionLink's optional full-document navigation choice;
all existing callers retain their original navigation. No lint rule is bypassed for this action.
Final integration on `chimwemwe_comm1_final_20261027_03`:

```sh
PGHOST=<retained private Unix socket> PGPORT=56427 \
  CHIMWEMWE_TEST_DATABASE=chimwemwe_comm1_final_20261027_03 \
  CHIMWEMWE_DEMO_E2E_PORT=3100 make check
```

**Exit 0: 559 core tests, 82 web unit tests and 108 end-to-end browser tests**
(36 + 6 + 1 + 3 + 60 + 1 + 1). The final communications journey passed in 22.4 seconds.
No required stage was skipped. Maintained documentation/repository-tool checks, formatting,
compilation with warnings as errors, all OpenAPI/generated-client contracts, migration drift,
Credo, Hex/Node dependency checks, Dialyzer, design tokens/CSS/accessibility contracts, build,
all test groups, shell tooling and whitespace checks passed. The earlier failed gate attempts
above remain failed evidence; they do not count as passing results.

Final log: `final-make-check-03.log` in the private run directory below; its SHA-256 is
`e9bf3529b101a0506cc4ba3dff498a4bfdb4a27b1afc7d22e79d6bfc0786f172`.
The structured private `completion.json` records exact counts, failures and exit status.
A post-gate documentation-only synchronization was checked again; runtime/helper fingerprint
remains identical to the measured candidate.

Initial, renewed and completion Advisor preflights returned `parent_runtime_unavailable`;
no isolated Advisor or independent security/privacy/safeguarding assurance is claimed.

## Custody and remaining gates

Private run locations (outside the repository):

- `/Users/francois/.local/share/chimwemwe/qualification-runs/2026-10-26-COMM1.eV40Az`:
  focused/browser logs, failed attempts and screenshots.
- `/Users/francois/.local/share/chimwemwe/comm1-qualification-20261027.Llyvhi`:
  private PostgreSQL 18.6 Unix-socket cluster, durability settings, all paired-run logs, manifests,
  migration evidence, synthetic archives/restores and custody record.

The server accepts no TCP connections; fsync, synchronous commit and full-page writes remain on.
No real records, human participants, credential delivery or provider calls are used. Archive and
database content stays private; repository evidence contains only aggregate fictional results.
At review closure, the temporary proof harnesses and private PostgreSQL process were stopped.
Databases, archives and evidence remain retained; the user's existing preview on ports
3115/3116/4115 was unchanged. No scheduled purge, per-record delete, database drop or
whole-environment decommission is authorized.

A pass closes only the local synthetic publication/attendance-impact checkpoint. It does not
establish simultaneous SQL throughput, sustained/checkpoint-period capacity, shared Identity
concurrency, connected authentication, delivery, real-school policy, security/privacy/safeguarding
acceptance, pilot or production readiness. ADRs 0045/0056 and inherited release gates remain binding.
