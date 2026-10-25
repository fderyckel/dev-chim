# ADR 0051: Private account principal-binding marker

- Status: Proposed
- Date: 2026-10-24
- Accountable owner: Identity and platform engineering
- Deciders: François — Project Owner; security/privacy review before connected use
- Implementation authority: François selected option B and authorized this scoped ADR,
  implementation, focused tests and four-agent checkpoint review on 2026-10-24;
  `make check` remains explicitly deferred
- Supersedes: None; adds the selected historical-binding contract to ADR 0047 without rewriting
  Accepted ADRs 0044 or 0045

## Context

The [renewed COMM-1 source checkpoint](../phase-2/communications-comm-1-source-fence-qualification.md#renewed-qualification--24-october-2026)
observes that an account can change actor A → B → A and regain its original current identifiers.
Ordinary same-actor credential rotations and that round trip both advance generic `lock_version`.
The existing decisions did not explicitly settle whether returning A could regain old-notice
admission. The four specialists recommended a distinct binding; François selected option B.

This is a new rule, not remediation of a previously settled permanent-denial requirement.
The complete audience adapter and publication remain unimplemented and unqualified.

## Decision drivers

- Distinguish principal reassignment from ordinary credential and account-status changes.
- Prevent an A → B → A round trip or reused account ID from restoring original notice admission.
- Enforce marker creation and preservation at the actual database write boundary.
- Preserve global accounts, tenant-qualified source selection, current authorization and sessions.
- Keep this prerequisite private and compatible with old named credential writers.

## Considered options

1. Permit restoration of the original current tuple under current gates. This was a valid explicit
   alternative, but François selected B instead.
2. Freeze generic `lock_version`. Rejected: it also changes for ordinary credentials and status.
3. Use a per-account counter starting over on account creation. Rejected: deletion/recreation of
   the same account ID could reuse a prior value.
4. Allocate private markers from a durable database sequence on creation and every actual actor
   change; preserve them otherwise. Selected for this bounded proof.

## Decision

Add a private, read-only, generated bigint `principal_binding_id` to global `identity_accounts`.
A logged bigint sequence, `identity_account_principal_binding_sequence`, uses `NO CYCLE` and is
not owned by a deletable account row. Its values are identifiers, not counts or timestamps.
Gaps, rollback consumption and concurrent allocation order have no audience meaning. Exhaustion
fails the write; it must never wrap or reset to recover service.

A `BEFORE INSERT OR UPDATE` trigger acquires ADR 0047's existing sorted actor-source locks before
assigning the marker. Insert always allocates a new value, ignoring supplied marker input.
An actual actor change allocates another new value, even when returning to a previous actor.
All same-actor updates overwrite submitted marker changes with the existing value. Credential
activation, password rotation/reissue, suspension, failed-attempt bookkeeping and lockout never
change binding identity. Existing deletion fencing and truncate refusal remain in force.

The Ash attribute is non-public, sensitive, generated and non-writable; no action accepts it.
Ordinary SQL cannot reset or copy a marker through an account insert/update. Sequence reset,
privileged DDL, disabled triggers, replication configuration and database restore remain operated
trust boundaries, as for ADR 0047. No new application permission or public SQL capability is added.

Future audience capture must freeze the original tenant/account/actor/binding marker together
with association, participation and membership. A missing, malformed or changed marker cannot
match that original admission. Returning A needs a new publication for admission. Same-actor
credential changes preserve identity, but current account, membership, permission and acting
session checks still apply. Initially absent/pending admission cannot be filled retrospectively.
The marker is neither authentication evidence nor permission, browser token, delivery or receipt.
This prerequisite supplies the marker only; it adds no audience API or notice-read action.

## Plain-English summary

### What this means

Changing a password keeps an account's admission identity. Giving that account to somebody else
creates a new binding, including when it is later given back.

### What was agreed

Only the private identity prerequisite, focused evidence and delegated review are authorized.
Publication, connected use, real records and release retain their existing gates.

### Context

Current identifiers alone cannot distinguish an uninterrupted account binding from reassignment
away and back. The extra marker makes that distinction available to future audience checks.

### Examples

- Illustrative: A changes their password; their binding marker stays the same.
- Illustrative: A's account is reassigned to B and later A; each reassignment gets a new marker.
- Illustrative: deletion and recreation using the same account ID cannot copy the old marker.

## Consequences

### Positive

- Binding continuity is distinct from generic row versions and current eligibility.
- Old named credential writers and ordinary alternate SQL are covered by database enforcement.
- No account history ledger, directory, account succession workflow or public field is introduced.

### Negative

- One extra private column, sequence and trigger must be retained and restored correctly.
- Sequence allocation can leave gaps and is database-local, not a cross-database identity service.
- A retained marker cannot be removed through ordinary rollback, even after account deletion.

## Security, privacy, operability, and migration effects

Generate the migration and snapshot from the Ash resource. Add the non-null column with a zero
bootstrap default, then allocate fresh baseline markers for retained rows, install the trigger
and positive-value constraint within the same migration transaction. Zero is never a valid
committed account marker. The baseline invents no historical lineage. Existing IDs, credential
hashes/status, versions, timestamps and relationships remain unchanged; no manifest exists yet.
Bound DDL lock waits to two seconds and inspect the generated artifact before applying it.

Empty, never-used apply/rollback/reapply is allowed. Down refuses when accounts remain **or the
sequence has ever issued a value**, including rolled-back/deleted accounts, to avoid reuse after
reinstallation. Retained cases require reviewed forward repair. This isolated small synthetic
trial does not establish online migration capacity or a selected deployment recovery procedure.
Restore must preserve sequence progress and account markers before any future admission check;
cross-database identity or merge requires another reviewed decision.

Accounts stay global; tenant membership and caller/source authorization remain separately checked
by existing source owners. Markers stay out of public responses, logs and metrics. No audit/outbox
business event is created by allocating a private marker; existing named actions retain their own
effects and token/session semantics. No credentials or real identity material enter evidence.

## Validation evidence

Record executed results and four read-only specialist dispositions in
[binding-marker evidence](../phase-2/account-principal-binding-evidence.md). Required: named
provision/activation/reissue/suspend/bootstrap, credential and lockout preservation, A → B → A,
direct SQL attempts to set/reset/copy/null markers, deletion/recreation, denied Ash input,
existing context/tenant/routing denials, old/new actor fence ordering, unrelated-actor progress,
whole-transaction rollback, sequence exhaustion, generated drift, retained-row preservation and
rollback refusal after issuance. Planned checks are not results. Complete audience qualification
still precedes publication work and `make check` remains deferred by the current instruction.

## Fallback and exit cost

On failure, keep publication stopped and repair forward. Do not replace the marker with generic
versions, permit restoration, reset the sequence or silently invent historical bindings.
Removing it after issuance requires a separately reviewed migration and any later manifest repair.

## Review triggers

- Cross-database identity, placement movement, restore, import, account merge or sequence exhaustion.
- Any public marker exposure, actor reassignment policy, new admission consumer or real-data use.
- Complete audience qualification, publication implementation or connected/release decision.

## Related records

- [ADR 0044](0044-administrator-provisioned-local-credentials.md)
- [ADR 0045](0045-governed-communications-audiences-and-engagement.md)
- [ADR 0047](0047-private-identity-account-source-fence.md)
- [Selected bounded option](../plans/communications-audience-source-qualification.md)
- [Threat model: TM-20/TM-21/TM-22](../security/threat-model.md)
- [PostgreSQL sequence behavior](https://www.postgresql.org/docs/18/sql-createsequence.html)
- [PostgreSQL trigger behavior](https://www.postgresql.org/docs/18/sql-createtrigger.html)
