# Slice 1I-A governed presentation definitions

- Status: Implemented; focused, production-core, migration-lifecycle, and complete repository verification passed on 2026-09-26
- Owner: Platform engineering
- Governing records: [ADR 0003](../../adr/0003-tenant-model-and-optional-postgresql-rls.md), [ADR 0005](../../adr/0005-domain-action-and-state-transition-convention.md), [ADR 0007](../../adr/0007-transactional-outbox-and-event-envelope.md), and [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md)
- Scope: typed tenant-owned presentation-definition publication only

## Question

Can a tenant publish bounded presentation choices against an exact code-owned module, schema, and
resource descriptor while keeping authorization, domain behavior, and execution in code, and while
failing closed on stale, private, incompatible, cross-tenant, or authority-shaped metadata?

## Implemented boundary

`ReleaseManifest` declarations now accept an optional immutable list of stable extension contract
keys and positive schema versions. Existing declarations remain compatible and default to no
contracts. Duplicate, malformed, and invalid declarations fail at manifest construction.

The trusted `GovernedExtension.Registry` binds one presentation schema to a released module and a
descriptor derived from a contract-valid tenant-owned resource plus explicit field and read-action
allowlists. Its schema accepts only a bounded title, ordered unique allowlisted fields, labels for
those fields, and one allowlisted public read action. Extra keys, private or stale references,
unsupported resources, and authority-shaped or executable content fail closed. Classification is
derived from the most sensitive referenced field and cannot be caller-selected.

`GovernedExtension.publish_definition/5` validates exact input, context, release declaration,
schema version, descriptor revision, and normalized content before entering the authoritative
writer. The private Ash action then revalidates the trusted registry and manifest, acquires the
module lifecycle and tenant-definition transaction locks, and independently requires release,
entitlement, compatible active module and dependencies, plus the
`platform.extensions.definitions.publish` capability.

Expected version zero creates the caller-supplied stable definition UUID; a positive exact version
revises the same aggregate. Exact and concurrent retries return the committed result. Changed
idempotency reuse, stale versions, duplicate keys, cross-tenant IDs, inactive or incompatible
modules, and missing authority fail without surviving state or evidence.

The definition, minimized audit fact, minimal outbox fact, and completed idempotency result commit
or roll back together. Audit and outbox payloads retain contract and version references but omit
the title, labels, and complete definition content. Stored metadata never grants read or write
authority.

## Persistent model and migration review

The generated table has a private non-null tenant key and a `MATCH FULL`, tenant-qualified foreign
key to the module activation. Unique tenant/module/definition identity, contract lookup indexes,
positive versions, stable dotted keys, semantic module versions, exact SHA-256 descriptor
revisions, known classifications, and object-shaped JSON content are enforced in PostgreSQL.

The negative database test exposed that backslash-escaped dots in generated SQL had become wildcard
matches. The reviewed resource, migration, and snapshot therefore use `[.]` literal-dot character
classes, and a direct alternate-write test proves malformed keys and versions are rejected.

The down migration refuses removal while any governed definition or matching publication audit,
outbox, or idempotency evidence remains, returning
`governed extension rollback requires empty definitions and publication evidence`. The refusal was
observed with retained synthetic publication state. After exact fixture cleanup, rollback and
reapply passed, and the generated migration/snapshot drift check passed.

## Executable evidence

| Requirement | Evidence |
| --- | --- |
| Immutable compatible contracts | Manifest defaulting, duplicate rejection, schema lookup, and descriptor-derived registry tests |
| Strict typed content | Positive normalization plus extra-key, private-reference, stale-revision, undeclared-schema, and malformed-content rejection |
| Classification | Restricted referenced field produces restricted retained state; the caller has no classification input |
| Independent gates | Dependency, release version, activation, entitlement, and actor-capability failures are exercised separately |
| Optimistic and exact replay | Create, revision, exact retry, concurrent retry, stale version, and changed-key reuse tests |
| Tenant isolation | Cross-tenant publication is non-disclosing and the compound database foreign key rejects an alternate write |
| Atomic evidence | Definition, audit, outbox, and idempotency rows are read back together; evidence payloads are checked for content minimization |
| Transaction rollback | Injected failure after outbox insertion leaves zero publication facts and permits a safe retry |
| Alternate-write defence | Database checks reject malformed keys, schema and lock versions, semantic versions, descriptor revisions, classifications, and non-object content |

## Verification

The focused suite passed with two deterministic seeds:

```sh
mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/governed_extension_test.exs --seed 0

mise exec -- env MIX_ENV=test mix test \
  apps/chimwemwe_core/test/chimwemwe/platform/governed_extension_test.exs --seed 799205
```

Both runs passed all 8 tests. Compilation with warnings as errors, strict Credo over 117 source
files and 1,244 modules/functions, generated migration/snapshot drift, retained-state rollback
refusal, empty rollback/reapply, and `make test-fast` all pass. The extension and module-lifecycle
suites also pass together in dependency-reversing order, proving the activation foreign-key cleanup
is test-order independent.

The complete `make check` gate passed: 25 Python repository tests, 106 Phase 0 Elixir/PostgreSQL
tests, 115 production-core Elixir/PostgreSQL tests, 6 generated-client tests, 20 web unit tests,
12 synthetic browser tests, 6 connected local-bridge browser tests, and 1 unavailable-core recovery
test. Both Elixir type analyses reported zero errors and zero skipped warnings. Formatting, strict
lint, dependency audits, generated contracts, migration drift, production build, accessibility,
responsive layout, and Git whitespace checks also passed.

## Remaining gates

Slice 1I-A deliberately has no real module or browser consumer, checked production descriptor
artifact, read boundary for stored definitions, renderer, report dataset, metadata executor,
custom-field store, runtime schema, workflow language, public interface, provisioning surface, or
school vocabulary. A later 1I increment needs separate authorization and must preserve exact
compatibility, authorization at every underlying action, classification, tenant isolation,
deactivation retention, and forward-only schema evolution. Slice 1J operational readiness remains
a later boundary.
