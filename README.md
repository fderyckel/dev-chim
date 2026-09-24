# Chimwemwe school platform

This repository is establishing the governed foundation for a modular school platform. Phase 0 completed its architecture, security-baseline, pressure-test, and accountable decision package on 2026-09-16. Ash is conditionally accepted as the default production-core framework, with eight binding production gates. Phase 1 slices 1A through 1F, the first bounded Slice 1G safe-write increment, and the local synthetic UI-0 browser experience are implemented. No school business module belongs here yet.

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
make web-check
make web-e2e
make check
```

These commands are the project contract. Editor tasks and future CI jobs must call them rather than recreating different check sequences.
`make test-fast` is the short production-core feedback loop during development; it does not replace `make check` before sharing a change.
`make web-dev` starts the explicitly synthetic, local-only UI-0 experience at `http://127.0.0.1:3000`.

## Current boundaries

- Phoenix/PostgreSQL and the modular-monolith shape are the firm base.
- Ash is conditionally accepted as the default production-core framework; every retained exception has a production gate, verification method, and fallback.
- The production core and Foundation Lab use the reviewed Ash 3.33.4 security-patch baseline.
- The accepted authoring model keeps Ash resources, actions, policies, and migrations authoritative while derived metadata may configure views and reports; it does not add a second runtime ORM.
- Roles and access scopes are tenant-defined data, never a fixed list of school job titles.
- Logical tenant controls remain mandatory in pooled databases, dedicated databases, and dedicated cells; physical placement is evidence-driven.
- Module release availability, entitlement, tenant activation, and actor authorization are separate server-side gates.
- All examples and tests use synthetic data.
- Slice 1A contains trusted context, the initially empty globally-authorized Ash platform domain, and a code-owned resource-authoring guard. Slice 1B adds the deterministic, allowlisted resource-descriptor builder. Slice 1C adds only trusted invocation of public named read actions. Slice 1D adds trusted pre-checkout tenant and placement admission. Slice 1E adds the explicitly configured PostgreSQL repository runtime, immutable current-route check, and scoped repository selection that wires admission before checkout. Slice 1F adds tenant memberships, tenant-defined roles and capabilities, tenant-qualified assignments and grants, cycle-safe role composition, and writer-only capability resolution. The first Slice 1G increment adds only capability-protected role rename with optimistic concurrency, exact idempotent replay, immutable audit evidence, and a transactional outbox fact. Generic or public write invocation, graph administration, descriptor consumers, experience metadata, business modules, production web applications, scheduler services, runtime AI, and analytics remain outside this boundary.
- UI-0 under `clients/web` is a local Next.js/React experience harness with deterministic synthetic fixtures, semantic CSS, and no core connection, authentication, persistence, storage, or production deployment authority.
