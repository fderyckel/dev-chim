# Scoped identity-account source-fence evidence

- Status: Scoped prerequisite implemented and focused-tested; four specialist reviews recorded;
  only remaining audience qualification may resume, publication remains blocked
- Date: 2026-10-23
- Authority: François explicitly authorized the scoped prerequisite ADR, implementation, tests
  and four-agent checkpoint review before resuming COMM-1; the focused checkpoint initially
  excluded `make check`, which the final coordinator integration later ran
- Contract: [ADR 0047](../adr/0047-private-identity-account-source-fence.md), Proposed with explicit
  bounded implementation authority; Accepted ADRs 0044 and 0045 are not rewritten
- Engineering custodian: Coordinator for these isolated runs; François remains accountable owner
- Overall audience gate: [not yet qualified](communications-comm-1-source-fence-qualification.md)

## Change and boundary

Account creation now takes the same transaction-scoped actor lock as the private reader, even
when the account row does not exist. Updates lock old/new actors in sorted order; deletes
participate; truncate is refused. There is no global table lock or new account-administration
path. Existing named credential actions, actor identities, permissions, statuses and token
invalidation meanings remain unchanged.

The private primitive validates trusted context, current caller/source memberships, READ COMMITTED
and an exact list of at most 25 actors. It grants no permission and returns no account records.
Its owner must establish the trusted writer, transaction and domain/purpose/capability/module
authorization. The server deadline includes prior transaction time, lock waits and idle time;
repeated calls cannot restart it and a shorter existing deadline is preserved. The actual server
is PostgreSQL **18.6**; this private path needs `transaction_timeout` support (17+) and fails closed
when unavailable. Credential writers gain no new total deadline or isolation requirement.

Readers acquire the complete actor set once and then use plain account reads. Do not take account
row locks after this fence: a writer may already own a row lock while waiting in its trigger.
Arbitrary multi-row or reversed acquisition can still deadlock. The existing owner transaction
maps dependency failure and rolls back the whole operation; this does not implement communication
outcomes, automatic retry or reconciliation of an unknown commit result.

Files: [resource](../../apps/chimwemwe_core/lib/chimwemwe/identity/account.ex),
[private fence](../../apps/chimwemwe_core/lib/chimwemwe/identity/account_source_fence.ex),
[generated migration](../../apps/chimwemwe_core/priv/repo/migrations/20261023195111_identity_account_source_fence.exs),
[snapshot](../../apps/chimwemwe_core/priv/resource_snapshots/repo/identity_accounts/20261023195112.json),
[account tests](../../apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs),
[composed source probes](../../apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs)
and [migration qualifier](../../tools/qualify_account_source_fence_migration.exs).

## Executed evidence

All database checks used the repository `core-test` lock and fresh isolated synthetic databases.
Generated temporary passwords are discarded inside their process, never printed or returned by
probe tasks. No retained checkpoint database was reused or decommissioned.

| Check | Result |
| --- | --- |
| Missing-account provisioning | Named writer blocks behind the observed PostgreSQL holder and commits after release; before-fence committed account basis is visible |
| Activation, active-account reissue/suspension, bootstrap | Each named write waits; same-ID transitions preserve exact account identity |
| Bootstrap rebinding | Holding either old or new actor blocks the actual named actor change; account ID remains stable |
| Direct SQL insert/update/delete | Cannot bypass table trigger; no new generic application action is exposed |
| Unrelated actor in another tenant | Provisioning completes while the first actor is held |
| Same global actor with two tenant memberships | Shares the identity fence intentionally; school authority stays tenant-qualified |
| Context/input/membership/routing/isolation negatives | Missing context/transaction/caller membership, unknown/foreign actors, invalid input, 26 actors, stale route and non-READ-COMMITTED reader refused; 0/1/25 actors and bounded deduplication pass |
| Whole-transaction timeout | Earlier mutation rolls back; time before acquisition, lock waiting and idle time count; repeated calls cannot restart budget; shorter deadline preserved |
| Injected reverse acquisition | One deadlock victim returns the typed dependency failure and its earlier mutation rolls back; the other owner completes. This is a negative control, not supported incremental lock order |
| People lifecycle + new account fence | Previously absent account provisioning is blocked through the held transaction; original row-only counterexamples remain useful controls |
| Existing people/credentials/persistence/local-auth configuration | Focused regression passes |

Final run: `CHIMWEMWE_TEST_DATABASE=chimwemwe_account_fence_20261023_03`, after test database
creation/migration under `core-test`:

```sh
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs apps/chimwemwe_core/test/chimwemwe/identity/local_credentials_test.exs apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs apps/chimwemwe_core/test/chimwemwe/platform/persistence_test.exs apps/chimwemwe_core/test/chimwemwe/auth_demo/config_test.exs --seed 29
```

Result: **68 passed**. Iteration `_01` had 24/25 passing: one harness assertion lost the original
SQL error by committing an aborted transaction. The harness now explicitly rolls back failed
operations. Test compile warnings and one helper-nesting lint finding were corrected. Intermediate
`_02` passed 55 tests; the final run adds stronger active-credential, elapsed-time and routing cases.

## Migration and static verification

Reviewed generated expansion: two functions and two triggers only; no column, index, foreign-key,
identifier, backfill or retained-row changes. Functions precede triggers; down removes triggers
before functions. Reviewed `SET LOCAL lock_timeout = '2s'` bounds DDL waits. Down refuses retained
accounts before removing a guard; populated installations require reviewed forward repair.

The qualifier requires an explicit dedicated database prefix/mode and never deletes accounts.
After `mix ecto.create --quiet`, run for each selected database with `MIX_ENV=test`:

```sh
mise exec -- env MIX_ENV=test mix run tools/qualify_account_source_fence_migration.exs
```

| `CHIMWEMWE_TEST_DATABASE` | Passed checks |
| --- | --- |
| `chimwemwe_account_fence_migration_20261023_empty` | Full apply, rollback of new migration, reapply and trigger catalogue assertions |
| `chimwemwe_account_fence_migration_20261023_retained` | Provision before expansion, complete row digest unchanged after expansion, rollback refused for the exact retained-account reason, row/guards/migration version intact, existing named suspension still works |

Both databases remain retained. Re-loading a migration for rollback/reapply emits expected module
redefinition warnings; no migration failure was ignored.

Also passed:

- `mise exec -- env MIX_ENV=test mix compile --warnings-as-errors`
- `mise exec -- mix credo --strict` in `apps/chimwemwe_core`: no issues
- `mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots` there: no drift
- Targeted `mix format --check-formatted` for the resource, primitive, migration, qualifier and tests
- `mise exec -- uv run python tools/check_docs.py`: passed after recorded reviews
- `git diff --check` and explicit new-file whitespace/JSON verification: passed; generated JSON
  retains its generator's no-final-newline format

Final integration used `CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_final8_20261023 make check` on the
combined checkout and passed every required stage: 335 core tests, 52 web unit tests, 70 browser
tests, both dependency audits, the production build, documentation/repository tooling and shell
tooling. This does not add benchmark, account-fence UI/accessibility, real-identity, deployment,
Restricted-consumer or independent security/privacy evidence. Isolated Advisor preflight returned
`parent_runtime_unavailable`; no consultation approval is claimed.

## Remaining source checkpoint

The account-absence prerequisite has executed evidence. The complete audience fence remains
**not qualified**: complete private projection, canonical preparation/approval basis,
institution-local midnight invalidation, full participation/link/membership/grant/module/session
race matrix and mixed-classroom workload remain unexecuted. A valid staff association or pending
first-login account is insufficient for ordinary access. Frozen account/association/member
admission identities, current authorization, exact receipt rules and withdrawal remain binding.
Account replacement/rejoin does not restore old-chain access; login lockout does not silently
revoke a valid session.

After the requested review, the next authorized COMM-1 work is remaining **audience source
qualification**, not publication implementation. No notice resource, route, screen, communications
outbox change or consumer has been started. Return any further stable-boundary change or wider
writer refactor under the original stop condition.

## Delegated checkpoint review

All four existing profiles reviewed the exact ADR, implementation, migration, tests and reported
results read-only. They did not reproduce the tests. The coordinator records **accept** for each
recommendation below; there is no unresolved material disagreement about the prerequisite.

| Profile | Disposition and conditions | Coordinator action |
| --- | --- | --- |
| Primary education | Approve scoped prerequisite; account synchronization grants no school or session authority. Institution-wide staff need no teaching assignment. | Accept. Resume only remaining source qualification; retain original privacy/custody and admission/current-access distinctions. |
| Secondary education | Approve with conditions on resumption: exact institution/local date/exclusive end; future starts/endings at midnight without DML; explicit staff, mixed status deduplication, original identities and whole-operation failure semantics. | Accept. Those cases, full membership/grant/module/session races and workload remain required; no complete audience or classroom-impact pass is inferred. |
| School/college admissions | Approve with conditions: bind original account ID **and actor ID**, association, participation and membership. Same account ID with a rebound actor is a different principal; membership checks here do not protect membership/grant changes through commit. | Accept. Actor rebinding must deny old-chain access in remaining audience tests; first provisioning/replacement/rejoin cannot restore it. Preserve pending-first-login and login-lockout/session distinctions and all applicant/family/referee/college exclusions. |
| UI | Approve prerequisite and remaining qualification only. Proven rollback in exercised owner tests does not make every timeout a known rollback; unknown commits require reconciliation. | Accept. No publication readiness, outcome-type implementation, screen or usability result. Keep changed/expired/failed/unknown states distinct in future interfaces. |

The checkpoint review required before COMM-1 resumption is complete for this prerequisite.
The permitted next work is the already authorized private audience projection and complete source
race/denial qualification. Publication remains blocked until the full checkpoint passes and is
reviewed. A further stable-boundary change or wider writer refactor still returns separately.
No additional permission is needed merely to perform remaining in-scope qualification.

These are delegated AI source/document reviews, not representative testimony, independent
security/privacy assurance, formal acceptance of ADR 0047 or approval of the unexecuted complete
audience fence. No UI exists to review visually. Future states remain: **Audience changed. Refresh
audience.**, **Audience preview expired. Refresh audience.**, proven preparation rollback:
**Audience not prepared. Try again.**, unknown publication outcome: **Publication not confirmed.
Check status.** Essential exclusions stay visible; secondary help remains keyboard/tap/hover
accessible. No partial audience success or delivery result is introduced.
