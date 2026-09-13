# Code conventions

## General

- Prefer explicit, small modules with one clear owner and stable public boundaries.
- Name operations with domain verbs. Avoid generic `update`, `process`, or `handle` when a specific action exists.
- Keep configuration typed and validated. Secrets remain outside source and ordinary configuration records.
- Return structured errors using validation, forbidden, conflict, not found, rate limited, retryable dependency, and internal failure categories.
- Keep generated code and migrations reviewable; generated does not mean trusted.

## Elixir

- Let `mix format` own formatting.
- Keep aliases explicit and avoid surprising global imports.
- Use pattern matching and tagged results at boundaries; reserve exceptions for exceptional failures.
- Keep Ash actions, policies, validations, and changes close to the resource they govern while domain-wide orchestration remains in named services or actions.
- Never issue an unscoped tenant-owned query.
- Mirror critical invariants with PostgreSQL constraints.

## Python repository tooling

- Python is for repository support tools during Phase 0, not a second domain implementation.
- Use type hints for public functions and `pathlib.Path` for paths.
- Use the standard library unless a dependency clearly improves correctness.
- Ruff owns formatting and linting; pytest owns tests.
- Invoke Python through `uv run` rather than a global environment.

## Shell

- Use POSIX `sh` for repository entrypoints unless a documented feature requires another shell.
- Start scripts with `set -eu`, quote variables, resolve the repository root, and use explicit paths for destructive operations.
- ShellCheck must pass.

