# ADR 0056: Local synthetic communications publication

- Status: Proposed
- Date: 2026-10-26
- Accountable owner: Communications, platform and product engineering
- Deciders: François — Project Owner; independent security/privacy review before real data
- Implementation authority: François explicitly authorized the bounded local synthetic COMM-1
  publication implementation, four-profile review and `make check` on 2026-10-26
- Supersedes: None; implements Accepted ADR 0045's bounded first proof

## Context

The [source prerequisite](../phase-2/same-writer-admission-evidence.md) is locally qualified.
The [COMM-1 proposal](../plans/communications-comm-1-staff-announcement-proposal.md) fixes the
staff-only audience, independent approval, receipt semantics and unchanged engineering limits.
This increment implements that contract without a delivery consumer or production surface.

## Decision drivers

- Preserve exact tenant/institution, current actor authority and original recipient admission.
- Make approval, receipt meaning, uncertainty and withdrawal independently reviewable.
- Preserve atomic audit/outbox/idempotency, temporal bounds and unchanged attendance-impact limits.
- Supply the authorized local synthetic proof while retaining connected-data and release gates.

## Considered options

1. Private named actions with purpose-built loopback screens — selected for this bounded proof.
2. Stop at source-only qualification — insufficient to demonstrate the now-authorized publication,
   correction, receipt and recovery workflow.
3. Add a general feed, generic CRUD, delivery or surveys — outside this authorization and the
   accepted domain boundaries; remains deferred.

The bounded admission alternatives and their failed measurements are recorded below. A
qualifier-only lane was rejected; the selected local policy runs identically in the service.

## Decision

Add `communications.core` v1.0.0, dependent on `people.core`. Its private named boundary owns
drafts, immutable operation preparations, immutable published revisions and exact-revision opening
and receipt facts. All records, counts and evidence are Restricted. Closed Ash resources expose
no generic actions; the purpose-built loopback adapter uses the same named boundary.
Startup fixes one tenant/institution and the local harness; browsers cannot choose audience,
institution, tenant, person, account, classification, rendering, module or placement.

Create/revise, prepare and submit are distinct actions. Preparation freezes exact content,
receipt mode, operation (publish/correct/withdraw), expected aggregate version, prior revision,
proposer and a private source proof. Submission selects that exact immutable preparation.
A different currently authorized actor approves and commits the exact operation atomically.
Independence is from each operation's proposer, not merely the original notice author.
No reusable approval token or publish-anyway path exists.

The People owner continues to bind ordinary `StaffAudience.recheck` to its preparer.
For independent approval, Communications obtains a new complete fenced capture using the
approver's own session. It compares tenant, institution, recipient-source digest, draft digest,
local date and expiry against the persisted preparation, while separately verifying proposer and
approver authority. People captures the union of caller and recipient authority locks once in
stable order, but hashes only the recipient-reachable graph into the population basis. Caller-only
membership/roles are independently checked and cannot make the population actor-dependent.
An approver need not be a recipient. This changes no permission or existing actor-bound recheck.

Every composed call uses the exact server-owned `communications.staff_audience` execution
context and one writer transaction, preserving ADR 0054's exact scope and ADR 0052's total
two-second server/monotonic deadline. Current session origin, expiry, membership and module/
capability checks run on the writer. Recipient access uses a People-owned exact original-binding
check, with the recipient's current session and notice-read capability; it grants no audience
preparation capability or general directory access.

Original publication freezes intended subjects and original admission. Corrections retain them
and the fixed receipt mode; current source capture produces a new disjoint eligibility snapshot.
Each required successor needs a new receipt. A new person, account activation after absent
admission, replaced association/membership, rejoin or changed principal binding cannot enter the
old chain. Current access is checked for opening, confirmation, own receipt and replay/outcome.
No returned replay contains content. Withdrawal hides ordinary content and blocks new confirmations,
without erasing retained receipts. It is terminal lifecycle state, not a third content revision.

Keep the existing caps: five communication identities/institution, two published revisions/
identity, 25 intended subjects, 120/2,000 code-point title/body, preparation expiry at five writer
minutes or local midnight, and a two-second total transaction budget. No truncation or deletion
to make space. Plain text only; comments/reactions remain closed and receipt requests default off.
Opening is an explicit origin/CSRF-protected POST after visible collection notice; GET, previews,
metrics and prefetch do not create opening facts.

Exact command identity binds tenant/action/actor/aggregate/version/canonical input. State,
immutable audit, Restricted outbox and completed result commit together. Lost responses reconcile
the actor-bound command under current authority; permitted retry uses the same identity.
The Internal-only dispatcher remains unable to claim these Restricted facts.

### Bounded local request admission

The loopback adapter and its qualifier share one explicit synchronous `LocalRequestGate`,
started only by the synthetic harness. It admits one communication request and at most 32 waiting
requests before authentication/database checkout, with a two-second waiting limit and typed
overflow/expiry refusal. Domain calls configured for this proof use the same gate; exact
synchronous nesting reuses its held slot. It grants no actor, tenant, route or domain authority.
After waiting, the ordinary current session, context, placement, module, source and action checks
still run, preserving the original pre-refresh session deadline and two-second transaction budget.
Waiting holds no database permit, connection, transaction or source lock. Monitored owners and
waiting callers release/remove their slots on completion, exception, cancellation or termination.
The adapter refuses an unheld/missing gate; no default application child or production queue,
background work, delivery consumer or scheduler is installed.

The mixed test therefore records five concurrent logical reader streams and a 25-recipient burst
with competing publication/correction, while one communications database operation is active.
Full wait plus operation time is measured. The unchanged four-reader/one-writer actual-attendance
workload, pool six, tenant six, placement twelve, latency targets and 20% impact limit remain.
All three independent paired comparisons must pass with every attempt retained. A qualifier-only
client lane was challenged by both education reviewers and is not used as exit evidence.

The first complete mixed comparison passed; the second exceeded the unchanged attendance-write
impact limit. Both attempts are retained. Recipient actions previously validated and refreshed
the identical session twice inside the same transaction. For status, explicit opening, receipt and
own receipt history only, the outer writer now observes/binds the original pre-refresh deadline;
the existing People recipient owner still performs full current session, origin, membership and
exact original-admission validation before every successful result, replay, claim or mutation.
No validated view is cached or borrowed. All other actions retain outer full session validation.
The recipient owner's server-supplied policy check runs immediately after full session validation
and before its existing module/source locks. Communications supplies its unchanged release,
activation/dependency and action-capability check there. Thus identity/session locks still precede
the communications gate and then People source locks; deferral does not invert that order.
This removes a redundant refresh without changing Identity APIs, authority, locks, caps or timing
targets. Negative/expiry/queued-revocation controls and new complete comparisons must qualify it;
the earlier measurements cannot qualify the changed candidate.

Starting a new notice deliberately performs a full document navigation, discarding the previous
protected task state after uncertainty is resolved. The shared ActionLink exposes an optional
`reloadDocument` presentation choice for this explicit action; all existing callers retain their current
navigation. It changes no domain authority, session, command identity or server action.

That repaired candidate also failed a complete mixed comparison (+32.63% read, +20.16% write p95
impact), with zero rejected operations. No threshold or capacity is changed. The shared local gate
now gives already-admitted work priority: before dispatch it observes the existing runtime's
`DatabaseAdmission.active_permits` and defers while nonzero, checking again on a bounded five-ms
timer. All drain and FIFO waiting share the original two-second arrival deadline. There is still
one active communications request, at most 32 waiting and ordinary admission after dispatch.
This is an observed opportunity, not an atomic reservation: new work may obtain admission after
the observation. Unrelated tenant/placement work in this explicit runtime can delay the lane;
there is no tenant fairness, urgent-notice, sustained-load or production scheduling guarantee.
Continuous other work must produce a typed expiry, never an unbounded wait or a reset deadline.
Both education profiles conditionally approved this local policy before implementation. Their
conditions require controlled drain/expiry/accounting tests and three new complete comparisons
with unchanged simultaneous logical starts, counts, full measured waits and acceptance criteria.
Any pass describes mixed logical requests with priority for already-admitted work and reduced SQL
overlap; it does not qualify shared Identity concurrency or simultaneous database throughput.

### Browser uncertainty

An interrupted write retains only its opaque action/key/target metadata and a client input digest
in the current URL fragment. These untrusted hints supply no authority and never execute a write
automatically. Content, source proofs and session secrets are not persisted there. Navigation and
persona switching stay blocked while unresolved. Exact actor-bound outcome lookup rechecks current
authority. An absent result does not prove a delayed original cannot arrive; every permitted retry
retains the original command identity. After reload, content-bearing commands require explicit
original-text re-entry and digest equality, while reference-only commands can reuse their exact
stored payload. No fresh identity is created from an uncertain/absent result. Opening replay and
command outcomes contain no notice content; viewing it requires a fresh explicit opening.

## Plain-English summary

A fictional staff notice can be prepared, independently approved, opened and optionally confirmed
in one local proof. A correction needs new approval and receipt; withdrawal stops ordinary access.
Counts describe the original audience and exact version, without named engagement lists.

## Consequences and retained boundaries

No student/family/applicant/college audience, survey, reaction, comment, scheduling, urgent mode,
notification, provider, search, export, realtime, consumer or production deployment is added.
The four AI specialists review design and implemented evidence; they supply no representative
testimony or independent security/privacy assurance.

## Security, privacy, operability, and migration effects

Use generated additive Ash migrations, non-null tenant keys, compound references, uniqueness,
immutable evidence guards, finite DDL locks and retained-state rollback refusal. Empty unused
rollback/reapply is qualified separately; retained installations require forward repair.
No credentials, session secrets, source proof contents or real records enter logs/evidence.
Run custody is local engineering custody through review; stop ordinary use at closure and retain
linked evidence. Decommission or deletion needs separate authority.

## Validation evidence

The implementation evidence must record positive/negative authority and tenant/institution tests,
distinct-actor approval, changed/expired preparation, immutable original admissions, independent
opening/receipt facts, exact replay and injected rollback, correction/receipt/withdrawal races,
caps and generated-artifact drift, migration safety and dump/restore convergence.
Qualify the full publication/receipt workload alongside real attendance in three complete repeated
baseline/mixed comparisons: no failed attempts, unchanged absolute targets and <=20% classroom
p95 degradation. Source-stage measurements are insufficient. Record actual hardware/configuration,
four read-only dispositions, rendered/browser evidence and final `make check` outcome.

## Fallback and exit cost

Keep the local candidate unavailable when a required check fails. Do not weaken source consistency,
raise limits or infer production readiness. Retain published proof facts and repair forward.

## Review triggers

Changed audience/approval/receipt semantics, any failed acceptance criterion, new consumer or
external processor, real records, selected deployment or production use.

## Related records

- [ADR 0045](0045-governed-communications-audiences-and-engagement.md)
- [ADR 0052](0052-private-staff-audience-source-capture.md)
- [ADR 0054](0054-same-writer-nested-admission.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [Threat model](../security/threat-model.md), TM-01, TM-02, TM-09–TM-15, TM-19–TM-22

## Executed checkpoint

The [publication evidence](../phase-2/communications-comm-1-publication-evidence.md) records the
final source/runtime fingerprint, earlier failures, six passing priority comparisons, migration
roundtrip/retained refusal/restore, all four specialist dispositions and `make check` exit 0
(559 core, 82 web unit and 108 browser tests). This Proposed ADR gains no connected-use or
production acceptance from that bounded implementation result.
