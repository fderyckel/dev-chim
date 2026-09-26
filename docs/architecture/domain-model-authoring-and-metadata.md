# Domain model authoring and metadata boundary

- Status: Accepted architecture; resource descriptor and Slice 1I-A/1I-B governed presentation-definition boundaries implemented
- Owner: Platform engineering
- Governing record: [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md)
- Review trigger: authoring-scenario evidence, first persistent resource, or any runtime model-customization proposal

## Decision summary

Chimwemwe will be code-defined at its core and metadata-driven at its edges. Developers express school concepts as declarative Ash resources, named actions, policies, and constraints. Chimwemwe derives a small, validated descriptor from that model so forms, views, reports, documentation, and bounded tenant configuration can reuse it.

This is the ORM-like development experience: Ash is the domain modelling framework. Chimwemwe should add conventions and derived tools around it, not build a second ORM beside it.

## Why this is richer without becoming more complex

The design separates four kinds of change instead of forcing all change through either code or metadata:

| Need | Authoritative mechanism | Why |
| --- | --- | --- |
| Shared school meaning and behaviour | Version-controlled Ash resource, named action, policy, and reviewed migration | Strong types, constraints, testing, security, and predictable upgrades |
| Tenant business choices such as roles, calendars, code lists, grading schemes, and terminology | Ordinary tenant-owned domain records or typed configuration changed through named actions | Runtime agility without runtime schema mutation |
| Form, view, localization, and reporting experience | Validated metadata referencing an approved resource descriptor | Fast variation without duplicating domain rules |
| Non-critical tenant-specific information | Optional constrained custom-field contract, only after evidence and a separate approval | Local agility without turning metadata into executable authority |

The framework gains one outward derivation path. It does not gain another persistence engine, policy language, migration system, workflow interpreter, or tenant-specific code path.

## Options and trade-offs

| Approach | Main advantage | Main cost | Fit for Chimwemwe |
| --- | --- | --- | --- |
| Runtime metadata-first models | Very fast administrator-led schema changes | A second runtime schema, policy, migration, typing, and recovery problem | Reject for the authoritative domain |
| Code only | Strong review, typing, migrations, and policy | Presentation and local variations require too many releases | Safe but unnecessarily rigid |
| Governed hybrid | One domain authority with adaptable experiences | Requires a small versioned descriptor and metadata validator | Best fit |
| YAML or JSON model compiler | Can standardize repetitive source definitions | Adds a compiler, diagnostics, compatibility format, and another authoring language | Defer until repetition is measured |

## Ownership layers

```text
Ash resource + named actions + policies + PostgreSQL constraints
                              |
                    derive and validate
                              v
             Chimwemwe resource descriptor
                 /                         \
        forms and views          report dataset definitions
                 \                         /
                  named, authorized actions
                              |
                       PostgreSQL state
```

### Authoritative domain model

Ash code owns persistent types, relationships, identities, business invariants, calculations with business meaning, named state transitions, authorization, tenancy, public actions, and migration intent. PostgreSQL owns durable state and the database constraints that must hold even if an unsafe alternate write is attempted.

An Ash resource is already declarative and introspectable: it is closer to compiled metadata than to a hand-written active-record class. Source control and compilation are advantages here because school records need reviewable behaviour and migrations.

School-specific behaviour does not require school-specific code forks. Values that schools genuinely control—such as tenant-defined roles, calendars, code lists, grading schemes, and terminology—remain governed domain data with typed validation and named actions. Their schema and security stay in code while their values change at runtime.

### Resource descriptor

The descriptor is a Chimwemwe-owned, versioned projection of only the public model surface needed by tools. It may contain stable references, labels or label keys, types, approved relationships, supported operations, and relevant compatibility information. It is generated and checked; developers do not maintain a second copy of the domain schema.

The descriptor must not expose Ash internals as a permanent client contract. A removed or changed reference produces a clear build-time or deployment-time compatibility failure. Runtime consumers fail closed on an unknown or incompatible descriptor version.

### Experience metadata

Experience metadata can arrange approved fields and actions; it cannot create their authority. It may own:

- labels, help, localization, grouping, ordering, and widgets;
- saved filters and view layout;
- report columns, parameters, formatting, and grouping over approved datasets; and
- references to explicitly allowlisted named actions.

It cannot own authorization, tenant routing, persistent relationships, database constraints, critical workflow transitions, arbitrary code or SQL, or the public API surface.

## Phase 0 authoring scenario

The neutral, disposable exercise is now recorded in [resource-authoring and governed-metadata evidence](../phase-0/evidence/resource-authoring-and-governed-metadata.md):

1. A developer creates a small tenant-owned Ash resource using the provisional core conventions, with one named read and one named transition.
2. The normal Ash and PostgreSQL workflow generates and reviews its migration.
3. A build step derives a versioned descriptor from the allowlisted public resource surface.
4. One form or view definition and one report definition reference that descriptor rather than repeating field types or permissions.
5. A tenant changes labels, order, saved filters, and report layout without changing domain code.
6. Attempts to reference a private field, an unapproved action, another tenant's definition, arbitrary SQL, or an old incompatible descriptor fail closed.
7. A field rename and representative Ash upgrade demonstrate drift detection and a controlled compatibility path.

The exercise passed with bounded remediation: it removes copied type, constraint, policy, tenant, and module ownership from view/report definitions while adding a checked descriptor, validator, execution registry, and compatibility contract. It did not add a second schema or policy engine. It supplied evidence for ADRs 0002 and 0019, but did not itself authorize a school business module.

## Slice 1I-A implementation

Slice 1I-A promotes only the first durable definition contract. Code-owned release declarations
list stable extension schema keys and versions. A trusted immutable registry derives a descriptor
from a contract-valid tenant-owned Ash resource and explicit field/action allowlists, then accepts
only bounded presentation content. A tenant can choose a title, field order, field labels, and one
allowlisted public read action; it cannot select a private reference, authorization rule, query,
code path, tenant, repository, or executable behavior.

The closed tenant-owned definition pins module version, schema version, descriptor revision,
resource reference, derived classification, and optimistic lock version. Publication rechecks the
independent module gates and a separate actor capability on the writer and records minimized audit,
outbox, and exact-replay evidence in the same transaction. There is no renderer or live consumer,
so retaining a valid definition does not expose or execute data. See the
[Slice 1I-A evidence](../phase-1/evidence/governed-extension-definitions.md).

Slice 1I-B adds only exact internal compatibility resolution. Before returning one stored
definition, the resolver requires separate read authority, all current module gates, exact current
schema/resource/descriptor/content/classification agreement, and an exact or explicitly compatible
module version. It returns metadata only and never invokes the stored action reference. There is no
enumeration, public contract, renderer, or domain-record read. See the
[Slice 1I-B evidence](../phase-1/evidence/governed-extension-resolution.md).

## Reports, views, security, and APIs

- A view controls presentation only. Every read and submission is re-authorized through an Ash read or named action with the real actor and tenant.
- A report references a versioned policy-protected dataset or read action, never an arbitrary table or user-supplied SQL. Rendering cannot broaden the dataset.
- An API derives from explicit public actions. Metadata cannot publish a private field or introduce generic update access.
- A job or integration resolves the same tenant and authorization boundary; copying a definition into an asynchronous process does not copy authority.
- A definition for an unavailable, unentitled, or inactive module cannot execute. Deactivation retains the definition for governed reactivation or removal; it does not erase it implicitly.
- Definition records are tenant-qualified, versioned, attributable, recoverable, and classified at least as strongly as the fields or dataset they reference.

## Custom-field graduation rule

Optional custom fields are for bounded, non-critical local variation such as a local reference, non-sensitive category, code, or date. Storage is deliberately undecided until real school cases establish query, indexing, export, retention, and volume needs.

A field belongs in Ash code when any of these is true:

- it changes authorization, tenancy, workflow, module gates, or data classification;
- it participates in a relationship, uniqueness rule, required invariant, or critical calculation;
- it is safeguarding, attendance, financial, statutory, contractual, audit, or legal evidence;
- it must be stable in an API, integration, import, export, or cross-module contract; or
- it needs material indexing, joins, aggregation, retention, or recovery guarantees.

This is how Chimwemwe supports broad school needs without pretending every future requirement should fit a generic custom-field system.

## Simplicity and future-proofing checks

- Use ordinary Ash resources, information APIs, and supported generators before creating a Chimwemwe DSL or generator.
- Add an abstraction only after at least two representative consumers show the same stable need and it removes more duplicated ownership than it introduces.
- Give every metadata type one owner, versioned schema, validator, compatibility rule, and removal path.
- Keep one-way derivation: code to descriptor to experience metadata. Metadata never rewrites the authoritative model.
- Reject tenant-specific executable code and parallel model or authorization engines.
- Defer custom-field storage, a general UI renderer, a visual model builder, and a schema compiler until measured use cases justify them.
- Re-run tenant, authorization, migration, report, and generated-interface negative tests whenever the authoring contract changes.

## Developer workflow

1. Start with the provisional Chimwemwe base resource and declare whether the resource is tenant-owned or global reference data.
2. Define fields, relationships, named actions, policies, tenancy, and business invariants in Ash code.
3. Generate and review the PostgreSQL migration, including tenant keys, constraints, indexes, locks, retained-data compatibility, and rollback or forward-fix boundaries.
4. Register the resource in its owned domain and run the resource-contract, positive, negative-authorization, and cross-tenant checks.
5. Derive and drift-check the public resource descriptor, then reference it from any approved view or report definition.
6. Use the repository verification contract. Add a custom generator only if repeated authoring work proves a smaller convention cannot remove the duplication.

## Related records

- [Core foundation boundary](core-foundation-boundary.md)
- [Deferred choices](deferred-choices.md)
- [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md)
- [ADR 0012](../adr/0012-report-templates-gotenberg-and-campaign-model.md)
- [ADR 0014](../adr/0014-primary-api-and-generated-typescript-client.md)
- [Threat model](../security/threat-model.md)
