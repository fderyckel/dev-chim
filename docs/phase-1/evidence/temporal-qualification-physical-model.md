# ADR 0018 T1-A temporal-qualification physical-model evidence

- Status: Implemented; focused and complete repository verification pass; ADR 0018 conditions remain open
- Date: 2026-09-25
- Owner: Platform engineering
- Governing records: [ADR 0018](../../adr/0018-temporal-records-correction-audit-and-evidence-semantics.md), [decision review](../../architecture/temporal-records-decision-review.md), [temporal contract](../../architecture/temporal-records-correction-and-evidence.md), [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0017](../../adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md), and [threat model TM-01/TM-09/TM-14/TM-15](../../security/threat-model.md)
- Scope: first closed physical-model increment of the neutral T1 proof; no temporal action, public interface, or school module

> Follow-up: [T1-B](temporal-qualification-revision-boundary.md) later adds two private revision
> actions and named reads. Statements below that the resources expose no actions describe the
> T1-A evidence boundary at the time it was recorded, not the current combined T1-A/T1-B state.

## Question

Can the production core represent one neutral revisioned aggregate and one append-only fact with
database-enforced identity, tenant, effective-time, immutability, and query semantics before a
callable correction boundary is introduced?

## Implemented boundary

Four tenant-owned resources are registered in the always-authorized, actor-required platform
domain under `Chimwemwe.Platform.TemporalQualification`:

| Resource | Qualification responsibility |
| --- | --- |
| `Aggregate` | Stable tenant-and-scope identity plus a mutable current-revision selector |
| `Revision` | Immutable writer-timestamped recorded revision with operation identity and one consecutive predecessor |
| `Segment` | Immutable half-open Date interval and synthetic value inside one exact revision |
| `Fact` | Immutable append-only entry or explicit reversal inside one tenant and scope |

Every resource exposes zero Ash actions and a deny-all policy. The tables are not a generic
temporal API, reusable persistence library, business module, or future-domain schema. Direct SQL
exists only in synthetic tests to pressure-test PostgreSQL invariants and does not become a
supported production write path.

## Database invariants

The reviewed migration enforces:

- non-null private tenant keys and tenant-qualified identities;
- a current selector that can reference only a revision of the same tenant and aggregate;
- one monotonic selector direction after initial publication;
- one consecutive, unbranched revision number per tenant and aggregate;
- a predecessor from the same tenant and aggregate;
- writer-assigned `recorded_at` that replaces caller-supplied values;
- immutable revisions, segments, and facts plus immutable aggregate identity;
- serialized segment insertion and no overlap inside one revision, while a successor revision may
  cover the same effective dates as historical state;
- segment-to-revision integrity across tenant and aggregate; and
- a reversal target from the same tenant and synthetic scope, with at most one reversal of an
  entry and no reversal-of-reversal.

The current selector is intentionally the only mutable field in the revisioned physical model.
The aggregate trigger rejects backward movement or clearing after selection. A later named action
still has to make revision creation, segment creation, selector advancement, operation result,
audit, outbox, and idempotency one writer transaction.

## Executable scenarios

Six focused PostgreSQL tests prove:

1. all four resources satisfy the production resource contract and remain action-closed;
2. exact revision 1 remains queryable after revision 2 becomes current, while current and
   effective query shapes resolve revision 2;
3. two racing overlapping segment inserts serialize and exactly one is rejected;
4. cross-tenant aggregate links, cross-aggregate predecessors and selectors, cross-revision
   segments, and cross-scope or cross-tenant reversals fail closed;
5. revision, segment, fact, and aggregate-identity update/delete attempts fail through direct SQL;
   and
6. an original fact, reversal, and replacement remain visible under two operation identities and
   rebuild to the corrected net synthetic quantity.

The tests use only synthetic UUIDs, labels, dates, and quantities. They contain no school,
identity-provider, child, employee, finance, or other production data.

## Migration review

AshPostgres generated the migration and resource snapshots. Manual review corrected two known
generator-ordering hazards before acceptance:

- nullable tenant-qualified self-references were emitted before their compound destination
  indexes and with unsafe `MATCH FULL`; the reviewed migration adds them after the indexes with
  aggregate/scope-qualified `MATCH SIMPLE` constraints; and
- the current-revision and segment-revision relationships require three-column compound keys so
  tenant equality alone cannot join the wrong aggregate.

Trigger functions and triggers are separate migration statements because PostgreSQL prepared
DDL accepts one command at a time. The down path removes self-references before their supporting
indexes. Apply, rollback, reapply, and resource-snapshot drift checks pass against the synthetic
test database. Rollback is development-only empty/synthetic-data evidence; retained temporal
history would require forward repair or an approved recovery point.

## ADR 0018 condition status

| Gate | T1-A evidence | Remaining before the gate can pass |
| --- | --- | --- |
| TR-01 | Physical revisioned aggregate and append-only fact exist in production core with no education module | Complete neutral action/read proof and all T1 obligations |
| TR-02 | Tenant, aggregate, and scope-qualified alternate-write negatives pass | Capability-protected actions and history reads, missing-context and disclosure negatives |
| TR-03 | Operation identifiers, consecutive revisions, one branch, and monotonic selector are represented | Expected-revision action, exact idempotent result, changed-request and concurrent correction proof |
| TR-04 | Writer time, revision-scoped interval exclusion, and physical exact/current/effective queries pass | Named authorized reads and explicit unsupported `as_known_at` failure |
| TR-05 | No claim | Atomic state/audit/outbox/idempotency and consumer-mode evidence |
| TR-06 | No claim | Retention, legal hold, redaction/erasure receipt, deactivation, and projection propagation |
| TR-07 | Apply/rollback/reapply and drift pass | Expand-and-contract limits, baseline import, reconciliation, backup/restore, and projection convergence |
| TR-08 | Preserved: the code is explicitly qualification-only and no common temporal library is introduced | Continue to block promotion until two real domain implementations justify it |

No TR-01 through TR-07 condition is marked complete by T1-A.

## Verification

Focused commands:

```sh
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/temporal_qualification_test.exs
cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check \
  --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
cd apps/chimwemwe_core && mise exec -- env MIX_ENV=test mix ecto.rollback --step 1
cd apps/chimwemwe_core && mise exec -- env MIX_ENV=test mix ecto.migrate
```

Results:

- 6 temporal-qualification tests passed;
- migration apply, rollback, and reapply passed;
- generated migration/resource-snapshot drift passed; and
- warnings-as-errors compilation passed.

The required complete `make check` passed on 2026-09-25. It included 24 repository Python tests,
103 Phase 0 Elixir/PostgreSQL tests, six generated TypeScript client tests, 75 production-core
tests, seven UI-0 unit tests, and 12 Playwright tests across wide, medium, and narrow viewports.
Formatting, lint, generated artifacts and migration drift, dependency and warning audits, both
Dialyzer suites, documentation conventions, types, the production browser build, keyboard and
reflow checks, automated accessibility checks, and Git whitespace validation also passed.

The first complete run reached the browser stage but could not bind `127.0.0.1:3000` while the
repository's development server was active. That exact process was temporarily stopped, the
required command passed with its fresh production test server, and the development server was
restored on the same address. No test configuration or server workaround was retained.

## Scope and next gate

T1-A adds no named publication, correction, reversal, history, retention, hold, erasure, import,
or reconciliation action. It adds no security-audit or outbox schema specific to the proof, no
idempotency manifest, no descriptor, public API, UI, dispatcher, worker, production runtime
wiring, business vocabulary, or school module.

The next bounded increment was implemented as
[T1-B](temporal-qualification-revision-boundary.md): separate capability-protected publication
and correction actions with exact replay and atomic audit/outbox evidence, plus named current,
exact, effective, history, and explicitly unsupported recorded-time reads. Retention/erasure and
recovery remain later T1 increments rather than being inferred from this physical model.
