# ADR 0052: Private staff-audience source capture

- Status: Proposed
- Date: 2026-10-24
- Accountable owner: People and platform engineering
- Deciders: François — Project Owner; independent security/privacy review before connected use
- Implementation authority: François authorized completing recipient eligibility qualification
  after the selected binding prerequisite, then specialist review before publication work
- Supersedes: None; implements the source checkpoint under Accepted ADR 0045 and supplements
  ADRs 0036, 0047 and 0051 without adding a communications publication boundary

## Context

The [remaining qualification plan](../plans/communications-audience-source-qualification.md)
requires an exact-institution source that keeps the complete intended and admitted account basis
stable through an owner callback. The concurrent [binding prerequisite](0051-private-account-principal-binding-marker.md)
distinguishes account reassignment from ordinary credential changes. Existing exact-ID People
reads and the account lock alone do not provide the composed source contract.

## Decision drivers

- Resolve only authoritative, current exact-institution staff records.
- Preserve offline recipients and frozen original account admission identities.
- Fence missing rows, inserts, endings, replacement identities and permission changes.
- Bound source traversal, transaction duration and preparation lifetime without truncation.

## Considered options

1. Reuse demo data, role labels or a caller-supplied recipient list. Rejected as non-authoritative.
2. Compare ordinary read snapshots twice. Rejected because changes can commit after comparison.
3. Compose existing writer/row/parent/account locks in a private People-owned source. Selected.

## Decision

Trusted startup fixes one exact institution. Validated writer context fixes tenant, actor and
placement; the server purpose is `communications.staff_audience`, with dedicated capability
`people.core.audiences.prepare_staff`. No browser route, directory, new business module or
caller-selected institution, person, role, date, source version or account is added.

The source owns its complete READ COMMITTED transaction. It sets a two-second server deadline
before locks and independently checks a monotonic deadline before and after its callback and
before returning to the transaction owner. That deadline includes time already spent in the
transaction and preserves a shorter pre-existing transaction timeout; resetting the server timer
cannot restart this budget. It validates and holds the acting opaque session and its origin,
composes People and dependency lifecycle locks, locks source parents/rows and the bounded reachable authority graph,
then acquires the complete account actor fence once. Account reads after that fence use ordinary
MVCC, never recipient account row locks. Reauthorize after the full fence and retain locks through
the owner's callback and transaction completion. Dependency failure rolls back the whole operation.
Deadlocks remain possible with competing source owners and are retryable whole-operation failures,
not partial audience acceptance. No wider source-writer refactor is authorized.

Capture a canonical private source basis and draft/receipt digest. Source equality and preparation
expiry are checked by a fresh complete capture, never by trusting a submitted proof. Preparation
expires at the earlier of five writer-clock minutes or the next institution-local midnight.
The transaction ends sooner at acting-session expiry or local midnight. Time calculations use
PostgreSQL writer time and the locked institution time zone; deterministic DST tests and actual
short-deadline rollback are distinct evidence.

Intended subjects are current staff, deduplicated by person, capped at 25. Account admission binds
the original person, participation, verified association, membership, actor, account and principal
binding marker. Pending, absent or suspended accounts are not admitted. Current notice capability
is a separate eligibility condition; no recipient session is required. Later provisioning,
activation, replacement association/membership or account reassignment cannot backfill an original
admission. Current denial never erases the original intended denominator. Same-actor credential
rotation preserves admission identity while current checks still apply.

Bound traversal at 100 institution staff participation rows, 64 reachable roles and 256 authority
edges/assignments/grants. Overflow fails closed; it never selects a partial audience. The callback
receives only a private classified value, with redacted inspection. Public summaries contain counts
only. This value is not durable publication preparation, approval, a notice-read entitlement or
a browser token. Durable communication storage and publication remain unimplemented.

## Plain-English summary

### What this means

The internal check can establish exactly which staff are intended and which original account
bindings can qualify, while keeping those records stable until the check finishes.

### What was agreed

Complete and test this local synthetic prerequisite, then obtain specialist review. Publication
screens, notices, receipts, real data, connected use and release retain their separate boundaries.

### Context

Staff records, accounts and permissions can change while a notice is being prepared.

### Examples

- An offline eligible staff account can qualify without an active recipient session.
- A staff member without an account remains intended but is not retroactively admitted later.
- A changed audience or draft requires fresh preparation rather than silent acceptance.

## Consequences

### Positive

- Current source checks compose existing owners without a generic people directory.
- Original admission and current eligibility remain distinct and testable.

### Negative

- Bounded source locks can delay competing writes; deadline and mixed-classroom checks are required.
- This source-stage proof cannot demonstrate durable approval or publication atomicity.

## Security, privacy, operability, and migration effects

Tenant, actor, session, placement, purpose, module and capability checks fail closed. Source data
inherits Restricted classification; names, email, proof contents, passwords and session material
stay out of logs, review packets and committed evidence. This source adds no database table or
migration; the separate identity prerequisite owns its generated migration and preservation proof.
No side-effect consumer, notification, public endpoint or authentication handoff is added.

## Validation evidence

Record actual denial, cardinality, date/expiry, identity replacement, source-writer race,
whole-transaction rollback and three-run source/classroom workload evidence in the
[checkpoint](../phase-2/communications-comm-1-source-fence-qualification.md). Record the exact
focused checks and four independent AI specialist dispositions. Publication/correction/receipt
workload, browser/accessibility and production readiness are not established by this checkpoint.

## Fallback and exit cost

Keep publication unavailable if a source boundary or acceptance target fails. Do not widen caps,
change source-writer isolation, infer recipients, truncate an audience or weaken the frozen basis.
Removing the private capture creates no domain-data migration.

## Review triggers

- Broader audiences, another source store, new authority semantics or a source-writer refactor.
- Failed race, deadline, stale-basis or mixed-classroom acceptance checks.
- Publication implementation, real records, independent review or selected deployment.

## Related records

- [ADR 0045](0045-governed-communications-audiences-and-engagement.md)
- [ADR 0047](0047-private-identity-account-source-fence.md)
- [ADR 0051](0051-private-account-principal-binding-marker.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [Threat model](../security/threat-model.md), TM-01, TM-02, TM-09, TM-11–TM-15, TM-19–TM-22
