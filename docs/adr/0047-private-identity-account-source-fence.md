# ADR 0047: Private identity-account source fence

- Status: Proposed
- Date: 2026-10-23
- Accountable owner: Identity and platform engineering
- Deciders: François — Project Owner, with security/privacy review before connected use
- Implementation authority: François explicitly authorized the scoped account-fence prerequisite,
  its ADR, implementation, focused tests and delegated checkpoint review on 2026-10-23. The
  focused checkpoint excluded the full gate; the final coordinator integration later ran it
- Supersedes: None; adds a serialization prerequisite without rewriting Accepted ADR 0044's
  credential lifecycle, authorization or release decisions

## Context

Accepted ADR 0045 requires a complete account basis to remain fenced through an audience
transaction's commit. The [first COMM-1 checkpoint](../phase-2/communications-comm-1-source-fence-qualification.md)
demonstrates that a people lifecycle lock plus existing account row locks cannot protect a missing
account: the named credential writer can provision it while those locks remain held.

Accounts are global actor identities. School participation, tenant membership, capability and
session validity remain separate. This prerequisite supplies synchronization, not audience
resolution or authentication. The wider source-fence matrix still gates publication work.

## Decision drivers

- Protect both existing accounts and their absence for a bounded, verified actor set.
- Cover actual account writes, including paths that do not call a new application helper.
- Preserve credential behavior, global identity, tenant authority and READ COMMITTED source reads.
- Avoid a global table lock, generic directory, new service or source-writer refactor.
- Bound held audience transactions and keep failures separate from successful publication.

## Considered options

1. Lock returned rows or compare hashes twice. Rejected by the missing-account counterexample.
2. Add cooperative locks only to `LocalCredentials`. Rejected because bootstrap, Ash and alternate
   SQL writers could bypass them.
3. Lock the entire account table or change isolation. Rejected for wider interference or changed
   source contracts.
4. Enforce actor-scoped transaction locks at the account database write boundary, with a private
   bounded reader primitive using the identical key. Selected for the authorized local proof.

## Decision

Add `identity_account_source_lock(uuid[])`, taking transaction-scoped advisory locks for distinct
actor UUIDs in sorted order, using the namespace `identity-account-source:`. The array is bounded
at 25 with no null entries. An empty source set is allowed. Hash collisions can serialize unrelated
actors but cannot omit protection; no capacity or production latency claim follows.

A `BEFORE INSERT OR UPDATE OR DELETE` row trigger on `identity_accounts` acquires this lock for
the new actor, old actor, or both old/new actors respectively. This covers provisioning, activation,
reissue, suspension, failed-attempt state, bootstrap and permitted actor changes at their actual
write boundary. It also covers ordinary direct SQL. It adds no new action, permission, deletion
or account-replacement policy. Reject `TRUNCATE`, which cannot use a row-scoped actor fence.
Privileged DDL, trigger disabling, replication and superuser behavior remain operational trust
boundaries, not an application authorization mechanism.

The private `AccountSourceFence.lock_current_transaction/2` primitive requires a validated trusted
execution context, an existing READ COMMITTED writer transaction, current caller membership and
current tenant membership for every supplied source actor. Callers must already own writer routing
and domain/purpose/capability/module authorization; this primitive grants none and returns no
account rows or eligibility decision. It has no route or browser-supplied selector. Missing or
foreign membership fails without revealing account existence. Same global actor in two tenants
intentionally uses one lock; unrelated actors can proceed independently.

Acquire the complete actor set in one call before reading account identity/status/version. Use
ordinary MVCC account reads while held; **do not add account row locks after this fence**. An
updater can already own a row lock while waiting in its trigger, and reversing that order would
introduce a deadlock. The source owner must preserve this order when composing its full fence.
Multi-row administrative SQL and intersecting source sets can still deadlock; PostgreSQL aborts
a victim and the owner must roll back the complete operation, never partially accept a source.

The reader primitive sets a local server transaction timeout to enforce the two-second budget,
counting time since the transaction began, including lock acquisition and idle time. It must not
extend an already shorter timeout or restart the budget on a second call. The private proof
requires PostgreSQL's `transaction_timeout` support (17+; actual local version recorded with
evidence); an unavailable setting fails closed. Existing credential writers gain no new total
deadline or isolation requirement from the trigger. The private primitive returns only a typed
dependency failure on database/lock failure. The enclosing owner must roll back on failure and
reconcile an unknown commit response rather than call it a proven rollback. This prerequisite
does not implement communication outcomes or retries.

## Plain-English summary

### What this means

An audience check can briefly keep a particular person's account basis stable even when that
person has no login account yet. Account creation waits until that check finishes.

### What was agreed

Only the local engineering prerequisite is authorized. It grants no access to a notice, creates
no staff relationship and adds no account-administration screen or public endpoint.

### Context

An account appearing during an approval could make its source evidence stale. Locking only
accounts already found cannot prevent that.

### Examples

- Illustrative: account provisioning waits while the same actor's source check is held.
- Illustrative: a different actor's credential operation continues independently.
- A newly created pending-first-login account still cannot be treated as an active recipient.

## Consequences

### Positive

- Existing and absent accounts share one write-enforced fence without a global table lock.
- Identity changes lock both actor identities in a defined order.
- No names, emails, passwords or tokens are needed by the lock primitive.

### Negative

- All writes to an affected actor's account can wait, including sign-in attempt bookkeeping.
- Advisory locks are database-local, so this does not qualify cross-database global identity.
- Correct reader lock order, whole-operation deadlines and rollback/error handling remain required.
- A server transaction timeout terminates its connection; pools must reconnect, and callers must
  not mistake this for a successful action or disclose a raw dependency error.

## Security, privacy, operability, and migration effects

The Ash resource owns the custom function/trigger declarations and generated migration/snapshot.
No account fields, identifiers, constraints, indexes, tenant keys, audit facts or retained rows
are rewritten. Accounts remain global; tenant-owned source selection remains tenant-qualified.
The expand migration installs functions/triggers under a finite DDL lock timeout. Old application
writers are covered by database enforcement. Down migration refuses retained account rows;
empty synthetic rollback/reapply is required. Retained installations use reviewed forward repair.
An old database without the function makes the new primitive fail closed; this is not a rollout
or selected-deployment compatibility claim.

A lock creates no business event, new authority or receipt. Existing named actions retain their
own authorization, audit/outbox, token invalidation and credential handling. Same-ID password
rotation is not new account admission; lockout alone does not revoke a valid session. No real
identity material or generated password/token enters logs, committed fixtures or review packets.
An original account ID with a different actor is not the original principal: the remaining
audience qualification must bind account/actor/association/participation/membership together and
deny old-chain access after rebinding. This fence does not implement or waive that admission test.

## Validation evidence

Implementation and results belong to the updated
[source-fence checkpoint](../phase-2/communications-comm-1-source-fence-qualification.md).
The [account prerequisite evidence](../phase-2/identity-account-source-fence-evidence.md) records
actual checks and delegated review separately from remaining audience work.
Required focused evidence: missing-row provisioning before/during/after the fence; activation,
reissue, suspension and same-ID rotation; bootstrap/old-new actor changes; alternate SQL writes;
unrelated-actor/tenant progress; context/membership/isolation/size denials; deadlock and total-time
rollback; generated migration drift; empty rollback/reapply and retained rollback refusal;
existing credential and people regressions. Unexecuted checks must remain labelled not run.
All four AI specialists review the resulting checkpoint before any COMM-1 resumption.

PostgreSQL references: [transaction timeouts](https://www.postgresql.org/docs/18/runtime-config-client.html#GUC-TRANSACTION-TIMEOUT),
[transaction advisory locks and deadlocks](https://www.postgresql.org/docs/18/explicit-locking.html#ADVISORY-LOCKS),
and [trigger behavior](https://www.postgresql.org/docs/18/trigger-definition.html).

## Fallback and exit cost

If qualification fails, leave publication work stopped. Do not fall back to repeated account
reads, row-only fencing or a global lock. Repair the functions/trigger forward when accounts are
retained; removing the primitive adds no data migration but cannot authorize unsafe publication.

## Review triggers

- Another identity store or cross-placement/cross-database account source.
- Bulk identity writes, new account succession policy or changed actor rebinding semantics.
- Lock contention, deadline failure, unqualified row-lock composition or new bypass path.
- Real identity, public/connected use or deployment; independent review remains mandatory there.

## Related records

- [ADR 0044](0044-administrator-provisioned-local-credentials.md)
- [ADR 0045](0045-governed-communications-audiences-and-engagement.md)
- [ADR 0029](0029-provider-neutral-identity-federation-and-directory-connections.md)
- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0036](0036-minimal-people-participation-and-staff-account-association.md)
- [Threat model](../security/threat-model.md)
