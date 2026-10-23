# COMM-1 audience source-fence checkpoint

- Status: **Not qualified — publication implementation blocked at this checkpoint**
- Account prerequisite: subsequently authorized, implemented and focused-tested under
  [ADR 0047](../adr/0047-private-identity-account-source-fence.md);
  [new evidence and review](identity-account-source-fence-evidence.md) distinguish it from
  the initial counterexample and complete audience qualification
- Date: 2026-10-23
- Authority: François accepted [ADR 0045](../adr/0045-governed-communications-audiences-and-engagement.md)
  and authorized the [bounded COMM-1 proof](../plans/communications-comm-1-staff-announcement-proposal.md),
  requiring agent review of this checkpoint before proceeding; `make check` is deferred
- Engineering custodian: Coordinator in this local Codex chat; François remains accountable owner
- Run references: `chimwemwe_comm1_fence_20261023_01` (initial harness failures),
  `chimwemwe_comm1_fence_20261023_02` (corrected four-probe run),
  `chimwemwe_comm1_fence_20261023_03` (focused source regression run)
- Scope: isolated local PostgreSQL tests with fictional people, institutions, memberships and
  generated credential material; no browser, publication path, communications storage or consumer
- Custody checkpoint: retain the isolated test databases through this review and unresolved
  findings; no decommission or per-record cleanup was performed after these runs

## Initial checkpoint decision and evidence

The existing people lifecycle lock is useful, but does not qualify the complete audience source
fence. Named people actions take the tenant's `people.core` lifecycle advisory transaction lock
before their mutation. A qualification transaction can take that same existing lock and order a
new staff insertion after its release. This is stronger than locking only participation rows
returned by a query, which leaves a new-person phantom possible.

Account identity is a separate source. `People.Foundation.current_staff_account` returns a
verified, unrevoked association with an effective exact staff participation and existing
tenant membership/actor. It does not join `identity_accounts`, establish credential existence or
active status, or prove a valid session/capability. The synthetic verifier proves only its exact
test-fixture assertion; it supplies no real human-identity assurance.

The decisive probe holds both the existing people lifecycle lock and `FOR SHARE` locks on all
account rows matching the relevant actor. Initially there is no such account row to lock. The
real `LocalCredentials.provision/2` operation then commits a new account for that actor **before
the candidate fence is released**. The original person/participation/association/membership remains
unchanged. The newly provisioned account is pending first login, not eligible ordinary access;
nevertheless its new identity/status changes the required preparation basis. A subsequent account
read sees that new row while the candidate fence is still held. There is no communications commit
in this probe, and no claim of an unauthorized publication or existing communications vulnerability.

An existing account row can be locked against a concurrent named suspension. That positive
control does not protect the absence of an account. At this initial checkpoint the credential
implementation had no shared actor-scoped absence fence that the audience adapter could acquire. Repeated queries,
hash comparisons and returned-row locks cannot supply the promised through-commit source fence.

| Executed probe | Observed result | Meaning |
| --- | --- | --- |
| Lock all returned participation rows, insert a different person's staff participation through the named writer | Insert commits while the lock remains held | Row-only candidate is insufficient |
| Acquire existing people lifecycle lock, attempt named staff insertion on an independent connection | PostgreSQL reports the holder in `pg_blocking_pids`; insertion completes after release | Existing people writer ordering is evidenced for this operation |
| Acquire people lifecycle lock and existing-account row locks for an actor with no credential row, then provision its account through the named writer | Account commits and is visible before release; association still resolves | Composed candidate is insufficient for the complete account basis |
| Lock one existing account row, attempt named suspension on an independent connection | PostgreSQL reports blocking; suspension completes after release | Existing-row protection works; absent-row protection remains missing |

Source: [executable qualification probes](../../apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs).
The tasks use explicit transaction/message barriers and inspect PostgreSQL blockers rather than
inferring ordering from a sleep. Writer backend observations are pinned in the same transaction
as the named operation. Generated temporary passwords are discarded inside their process and
are never returned by the probe tasks or recorded here.

## Verification and limits

On database `chimwemwe_comm1_fence_20261023_02`, executed under the repository's `core-test` lock:

```sh
mise exec -- env MIX_ENV=test mix ecto.create --quiet
mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs --seed 0
```

Result: **4 passed**. These tests assert the counterexamples as well as the positive controls;
passing tests do not mean the audience fence passed qualification. Targeted formatting passed.
The first run had three test-harness failures: an incorrect result-tuple assertion and backend
observations made before a writer pinned its connection. Those were corrected in the harness;
no production writer was changed to obtain the result.

Focused regression on fresh database `chimwemwe_comm1_fence_20261023_03`, also under the
`core-test` lock after database creation/migration:

```sh
mise exec -- env MIX_ENV=test mix test apps/chimwemwe_core/test/chimwemwe/people/communications_source_fence_qualification_test.exs apps/chimwemwe_core/test/chimwemwe/people/foundation_test.exs apps/chimwemwe_core/test/chimwemwe/identity/local_credentials_test.exs --seed 17
```

Result: **34 passed**, including the four qualification probes and existing people/credential
tests. An earlier attempt was refused by the shared verification lock while another owner held
it; no competing run was forced. Documentation validation, targeted formatting and whitespace
checks passed. No existing production writer or authentication path was changed.

Not qualified or run: a private complete audience projection, institution/time-zone midnight
invalidation, full new/end/revoke/replacement/account/grant/module/session race matrix, 1/25/26
cardinality, five-minute expiry, a total two-second transaction deadline, publication atomicity,
rollback/unknown-result mappings, mixed classroom workload, migration/recovery trials, or UI
screens/accessibility/browser tests. The probe's statement timeout is not a total transaction
deadline. No COMM-1 outcome/error type or screen is implemented. `make check` was not run, as
instructed; this checkpoint makes no repository-green or end-to-end readiness claim.

Isolated Advisor assurance remains unavailable: the runtime preflight returned
`parent_runtime_unavailable`. Specialist AI reviews cannot replace that assurance or accountable
security/privacy, representative, connected-use or release gates.

## Smaller prerequisite decision

The approved proof requires: “If that needs a new general people mechanism, stable-boundary change
or wider writer refactor, stop and return that smaller decision; do not enlarge COMM-1 implicitly.”
This checkpoint stops here. No publication path or shared account mechanism has been introduced.

Recommended next authorization: a **private identity-account source-fence qualification**, owned
by identity/platform engineering, before resuming the audience adapter. Prepare a scoped ADR
addendum or superseding decision if a stable accepted identity boundary changes. The candidate
would serialize account existence and eligibility-relevant account writes for the exact verified
actor identities, including the missing-row case. Enforce participation at the actual database
write boundary so provisioning, activation, reissue, suspension, bootstrap and allowed actor
changes cannot bypass it. Use deterministic old/new actor lock order where applicable. Account
identity/status/version remain separate from school participation, membership, permission and
session authority. A credential login lockout must not silently become session revocation.

This recommendation was **not authorized or implemented at the initial checkpoint**. François
subsequently authorized it; current implementation/evidence is linked above. Its concrete exit evidence must
include missing-account provisioning and activation before/during/after the fence, same-identity
credential rotation, suspension, allowed actor change, exact cross-actor/tenant non-interference,
deadlock/timeout rollback, no password/token exposure and compatibility with existing credential
tests. Use READ COMMITTED and the stated total time budget. No global account-table lock, new
directory, changed isolation, local-credential-to-public-session handoff, new account succession
policy, provider, release or real-identity work is included in this recommendation.

Even a successful account prerequisite will not automatically qualify the audience fence:
institution/effective time, participation/link, membership/grant/module and current session
boundaries still need the complete bounded race/denial evidence before publication implementation.

## Initial delegated specialist checkpoint review

All four existing AI profiles reviewed this exact record, the probe source and the coordinator's
observed results read-only. They did not reproduce the run. No screen exists to review visually;
the UI judgment concerns contract wording and evidence honesty only.

| Profile | Disposition and finding | Coordinator response / owner |
| --- | --- | --- |
| Primary education | Approve the stop record; association continuity does not preserve account basis. Pending-first-login creation changes that basis without granting ordinary access. Institution-wide staff access must not require teaching assignment. | **Accept.** Keep not qualified; return the smaller prerequisite to François. People and identity owners must preserve separate school/credential/current-access meanings. |
| Secondary education | Approve stopping. Staff row locks miss phantoms; the complete race matrix, especially local midnight and replacement identities, remains open. Mixed student/staff status and a role named Teacher grant no extra audience authority. | **Accept.** No best-effort audience or weakening of current authorization; complete qualification precedes publication work. |
| Admissions | Challenge fence qualification and approve the stop. An association is neither an actual active account nor a valid session; original exact admission identities remain binding. Login lockout must not silently become session revocation. | **Accept.** Keep applicant/family/referee/external-college exclusions and frozen admission. Return actual-write-boundary account protection for its own decision, without implementing it. |
| UI | Approve report and stop. Passing counterexample probes must never appear as a qualified audience. No outcome types, screens, visual review or runtime usability have been supplied. | **Accept.** Report “Audience preparation not qualified. Publication work is stopped.” Preserve the future state distinctions below; no implementation or usability claim. |

Future interface requirements from the UI review, not executed outcomes: show **Audience preview**
with exact institution, checked time, intended count and essential exclusions before publication;
use publication-time eligibility labels only after confirmed publication. A changed basis says
**Audience changed. Refresh audience.** Age expiry says **Audience preview expired. Refresh
audience.** Both require fresh review/approval. A proven preparation rollback may say **Audience
not prepared. Try again.** Only authoritative publication rollback may say **Not published. Try
again.** Unknown outcome says **Publication not confirmed. Check status.** Reconcile under current
authority and reuse the same permitted operation identity. No publish-anyway, partial audience
success, Queued or Delivered state is introduced. Essential effects stay visible; secondary help
must support keyboard/tap/hover.

The review checkpoint is now recorded, with no disagreement about stopping. This approves the
stop decision, **not** the candidate fence, implementation exit, new prerequisite authorization,
representative educator evidence or independent security/privacy assurance. COMM-1 authorization
remains recorded; its publication work cannot proceed until the source-fence requirement is met.

## Subsequent authorized account prerequisite

François then authorized the scoped account-fence ADR, implementation and tests, with another
four-agent checkpoint review before resuming COMM-1. [ADR 0047](../adr/0047-private-identity-account-source-fence.md)
and the [implemented prerequisite evidence](identity-account-source-fence-evidence.md) record
68 focused passes, database-enforced missing-account protection, migration safety and all four
completed specialist dispositions. That specific gap is closed in the local engineering proof.
The historical counterexamples above still reject the weaker row-only candidate.

The complete audience source fence remains not qualified. Following the new review, only
remaining audience projection/race/denial qualification may resume under existing authority;
publication implementation stays blocked. The identity tuple includes the original actor as
well as account, association, participation and membership. Account rebinding with the same
account ID cannot transfer old-chain access. No new slice, representative or independent
assurance, real data, consumer or release is authorized by this checkpoint.

The final coordinator integration later ran
`CHIMWEMWE_TEST_DATABASE=chimwemwe_commit_final8_20261023 make check` on the combined checkout.
Every required stage passed: 335 core tests, 52 web unit tests, 70 browser tests, both dependency
audits, the production build, documentation/repository tooling and shell tooling. That integration
result protects the current repository state; it does not qualify the remaining audience fence or
authorize publication work.
