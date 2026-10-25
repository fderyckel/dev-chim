# COMM-1 remaining audience-source qualification

- Status: François selected B; binding prerequisite implemented, focused-tested and reviewed;
  complete audience qualification and publication remain gated
- Latest source checkpoint: [People-owned write-fence evidence](../phase-2/people-source-write-fence-evidence.md).
  François authorized ADR 0053 and the scoped fence. Correctness/migration controls and three
  unchanged foundation comparisons pass within 20%; actual attendance rejects concurrent work
  under the existing admission contract, including baseline. The complete checkpoint remains
  not qualified and publication stopped. A same-writer nested-admission decision is proposed,
  not implemented; no limit or independent session protection is weakened.
- Date: 2026-10-24
- Authority: François's instruction to complete remaining qualification, obtain four-agent review
  of the complete checkpoint before publication work, and defer `make check`
- Governing decisions: [ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md),
  [ADR 0047](../adr/0047-private-identity-account-source-fence.md)
- Evidence owner: Coordinator; François retains accountable decisions and release authority

## Decision returned to François

François subsequently selected **B** and explicitly authorized its scoped ADR, implementation,
tests and specialist checkpoint review before COMM-1 resumption. [ADR 0051](../adr/0051-private-account-principal-binding-marker.md)
and the [binding checkpoint](../phase-2/account-principal-binding-evidence.md) now own that
prerequisite. The comparison below retains the rationale for the selection; it no longer awaits
an A/B choice. Neither selection nor this prerequisite qualifies the complete audience fence.

The [executed checkpoint](../phase-2/communications-comm-1-source-fence-qualification.md#renewed-qualification--24-october-2026)
now includes a named-action comparison of ordinary same-actor credential rotations and
account actor A → B → A. In both cases the generic account version advances twice. After the
second rebind, the original account/actor/association/participation/membership tuple matches
again. While the account belongs to B, it is absent from A's account lookup. These are source
observations; no notice exists and no notice-read authorization was exercised.

ADR 0045 freezes original admission identities and requires current eligibility. ADR 0047 says
an account with a different actor is not the original principal and requires denial after
rebinding. Neither explicitly defines the historical binding of A after A → B → A; ADR 0047
also excludes a new succession policy. The specialists initially read that case differently,
then agreed it requires an explicit choice. The probe is not evidence of a violated settled
permanent-denial rule. Neither locking nor generic `lock_version` resolves that choice.

| Bounded choice | Result for the old notice when A returns | Tradeoff |
| --- | --- | --- |
| A — original current tuple | The original tuple may regain eligibility, subject to all current staff, account, association, membership, permission and acting-session gates | No binding-history mechanism; explicitly permits restoration after an intervening different principal. Must not claim uninterrupted identity binding. |
| B — distinct principal binding (selected by François) | Every account creation or actor rebind receives a new private binding marker. A returning to the account requires a new publication for admission; same-actor credential rotation preserves the marker | Prevents restoration through principal reassignment, with the separately authorized identity-owned contract, migration and write-boundary tests recorded in ADR 0051. |

The recommendation was **B** because a notice's original admission should not silently return
after the account has belonged to another principal. François selected that new rule explicitly;
it was not an interpretation presented as a pre-existing permanent-denial requirement.

The separately authorized bounded prerequisite is:

1. Add the required ADR before implementation; supplement or supersede accepted boundaries
   through the normal process. Keep account identity, binding marker and current access separate.
2. Add one private server-managed, non-reused binding marker. The database sets a fresh marker
   on creation and every actual actor change, including A → B → A and deletion/recreation with
   a reused account ID. Same-actor password, activation, suspension and lockout changes preserve
   it. Request input must not select or reset a marker; existing old/new actor fence ordering
   remains binding. A numeric version that can restart after recreation is insufficient.
3. Give retained accounts a fresh baseline without claiming any recovered historical lineage.
   No communications manifest exists yet to backfill. Review expand/rollback behavior and
   inspect the generated migration before applying it to the isolated proof database.
4. Later source capture binds the marker with the original account, actor, association,
   participation and membership. Missing or changed markers fail closed for that original
   admission. It grants no permission and is never a browser token or public metric.
5. Test the real named credential/bootstrap paths and direct SQL guard, actor round trips,
   same-principal rotations, deletion/recreation, current mismatch, cross-tenant/actor behavior,
   fence ordering, migration preservation and whole-transaction rollback. Then repeat the full
   audience-source checkpoint and specialist review before publication implementation.

This prerequisite adds no authentication handoff, credential delivery, directory, audience API,
publication, consumer or release. Its implementation and focused results are recorded separately
in the binding checkpoint. A future change to choice A requires another explicit reviewed decision.

## Current execution boundary

At the initial renewed checkpoint only the qualification probe and documentation were retained;
the incomplete source-adapter draft was removed. That six-file regression passed **69 tests**
on fresh database `chimwemwe_comm1_sources_20261024_02` after the helper cleanup. Complete source
projection, combined race/denial matrix, time-boundary/expiry qualification and source/classroom
workload measurements were unexecuted at that checkpoint. The subsequent binding prerequisite
is now tracked by ADR 0051; composed source qualification is a separate coordinated continuation.
`make check` is deferred by François's current instruction. The design below remains a candidate,
not an implemented or qualified adapter. Accepted ADR decisions have not been rewritten.

## Candidate boundary

Implement one private People-owned exact-institution source projection. Trusted startup selects
the institution; validated writer context selects tenant, placement and actor. Require the exact
server purpose `communications.staff_audience` and dedicated source capability
`people.core.audiences.prepare_staff`. No recipient IDs, role names, capabilities, dates, source
versions or institution selectors enter the draft input. No directory, browser route, new module,
publication resource, consumer or local-credential-to-public-session handoff is added.

Use the existing opaque-session foundation for the acting session in the synthetic qualification
harness. It is independent of the credential account fixture: no new authentication adapter is
implied. Recipients may be offline. Account admission requires the verified original active
account/actor/association/participation/membership tuple. Prospective notice capability is a
separate current-access condition, not account identity and not implemented notice-read authority.
Future publication still enforces its own communications module and action gates.

## Lock and temporal composition

Set the total transaction budget before acquiring other locks. Validate and hold the current
acting session and its existing link/connection; protect its account before actor advisory locks.
Use existing people/dependency lifecycle locks, the exact published institution parent lock,
association locks, membership parent locks, existing assignment/role/inclusion/grant/capability
row locks and ADR 0047's complete recipient actor fence. Traverse role composition only under
locked parents; a returned-row hash alone is not phantom protection. Use plain account reads after
actor locking. Reauthorize after the full fence. Keep every lock through the source-owner callback
and transaction end. Do not change source writers or introduce a shared people/authority mechanism.

Time remains a source even without DML. Compute the institution-local date and next local midnight
from PostgreSQL writer time, bind both into preparation, and expire within five minutes or sooner
at that boundary. Bound the transaction to the earlier of its two-second budget, the acting
session's expiry, and the next local-date boundary. Never substitute transaction-start date for
the current effective-date basis. Deterministic date/DST tests and actual short-deadline rollback
tests are distinct from waiting for a real midnight.

The source proof may carry a restricted immutable value; it is not a client token or authoritative
durable publication. Later publication must persist the server-created preparation/approval basis
in PostgreSQL and must not accept a submitted snapshot as authority. The checkpoint must distinguish
source qualification from unimplemented durable approval and publication behavior.

## Bounded evidence

At most 25 current intended people, deduplicated by person UUID. Also cap this private proof's
source traversal (100 staff participation rows including historical/future rows, 64 reachable
roles, 256 assignments/edges/grants); overflow fails closed without truncating an audience. These
are engineering safety bounds, not tenant role policy or production capacity. Test empty/1/25/26,
traversal overflow, source/date/session/module/capability denials, changed canonical draft/receipt
basis, replacement/rebound identities, initially absent/pending admission and same-principal
credential rotation. No raw source rows, names, emails, proof references or session material in
public summaries, logs or committed results.

Pair complete source captures with controlled independent-connection writer races and observe
PostgreSQL blocking/commit order. Include inserts, future starts/ends, ending, revoke/relink,
membership/assignment/grant/role-composition changes, account lifecycle/rebinding, module changes
and current acting-session denial. Retain isolated evidence and label every unexecuted check.

Measure a source-stage mixed workload beside the real classroom writer over at least three runs;
state explicitly that actual publication/correction/receipt burst measurements remain later
COMM-1 exit evidence. The complete checkpoint cannot claim those unimplemented actions were run.
Return any required stable-boundary change, wider source writer refactor or failed acceptance
limit under the approved stop condition. All four specialists review the actual outcome before
publication work begins. Isolated Advisor availability is recorded separately.
