# Chimwemwe school platform

This repository is establishing the governed foundation for a modular school platform. Work is currently limited to Phase 0: architecture decisions, security and quality targets, and a disposable Ash pressure-test. No school business module belongs here yet.

## Start here

1. Read [the Phase 0 scope](docs/phase-0/README.md).
2. Read [the architecture index](docs/architecture/README.md) and [ADR index](docs/adr/README.md).
3. Follow [local setup](docs/development/getting-started.md).
4. Run `make check` before sharing changes.

The detailed execution sequence is in the [Phase 0 implementation plan](docs/plans/phase-0-implementation-plan.md).

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
- Roles and access scopes are tenant-defined data, never a fixed list of school job titles.
- All examples and tests use synthetic data.
- Production modules, web applications, scheduler services, runtime AI, and analytics remain outside Phase 0.

