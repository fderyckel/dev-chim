# Chimwemwe school platform

This repository is establishing the governed foundation for a modular school platform. Phase 0 completed its architecture, security-baseline, pressure-test, and accountable decision package on 2026-09-16. Ash is conditionally accepted as the default production-core framework, with eight binding production gates. Phase 1 slices 1A through 1H-B, ADR 0018 T1-A temporal physical-model qualification and T1-B governed revision boundary, and the local synthetic UI-0 browser experience are implemented. Slices 1H-A and 1H-B add neutral independent module gates, safe initial activation, controlled drain, mandatory work, and compatible reactivation; they do not add a school business module.

## Start here

1. Read [the Phase 0 outcome](docs/phase-0/README.md) and its binding later gates.
2. Read [the Phase 1 core scope](docs/phase-1/README.md).
3. Read [the architecture index](docs/architecture/README.md) and [ADR index](docs/adr/README.md).
4. Follow [local setup](docs/development/getting-started.md).
5. Run `make check` before sharing changes.

The execution sequences are in the [Phase 0 implementation plan](docs/plans/phase-0-implementation-plan.md) and the [Phase 1 core-foundation plan](docs/plans/phase-1-core-foundation-plan.md).

## Stable commands

```sh
make bootstrap
make format
make lint
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
- Roles and access scopes are tenant-defined data, never a fixed list of school job titles.
- Logical tenant controls remain mandatory in pooled databases, dedicated databases, and dedicated cells; physical placement is evidence-driven.
- Module release availability, entitlement, tenant activation, and actor authorization are separate server-side gates.
- All examples and tests use synthetic data.
- Slice 1A contains trusted context, the initially empty globally-authorized Ash platform domain, and a code-owned resource-authoring guard. Slice 1B adds the deterministic, allowlisted resource-descriptor builder. Slice 1C adds only trusted invocation of public named read actions. Slice 1D adds trusted pre-checkout tenant and placement admission. Slice 1E adds the explicitly configured PostgreSQL repository runtime, immutable current-route check, and scoped repository selection that wires admission before checkout. Slice 1F adds tenant memberships, tenant-defined roles and capabilities, tenant-qualified assignments and grants, cycle-safe role composition, and writer-only capability resolution. Slice 1G-A adds capability-protected role rename; Slice 1G-B adds capability-protected assignment of an existing membership to an existing role. Both use exact idempotent replay, immutable audit evidence, and a transactional outbox fact. ADR 0018 T1-A adds synthetic aggregate, revision, effective-segment, and append-only-fact resources with database-level qualification tests. T1-B adds separate private revision publication and correction actions plus capability-protected current, effective, exact, and bounded-history reads with exact replay and atomic audit/outbox evidence. Slice 1H-A adds a trusted immutable module manifest, closed tenant entitlement and activation state, one private initial-activation action, and an ordinary server-side gate that independently requires release, entitlement, compatible activation/dependencies, and actor capability. Slice 1H-B adds deterministic dependency-safe drain, queue-neutral ordinary and mandatory work state, retained cursor/projection/reconciliation state, and private compatible reactivation. It adds no real queue/consumer/projection adapter, entitlement or offboarding workflow, retained-data deletion, provisioning, public API, or school module. Generic or public write invocation, membership/role/grant/composition/revoke administration, descriptor consumers, experience metadata, business modules, production web applications, scheduler services, runtime AI, and analytics remain outside this boundary.
- UI-0 under `clients/web` is a local Next.js/React experience harness with deterministic synthetic fixtures, semantic CSS, and no core connection, authentication, persistence, storage, or production deployment authority.
- UI-1A adds one guarded, loopback-only, read-only assignment-options connection from that
  harness to the existing core. It uses synthetic server-owned context, checked OpenAPI and
  generated TypeScript types, and exposes no assignment write or production identity path.
