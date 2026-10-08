# ADR 0041: Local attendance correction and request recovery

- Status: Proposed
- Date: 2026-10-07
- Owners: Product and platform engineering
- Decision scope: Disabled local synthetic classroom workflow only
- Depends on: ADR 0018, ADR 0030, ADR 0037, ADR 0038
- Supersedes: None

## Context

ADR 0038 proves one immutable daily attendance submission but deliberately leaves correction and
recovery for a later named increment. The classroom-first plan makes this the next bounded slice.
An educator needs to repair a wrong mark without rewriting the submitted register, losing the
original attribution, silently accepting a stale screen, or creating a second source of truth.

Representative policy has not settled backdating, correction after an assignment ends, absence
reasons, or free-text explanations. The existing Restricted outbox also has no qualified
Restricted consumer. Those boundaries must remain visible rather than being implied by a local
synthetic demonstration.

## Decision drivers

- Preserve the submitted register and every later correction as durable domain history.
- Give the classroom one unambiguous current register without hidden latest-row behavior.
- Reject stale and concurrent writes instead of merging correction branches.
- Revalidate current session, capability and teaching authority at the domain boundary.
- Recover truthfully after a lost response through idempotency and an authoritative read.
- Keep reason policy, backdating, history disclosure and Restricted consumers outside this slice.

## Considered options

1. Update the original submission in place and rely on audit. This erases the prior domain meaning
   and cannot provide an authoritative correction chain.
2. Store only changed marks as adjustments. This reduces payload size but makes every current read
   dependent on replaying a partial chain and complicates bounded recovery.
3. Append one complete immutable successor register with its exact predecessor and stable reason:
   selected. The maximum roster is sixty, so the bounded complete replacement is small and keeps
   each revision directly inspectable.

## Decision

Add `classroom.attendance.correct` as a separately authorized named action in the existing
`classroom.attendance` module. It applies only to today's already-submitted register for a class
that the current session is still assigned to teach. The action requires a complete replacement
set of Present, Absent, or Late marks, the exact current attendance revision, the fixed synthetic
reason code `marking_error`, an idempotency key, and a causation ID. It accepts no arbitrary date,
free text, absence detail, tenant, actor, roster, or calendar input.

The original submission remains immutable. Each correction is an immutable successor row linked
to the root submission and, after the first correction, to the exact previous correction. A
monotonic correction number orders the chain. The writer locks the root submission, resolves the
current successor, compares the caller's expected revision, rejects branches and no-op
corrections, and stores a complete replacement marks map. A database trigger validates the
tenant-qualified single chain and refuses update or deletion. This local proof permits at most ten
corrections per register; exceeding the bound fails closed for accountable follow-up.

The authoritative classroom read resolves marks from the latest correction and otherwise from the
original submission. It returns the current revision ID, correction number, and current correction
reason. It does not expose the full correction history. A later history view requires its own
authorization and disclosure decision under ADR 0018.

Correction revalidates the current application session, module activation, distinct
`classroom.attendance.correct` capability, staff-account association, staff participation, and
teaching assignment inside the writer transaction. A former educator cannot correct the register
solely because they submitted or previously taught the class. The correction uses the original
pinned roster, calendar revision, local date, and roster basis; later placement or calendar changes
do not add, remove, or reinterpret people in that historical register.

Correction state, minimal audit, Restricted outbox fact, and exact idempotency result commit in one
transaction. The event contains identifiers and correction number, never names, marks, or free
text. An exact authorized retry returns the original receipt. A changed retry conflicts. After an
uncertain response, the UI tells the educator to reload the class; an authoritative read shows the
committed revision or the unchanged predecessor. The same retained request may then be retried.

Restricted event delivery remains outside this increment. The repository's current dispatcher is
Internal-only, so this slice proves durable event creation and transaction recovery but makes no
consumer-delivery or downstream-reconciliation claim.

The browser keeps the route disabled by default and uses the existing local synthetic HTTPS,
session, exact-origin, and session-bound CSRF controls. A saved register has an explicit Correct
attendance action. The correction form starts from the authoritative current marks, identifies the
reason, and requires a deliberate save. Conflicts and connection uncertainty require reload rather
than an optimistic success message.

## Plain-English summary

An assigned synthetic educator can fix a mark in today's saved register. The original register and
every prior correction remain stored. If another correction wins first, the stale screen cannot
overwrite it.

## Consequences

### Positive

- The classroom workflow can recover from a marking error without mutating the submitted record.
- Exact revision comparison makes concurrent correction behavior visible and deterministic.
- Current UI state comes from PostgreSQL after the action rather than from an optimistic client.
- Idempotent retry and authoritative reload give a bounded recovery path after a lost response.

### Negative

- Only today's assigned educator and the synthetic `marking_error` reason are covered.
- Full correction history is retained but has no browser history screen in this slice.
- The ten-correction ceiling requires human follow-up if reached.
- Restricted outbox consumer recovery is still unqualified.

## Security, privacy, operability, and migration effects

The new table is additive, tenant-qualified, append-only, and linked to the existing submission by
a compound tenant foreign key. It stores IDs, complete marks, the stable reason code, sequence, and
recorded time; it copies no names. Exact input and roster bounds remain one class and at most sixty
people. Audit and event payloads remain minimized. Retained correction, audit, outbox, or
idempotency evidence blocks rollback and requires forward repair.

## Validation evidence required

Prove original retention and authoritative current reads; first and subsequent correction;
idempotent replay; stale and concurrent correction conflict; capability, session, assignment,
tenant and class denial; pinned roster after placement change; invalid, incomplete, extra, no-op
and over-limit input; transaction rollback after correction insert; exact HTTP origin/CSRF and
input handling; browser success, reload recovery, keyboard and narrow layout; generated OpenAPI
drift; migration constraints and rollback refusal. Run `make check` and report every failure and
skipped stage separately.

## Fallback and exit cost

Keep the correction route and control disabled with the classroom workflow if qualification fails.
Never fall back to in-place submission updates, a client-selected actor or tenant, a generic update
endpoint, or an optimistic corrected label. Retained corrections require forward repair.

## Review triggers

Representative reason vocabulary, correction by administrators, backdating, correction after an
assignment ends, more than ten corrections, history or export UI, Restricted consumer delivery,
real identity, real records, pilot, or deployment.

## Related records

- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0037](0037-class-register-enrolment-and-placement.md)
- [ADR 0038](0038-local-classroom-attendance-workflow.md)
- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [Classroom slice contract](../phase-2/classroom-first-slice-contract.md)
- [Threat model](../security/threat-model.md)
