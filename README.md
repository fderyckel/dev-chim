# Chimwemwe — operating system for learning institutions

Chimwemwe is an operating system for learning institutions: kindergartens, primary and secondary
schools, combined schools, colleges, community colleges, universities, and other governed learning
environments. The learner and the learner's context remain central regardless of age, while each
institution may operate through its own nested structure, terminology, programmes, and policies.

This repository is establishing that governed modular foundation. Phase 0 completed its
architecture, security-baseline, pressure-test, and accountable decision package on 2026-09-16.
Ash is conditionally accepted as the default production-core framework, with eight binding
production gates. Phase 1 slices 1A through 1J-A, ADR 0018 T1-A/T1-B/T1-C, and the local synthetic
UI-0 browser experience are implemented. Slices 1H-A and 1H-B add neutral module lifecycle; Slices
1I-A and 1I-B add typed tenant-owned presentation-definition publication and exact internal
compatibility resolution; Slice 1J-A adds only an internal outbox delivery lease and status
boundary. Phase 2 has started with the L0 entry decision register only. None of this adds a
learning-institution business module, production identity, public interface, or real-data
authority.

## Start here

1. Read [the Phase 0 outcome](docs/phase-0/README.md) and its binding later gates.
2. Read [the Phase 1 core scope](docs/phase-1/README.md).
3. Read [the Phase 2 entry status](docs/phase-2/README.md) before proposing a learning-institution
   module or production boundary.
4. Read [the architecture index](docs/architecture/README.md) and [ADR index](docs/adr/README.md).
5. Follow [local setup](docs/development/getting-started.md).
6. Run `make check` before sharing changes.

The execution sequences are in the [Phase 0 implementation plan](docs/plans/phase-0-implementation-plan.md),
the [Phase 1 core-foundation plan](docs/plans/phase-1-core-foundation-plan.md), and the accepted
[Phase 2 sequencing proposal](docs/plans/phase-2-entry-and-school-structure-proposal.md).

## Stable commands

```sh
make bootstrap
make fix
make format
make lint
make check-staged
make test-fast
make test
make docs-check
make web-dev
make web-core-dev
make web-check
make web-e2e
make web-core-e2e
make check
```

These commands are the project contract. Editor tasks and future CI jobs must call them rather than recreating different check sequences.
`make fix` applies Ruff's safe fixes, then runs the repository-owned Python, Elixir, and web formatters.
`make check-staged` is the pre-commit Elixir gate: formatting, warnings-as-errors compilation, strict Credo, Dialyzer, core tests, and staged whitespace.
`make test-fast` is the short production-core feedback loop during development; it does not replace `make check` before sharing a change.
`make web-dev` starts the explicitly synthetic, local-only UI-0 experience at `http://127.0.0.1:3000`.
`make web-core-dev` starts the guarded UI-1A qualification at
`http://127.0.0.1:3000/authority/assignments`, backed by a dedicated local synthetic database
and a server-owned ephemeral session. It is read-only and is not production authentication.

## Current boundaries

- Phoenix/PostgreSQL and the modular-monolith shape are the firm base.
- Ash is conditionally accepted as the default production-core framework; every retained exception has a production gate, verification method, and fallback.
- The production core and Foundation Lab use the reviewed Ash 3.33.11 security-patch baseline.
- The accepted authoring model keeps Ash resources, actions, policies, and migrations authoritative while derived metadata may configure views and reports; it does not add a second runtime ORM.
- Roles and access scopes are tenant-defined data, never a fixed list of institutional job titles.
- A tenant may own several root institutional units. Institutional units may nest to any reviewed
  depth, so a university can contain schools and departments and a combined school can contain
  kindergarten, middle-school, and high-school units. Hierarchy never grants access or silently
  supplies configuration, reporting, site, module, or placement semantics. See
  [ADR 0025](docs/adr/0025-learning-institution-operating-system-and-institutional-structure.md).
- Logical tenant controls remain mandatory in pooled databases, dedicated databases, and dedicated cells; physical placement is evidence-driven.
- Module release availability, entitlement, tenant activation, and actor authorization are separate server-side gates.
- All examples and tests use synthetic data.
- Slice 1A contains trusted context, the initially empty globally-authorized Ash platform domain, and a code-owned resource-authoring guard. Slice 1B adds the deterministic, allowlisted resource-descriptor builder. Slice 1C adds only trusted invocation of public named read actions. Slice 1D adds trusted pre-checkout tenant and placement admission. Slice 1E adds the explicitly configured PostgreSQL repository runtime, immutable current-route check, and scoped repository selection that wires admission before checkout. Slice 1F adds tenant memberships, tenant-defined roles and capabilities, tenant-qualified assignments and grants, cycle-safe role composition, and writer-only capability resolution. Slice 1G-A adds capability-protected role rename; Slice 1G-B adds capability-protected assignment of an existing membership to an existing role. Both use exact idempotent replay, immutable audit evidence, and a transactional outbox fact. ADR 0018 T1-A/T1-B/T1-C qualify neutral temporal state, governed revision and fact actions, and explicit consumer reconciliation. Slice 1H-A adds a trusted immutable module manifest, closed tenant entitlement and activation state, one private initial-activation action, and an ordinary server-side gate that independently requires release, entitlement, compatible activation/dependencies, and actor capability. Slice 1H-B adds deterministic dependency-safe drain, queue-neutral ordinary and mandatory work state, retained cursor/projection/reconciliation state, and private compatible reactivation. Slice 1I-A adds released extension-contract declarations, a trusted descriptor-derived registry, and one private exact-versioned publication path for bounded presentation definitions with minimized atomic evidence. Slice 1I-B adds exact tenant-qualified internal resolution with separate read authority, current module gates, exact descriptor/content/classification revalidation, and explicit compatible-release handling. It adds no enumeration, renderer, action execution, domain-record read, custom fields, runtime schema, public API, or learning-institution module. Generic or public write invocation, membership/role/grant/composition/revoke administration, interface/rendering consumers, business modules, production web applications, scheduler services, runtime AI, and analytics remain outside this boundary.
- UI-0 under `clients/web` is a local Next.js/React experience harness with deterministic synthetic fixtures, semantic CSS, and no core connection, authentication, persistence, storage, or production deployment authority.
- UI-1A adds one guarded, loopback-only, read-only assignment-options connection from that
  harness to the existing core. It uses synthetic server-owned context, checked OpenAPI and
  generated TypeScript types, and exposes no assignment write or production identity path.
- Phase 2's bounded implementation sequence is authorized. Slice 2.0-A is in progress, and its
  entry register leaves L1 through L4 blocked until their evidence gates pass; no institutional
  resource, production identity, public route, deployment, or real data is eligible yet.
