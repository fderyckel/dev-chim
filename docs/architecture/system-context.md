# System context

- Status: Proposed
- Owner: Architecture review group

## People and actors

The platform serves human users acting within one or more tenant contexts, platform support with explicit time-bounded access, service actors, external integrations, and governed AI clients. School labels describe principals and relationships, not fixed authorization roles.

## System boundary

The authoritative application boundary is a Phoenix/Ash/PostgreSQL modular monolith. A Next.js experience, durable jobs, files and reports, analytics, scheduling, integrations, and AI are clients or bounded supporting planes. They do not receive independent authority over domain state.

## Authoritative flow

1. Authenticate the human or service actor and establish tenant, assurance, purpose, locale, and correlation context.
2. Call a named action.
3. Evaluate validation and policy before changing state.
4. Commit state, audit references, and durable event facts atomically where required.
5. Dispatch bounded work and update disposable projections after commit.
6. Return only policy-authorized data.

## Non-goals for Phase 0

There is no production business module, user interface, runtime AI capability, scheduling engine, file processor, analytics plane, or report renderer in Phase 0.

