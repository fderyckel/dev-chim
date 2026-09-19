# Ash dependency upgrade exercise

- Status: Pass with bounded remediation
- Owner: Platform engineering
- Date: 2026-09-13
- Time box: 30 minutes; the exercise completed within the budget
- Source: revision `5c4569024d00` plus the current uncommitted Phase 0 spike changes
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, PostgreSQL 18.6
- Decision: The tested patch update is compatible without application changes; compiler-warning drift is machine-bounded, and the subsequent non-patch exercise also passes

## Scope and method

`mix hex.outdated` reported the repository lock as current, so there was no forward update available to exercise. The test therefore used an isolated disposable copy and the immediately preceding non-vulnerable patch releases as its baseline. It did not alter the repository's `mix.exs` or `mix.lock`.

The baseline was resolved with exact temporary requirements, compiled, audited, used to generate a fresh migration, and run against a dedicated synthetic database. The temporary requirements were then restored to the repository ranges, the three framework dependencies were updated, and the same compile, audit, migration, and test checks were repeated against the existing database. Older Ash 3.32 releases were deliberately excluded because Hex marks them as vulnerable.

| Dependency | Previous patch | Candidate/current | Release-note relevance |
| --- | --- | --- | --- |
| [Ash](https://hex.pm/packages/ash/3.33.3) | 3.33.2 | 3.33.3 | Fixes dependency compilation reading the application codepoint setting |
| [AshJsonApi](https://hex.pm/packages/ash_json_api/1.7.1) | 1.7.0 | 1.7.1 | Excludes resources without a JSON:API type from filter schemas |
| [AshPostgres](https://hex.pm/packages/ash_postgres/2.13.1) | 2.13.0 | 2.13.1 | Avoids PostgreSQL `MERGE` for upserts |

No transitive dependency changed. The candidate lock produced in the disposable copy was byte-for-byte equal to the repository's existing lock.

## Commands and results

The temporary copy used the repository toolchain through `mise`. Its database was named `ash_foundation_lab_upgrade_review_20260913` and was dropped after the exercise.

| Check | Previous patch result | Candidate result |
| --- | --- | --- |
| `mix compile --warnings-as-errors` | Passed; no spike-code warning failed compilation | Passed; no application change required |
| `mix hex.audit` | No retired or security-advisory packages | No retired or security-advisory packages |
| `mix hex.outdated` | Not applicable to the deliberately pinned baseline | Every direct dependency up to date |
| `mix ash_postgres.generate_migrations --check --migration-path priv/upgrade_previous/migrations --snapshot-path priv/upgrade_previous/resource_snapshots` | Snapshots created for comparison | Passed after the update; no resource drift |
| Fresh generated baseline | SHA-256 `a43edd46042463ff6091798589a329f45610ad1d1f2852bd60881783d5113503` | Same SHA-256; byte-for-byte identical migration output |
| `PGDATABASE=ash_foundation_lab_upgrade_review_20260913 MIX_ENV=test mix test` | 21 tests passed | 21 tests passed against the same existing schema |

The lock diff contained only these direct patch changes:

- `ash` 3.33.2 to 3.33.3;
- `ash_json_api` 1.7.0 to 1.7.1; and
- `ash_postgres` 2.13.0 to 2.13.1.

Application-source diff required by the candidate: zero files. Migration diff: zero bytes. Test regressions: zero.

## Warning review

Clean dependency compilation on both sides emitted warnings in third-party packages under Elixir 1.20/OTP 29. The observed categories included deprecated Erlang `catch`, deprecated Mix `xref` configuration, redundant or unreachable clauses, type-analysis findings, unused requirements, optional Igniter/Owl module references, and native compiler/linker warnings. No warning originated in the spike modules, and `mix compile --warnings-as-errors` completed successfully before and after the update.

The candidate still emits the runtime warning that `Ash.Error.Invalid.TenantRequired` has no specific AshJsonApi error implementation. The request continues to fail closed and its test passes, but the patch update does not resolve the stable-error-mapping gap. The generated baseline continues to print the expected destructive-operation warning because its explicit `down` path drops fresh baseline tables; [the migration review](ash-pressure-test.md#generated-migration-review-slice) bounds that warning to disposable baseline evidence.

Follow-up on 2026-09-15: the [machine-normalized warning baseline](ash-dependency-warning-baseline.md) now forces the complete locked dependency compile, records 39 warning groups with their owning packages and locations, fixes the lock digest and Elixir/OTP pair, and rejects both additions and removals. The missing-tenant JSON:API implementation was separately added and its prior runtime warning is no longer part of current evidence. These changes close items 1-3 below for the current pinned graph without rewriting the historical patch comparison.

Follow-up on 2026-09-16: the [AshJsonApi non-patch exercise](ash-nonpatch-upgrade-exercise.md) upgrades 1.6.6 to 1.7.1 on the same schema with no application, generated migration, OpenAPI, descriptor, test, or advisory regression. It closes the historical item 3 below. Preceding Ash and AshPostgres minors were rejected as baselines because they are advisory-affected.

## Assessment and bounded remediation

This patch-level exercise passes: the update is three lock-entry changes, requires no application edits, preserves migration output, keeps the existing database compatible, passes the full spike test set, and introduces no reported dependency advisory.

Upgrade and dependency health is recorded as **Pass with bounded remediation**, not an unconditional pass. Before ADR 0002 is accepted, Platform engineering must:

1. preserve the checked classification and zero-delta warning baseline for the pinned Elixir/OTP pair and review any dependency change explicitly;
2. preserve the stable JSON:API mapping for missing tenant context; and
3. preserve the non-patch review method for future framework minors and majors; the first recorded AshJsonApi minor exercise now passes.

## Limits

- This document remains patch-level evidence; the linked follow-up separately covers one AshJsonApi minor transition, not an Ash core, AshPostgres, or major transition.
- The exercise used a disposable local copy and synthetic database, not a clean CI host.
- It proved compatibility with the existing schema but did not rehearse a retained-data migration, rolling deployment, or mixed-version cluster.
- Warning categories are normalized for the current complete lock; the non-patch follow-up separately records three reviewed source-location moves and no message or net-group change.
- Package freshness and advisory results are a dated snapshot and must be rechecked at the adoption review.
