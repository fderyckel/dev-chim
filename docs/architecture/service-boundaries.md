# Service boundaries

- Status: Proposed
- Owner: Architecture review group
- Governing record: [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md)

## Default deployment boundary

The Phoenix/Ash application, PostgreSQL transactions, Oban workers, authorization, audit, outbox, file metadata, report orchestration, and integrations remain one modular core unless measured evidence requires separation.

## Permitted supporting planes

- Next.js web delivery has an independent static and edge lifecycle but no independent policy engine.
- Scheduling may use Kotlin/Timefold behind a versioned contract and cannot publish authoritative state.
- Runtime AI stays behind a provider-neutral gateway with curated tools and the real actor/tenant context.
- Analytics consumes governed publications and does not query OLTP as a general BI source.
- Hardened file and rendering utilities are isolated for resource and attack-surface control.

Adding a service requires an ADR naming the unmet capability, transaction boundary, data ownership, authentication, tenant propagation, failure model, observability, operational owner, and exit cost.

