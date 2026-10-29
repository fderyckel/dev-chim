# ADR 0035: C25-04 delegated primary-operator acceptance for synthetic L1

- Status: Accepted
- Date: 2026-10-03
- Accountable owner: François — Project Owner
- Decider: Codex, using the requested Jamie board-review perspective under explicit delegated Project Owner authority
- Supersedes: ADR 0025 C25-04's outstanding review prerequisite for synthetic L1; ADR 0034's temporary prohibition on operator persistence/publication pending C25-04
- Evidence: [Completed primary-operator review](../phase-2/c25-04-primary-operator-review.md)

## Context

François requests C25-04 closure using the same delegated review route as C25-02/C25-03 and asks
for a disposition on seven operator rules, the retrospective-review owner, and two deadlines.
The authority is his explicit delegation. Jamie is the requested analytical persona; the actual
author and delegated decider is Codex. This record does not assert personal board service or
invent a qualified human signatory.

ADR 0025 already separates legal operation from ownership, educational containment, accounting,
employment, property, data control, and actor permissions. ADR 0034 accepts the synthetic
educational contract but keeps operator persistence and institution publication blocked pending
this decision. The [completed review](../phase-2/c25-04-primary-operator-review.md) settles the
remaining controls and evidence policy. No application implementation is accepted by this ADR.

## Decision drivers

- Give each published institution one explicit recorded primary legal operator.
- Prevent unreviewed changes, stale activation, fabricated evidence, and self-certified exceptions.
- Preserve learner continuity and history when present accountability is disputed.
- Set concrete ownership and clocks, with stronger responses where risk requires them.
- Keep synthetic product decisions separate from actual jurisdictional validation and release.

## Considered options

1. Retain an unresolved C25-04 decision despite the Project Owner's delegation. Rejected.
2. Treat a persona, a timeout, or a repository test as external governance approval. Rejected.
3. Accept a complete synthetic policy through delegated authority and retain the existing external
   adoption and release gates. Selected.

## Decision

**C25-04 is closed for synthetic L1 on 2026-10-03, disposition `approve`.** Adopt all seven proposed
rules with the explicit controls below and the completed review's evidence, continuity, resolution,
scenario, and verification requirements. No further Project Owner ratification of this contract
is required. Implementation must still prove it before claiming a passing slice.

### Accepted workflow

1. **Initial assignment:** one authorized named action while the institution is unpublished.
   Pending evidence may be recorded in draft; publication requires verified applicable evidence,
   exactly one current operator, current versions and an accepted impact assessment. Initial
   assignment is not a repeated overwrite action or a way to unpublish and evade transfer review.
2. **Published transfer:** a proposal and approval by distinct authorized people, then a separately
   attributable activation. Distinct accounts belonging to one person do not provide separation
   of duties. Approval is bound to the exact proposal, evidence, policy and impact revisions.
3. **Single-controller exception:** permitted only by explicit synthetic policy when one qualified
   decision maker is available. Require fresh stronger assurance, reason, protected evidence,
   visible marking, and a named independent retrospective reviewer and alternate assigned before
   use. The ordinary capability checks and evidence requirements still apply. A missing reviewer
   or overdue unresolved review blocks further exception use.
4. **Effective activation:** the authoritative writer revalidates evidence, approvals and actor
   authority, both entities' applicable status, expected versions and every registered impact.
   Close/open intervals atomically with exact replay protection. Missing, stale, inaccessible,
   revoked, ambiguous or unknown required input blocks activation. Time passing never activates
   a proposal by itself or grants a standing automated-writer privilege.
5. **Revocation:** record an accountability-under-review case, affected-action restrictions and a
   durable alert obligation immediately on credible discovery; preserve recorded operator
   history. Deliver alerts after commit through the transactional outbox. The 72-hour human
   response deadline never postpones the case, restrictions or alert obligation.
6. **Continuity:** teaching, safeguarding, attendance and learner support remain eligible through
   explicit policy unless an applicable suspension direction requires otherwise. Each action
   still needs its normal actor, tenant, capability and module checks. Unknown classification
   fails closed; “essential” cannot be a caller-supplied bypass.
7. **Resolution:** successful reverification, approved transfer, attributable factual correction
   under ADR 0018, or separately authorized suspension/closure only. No generic dismiss button,
   silent successor, automatic rollback, or timeout-driven clearance is allowed.

### Exact owner and deadlines

| Decision | Accepted synthetic value | Clock and enforcement |
| --- | --- | --- |
| Retrospective-review owner | Tenant compliance/governance owner | A named duty assignment with the authority to obtain evidence, commission an independent reviewer, escalate and withhold further exception use; no hard-coded production role |
| Retrospective-review completion | 14 calendar days | Starts at the exception authorization commit, not activation; due at the same local wall-clock time 14 dates later in the institution's recorded IANA zone, persisted as a UTC deadline. For a nonexistent time use the first valid instant after the gap; for a repeated time use the earlier instant. Synthetic fixtures use UTC. Neither weekends, future activation, reassignment nor a new proposal resets it |
| Revocation response | Immediate case/restrictions/alert obligation; documented human reconciliation initiated within 72 elapsed hours | Starts at the earliest recorded credible discovery; case reassignment or later confirmation does not restart it. Applicable shorter emergency or jurisdictional deadlines prevail |

The 14-day review is **completed**, not merely scheduled: a distinct named reviewer assesses
authority, evidence, necessity, conflicts, assurance, impacts and continuity and records uphold,
uphold with remediation, or reject. The owner cannot independently review their own exception;
a qualified independent alternate or external reviewer performs that duty. Review rejection
blocks pending activation or opens under-review reconciliation after activation. It cannot erase
the operator interval or manufacture legal validity.

Within 72 hours the case must contain a named investigator, an initial evidence assessment,
affected-action and learner-continuity assessment, and a dated resolution/remediation plan with
owners. Automatic case creation or an acknowledgement alone does not meet this obligation.
Open cases receive a recorded owner review at least every 24 elapsed hours after initiation;
the plan records a risk-specific resolution deadline. A plan does not restore verified standing.
Missed deadlines escalate to the named governing-body chair or designated accountable executive,
retain restrictions, and require a new recorded remediation decision; they never approve a case.
Unavailability of these named assignments blocks the exception rather than manufacturing an owner.

These are synthetic product defaults, not statutory periods. This decision supersedes the
earlier nonbinding C25-02 Q8–Q10 timing recommendations for this synthetic operator contract.
Real use requires documented jurisdictional applicability and actual duty holders under the
existing adoption gates; policy may shorten the clocks, not silently lengthen them.

### Evidence and meaning

The review's evidence table is normative for synthetic L1: incorporation/status evidence alone
does not prove permission to operate an institution. Establish the exact institution, operator,
jurisdiction, operative instrument, effective dates, conditions, authorization and verification.
Use synthetic evidence only. Default synthetic current-status verification is no older than
30 calendar days at proposal/initial verification and is refreshed at activation/publication;
an instrument's age is not its expiry. Required approvals and conditions must still be satisfied
at the effective boundary. Unknown policy or jurisdiction/type mapping blocks the action.

Full instruments stay in a separately authorized records repository; structure stores classified
metadata and protected opaque references. Audit, outbox, logs and errors never contain full
documents, sensitive URLs or unrestricted copies of protected evidence. The records owner sets
retention, hold, access, correction, export and deletion policy at the real-adoption boundary.

The operator relationship is many institutions to one legal entity: an institution has one active
primary operator, while an operator may serve several institutions. Contained institutions have
their own operator; ordinary units resolve through their nearest containing institution. A
separate under-review verification state preserves the last recorded operator without asserting
that disputed evidence remains valid. Revocation therefore creates an explicit degraded
accountability condition, not fabricated compliance with the verified-operator invariant.

Use the accepted institution-local date intervals, inclusive start/exclusive end, plus UTC
recorded times. Significant time-of-day source requirements remain unresolved until a separate
precision extension is accepted. Late discovery/correction cannot be disguised as an ordinary
backdated transfer. No effect is inferred for payroll, property, contracts, admissions, awards,
immigration sponsorship, records custody, data control, finance or permissions.

### Implementation admission and retained gates

This removes C25-04's **domain-decision** block on bounded private synthetic operator assignment,
publication, proposal/approval/activation and reconciliation proof within Slice 2.1-D and the
authorized delivery sequence. Publication here is an internal synthetic lifecycle state, not a
public endpoint, connected workflow or permission to receive real operational records. The
classroom-first priority remains unchanged. Implement in reviewable increments with applicable
predecessor, security, migration, lifecycle and complete repository checks; a gate decision
neither implements these actions nor proves their controls.

ADR 0034's educational meanings and C25-03-R remain binding. Existing external legal/adoption
validation under ADR 0031, representative validation, C25-05 connected-experience/security review,
C25-06 records/real-data/deployment qualification and identity qualification are not closed.
Before connected or real use, the applicable operator policy must be reviewed with actual
jurisdictional expertise, evidence sources, independent duty holders and continuity/records
arrangements. François owns securing that validation; no fictitious tenant officers are named.
The existing 2026-12-15 or first-affected-boundary review date remains; no new standalone human
ratification is needed to complete the synthetic decision.

## Plain-English summary

### What this means

The synthetic operator contract is settled. Changing the legal organization accountable for a
published institution is a controlled decision, not an editable profile field.

### What was agreed

One person can establish an unpublished institution's initial assignment. A published transfer
normally needs a separate approver. Exceptional self-approval needs independent review within
14 days. Disputed evidence triggers immediate restrictions and human reconciliation within
72 hours while permitted essential learner services continue.

### Context

A school, university or college may keep its identity while its operator changes. A shared site,
brand, corporate parent or educational parent is insufficient evidence of legal responsibility.

### Examples

- A fictional operator runs three schools; each school has one explicit relationship.
- A fictional college transfer approved for a future date fails activation if its evidence expires.
- A revoked instrument opens a visible case; it does not erase yesterday's attendance or transcript.

## Consequences

### Positive

- The seven rules, evidence policy, owner and deadlines have a concrete disposition.
- Independent review, effective-time checks and historical truth are independently testable.
- Learner continuity is assessed explicitly without implying legal authority for new commitments.

### Negative

- Synthetic defaults lack real jurisdictional validation until the retained adoption reviews pass.
- A small tenant must arrange independent retrospective review or cannot use the exception.
- Timer, alert, policy and reconciliation enforcement still require implementation evidence.

## Security, privacy, operability, and migration effects

ADRs 0003, 0005, 0007, 0018, 0023 and 0029, and TM-17/AC-18 remain binding. All reads, proposals,
evidence metadata, decisions, deadlines, audit, outbox facts and cases are tenant-qualified.
Use trusted actor/placement, current capability/module/assurance checks, PostgreSQL concurrency,
idempotency and atomic history. Retrospective review does not waive these controls. No scheduler,
external records connector, authentication provider, business route or real-data migration is
authorized by this documentation change. Sources A–F remain synthetic compare-only evidence;
incomplete operator history remains explicitly unknown.

## Validation evidence

The [completed review](../phase-2/c25-04-primary-operator-review.md) records the reviewed sources,
scenario dispositions, required negative implementation proof, and actual documentation checks.
Repository checks validate the documents; they do not constitute independent domain approval.

## Fallback and exit cost

If the controls cannot be enforced, keep synthetic institutions unpublished and operator
proposals inactive while preserving drafts and evidence history. Do not fall back to a generic
editable operator field. Stable institution/entity IDs and separate evidence/decision records
allow policy or workflow replacement without rewriting learner or legal history.

## Review triggers

Revisit through a superseding ADR if actual jurisdictional review rejects the evidence mapping,
single-controller exception, time precision or continuity policy; if no independent reviewer can
be assigned; or if implementation cannot enforce current evidence, immediate restrictions,
atomic intervals, deadline obligations or non-authority without weakening the contract.

## Related records

- [ADR 0025: institutional structure](0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0034: synthetic educational acceptance](0034-c25-03-delegated-educational-structure-acceptance.md)
- [ADR 0018: temporal correction and evidence](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0029: provider-neutral identity and assurance](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [C25-04 completed review](../phase-2/c25-04-primary-operator-review.md)
- [Phase 2 entry register](../phase-2/entry-decision-register.md)
- [Threat model](../security/threat-model.md)
