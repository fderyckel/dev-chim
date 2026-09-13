# Deferred architecture choices

- Status: Active guardrail
- Owner: Architecture review group

The following remain deferred: Kafka, Kubernetes, continuous CDC, a dedicated search cluster, a vector database, full event sourcing, a universal workflow language, per-domain microservices, GraphQL without a concrete unmet use case, shared Valkey before measured need, a final embedded BI product, schema-per-tenant as the strategic default, and a complete stack per tenant without workload, recovery, residency, or isolation evidence.

A proposal to introduce one must include:

- the unmet requirement and measured evidence;
- simpler alternatives considered;
- data ownership, tenant, security, privacy, and recovery effects;
- an operational owner and ongoing cost;
- compatibility and migration strategy; and
- an exit or rollback plan.

The architecture review records the outcome in a new or superseding ADR.
