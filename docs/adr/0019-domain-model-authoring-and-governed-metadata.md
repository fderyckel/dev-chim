# ADR 0019: Domain model authoring and governed metadata

- Status: Accepted
- Date: 2026-09-15
- Decision date: 2026-09-16
- Accountable owner: Platform engineering
- Deciders: Architecture review group, product owner, and security architecture
- Supersedes: None

## Context

Chimwemwe needs a productive way to add and evolve school capabilities without making every local variation a code release. Frappe-style runtime metadata is flexible, while Odoo-style source models and Ash resources make types, behaviour, policy, and migrations reviewable. Treating both as authoritative would create two model engines whose schema, security, API, and upgrade behaviour could diverge.

Ash already provides a declarative source model for resources, fields, relationships, calculations, named actions, policies, and tenancy. Its resource information APIs can support derived development tools. It does not by itself provide a safe tenant-operated runtime domain-model designer, and Chimwemwe should not build one speculatively.

## Decision drivers

- One authoritative domain and authorization model.
- Fast, understandable development for new school capabilities.
- Bounded tenant variation without forks or per-tenant executable code.
- Reviewable PostgreSQL constraints and expand-and-contract migrations.
- Policy-preserving forms, views, reports, APIs, jobs, and integrations.
- A small operational surface that can evolve without locking public contracts to Ash internals.

## Considered options

1. A governed hybrid: code-defined Ash domain models with derived and validated experience metadata.
2. Runtime metadata defines resources, fields, relationships, workflows, and permissions.
3. Source code defines every domain and presentation concern with no runtime metadata.
4. A Chimwemwe YAML or JSON schema compiler generates Ash resources and migrations.

## Decision

Adopt the governed hybrid.

Source-controlled Ash resources and named actions are the authoritative application model. They own persistent fields and types, relationships, identities, invariants, calculations with business meaning, tenancy, authorization policies, public actions, and migration intent. PostgreSQL remains authoritative for persisted state and critical database constraints.

Chimwemwe may derive a versioned resource descriptor from the public, allowlisted Ash model. The descriptor may expose stable Chimwemwe-owned references to approved fields, relationships, actions, types, and tenancy characteristics. It is a build- or release-time contract for tooling, not another source of domain truth and not a promise that Ash's internal code-generation files are a public format.

Validated experience metadata may define labels, help, localization, layout, widgets, ordering, saved filters, report columns, and references to allowlisted actions or policy-protected reporting datasets. It may not:

- create arbitrary resources, relationships, database schemas, or executable code;
- add or weaken authorization, tenancy, module, entitlement, placement, or data-classification rules;
- expose a private field or generic mutation;
- contain arbitrary SQL or invoke an action outside its allowlist; or
- silently reinterpret a missing, stale, or incompatible descriptor reference.

Experience metadata is a controlled input to browser and native component systems, not a promise of one universal screen tree. It may safely support repeated form and view primitives, while device-specific navigation, density, keyboard behaviour, touch interaction, recovery, and workflow composition remain intentional product design. No generated form or hidden interface control is an authorization decision.

Every invocation still enters a named domain action or approved read dataset with the real actor and tenant. Views and forms never authorize access. Report definitions never acquire direct table authority.

Runtime business configuration is not the same as runtime schema design. Tenant-defined roles, calendars, code lists, grading schemes, terminology, and similar school choices should be ordinary tenant-owned Ash resources or typed configuration with named actions and explicit validation. Schools may change those values without a deployment while their structure, invariants, and security remain code-defined.

Tenant-defined custom fields remain a deferred, optional extension. If evidence justifies them, they must be constrained to non-critical local information, inherit the parent record's tenant, policy, retention, and classification boundary, and use a separately approved storage and query design. A proposed custom field graduates to the code-defined Ash model when it affects authorization, workflow, referential integrity, uniqueness, legal or audit evidence, safeguarding, attendance, finance, retention, an integration or stable API, or requires material indexing and query guarantees.

Initial developer tooling should use Ash's normal resource DSL, information APIs, and supported generators. A custom Chimwemwe DSL, schema compiler, visual model builder, custom-field store, or general renderer requires repeated concrete use cases and a separate accepted boundary. The first implementation should prove the authoring contract and descriptor with neutral synthetic resources before adding a school business module.

## Consequences

### Positive

- Developers get a declarative, typed model that can drive persistence, policy, interfaces, and tools from one source.
- Schools can vary presentation and reporting without tenant code forks.
- Critical school semantics remain code-reviewed, testable, migratable, and recoverable.
- A Chimwemwe-owned descriptor limits coupling between future tools and Ash internals and preserves the Phoenix/Ecto fallback.

### Negative

- Runtime users cannot invent arbitrary core tables or workflows as they can in a fully metadata-first platform.
- Descriptor and metadata schemas need versioning, validation, ownership, and compatibility tests.
- Some apparently simple tenant requests must become reviewed product changes when they cross the graduation boundary.
- A constrained custom-field facility, if later justified, will need explicit storage, indexing, export, retention, and recovery limits.

## Security, privacy, operability, and migration effects

Experience metadata is tenant-owned where customized, versioned, attributable, and validated against the exact compatible resource descriptor. Unknown fields, removed actions, invalid types, cross-tenant references, and incompatible versions fail closed. Definitions inherit the highest data classification and access restrictions of the fields or dataset they reference.

Rendering, reporting, export, integration, and background execution re-authorize through the domain boundary; metadata filtering or field hiding is never a security control. Metadata cannot select tenant placement, repository, queue, storage namespace, or cache namespace.

Code-defined model changes use generated, human-reviewed migrations with tenant keys, compound constraints, indexes, rollback or forward-fix behaviour, lock budgets, retained-data rehearsal, and expand-and-contract compatibility. Presentation-only metadata changes do not create database migrations. Per-tenant executable modules and per-tenant physical schemas are not introduced by this decision.

## Validation evidence

The existing [Ash pressure-test](../phase-0/evidence/ash-pressure-test.md) proves important parts of the authoritative side: named actions, policy and tenancy enforcement, relationship and field policy, generated interfaces, migration inspection, and upgrade behaviour. The provisional production core supplies a base-resource convention and resource-contract audit while keeping its domain resource-empty.

The disposable [resource-authoring and governed-metadata scenario](../phase-0/evidence/resource-authoring-and-governed-metadata.md) now derives and drift-checks a stable-reference descriptor from the real neutral Ash resource, validates tenant-customized view and report definitions without copied types or permissions, re-enters an authorized filtered Ash read, rejects private, stale, cross-tenant, arbitrary-SQL, executable, authority, and unapproved-action content, and exercises explicit rename plus adjacent-patch compatibility. It records both the duplication removed and the added descriptor/validator/registry cost.

Provisional Phase 1 [slice 1B](../phase-1/evidence/resource-descriptor.md) now implements only the production-core derivation seam: explicit allowlists over resources that pass the core resource contract, ownership-derived tenant scope, the full platform classification vocabulary, portable fields/actions/arguments, deterministic ordering, canonical encoding, and content revision. Neutral negative tests reject private or missing fields and actions, unsupported types and classifications, generic mutations, malformed or duplicate stable references, invalid resources, and caller-supplied authority-shaped contract data. The production domain remains resource-empty, so there is no production descriptor artifact or consumer. Durable definitions, reporting execution, metadata validation, rendering, and custom fields remain unimplemented.

Before this decision can be accepted, accountable reviewers must judge that bounded cost, approve or reject the listed production closure gates, and record the ADR outcome. Passing the scenario's security tests alone does not accept this decision.

## Fallback and exit cost

If ADR 0002 rejects Ash, retain the same boundary over explicit Phoenix/Ecto schemas, action modules, and policy services. Replace the small Ash introspection adapter and regenerate the Chimwemwe-owned descriptor from that model rather than preserving two production model paths. No production resource or consumer depends on the descriptor yet, and no metadata engine or custom-field storage is authorized, so the current exit cost remains bounded to the descriptor module, its tests, and documentation.

## Review triggers

- The authoring scenario shows descriptor or metadata maintenance costs greater than the duplication removed.
- A school requirement cannot be represented through a code-defined module, governed configuration, or constrained extension.
- A proposal introduces runtime schema mutation, arbitrary SQL or code, per-tenant modules, or a universal workflow/model language.
- An Ash upgrade changes the information or generation surface used by the descriptor.
- Custom fields need joins, indexes, public API stability, critical evidence, or policy effects.

## Related records

- [Domain model authoring and metadata boundary](../architecture/domain-model-authoring-and-metadata.md)
- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0012](0012-report-templates-gotenberg-and-campaign-model.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [Threat model](../security/threat-model.md)
