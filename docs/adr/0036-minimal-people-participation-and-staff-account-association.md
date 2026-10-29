# ADR 0036: Minimal people, participation and staff-account association

- Status: Proposed
- Date: 2026-10-04
- Accountable owner: Product and platform engineering
- Deciders: François — Project Owner, with domain records and security/privacy review
- Implementation authority: François's “green light on next slice” authorizes the bounded private synthetic increment described here; it does not constitute representative review or acceptance of the wider People domain
- Supersedes: None

## Context

The classroom-first programme needs a student who need not sign in, a staff member who may also
be a student, and an explicit association between a staff person and an existing account. CF-1
already supplies the stable institution reference. Account identity and tenant authority exist
independently. This record defines the implementation contract before the authorized synthetic
persistence work; its wider architectural acceptance remains Proposed.

## Decision drivers

- Deliver the smallest records needed by subsequent enrolment and teaching-assignment work.
- Preserve independent person, participation, account and permission lifecycles.
- Keep personal information out of events and avoid a general people directory.

## Considered options

1. One user record with a student/teacher role: conflates accounts, people and authority.
2. A general relationship or HR engine: exceeds the classroom scope.
3. A tenant-owned person, two explicit participation meanings, and a verified staff-account
   association: selected for this bounded synthetic implementation.

## Decision

Implement `people.core` v1.0.0, dependent on `institution.structure`, as a private synthetic
foundation. No public route, UI-to-core write, identity provisioning or real personal data is
authorized. Before connected use, the deciders must accept the domain, representative workflow,
records-retention/erasure and account-verification policy with independent review.

`Person` is tenant-owned, with an immutable UUID and a minimal current display name. The display
name is mutable operational profile data, changed only by `revise_person_name` with expected
version and the reason `name_correction`. It is not a legal-name record or historical identity
assertion. This increment does not expose name history, legal names, birth dates, contact data,
national identifiers, medical information or safeguarding notes. Names are never deduplication
keys; duplicate names are valid. Merge, erasure and duplicate resolution are deferred.

`Participation` records an exact person and published root institution, the explicit meaning
`student` or `staff`, institution-local start date, optional exclusive end date, and a protected
source reference. `record_student_participation` and `record_staff_affiliation` are separate named
actions and capabilities. A person may hold both meanings and may participate at multiple
institutions. This is neither year enrolment nor employment, payroll, teaching assignment or a
role. Initially there is at most one record per person/institution/meaning; returning after an
ended record requires a later reviewed succession action. Start and supplied end dates are
immutable; `end_participation` can close an open interval prospectively, including today, with
expected version. It cannot backdate an ending or rewrite an already-ended interval. A recorded
start in the past is a present-day baseline observation, never invented recorded-time history.

`StaffAccountAssociation` connects one staff participation to one existing tenant membership.
The stable technical actor is the provider-neutral actor already identified by that membership;
the person remains tenant-owned. At most one unrevoked association exists per person and per
membership within a tenant. The same actor may have a distinct, explicitly verified person
association in another tenant. The database and action bind participation, person and membership
to the same tenant. Neither email nor a provider profile/group may select or verify a person.

`associate_staff_account` requires current staff participation on the institution-local date and
a fresh exact-bound proof from a startup-configured verifier. The synthetic policy
`synthetic.people.staff_account.v1` binds tenant, person/version, participation/version,
membership/actor, protected evidence reference and the writer timestamp. The adapter must confirm
a human account and the person-to-account match; a UUID reference alone is not proof. There is no
production/default adapter. The only supplied adapter lives in test support. Missing, mismatched,
revoked or extra-field proof is refused. `revoke_staff_account_association` records one attributable
irreversible revocation and permits a later separately verified association. No action creates or
changes membership, roles, capabilities, external identity links or sessions.

Current account resolution rechecks membership existence, unrevoked association and effective
staff participation on the writer. Ended/future participation is not current. Ending/unlinking
does not revoke unrelated capabilities or erase domain history; every later classroom action
must independently enforce its current teaching assignment and capability.

Reads are exact-ID operations only: person, participation and current staff association for one
membership. Their separate tenant-wide administrative capabilities are explicit; no ancestor,
staff link or institution label supplies authority. There is no list, search, count, traversal,
roster, export or history endpoint. Classroom-scoped reads need their own contract.

The outbox storage boundary expands only for the three `people.core` aggregate types: their
events must be Restricted, while existing platform/domain events retain Internal classification.
The existing dispatch/consumption boundary stays Internal-only and must refuse these Restricted
events; no people subscription or automatic delivery is added. A later qualified consumer must
implement Restricted handling before this durable backlog can be consumed. This is an additive
synthetic storage qualification under ADR 0007, not approval for a production consumer.

Every mutation uses current module gates and writer authorization, optimistic versions where
state exists, actor/request-bound idempotency, and atomic state/audit/outbox/result recording.
Database guards protect identity, one-way end/revoke transitions and compound references.

## Plain-English summary

### What this means

The school can record a student without creating an account. A staff record can be connected to
an existing account only after the person-to-account match has been verified.

### What was agreed

The Project Owner authorized this small synthetic implementation. The broader People decision
and real-data policies still require review. Student/staff records do not grant access.

### Context

A learner, a person's account and their permission to take attendance answer different questions.
Keeping them separate prevents record setup from accidentally granting school-data access.

### Examples

- A synthetic student has a person and participation record, with no login.
- A synthetic staff member also studies at the institution; the same person has both records.
- A future guardian-plus-staff or educator-plus-guardian person remains one tenant person; guardian
  relationships and their access rules are deliberately not implemented here.
- A name or email coincidence cannot connect someone else's account to that person.

## Consequences

### Positive

- Provides stable person and participation IDs for the classroom programme.
- Avoids implicit account provisioning, role grants and premature HR complexity.

### Negative

- No general directory or preparation screen is delivered by this increment.
- Re-entry, disputed identities, merge, retrospective correction, guardians and name history need
  later named contracts. Those are limitations, not generic update escape hatches.

## Security, privacy, operability, and migration effects

Treat the records and their derived event payloads as Restricted, even though all fixtures are
synthetic. Events contain only identifiers, version and action kind; no names or proof contents.
Only protected UUID references and bounded proof metadata are stored. No reference is dereferenced
as a caller-supplied URL. Actor, tenant and placement always come from trusted context.

Synthetic retained rows and audit/outbox/idempotency evidence block rollback. No deletion or
retention-period claim is made. Before real data, records/privacy owners must settle retention
start/duration, legal holds, lawful erasure, unlink/merge history, backup convergence and protected
proof access. The three new tables are additive, with tenant-qualified references and partial
uniqueness for unrevoked account associations. No backfill, partitioning or new service is needed.

## Validation evidence

The implementation must prove positive actions plus missing context, wrong tenant, unauthorized
actor, inactive module/dependency, stale version, changed replay, concurrent conflicting links,
invalid dates, unverified person/account matches, ended staff resolution, direct-write rejection,
redacted events, and transaction rollback after the outbox write. Record actual results in the
[people foundation evidence](../phase-2/people-foundation-evidence.md), including `make check`.
Tests do not substitute for representative or independent review.

## Fallback and exit cost

Keep this private until its checks pass. Retain the prior foundation if this candidate fails;
never enable a generic people write as fallback. Empty synthetic migrations can roll back;
retained records require forward repair or an approved recovery point.

## Review triggers

- Enrolment/classroom adoption: product and educational records owners.
- Account proof, scope, person merging or identity correction: security/privacy and domain owners.
- First connected workflow or real data: named deciders, representative and independent review.

## Related records

- [Classroom-first plan](../plans/classroom-first-six-week-plan.md)
- [People and identity proposal](../plans/phase-2-identity-people-relationships-and-access-proposal.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0023](0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [Threat model](../security/threat-model.md), TM-01, TM-02, TM-09–TM-15, TM-18 and TM-19
