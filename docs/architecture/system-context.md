# System context

- Status: Proposed
- Owner: Architecture review group

## People and actors

The platform serves human users acting within one or more tenant contexts, platform support with explicit time-bounded access, service actors, external integrations, and governed AI clients. School labels describe principals and relationships, not fixed authorization roles.

## System boundary

The authoritative application boundary is a Phoenix/Ash/PostgreSQL modular monolith released as one immutable product. A small kernel governs tenant context, policy, module lifecycle, and shared platform contracts. A Next.js experience, durable jobs, files and reports, analytics, scheduling, integrations, and AI are clients or bounded supporting planes. They do not receive independent authority over domain state.

The product may run in several deployment cells. Within a cell, tenants can use a pooled database or dedicated databases; a tenant can receive a dedicated cell when approved evidence requires it. Every profile preserves the same tenant-keyed logical model and domain policies. A trusted routing registry contains placement metadata only and resolves tenant context to database, queue, storage, and supporting namespaces.

## Authoritative flow

1. Authenticate the human or service actor and establish tenant, assurance, purpose, locale, and correlation context.
2. Resolve the tenant's trusted, versioned placement; fail closed rather than choosing a default placement.
3. Confirm release availability, entitlement, and module activation, then call a named action.
4. Evaluate actor authorization, validation, and policy before changing state.
5. Commit state, audit references, and durable event facts atomically where required.
6. Dispatch bounded work and update disposable projections after commit using the same tenant placement.
7. Return only policy-authorized data.

## Non-goals for Phase 0

There is no production business module, user interface, runtime AI capability, scheduling engine, file processor, analytics plane, or report renderer in Phase 0.

Phase 0 documents and pressure-tests placement and module-lifecycle contracts; it does not create the production control-plane registry or module registry.
