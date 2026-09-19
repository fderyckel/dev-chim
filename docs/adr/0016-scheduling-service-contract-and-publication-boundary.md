# ADR 0016: Scheduling service contract and publication boundary

- Status: Deferred
- Date: 2026-09-13
- Decision date: 2026-09-16
- Accountable owner: Platform and scheduling engineering
- Deciders: Architecture review group and product owner
- Supersedes: None

## Context

Constraint solving benefits from a specialized runtime, but the solver must not own authoritative schedules or publish decisions outside core policy.

## Decision drivers

- Reproducible, explainable solver inputs and outputs.
- Hard-constraint protection and bounded resources.
- Authorized review and publication in the core.

## Considered options

1. Kotlin/Timefold service behind a versioned contract.
2. Python/OR-Tools as the default service.
3. Solver logic embedded directly in the core domain.

## Decision

Defer solver and service selection until the scheduling phase has a deterministic fixture and representative constraints. Retain a versioned scheduling contract with immutable input snapshots, constraints, scores, explanations, cancellation, resource budgets, and candidate outputs as the later decision boundary. Kotlin/Timefold remains a candidate. Only an authorized core action may review, override, or publish a candidate.

## Consequences

### Positive

- Solver lifecycle and CPU isolation do not fragment domain authority.
- Candidate results remain reproducible and reviewable.

### Negative

- A versioned service contract and another runtime require maintenance.
- Cross-runtime observability and compatibility need tests.

## Security, privacy, operability, and migration effects

Submissions are authenticated, tenant-scoped, minimized, quota-bound, cancellable, and traceable. The service stores no uncontrolled authoritative copy and cannot publish state.

## Validation evidence

Phase 0 reviews the contract boundary only. A deterministic Timefold fixture, infeasibility report, cancellation, and publication denial belong to Phase 12.

## Fallback and exit cost

Use OR-Tools only for a bounded case with its own evidence. Preserve the contract so the solver implementation can change without changing domain authority.

## Review triggers

- Timefold cannot satisfy accepted constraints, licensing, reproducibility, or operations needs.
- A second solver is proposed.

## Related records

- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
