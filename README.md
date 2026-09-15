# Chimwemwe school platform

This repository is establishing the governed foundation for a modular school platform. Phase 0 architecture and acceptance work remains incomplete. A provisional Phase 1 core-foundation slice has started under the user's working assumption that Ash will be selected; this does not accept Ash or any Proposed ADR. No school business module belongs here yet.

## Start here

1. Read [the Phase 0 scope](docs/phase-0/README.md) and its unresolved exit gates.
2. Read [the provisional Phase 1 core scope](docs/phase-1/README.md).
3. Read [the architecture index](docs/architecture/README.md) and [ADR index](docs/adr/README.md).
4. Follow [local setup](docs/development/getting-started.md).
5. Run `make check` before sharing changes.

The execution sequences are in the [Phase 0 implementation plan](docs/plans/phase-0-implementation-plan.md) and the [Phase 1 core-foundation plan](docs/plans/phase-1-core-foundation-plan.md).

## Stable commands

```sh
make bootstrap
make format
make lint
make test
make docs-check
make check
```

These commands are the project contract. Editor tasks and future CI jobs must call them rather than recreating different check sequences.

## Current boundaries

- Phoenix/PostgreSQL and the modular-monolith shape are the firm base.
- Ash is a candidate under pressure-test, not yet an accepted production dependency.
- The production core uses the exact pressure-tested Ash version provisionally; replacement remains required if ADR 0002 later rejects Ash.
- Roles and access scopes are tenant-defined data, never a fixed list of school job titles.
- Logical tenant controls remain mandatory in pooled databases, dedicated databases, and dedicated cells; physical placement is evidence-driven.
- Module release availability, entitlement, tenant activation, and actor authorization are separate server-side gates.
- All examples and tests use synthetic data.
- Slice 1A contains only trusted context and the empty globally-authorized Ash platform domain. Production persistence, business modules, web applications, scheduler services, runtime AI, and analytics remain outside its scope.
