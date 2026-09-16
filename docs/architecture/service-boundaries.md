# Service boundaries

- Status: Proposed
- Owner: Architecture review group
- Governing record: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md)

## Default deployment boundary

The Phoenix/Ash application, PostgreSQL transactions, Oban workers, authorization, audit, outbox, file metadata, report orchestration, and integrations remain one modular core unless measured evidence requires separation.

One common product release may run in multiple deployment cells. A cell is an operational and failure-isolation boundary, not a domain module. Inside a cell, pooled and dedicated databases remain behind one trusted tenant-placement boundary. Database placement does not move domain authority out of the core.

## Independent axes

- A module boundary owns domain language, state, actions, and policies inside the modular monolith.
- A database placement controls tenant data, credential, backup, restore, and resource containment.
- A deployment cell controls a wider application, queue, storage, cache, network, and supporting-resource failure domain.

Activating a module does not create a service, schema, database, or cell. Moving a tenant does not change its enabled modules, roles, or application model.

## Internal application boundary

Each module exposes Chimwemwe-owned, named domain actions and read interfaces. These may be Ash code interfaces or small context functions, but callers outside the owning module do not construct or pass `Ash.Query` or `Ash.Changeset` values, choose an Ecto repository, or reach around a policy with a generic CRUD call. Phoenix controllers, web components, generated APIs, jobs, integrations, reports, and AI tools enter through the same actor- and tenant-aware boundary.

This boundary does not require redundant maps around every Ash value. Resource structs may remain useful inside the owning core, while public, cross-module, asynchronous, and wire contracts use deliberate Chimwemwe-owned types and versioning where compatibility matters. The purpose is to protect domain intent and replacement boundaries, not to hide every framework type mechanically.

An owner may use Ecto or SQL internally for a measured bulk, projection, or reporting need that Ash cannot meet adequately, but the escape path remains behind the named domain or dataset interface. It preserves trusted actor and tenant context, authorization, transaction semantics, audit and outbox obligations, error taxonomy, and negative tests. A user interface, report definition, or integration never receives raw-table authority.

## Permitted supporting planes

- Next.js web delivery has an independent static and edge lifecycle but no independent policy engine.
- Scheduling may use Kotlin/Timefold behind a versioned contract and cannot publish authoritative state.
- Runtime AI stays behind a provider-neutral gateway with curated tools and the real actor/tenant context.
- Analytics consumes governed publications and does not query OLTP as a general BI source.
- Hardened file and rendering utilities are isolated for resource and attack-surface control.

Adding a service requires an ADR naming the unmet capability, transaction boundary, data ownership, authentication, tenant propagation, failure model, observability, operational owner, and exit cost.

See [tenant placement and workload capacity](tenant-placement-and-capacity.md), [PostgreSQL availability, recovery, and read routing](postgresql-availability-recovery-and-read-routing.md), and [module activation and lifecycle](module-activation-and-lifecycle.md).
