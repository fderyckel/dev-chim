# COMM-1: bounded synthetic staff-announcement proof

- Status: Authorized bounded proof; source-fence qualification is the first checkpoint
- Date: 2026-10-23
- Authorization: François accepted ADR 0045 and authorized exactly this proof on 2026-10-23;
  agents must review the source-fence checkpoint before further implementation; the initial
  checkpoint deferred `make check`, which the final coordinator integration later ran
- Owner and implementation decider: François — Project Owner
- Preparation: Coordinator and the four delegated education, admissions and UI specialists
- Review trigger: implementation authorization, failed source-consistency qualification, scope change or new representative evidence
- Governing paper contract: [ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md)
- Review evidence: [COMM-0 decisions and specialist review](../phase-2/communications-comm-0-experience-evidence.md#delegated-paper-review--23-october-2026)
- Current checkpoint: [source fence not qualified](../phase-2/communications-comm-1-source-fence-qualification.md);
  [authorized account prerequisite](../phase-2/identity-account-source-fence-evidence.md) implemented,
  focused-tested and reviewed by all four agents. Renewed qualification on 2026-10-24 returns a
  [bounded account-binding decision](communications-audience-source-qualification.md), subsequently
  selected as B and implemented under [ADR 0051](../adr/0051-private-account-principal-binding-marker.md)
  with its [separate checkpoint](../phase-2/account-principal-binding-evidence.md);
  publication implementation remains blocked and `make check` is currently deferred

The subsequent [composed source candidate](../phase-2/staff-audience-source-evidence.md) passes
41 source checks but fails the retained classroom p95-impact criterion in all three
initial measured repeats. The source is **not qualified** and publication remains unimplemented.
François subsequently authorized the [scoped contention follow-up](communications-source-lock-contention-proposal.md).
Its [ADR 0053 checkpoint](../phase-2/people-source-write-fence-evidence.md) removes the measured
People-row blocking and passes all three unchanged foundation comparisons within 20%. Actual
attendance cannot qualify because requests are rejected at the unchanged admission limit even
without source captures. The next nested-admission proposal is not implemented; publication and
`make check` remain explicitly deferred for this increment.

## Proposed outcome

In a disabled-by-default loopback environment, a fictional staff author prepares an ordinary
notice for one exact institution. A different authorized actor approves and publishes it. An
eligible staff recipient opens it and, only when requested, confirms receipt. A separately approved
correction preserves its audience and requires a fresh confirmation when receipt was originally
required. Approved withdrawal stops ordinary content presentation and new confirmation actions.

This is one end-to-end engineering proof. The Project Owner has authorized this bounded scope,
starting with audience source-fence qualification and agent review before further implementation.
Qualification does not itself create a publication path or prove the end-to-end outcome. The stop
conditions below remain binding. This does not reprioritize the classroom plan.

## Included boundary

| Area | Proposed first-proof boundary |
| --- | --- |
| Environment | One isolated local synthetic database/run, loopback HTTPS harness, startup-selected tenant and exact institution; a second tenant/institution exists only for denial tests |
| Audience | Current exact-institution staff participation; deduplicate by stable person identity; no descendants or browser-supplied people, tenant or institution identifiers |
| Account admission | Verified original staff-account association, membership and account identities; current session, participation, authorization and module gates still rechecked on every action |
| Content | Plain-text title/body only; render as text; no HTML, attachments, links-as-authority, translations or learner-linked content |
| Interaction | Closed comments and reactions; optional receipt request, default off, fixed for the correction chain |
| Review | Author and approver are different currently authorized actors; approval binds the exact operation, revision, content, audience basis, eligibility snapshot and receipt mode |
| Publication | Immediate atomic writer transaction; no scheduling, timer, quiet-hours or urgent mode |
| In-product access | Direct authorized writer-backed reads; no fan-out/delivery consumer, notification, email, push, SMS, realtime or provider callback |
| Metrics | Exact-revision aggregate counts only; recipient may inspect their own exact receipt while still authorized |
| History | Immutable earlier revisions/receipts retained; current revision/status shown; no general historical record browser or export |
| Withdrawal | Separately approved terminal state; no reopen or restore action in this proof |

Staff may also be applicants, students or guardians, but only their independently established
staff relationship is relevant. Student, family, applicant, referee, external-college, class,
cohort, subject-group, community, tenant-wide and urgent target kinds remain unavailable. Ordinary
staff access does not authorize confidential references, admissions decisions or learner records.

## Settled paper decisions

The logical rules live in ADR 0045's
[bounded proof disposition](../adr/0045-governed-communications-audiences-and-engagement.md#comm-0-paper-disposition-for-the-first-proof).
The four specialists approve that paper direction, including its review/confirmation workload.
François has now formally accepted ADR 0045; no other named decider or real school representative
approval is invented. No COMM-0 product-policy question remains open for the
included proof. Broader audience, emergency, retention and release policies remain excluded.

The fixed statement is **I acknowledge receipt of this notice.** It is receipt evidence, not
reading, agreement, consent or policy acceptance. No custom acknowledgement statement is included.
The original receipt-required choice cannot change through a correction. Each required successor
needs its own exact-revision receipt, without a minor-edit exception.

## Authoritative source preparation and publication

The people foundation exposes exact reads, not a staff-directory API. The authorized COMM-1 therefore
needs one new private, source-owner-controlled projection for this exact staff-audience task.
It must preserve current actor/tenant/module/purpose/capability checks and return no browser-visible
recipient rows, protected proof references, names or emails. The existing demo JSON packs cannot
become identity or audience authority.

Select the following consistency contract:

1. Resolve intended people and eligible original account identities from authoritative writer
   records. Capture exact institution/time-zone and effective-date basis; include the relevant
   participation, account-association, membership/account and authorization versions or an
   equivalent owner-controlled generation. Never manufacture a source version from a label.
2. Store an immutable preparation result and canonical basis digest, tied to draft version,
   content, exact subject/account admission set, receipt mode, actor and tenant. The approval
   refers to that exact result. Preparation/approval expires after five server-clock minutes;
   effective-date boundaries and source changes invalidate it sooner.
3. At approval/publication, reacquire a writer-consistent source fence and recompute the complete
   bounded set and eligibility basis. Detect new/ended/future-effective staff, associations,
   accounts, memberships and relevant grants, not just changed rows already in the preview.
   A mismatch or unavailable fence refuses the action and requires refreshed preparation and
   a fresh approval. There is no publish-anyway option or automatic changed-audience retry.
4. Keep that source fence through atomic revision/manifest/audit/outbox/idempotency commit, so
   concurrent changes have a defined ordering. Use the existing READ COMMITTED writer contract;
   an ordinary query, repeated hash comparison or a lock on only returned rows is not sufficient
   phantom protection. Do not change source writers' isolation contracts or invent a global
   directory/cache authority to obtain the fence.

**First implementation checkpoint:** qualify this adapter/fence against source-writer races
before building a publication path. Exact locking/generation mechanics must be evidenced against
the existing source owners, including insert/ending/revocation/date-boundary cases. If that needs
a new general people mechanism, stable-boundary change or wider writer refactor, stop and return
that smaller decision; do not enlarge COMM-1 implicitly. This is required engineering proof of a
settled consistency rule, not a claim that an audience API or fence already exists.

Publication freezes the original intended set and admitted account/association identities.
Corrections retain that set and current-access restrictions. New people, newly provisioned or
replacement associations, rejoin and membership replacement need a new publication for access;
credential rotation with unchanged identity does not bypass normal session revocation checks.
The original intended denominator does not change. Current denials never erase historical facts.

## Explicit engineering limits

These are conservative first-proof limits, not measured school capacity or production quotas.
Existing fictional packs have at most 18 staff; a 25-person bound leaves a small executable
boundary case while avoiding a broad directory. The larger 84-person COMM-0 example remains a
paper vocabulary exercise, outside this first implementation envelope.

| Limit / target | Proposed value and failure rule |
| --- | --- |
| Intended audience | At most 25 people; test 1, 25 and 26. Reject overflow without truncation, partial publication or returning a people list |
| Run size | At most 5 communication identities per institution and 2 published revisions per identity; reject extra work explicitly, do not overwrite or delete retained evidence |
| Content | Title at most 120 Unicode code points; body at most 2,000; closed request schema and no caller-controlled rendering or classification |
| Preparation/approval age | Five server-clock minutes maximum; source/time-basis change invalidates it earlier |
| Write duration | Two-second total transaction budget, including fence acquisition; timeout rolls back and returns a typed retryable result, without a new operation identity |
| API targets | Reuse [accepted targets](../architecture/quality-attribute-targets.md): reads p95 <= 300 ms / p99 <= 750 ms; mutations p95 <= 750 ms / p99 <= 2,000 ms |
| Local mixed workload | Five concurrent readers, a 25-recipient receipt burst, and competing publication/correction attempts alongside the existing classroom read/write journey; measure at least three repeat runs |
| Isolation / impact | No unauthorized or partial commit, duplicate logical receipt or stale approval; classroom p95 degradation <= 20% against the same fixture/hardware baseline |

Failure means the candidate does not exit COMM-1. Record measurements and hardware/configuration;
do not increase caps, weaken consistency, waive the classroom target or infer production readiness.
Per-tenant physical placement is not inferred from these fixture sizes.

## Classified storage and evidence custody

Use **Restricted** throughout this proof: content, intended/admission references, publication
snapshots, receipts, aggregates, audit, idempotency and outbox. ADR 0036 already classifies source
people records/events Restricted even when synthetic; aggregation does not declassify them.
No real staff/learner records, credentials or protected source proof contents enter fixtures,
logs, prompts, screenshots, repository evidence or provider calls.

Publication, correction, withdrawal and receipts commit their state and minimal required audit,
idempotency result and Restricted outbox facts atomically. The existing Internal-only dispatcher
must continue to refuse Restricted facts. Add no communications consumer or claim of delivery.
Any narrowly needed storage allowlist/schema change must be reviewed as part of the future slice;
it cannot enable existing consumers or change other modules' gates.

Before a future run, record its isolated run/environment reference, fictional scope, actual
engineering custodian and review checkpoint. Preserve the complete linked proof evidence through
review and unresolved findings. At review closure, stop ordinary use and retain the evidence.
There is no scheduled purge, per-record hard delete or rollback through retained facts.
Whole-environment decommission needs separate authorization and dependency/evidence review;
retain a minimal redacted decision/test record outside it. This selects proof custody without
inventing a legal retention duration, real records policy or deletion authority.

## Proposed actions and compact screens

Action intents below are proposed contracts, not existing APIs or fixed permission-role names.
Every action requires current writer-side tenant, actor, placement, module and dedicated capability
checks; authorship, staff participation and hierarchy alone grant none.

| Task | Named intent / interface boundary |
| --- | --- |
| Prepare notice | Create/revise draft, prepare exact staff audience, submit exact revision for approval; author sees counts and scope only |
| Approve operation | Independently authorize and atomically approve/publish, approve/correct or approve/withdraw; no separate reusable approval token that permits edited content |
| Open notice | User-initiated named opening action returns authorized exact current content and records its own opening fact; require the ordinary mutation/origin/CSRF checks, never a side-effecting GET, prefetch or background fetch |
| Confirm receipt | Session-derived own subject, exact current revision and fixed statement; reject superseded/withdrawn/unauthorized actions |
| Inspect result | Exact actor-bound command outcome or own receipt; never caller-selected subject, arbitrary operation lookup or post-revocation receipt access |
| Inspect metrics | One authorized communication/revision and its aggregate publication snapshot; no named drill-down, pagination/search/export or cross-notice engagement profile |

Author flow: **Write notice → Review → Submit for approval**. Approver flow: full notice plus a
compact scope/count/receipt summary and **Approve and publish** (or the exact correction/withdrawal
action). Recipient flow: sender/institution, title/body, time/version/state, and **Confirm receipt**
only when required. Show **Restricted** once as metadata; no classification, channel, timing or
interaction dropdowns for fixed proof choices.

Essential audience exclusions, approval effects, errors and collection notice stay visible:
**Openings and receipt confirmations are recorded.** Secondary definitions may use labelled
question-mark help with keyboard, tap and hover access. Corrected content shows its version and
short reason; withdrawal stops the ordinary body and pending action. No production screen or
human usability result is claimed by this paper design.

## Metrics and recovery

Use the original intended count N for all revision counts. Display **Audience**, **Eligible when
this version was published**, **No eligible account at publication**, **No current access at
publication**, **Opened S of N**, and, when required, **Receipt confirmed A of N**. Eligibility
categories are mutually exclusive, sum to N and remain historical snapshots. Do not rewrite them
after later access changes. Openings and receipts are distinct exact-revision facts; never derive
their intersection by subtraction. No Queued, Delivered, Not read, named non-viewer or engagement
score is included.

Partition each original intended subject exactly once: ended staff eligibility means no current
access; otherwise missing original eligible account admission means no eligible account; otherwise
failed current association/membership/account/access checks mean no current access; all remaining
subjects are eligible. Later provisioning cannot change the frozen admission rule. This precedence
prevents overlapping exclusions or a denominator assembled from incompatible times.

The aggregate response contains only communication/revision reference, fixed institution context,
lifecycle state, publication time, metrics-as-of time, receipt-required flag and the counts above.
An authorized own-receipt response contains an opaque receipt reference, communication/revision
reference, exact fixed statement, recorded UTC time and confirmed status. Subject identity is
derived server-side and omitted from that response; no name, email, audience reason, source-proof
reference or other recipient's timestamp is returned. A first opening fact does not imply a
receipt, and a confirmed receipt does not require a separately captured opening event.

Bind writes to tenant/action/actor/aggregate, expected version and canonical input. Lost responses
show an uncertain state and reconcile an authorized exact outcome from the writer. If committed,
return the original result under current authority; if absent and still valid, retry the same
operation identity. Changed payload/key reuse conflicts. Superseded/withdrawn state forbids a new
receipt; a previously committed receipt remains retained without granting fresh access.

The Restricted outbox is durable evidence, not a delivery work queue for this slice. No provider
retry, consumer replay, fan-out completion, delivery success or reminder is inferred from it.

## Implementation order and exit evidence

1. Record the 2026-10-23 explicit COMM-1 authorization, actual run custodian, exact fixture and
   current inherited gates. No real identity, public/deployment, pilot or production use.
2. Qualify the private source projection/fence and all denial/race cases. Stop at that checkpoint
   if existing source contracts cannot support it within scope.
3. Build only the approved synthetic announcement/revision/manifest/approval/receipt boundary.
   Review generated additive migrations, non-null tenant keys, compound foreign keys, uniqueness,
   indexes, locking, drift, apply/rollback/reapply on empty data and retained-evidence forward repair.
4. Add the purpose-built local screens and current-session named actions together; no generic
   CRUD, people directory, raw Ash query/filter, runtime schema or broad generated action route.
5. Pair positive tests with missing/stale context, cross-tenant/institution, capability/module
   denial, self-approval, source phantom/end/revoke, changed approval, stale/changed replay,
   simultaneous correction/receipt/withdrawal, oversized inputs and unauthorized enumeration tests.
6. Inject failure after audit/outbox insertion and before commit; prove complete rollback. Verify
   lost-response outcomes, retained history, module deactivation denial and Restricted consumer
   refusal. No consumer success is part of this proof.
7. Exercise responsive keyboard/touch, visible focus, error association, screen-reader semantics,
   reflow/text scaling and all draft/approval/stale/uncertain/corrected/withdrawn/denied states.
   Supply actual screenshots for UI review; record human observations only if actually gathered.
8. Measure the bounded and mixed workload; report exact checks, including the then-required
   repository gate at implementation exit when authorized to run it. The current instruction
   explicitly defers `make check`; focused checkpoint checks do not establish a green repository.

The smallest demonstration uses one fictional author, a distinct approver, an eligible recipient,
one staff member without an account, one ended staff record and a newcomer after publication.
Show publication, opening, optional exact receipt, corrected time with fresh receipt, withdrawal,
and denials without developer explanation or invented delivery. Repeat independent fresh runs for
the receipt-off case and cardinality/race limits rather than accumulating unbounded evidence.

Exit permits only the demonstrated disabled local synthetic candidate. Representative educator,
administrator, accessibility, safeguarding, records and independent security/privacy review,
Restricted consumers, selected identity/origin, real data and release retain their later gates.
Passing COMM-1 never authorizes COMM-2 or emergency communications.

## Prior paper verification and current authorization

This document and COMM-0 revisions receive documentation-link/structure and whitespace checks as
their focused evidence. No communication implementation, migration, runtime trial, benchmark or
human session has been performed. The repository-wide integration run
`CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_final6_20261023 make check` passed every existing required
stage after these paper changes; that protects current behaviour but does not execute or qualify
the proposed COMM-1 proof.

After the authorized account prerequisite and concurrent calendar/demo work, the final combined
checkout passed `CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_final8_20261023 make check`: 335 core
tests, 52 web unit tests, 70 browser tests, both dependency audits, the production build,
documentation/repository tooling and shell tooling. This remains repository integration evidence,
not complete audience qualification or permission to begin publication implementation.

The Project Owner has now authorized exactly this proof with the source-fence checkpoint, limits
and exclusions above. Further implementation depends on that checkpoint and the requested agent
review. No commit, push, deployment, external message or deletion is authorized by this proof.
