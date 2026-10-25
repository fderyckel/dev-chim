# ADR 0053: People-owned source write fence

- Status: Proposed
- Date: 2026-10-25
- Accountable owner: People and platform engineering
- Deciders: François — Project Owner; independent security/privacy review before connected use
- Implementation authority: François explicitly authorized this scoped fence, ADR, tests,
  unchanged classroom-impact trials and delegated review on 2026-10-25; publication and
  `make check` remain deferred
- Supersedes: None; supplements ADR 0036's private write boundary and replaces only the
  redundant People-row locking composition of Proposed ADR 0052

## Context

The [staff-source checkpoint](../phase-2/staff-audience-source-evidence.md) passed functional
checks but exceeded the retained 20% classroom p95-impact limit in all three measured repeats.
Its source transaction locks participation/person/association rows and the institution parent;
classroom assignment and attendance require overlapping rows. The
[bounded follow-up](../plans/communications-source-lock-contention-proposal.md) requires measured
blocking attribution and a People-owned actual-write fence before removing redundant locks.

Named People operations already acquire the tenant's `people.core` lifecycle transaction lock.
Alternate SQL writes did not participate in that owner boundary. Repeated snapshots or locking
only returned rows cannot protect missing/new records. Broader authority/session redesign,
increased capacity/caps or relaxation of the acceptance threshold are outside this authorization.

## Decision drivers

- Keep complete People-source stability through the owner callback and transaction commit.
- Cover ordinary alternate writes, insertions, ending, profile changes and link revocation.
- Allow classroom reads/writes that do not change People sources to progress concurrently.
- Preserve current tenant, purpose, module, capability, session and frozen admission semantics.
- Keep the 25-person/traversal bounds, two-second budget, READ COMMITTED and 20% p95 limit.

## Considered options

1. Retain broad source row/parent locks. Preserves existing evidence but failed the impact limit.
2. Remove locks and compare snapshots. Rejected: leaves phantoms and a post-comparison race.
3. Introduce a new global lock/service or wider authority/session mechanism. Outside scope.
4. Enforce the existing tenant People fence at the actual write boundary, then remove only
   redundant People-source row locks. Selected for the explicitly authorized local proof.

## Decision

Add private SQL `people_source_lock(uuid)` using the exact existing transaction advisory key
`platform-module-lifecycle:<tenant UUID>:people.core`. Missing tenant is refused. This supplies
synchronization only; it grants no authorization or membership and returns no source data.
It does not impose a new isolation/deadline contract on existing writers.

Install a separate `BEFORE INSERT OR UPDATE OR DELETE` trigger on `people_persons`,
`people_participations` and `people_staff_account_associations`. Its name sorts before each
existing semantic guard, so the source fence precedes proof checks and foreign-key parent
acquisition. UPDATE locks distinct old/new tenant keys in sorted order, even though existing
semantic guards subsequently reject a tenant move. DELETE takes the old tenant fence before
the existing retained-history refusal. Existing semantic guards remain intact. TRUNCATE is a
separate operator action: PostgreSQL's AccessExclusive relation locks conflict with the source
reads' retained AccessShare locks, so it cannot change captured tables before commit. Qualify
that ordering with a rollback-only probe; add no new truncation or cleanup policy here.

The reader first validates context, purpose, current acting session and existing module gates.
It explicitly calls the new SQL primitive so a database missing this expansion fails closed.
After the People fence, use ordinary READ COMMITTED reads of person, participation and
association sources. Capture the institution once with `FOR SHARE`, preserving current published
status/time-zone stability while remaining compatible with ordinary classroom parent reads.
No People row lock is acquired after the owner fence: an alternate writer may already hold its
target row while awaiting the trigger's advisory lock. Re-read time and retain all fences through
the owner callback/commit. Future starts/endings and local midnight still invalidate by time.

Membership, assignment, role/inclusion/grant/capability, account, module/dependency, origin and
acting-session protection remain unchanged. The original tenant/account/actor/principal marker/
association/participation/membership basis, offline recipients, frozen denominator and current
eligibility remain unchanged. No new source selector, browser route, general directory or
publication action is introduced. A lock never grants notice access or proves a human identity.

Arbitrary explicit pre-locks or multi-tenant writes can still deadlock. PostgreSQL must abort a
victim; the whole owner transaction rolls back and returns a bounded dependency failure. There
is no partial audience or best-effort acceptance. Privileged trigger disabling, DDL and restore
remain operational trust boundaries, as with the account fence.

## Plain-English summary

### What this means

An audience check keeps staff-source records stable without unnecessarily locking records that
ordinary classroom work only needs to read. Real People changes wait until that check finishes.

### What was agreed

Implement and qualify only this private source prerequisite, then have the specialists review.
The 20% classroom-impact limit remains binding. Publication and the full repository check are
not part of this instruction.

### Context

Passing correctness checks did not satisfy the separate requirement to protect classroom work
from source-check contention.

### Examples

- Illustrative: inserting or ending staff participation waits for a held audience source check.
- Illustrative: ordinary class setup and attendance can read stable People rows without waiting
  on the source's former People row locks; independent authority/session checks still apply.
- A failed race, deadline or performance trial leaves publication unavailable.

## Consequences

### Positive

- Named and ordinary SQL writes share the same existing tenant-scoped source boundary.
- Source readers no longer need conflicting People row locks to prevent new-row phantoms.
- Existing semantic, authorization and retention rules remain separately enforced.

### Negative

- All People writes in a tenant share that tenant fence, including unrelated People records.
- A caller that pre-locks arbitrary parents can still create a deadlock or timeout.
- Database-local locks do not establish cross-placement/cross-database source consistency.
- Reduced row contention does not guarantee that the unchanged performance target will pass.

## Security, privacy, operability, and migration effects

Declare functions/triggers in the People Ash resource and generate the migration/snapshot.
Inspect ordering and apply with a two-second DDL lock timeout. No column, ID, source version,
tenant key, foreign key, index, timestamp, audit/outbox fact or retained record is rewritten.
Keep old semantic guards installed. Empty rollback/reapply is allowed; down refuses retained
People rows and requires forward repair. Down takes all three relation locks before checking
emptiness, so concurrent insertion cannot race that check. Removing the primitive makes the new reader fail
closed, rather than silently reverting to unfenced reads. Qualify old named/SQL write shapes.

Keep measurements aggregate-only: operation counts, timings, source-stage query categories and
blocking outcomes. Do not log names, records, credentials, proof contents, tokens or tenant/actor
identities. Selected deployment, production migration/restore, representative evidence and
independent security/privacy review remain separate. No event consumer or delivery is added.

## Validation evidence

Record executed results in [write-fence evidence](../phase-2/people-source-write-fence-evidence.md).
Required: before/after controlled classroom assignment and actual attendance blocking probes;
source-stage timing attribution; named and alternate inserts/updates/deletes, invalid/missing
tenant, old/new tenant ordering, rollback-only truncate serialization, cross-tenant progress, existing semantic
denials, FK/reverse-order deadlock and whole-operation rollback; empty migration rollback/reapply,
retained preservation/refusal; full source/identity/classroom/attendance regression; and at least
three unchanged-load comparisons for both foundation and actual attendance workloads. Keep the
20% p95-impact limit, original source caps and absolute targets. Planned tests are not results.
All four specialists review the resulting checkpoint; no publication or `make check` is run.

## Fallback and exit cost

If correctness, migration or retained performance fails, keep the private candidate unqualified
and publication stopped. Repair forward while People rows remain. Do not remove independent
authority/session locks, add capacity, weaken caps, truncate the audience or relax the 20% limit
under this authorization. A wider contract needs a smaller explicit decision.

## Review triggers

- Failed source race, migration, deadline or classroom-impact trial.
- Wider authority/session locking, another source store, movement, restore or cross-database use.
- Publication, real data, connected use, representative review or release.

## Related records

- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [ADR 0052](0052-private-staff-audience-source-capture.md)
- [ADR 0051](0051-private-account-principal-binding-marker.md)
- [ADR 0047](0047-private-identity-account-source-fence.md)
- [ADR 0045](0045-governed-communications-audiences-and-engagement.md)
- [Threat model](../security/threat-model.md), TM-01/TM-02/TM-09/TM-11–TM-15/TM-19–TM-22
