# Private account principal-binding checkpoint

- Status: Focused prerequisite passed with all four delegated reviews; remaining audience-source
  qualification may resume, publication remains gated
- Date: 2026-10-24
- Authority: François selected option B and authorized the scoped ADR, implementation, tests
  and specialist checkpoint review before resuming COMM-1; `make check` remains deferred
- Governing record: [ADR 0051](../adr/0051-private-account-principal-binding-marker.md)
- Overall gate: [complete audience qualification](communications-comm-1-source-fence-qualification.md)
  remains separate; no publication implementation is authorized by this prerequisite result
- Engineering custodian: Coordinator; François retains accountable decisions and release authority

## Implemented boundary

The private generated `identity_accounts.principal_binding_id` is allocated by a logged bigint
`NO CYCLE` sequence. A database trigger takes the existing ADR 0047 old/new actor fences before
assigning a fresh value on insert or actual actor change. Same-actor writes preserve the existing
marker regardless of a supplied marker, including null, zero, negative or copied values.
The global sequence survives account deletion; creation using a reused account ID receives a
new binding. It cannot wrap, and failed transactions can consume values without reusing them.
Sequence values are private identifiers, not chronology, audience counts or public information.

The Ash attribute is sensitive, generated, non-public and non-writable. No named action accepts
marker input. Bootstrap actor rotation explicitly includes the trigger-owned value in its SQL
return so the action cannot return a stale pre-reassignment marker. Ordinary raw SQL is covered
by the database trigger. Privileged sequence reset, DDL, disabled triggers, replication and restore
remain operated trust boundaries; no application capability or browser field is added.

Same-actor activation, password rotation/reissue, suspension and lockout bookkeeping preserve
binding identity. Current access and acting-session validity remain separate requirements.
A → B → A now has a different marker despite returning to the original account/actor IDs.
Future audience capture must bind the marker with the original tenant/account/actor/association/
participation/membership and reject missing/changed binding evidence. No notice-read action,
manifest, audience resolver or eligibility grant is implemented here. Initially absent/pending
admission cannot be filled retrospectively; eligible recipients may be offline.

## Verification ownership and isolation

The shared checkout contains independently authorized directory/local-login, password-hash,
browser navigation and composed audience-source work. None is absorbed or reset here.
An early shared-checkout run encountered a directory table not yet migrated and a concurrent
credential regression. That run is not a passing integration claim.

Focused prerequisite qualification uses an attached isolated worktree at
`/Users/francois/.codex/worktrees/account-principal-binding/dev-chim`, based on committed
`c5fbe58347091b7add395489d55f29570c2d4550`, with only this prerequisite's account declarations,
generated migration/snapshot, two probe files and trial scripts. Concurrent password-provider
and password-input changes in the shared account file are excluded from this isolated copy.
Existing dependency builds are reused; application compilation is separate. The shared account
file preserves those other changes. The result is bounded prerequisite evidence, not combined
checkout readiness.

The initial generator saw concurrent directory/session/outbox declarations. Its generated
migration was reviewed and reduced to the account-only operations; only generator-created
unrelated snapshots from that invocation were removed. Other owners' later migrations and
snapshots remain untouched. The scoped drift helper runs the actual Ash generator against a
temporary account-only snapshot tree and does not rewrite repository snapshots.

## Focused results

Executed on isolated database `chimwemwe_binding_isolated_20261024_03` under `core-test`:

```sh
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs apps/chimwemwe_core/test/chimwemwe/identity/local_credentials_test.exs apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs apps/chimwemwe_core/test/chimwemwe/platform/persistence_test.exs apps/chimwemwe_core/test/chimwemwe/auth_demo/config_test.exs --seed 29
mise exec -- env MIX_ENV=test mix run --no-start tools/check_account_binding_snapshot.exs
```

Results: **78 passed**; application compilation with warnings as errors and account-only Ash
generator drift check passed. After expanding direct SQL insert cases to null/zero/negative/copied
marker input, the final account-only replay passed **30 tests** on that same isolated database:

```sh
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs --seed 29
```

| Executed case | Observed result |
| --- | --- |
| Named provision, activation, reissue, suspension and same-actor bootstrap rotation | Positive generated marker is returned and remains equal to PostgreSQL; same-principal changes preserve it |
| Five failed-attempt updates and clearing lockout state | Binding remains unchanged |
| Named bootstrap A → B → A | Stable account ID returns to A; each actor change has a distinct marker, including the action's returned record |
| Private attribute and submitted Ash marker input | Non-public, sensitive, generated, non-writable; ordinary action input is invalid without mutation |
| SQL insert with null/zero/negative/copied marker; same-actor SQL reset; actor change with original marker supplied | Database owns the actual positive value; resets/copies cannot restore an earlier binding |
| SQL deletion/recreation retaining account ID and actor | A new marker is allocated |
| Source fence held during marker-reset SQL, and existing old/new actor rebind tests | Independent writer is observed blocked by PostgreSQL, then completes after release with the correct binding |
| Actor-change rollback | Account/actor/marker revert atomically; consumed sequence values are skipped, never reused by the next committed rebind |
| Fenced People source observation | Same-actor password rotations preserve the marker; A → B → A changes it while original association IDs return. No notice-read behavior is claimed |
| Existing fence, context/membership/tenant/routing/size/isolation, credential and People regressions | Existing negative and positive checks pass; the marker grants no new source or school authority |

All probes use fictional identities and generated credentials kept in process memory. No account
rows, passwords, hashes, tokens or markers are printed in committed evidence. The expected
timeout/connection-disconnection log comes from the existing rollback negative controls.
Databases are retained through review and unresolved findings.

Earlier trial outcomes are not passing evidence: the first migration used multiple prepared SQL
commands and was corrected to one transactional `DO` block; isolated `_01` found stale action
return values (75/78 passed), and `_02` found unsupported automatic atomic constraint casting
(73/78 passed). The action now selects the database-owned marker with an internal self-assignment
and no redundant atomic cast; the database positive-value constraint remains authoritative.
An initial isolated preparation accidentally included concurrent password-provider declarations;
those two unrelated lines were excluded before the actual isolated runs. Migration-tool compile
and application-start setup errors were corrected before the five executed trials below.

Strict Credo passed in the isolated core after one alias-style repair. Targeted formatting,
repository documentation validation and whitespace checks passed on the shared checkout.
Final seven-file candidate SHA-256 is
`15fabf9fc4bf524e1ca7b0007ef14ab8782c0c121035450a132330ffed2ce7e7`, computed from
sorted repository-relative paths, a NUL, file bytes and a NUL for each of: account resource,
generated migration, generated account snapshot, the account fence and People source probe files,
and the two binding trial/drift scripts. The shared marker declarations match this isolated source;
only the two separately owned credential declarations differ in the shared account file.

The six-file regression covers the account fence and marker, composed People observation,
existing local credentials, People, persistence and local-auth configuration. The complete
audience source and new connected directory/session suites are not substitutes for this scope.

## Migration and recovery trials

Generated artifact:
[account-only expansion](../../apps/chimwemwe_core/priv/repo/migrations/20261024134151_account_principal_binding.exs).
One non-null bigint column is added with zero bootstrap default; fresh baseline allocation,
trigger installation and positive-value constraint occur in the same transaction. No old IDs,
credential state/hash, versions, timestamps, tenant keys or associations are changed. No
historical identity continuity is invented. DDL lock waits are bounded to two seconds.

The trial script refuses a database without the dedicated `chimwemwe_binding_migration_`
prefix and an explicit mode. It requires an empty account fixture before creating its owned
synthetic rows. Five executed modes passed on dedicated databases
`chimwemwe_binding_migration_20261024_03_<mode>`:

| Mode | Executed outcome |
| --- | --- |
| `empty` | Apply, empty never-issued rollback, reapply; marker sequence/guard installation restored |
| `retained` | Two existing legacy account rows receive distinct positive baselines; all pre-existing fields remain byte-equivalent by digest; retained rollback refused; named suspension preserves marker; old SQL insert shape still works |
| `deleted` | Delete only the trial's own synthetic account; down still refuses prior issuance with zero accounts remaining |
| `exhausted` | Privileged dedicated-database injection reaches the sequence maximum; new creation and actor rebind fail, original row/marker stay intact, same-actor suspension succeeds; sequence is never reset |
| `contended` | Independent connection holds a legacy account row; the migration refuses after its two-second lock wait, rolls back expansion/baseline without changing the original row, then applies successfully after release |

For each mode, under `core-test`, run in the isolated checkout with the selected database:

```sh
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix run --no-start tools/qualify_account_principal_binding_migration.exs
```

Repeated Ecto migration loading emits module-redefinition warnings within these trials; all
assertions and process exits passed. This is separate from the warning-free application compile.
Down refuses any retained account or
previous sequence issuance, including after deletion, so rollback cannot reinstall a counter
that reuses an earlier binding. Empty and never-issued rollback remains allowed.

These local small-database trials do not qualify online production migration capacity, selected
restore/backup, cross-database identity, deployment or real staff access. The overall account
fence still requires plain account reads after actor fencing, existing context/tenant/routing
authorization, bounded source transactions and whole-operation error handling.

## Specialist review and continuation

All four existing profiles completed bounded read-only reviews of ADR 0051, the source/migration,
probe changes and the exact executed evidence above. They did not reproduce tests. Admissions
also reproduced the candidate fingerprint; that is source-integrity evidence, not a test rerun.

| Profile | Disposition and reason | Coordinator response / continuation condition |
| --- | --- | --- |
| Primary education | Approve the isolated prerequisite; ordinary credentials preserve identity, reassignment/recreation does not. Marker grants no staff status, session authority or notice access. | Accept. Preserve private markers and sequence progress, never describe the baseline as recovered history; only remaining source qualification may resume after all reviews are recorded. |
| Secondary education | Approve B and remaining qualification; no blocking education issue. Current access remains separate from credential/binding identity. | Accept. Bind all original identities and marker; still demonstrate exact local-date staff/future/end/midnight behavior, independent mixed-status deduplication, current module/capability/session checks and classroom impact. |
| School/college admissions | Approve the scoped prerequisite; source fingerprint matches and inputs cannot restore a prior binding. No applicant/family/referee/external-college or notice authority is added. | Accept. Missing/changed marker denies original admission; initially absent/pending admission remains absent. Complete all source races, time boundaries, failure bounds and workload tests before publication. |
| UI | Approve bounded evidence and remaining qualification; isolation and 78-test/30-test replay distinctions are clear. Marker stays private and is not permission. | Accept. Keep marker mechanics out of routine screens and metrics. Current status: “Account identity prerequisite verified. Full audience qualification remains incomplete.” No visual/usability approval is claimed. |

All material conditions are accepted; no unresolved specialist objection remains to this
prerequisite. Only the already authorized remaining audience-source qualification may continue.
The complete fence, publication, formal ADR acceptance, representative testimony, independent
security/privacy review, combined-checkout readiness and release are not approved here.

The original source checkpoint remains not qualified until its composed evidence and review
pass. No publication implementation or new interface was introduced here. No browser/web,
production recovery, complete audience mixed-load or end-to-end publication checks were run.
The isolated worktree and databases remain available for this checkpoint and later integration.

Isolated Advisor preflight returned `parent_runtime_unavailable` both before implementation and
at completion; no consultation process or isolated assurance is claimed. This is separate from
the four completed delegated AI reviews. `make check` was **not run**, as instructed; no
repository-green or release claim follows from these focused results.

## Shared-schema truncate-test follow-up — 25 October 2026

The directory and local-session expansion adds foreign keys referencing `identity_accounts`.
PostgreSQL can reject standalone `TRUNCATE identity_accounts` with `feature_not_supported`
(`0A000`) before executing its truncate trigger. The operation remains refused. Split that
assertion from malformed fence-input tests: only standalone truncate accepts either that
preemption or the trigger's `check_violation`; malformed lock calls still require exact
`check_violation`. No runtime, migration or marker semantics changed. The retained isolated
no-FK trigger proof and its recorded candidate fingerprint remain unchanged.

On fresh shared-schema database `chimwemwe_binding_truncate_20261025_01`, under `core-test`,
after creation/migration:

```sh
mise exec -- mix format --check-formatted apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/identity/account_source_fence_test.exs --seed 29
```

Result: **31 passed**. The increase from the previous 30-test replay comes from splitting the
combined guard test into two. The expected transaction-timeout log is the existing negative
rollback control. This follow-up verifies that account test file with the shared schema; it
does not qualify the complete audience fence, its classroom-impact limit, publication or the
whole repository. `make check` remains explicitly deferred.
