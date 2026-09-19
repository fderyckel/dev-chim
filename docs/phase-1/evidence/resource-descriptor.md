# Core-foundation slice 1B resource-descriptor evidence

- Status: Focused and full working-tree checks passed; ADR 0019 subsequently accepted
- Owner: Platform engineering
- Date: 2026-09-15
- Source: revision `61469c9` plus the current uncommitted Phase 0 and Phase 1 work
- Environment: Apple silicon macOS 26.6.2, Erlang/OTP 29.0.5, Elixir 1.20.3, Ash 3.33.3, PicoSAT 0.2.3, Python 3.14.5, PostgreSQL 18.6, and Node.js 24.15.0
- Boundary: [core foundation](../../architecture/core-foundation-boundary.md)

## Implemented proof

`Chimwemwe.Platform.ResourceDescriptor` is a production-core build and release tooling boundary. It derives a Chimwemwe-owned descriptor from two code-controlled inputs: an Ash resource that passes `Chimwemwe.Platform.ResourceContract` and an explicit public allowlist.

The output contains only:

- schema and model versions plus a stable resource reference;
- stable field references, portable types and selected constraints, nullability, primary-key shape, and one of Public, Internal, Confidential, or Restricted classification;
- stable named-action references, read or mutation kind, public arguments, and bounded read-pagination characteristics;
- tenant-owned or global-reference scope derived from the resource's code-owned ownership declaration; and
- a SHA-256 revision over a canonical representation.

Fields and actions are sorted by their stable reference, nested object keys are canonicalized, and pretty encoding is byte-for-byte deterministic. The allowlist cannot supply tenant scope or unknown keys. The descriptor excludes source attribute/action names, Ash modules, policy implementations, tenant keys, private fields and arguments, persistence details, and executable behavior.

Only neutral in-memory resources compile in the test environment. The production domain remains empty, so this slice intentionally creates no production descriptor artifact.

## Test evidence

Focused command: `make test-fast`

Focused result: 25 production-core tests passed, including 11 descriptor tests. The descriptor cases prove:

- valid tenant-owned and global-reference resources derive the correct ownership-controlled scope;
- UUID, string, enum, and integer fields expose only selected portable constraints;
- all four platform classifications are represented;
- public action arguments and bounded pagination are included while private arguments are absent;
- private, missing, unsupported, or unallowlisted fields and actions fail closed;
- invalid resources, unsupported argument types, generic mutation references, invalid versions, malformed or cross-resource references, duplicate sources, duplicate public references, and authority-shaped extra keys fail closed;
- equivalent allowlist order produces the same descriptor, encoding, and revision; and
- a source-field rename preserves a stable field reference while an explicit model-version change changes the revision.

Core command: `./bin/core-check`

Core result: shell and Elixir formatting, warnings-as-errors compilation, strict Credo analysis, Hex advisory and unused-dependency checks, Dialyzer, 25 tests, and Git whitespace checks passed.

Full command: `make check`

Full working-tree result: 5 repository-tool tests, 94 Phase 0 Ash/PostgreSQL tests, 6 Phase 0 TypeScript client tests, and 25 Phase 1 core tests passed. Ruff, ShellCheck, documentation and phase-boundary validation, generated migration, Phase 0 descriptor, OpenAPI, and TypeScript drift checks, TypeScript checking, Credo, Hex and npm audits, unused-dependency checks, Dialyzer, formatting, and Git whitespace checks also passed.

One strict-lint finding in the concurrently advanced Phase 0 tenant-movement test was resolved by extracting its row-copy loop into a helper without changing behavior; the full Phase 0 suite then passed.

## Limits and next gate

- This is a descriptor builder, not a second model, metadata engine, or runtime schema.
- There is no production resource, descriptor artifact, registry, consumer, persistence, renderer, report executor, or public interface.
- The builder supports only the four portable Ash field types proven by the Phase 0 scenario: UUID, string, enum, and integer. A new type requires an explicit mapping and compatibility tests.
- Relationships, calculations, aggregates, accepted-attribute mapping, datasets, metadata compatibility persistence, and removal choreography remain later evidence-driven extensions.
- Descriptor classification is code-declared and exposed; this slice does not yet validate classification against a durable registry or enforce downstream propagation.
- ADR 0019 is now Accepted. This slice still does not authorize a descriptor consumer, durable metadata, renderer, report executor, or public interface; each must pass its production security gate.
