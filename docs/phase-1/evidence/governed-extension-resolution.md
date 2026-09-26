# Slice 1I-B exact governed-definition resolution

- Status: Implemented; focused, production-core, and complete repository verification passed on 2026-09-26
- Owner: Platform engineering
- Governing records: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md), and [TM-16](../../security/threat-model.md)
- Scope: exact internal compatibility resolution of one retained definition only

## Question

Can one trusted internal consumer resolve a retained tenant definition against current code and
module state without letting metadata choose authority, expose another tenant, enumerate
definitions, execute a domain read, or become a renderer?

## Implemented boundary

`GovernedExtension.resolve_definition/5` accepts only the configured persistence runtime, a
revalidated code-owned release manifest and extension registry, validated execution context, and
one exact definition UUID. Invalid identifiers fail before persistence. There is no list, search,
filter, history, or bulk-read function and no public Ash read action.

Inside the authoritative writer transaction, the resolver requires
`platform.extensions.definitions.read` before loading definition state. It reads with tenant and
definition ID together, so absent and cross-tenant IDs return the same not-found result. It then
rechecks the read capability together with release, entitlement, active module version, and active
dependency gates under the module lifecycle lock. Publication permission is deliberately separate.

The stored schema key must resolve through the current trusted registry and current release. The
retained module relationship, schema version, resource reference, descriptor revision, normalized
content, and derived classification must all match current code. The published module version must
equal the active version or appear explicitly in the active release's `compatible_from` list.
Implicit compatibility fails closed.

The resulting immutable `DefinitionView` reports exact or compatible status and carries only the
definition contract, normalized content, classification, and lock version. It omits tenant, actor,
activation, entitlement, routing, placement, repository, authority-graph, audit, outbox, and
idempotency identifiers. It does not invoke the retained `read_action` reference.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Exact internal resolution | A published definition resolves to an immutable exact view with normalized content and no platform/evidence identifiers |
| Authority separation | Removing only the read grant denies resolution while the same actor can still publish a revision |
| Tenant non-disclosure | Another authorized tenant receives the same not-found result for the first tenant's definition ID |
| Explicit compatibility | A stored 1.0.0 definition fails under an implicit 1.1.0 upgrade and resolves as compatible only when 1.0.0 is declared in `compatible_from` |
| Lifecycle gate | An inactive module retains its definition but resolution fails with the module-gate error |
| Contract drift | Changed descriptor or schema versions fail without returning definition content |
| Retained-state defence | Directly corrupted private-field content and a lowered stored classification both fail current registry revalidation |
| Availability | An unavailable persistence runtime fails closed with the existing non-disclosing retryable-dependency result |
| Scope restraint | Structural assertions prove no definition listing or execution function exists |

## Verification

The governed-extension suite passes all 13 tests with deterministic seeds 0 and 799205. The
combined governed-extension and module-lifecycle suites pass all 24 tests in dependency-reversing
order. Strict compilation, Credo over 119 source files and 1,263 modules/functions, Dialyzer with
zero errors or skipped warnings, generated migration/snapshot drift, and `make test-fast` all pass.
The production-core suite now passes all 120 tests.

Complete `make check` verification also passes: 25 Python tests, 6 generated TypeScript
contract tests, 106 Phase 0 Elixir/PostgreSQL tests, 120 production-core tests, 20 web unit
tests, 12 UI-0 browser tests, 6 connected UI-1A browser tests, and 1 unavailable-core recovery
browser test, together with formatting, lint, dependency, type, generated-contract, build, and
whitespace gates.

## Remaining gates

Slice 1I-B is the Phase 1 closure of governed extension contracts, not permission to execute or
render them. A real module or interface must still re-authorize the referenced named action with
the real actor and tenant. Stored-action execution, domain-record reads, rendering, public/client
contracts, pagination or collection exposure, reporting/export, caching, search, schema evolution,
custom fields, and independent security review remain later boundaries. The next Phase 1 boundary
is Slice 1J operational readiness.
