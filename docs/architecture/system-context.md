# System context

- Status: Architecture overview; governing ADRs retain their decision statuses and conditions
- Owner: Architecture review group

This overview describes the architecture and its boundaries. The [ADR index](../adr/README.md)
records decisions; the [current phase](../phase-2/README.md) records implementation and release gates.

## People and actors

Chimwemwe is an operating system for learning institutions across early-childhood, primary,
secondary, college, community-college, university, and other governed learning contexts. The
learner and the learner's changing context remain central regardless of age. `Student`, `learner`,
`guardian`, `teacher`, `lecturer`, and similar labels describe contextual relationships or local
vocabulary, not permanent person types or fixed authorization roles.

The platform serves human users acting within one or more tenant contexts, platform support with
explicit time-bounded access, service actors, external integrations, and governed AI clients.

## Institutional context

A tenant is the governed security, placement, lifecycle, and data boundary. It may contain several
legal entities and corporate units as well as several root institutional units. The legal entity,
not the tenant, carries accountable legal operation. Educational units form a recursive
tenant-local hierarchy with no fixed depth: a university may contain schools, faculties, and
departments, while a combined school may contain kindergarten, middle-school, and high-school
units.

Legal relationships, consolidation, corporate and educational hierarchy, and primary legal
operation remain distinct domain meanings. Sites, academic affiliations, authorization scope,
reporting and finance roll-up, workflow/configuration adoption, module lifecycle, and physical
placement remain separate explicit contracts. See
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md).

## System boundary

The authoritative application boundary is a Phoenix/Ash/PostgreSQL modular monolith released as
one immutable product. A small kernel governs tenant context, policy, module lifecycle, and shared
platform contracts. The proposed Next.js browser experience and companion native-mobile
experience, durable jobs, files and reports, analytics, scheduling, integrations, and AI are
clients or bounded supporting planes. They do not receive independent authority over domain
state. The service separation and module lifecycle decision belongs to
[ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md); Ash adoption and its conditions
belong to [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md).

The product may run in several deployment cells. Within a cell, tenants can use a pooled database or dedicated databases; a tenant can receive a dedicated cell when approved evidence requires it. Every profile preserves the same tenant-keyed logical model and domain policies. A trusted routing registry contains placement metadata only and resolves tenant context to database, queue, storage, and supporting namespaces.

## Service boundaries

The Phoenix/Ash application, PostgreSQL transactions, Oban workers, authorization, audit, outbox,
file metadata, report orchestration, and integrations remain one modular core unless measured
evidence requires separation. Database placement does not move domain authority out of the core.

- A module boundary owns domain language, state, actions, and policies inside the modular monolith.
- A database placement controls tenant data, credential, backup, restore, and resource containment.
- A deployment cell controls a wider application, queue, storage, cache, network, and supporting-resource failure domain.

Activating a module does not create a service, schema, database, or cell. Moving a tenant does not
change its enabled modules, roles, or application model. See the detailed contracts for
[tenant placement](tenant-placement-and-capacity.md),
[database operations and read routing](postgresql-availability-recovery-and-read-routing.md),
and [module lifecycle](module-activation-and-lifecycle.md).

### Internal application boundary

Each module exposes Chimwemwe-owned, named domain actions and read interfaces. These may be Ash code interfaces or small context functions, but callers outside the owning module do not construct or pass `Ash.Query` or `Ash.Changeset` values, choose an Ecto repository, or reach around a policy with a generic CRUD call. Phoenix controllers, web components, generated APIs, jobs, integrations, reports, and AI tools enter through the same actor- and tenant-aware boundary.

This boundary does not require redundant maps around every Ash value. Resource structs may remain useful inside the owning core, while public, cross-module, asynchronous, and wire contracts use deliberate Chimwemwe-owned types and versioning where compatibility matters. The purpose is to protect domain intent and replacement boundaries, not to hide every framework type mechanically.

An owner may use Ecto or SQL internally for a measured bulk, projection, or reporting need that Ash cannot meet adequately, but the escape path remains behind the named domain or dataset interface. It preserves trusted actor and tenant context, authorization, transaction semantics, audit and outbox obligations, error taxonomy, and negative tests. A user interface, report definition, or integration never receives raw-table authority.

### Permitted supporting planes

- Next.js web delivery has an independent static and edge lifecycle but no independent policy engine.
- Scheduling may use Kotlin/Timefold behind a versioned contract and cannot publish authoritative state.
- Runtime AI stays behind a provider-neutral gateway with curated tools and the real actor/tenant context.
- Analytics consumes governed publications and does not query OLTP as a general BI source.
- Hardened file and rendering utilities are isolated for resource and attack-surface control.

Adding a service requires an ADR naming the unmet capability, transaction boundary, data ownership,
authentication, tenant propagation, failure model, observability, operational owner, and exit cost.
These boundaries do not authorize implementation of a supporting plane; its governing decision
and delivery gates still apply.

## Authoritative flow

1. Authenticate the human or service actor and establish tenant, assurance, purpose, locale, and correlation context.
2. Resolve the tenant's trusted, versioned placement; fail closed rather than choosing a default placement.
3. Confirm release availability, entitlement, and module activation, then call a named action.
4. Evaluate actor authorization, validation, and policy before changing state.
5. Commit state, audit references, and durable event facts atomically where required.
6. Dispatch bounded work and update disposable projections after commit using the same tenant placement.
7. Return only policy-authorized data.
