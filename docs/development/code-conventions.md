# Code conventions

## General

- Prefer explicit, small modules with one clear owner and stable public boundaries.
- Name operations with domain verbs. Avoid generic `update`, `process`, or `handle` when a specific action exists.
- Keep configuration typed and validated. Secrets remain outside source and ordinary configuration records.
- Return structured errors using validation, forbidden, conflict, not found, rate limited, retryable dependency, and internal failure categories.
- Keep generated code and migrations reviewable; generated does not mean trusted.

## Elixir

- Let `mix format` own formatting.
- Keep aliases explicit and avoid surprising global imports.
- Use pattern matching and tagged results at boundaries; reserve exceptions for exceptional failures.
- Keep Ash actions, policies, validations, and changes close to the resource they govern while domain-wide orchestration remains in named services or actions.
- Never issue an unscoped tenant-owned query.
- Mirror critical invariants with PostgreSQL constraints.

## Domain model authoring

[ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md) owns the decision,
rationale, alternatives, and limits for code-defined models and governed metadata. The workflow
below applies within an authorized implementation slice. The [core foundation map](../architecture/core-foundation-boundary.md#ash-boundary)
describes the implementation; the [Phase 0](../phase-0/handover-evidence.md) and
[Phase 1](../phase-1/handover-evidence.md) handovers retain the authoring and definition evidence.

### Authoring workflow

1. Start with `Chimwemwe.Platform.Resource` and declare tenant ownership or global reference data.
2. Define fields, relationships, named actions, policies, tenancy, and business invariants in Ash
   code. Tenant choices such as terminology and grading schemes remain typed domain records or
   configuration changed through named actions.
3. Generate and review the PostgreSQL migration using the [migration discipline](migrations.md),
   including tenant keys, constraints, indexes, locks, retained-data compatibility, and rollback
   or forward-fix boundaries.
4. Register the resource in its owned domain and run the resource-contract, positive,
   negative-authorization, and cross-tenant checks.
5. When an approved consumer needs metadata, derive and drift-check an allowlisted resource
   descriptor. View and report definitions reference it rather than copying types or permissions.
6. Follow the [verification contract](testing.md). Changes to the authoring contract must rerun
   the relevant tenant, authorization, migration, report, and generated-interface negative tests.

### Descriptor and definition compatibility

Keep derivation one-way: domain code → resource descriptor → experience metadata. The descriptor
is a generated, versioned projection with stable Chimwemwe-owned references, types, approved
relationships and operations, labels where needed, and compatibility information. It must not
expose Ash internals as a permanent client contract. Changed or removed references must produce
build or deployment compatibility failures; runtime consumers reject unknown or incompatible versions.

For the bounded presentation-definition contract:

- Code-owned release declarations name extension schema keys and versions. A trusted immutable
  registry derives the descriptor from a contract-valid tenant-owned resource and explicit
  field/action allowlists.
- Content is limited to a title, field order, field labels, and one allowlisted public read action.
  It cannot select private references, authorization, queries, code paths, tenants, repositories,
  or executable behaviour.
- Stored definitions pin module version, schema version, descriptor revision, resource reference,
  derived classification, and optimistic lock version.
- Publication checks independent module gates and a separate actor capability on the writer;
  minimized audit, outbox, and exact-replay evidence commit in the same transaction.
- Exact internal resolution requires separate read authority, current module gates, agreement on
  schema/resource/descriptor/content/classification, and an exact or explicitly compatible module
  version. It returns metadata only, without enumeration, a public interface, rendering,
  domain-record reads, or invocation of the stored action.

The broader presentation possibilities in ADR 0019 do not extend this bounded contract. A valid
stored definition does not itself provide a renderer or authorize a consumer.

### Consumer and extension checks

- Every view read or submission enters an authorized read or named action with the real actor and
  tenant. A report uses a versioned policy-protected dataset or read action, never a raw table or
  user-supplied SQL. Rendering cannot broaden the dataset.
- APIs derive from explicit public actions; metadata cannot expose private fields or generic
  updates. Jobs and integrations re-establish tenant and actor authority rather than inheriting it
  from a copied definition.
- Unavailable, unentitled, or inactive modules cannot execute definitions. Deactivation retains
  them for governed reactivation or removal. Definition records stay tenant-qualified, versioned,
  attributable, recoverable, and classified at least as strongly as their referenced data.
- Give each metadata type one owner, versioned schema, validator, compatibility rule, and removal
  path. Reject tenant code and parallel schema or authorization engines.
- Use ordinary Ash resources, information APIs, and supported generators. Add an abstraction only
  after at least two representative consumers establish the same stable need and it removes more
  duplicated ownership than it introduces. A custom generator needs evidence that a smaller
  convention is insufficient.

Custom fields remain deferred under [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md#decision).
When assessing a future request, use domain code for fields affecting authorization, tenancy,
workflow, module gates, classification, relationships, uniqueness, invariants, or critical
calculations; safeguarding, attendance, finance, statutory, contractual, audit, or legal evidence;
stable API, integration, import/export, or cross-module contracts; or material indexing, joins,
aggregation, retention, or recovery guarantees. Even non-critical local fields need separately
approved storage and query design based on actual use cases. General renderers, visual model
builders, and schema compilers also require the evidence and approval in
[deferred choices](../architecture/deferred-choices.md).

## Python repository tooling

- Python is for repository support tools during Phase 0, not a second domain implementation.
- Use type hints for public functions and `pathlib.Path` for paths.
- Use the standard library unless a dependency clearly improves correctness.
- Ruff owns formatting and linting; pytest owns tests.
- `make fix` applies Ruff's safe fixes before the repository formatters run.
- Invoke Python through `uv run` rather than a global environment.

## Shell

- Use POSIX `sh` for repository entrypoints unless a documented feature requires another shell.
- Start scripts with `set -eu`, quote variables, resolve the repository root, and use explicit paths for destructive operations.
- ShellCheck must pass.
