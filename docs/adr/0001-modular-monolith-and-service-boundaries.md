# ADR 0001: Modular monolith and permitted service boundaries

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Architecture review group
- Deciders: Architecture review group and product owner
- Supersedes: None

## Context

The platform needs strong transactional coherence and a foundation that a small team and coding agents can extend without creating distributed ownership or policy gaps.

## Decision drivers

- One authoritative policy and transaction boundary.
- Low operational burden and explicit module ownership.
- Specialized runtimes only where capability or isolation requires them.

## Considered options

1. Phoenix/Ash/PostgreSQL modular monolith with bounded supporting planes.
2. Per-domain microservices from the start.
3. One unstructured application with no enforced module boundaries.

## Decision

Propose a Phoenix/Ash/PostgreSQL modular monolith as the authoritative core. Permit separate web delivery, scheduling, AI, analytics, and hardened utility runtimes only behind versioned contracts and without independent domain authority.

## Consequences

### Positive

- Transactions, policy, audit, and migrations remain coherent.
- Modules can evolve without network boundaries.

### Negative

- Internal boundaries require architecture tests and disciplined ownership.
- Specialized workloads still need explicit contracts and operations.

## Security, privacy, operability, and migration effects

One core reduces distributed authorization drift. Every supporting plane must propagate actor and tenant context, tolerate core unavailability, and avoid owning authoritative school state.

## Validation evidence

See [service boundaries](../architecture/service-boundaries.md) and the Phase 0 architecture review record.

## Fallback and exit cost

Extract a capability only after measured isolation, scaling, lifecycle, or runtime needs justify it. Extraction requires an ADR, versioned contract, data-ownership plan, and rollback path.

## Review triggers

- A capability cannot meet an accepted requirement inside the core.
- Team or deployment topology materially changes.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0015](0015-ai-gateway-tool-exposure-and-evaluation-policy.md)
- [ADR 0016](0016-scheduling-service-contract-and-publication-boundary.md)

