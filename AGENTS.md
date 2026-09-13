# Repository instructions for coding agents

## Read before changing code

Read `README.md`, `docs/phase-0/README.md`, `docs/architecture/README.md`, and `docs/adr/README.md`. For structural or security-sensitive work, read every linked ADR and threat-model section first.

## Scope

- Phase 0 may add architecture evidence, repository tooling, and the disposable Ash pressure-test.
- Do not add a school business module or production application shell during Phase 0.
- Do not treat spike code as a production framework API.
- Preserve unrelated user changes and never commit, push, clean, or rewrite history without an explicit request.

## Architectural invariants

- Express state changes as named domain actions, not generic CRUD.
- Require tenant context for every tenant-owned query, mutation, event, job, cache key, file path, search projection, realtime channel, export, telemetry record, and AI tool.
- Fail closed when actor or tenant context is missing.
- Treat roles as tenant-defined, hierarchical, nested, renameable, and composable data. Learner, guardian, educator, and administrator are not production role constants.
- Apply authorization at the domain boundary. Interface hiding is not authorization.
- Keep PostgreSQL authoritative. Caches, search indexes, and projections must be disposable and rebuildable.
- Record durable side effects through a transactional outbox after the state transaction commits.
- Preserve the non-null tenant key and policy model in pooled, dedicated-database, and dedicated-cell placements. Resolve placement from trusted authenticated context, never request input, and fail closed on stale or missing routing.
- Base tenant placement on per-domain workload, burst, retention, reporting, integration, recovery, residency, and isolation evidence. Student count alone is not a placement rule.
- Keep release availability, entitlement, module activation, and actor authorization as separate server-side gates. Deactivation must not drop shared tables or erase retained tenant data.
- Never place secrets, production data, restricted child data, or unredacted records in tests, logs, prompts, fixtures, or committed evidence.
- Keep AI provider access behind explicit, typed, allowlisted capabilities with the real actor and tenant.

## Change discipline

- Update or add an ADR before changing a stable architectural boundary.
- Do not rewrite an Accepted ADR's decision; supersede it.
- Keep changes small and reviewable. Separate formatting-only work from semantic work.
- Add negative authorization and tenant-isolation tests with every relevant positive test.
- Use generated migrations as reviewable artifacts; inspect constraints, tenant keys, indexes, rollback behaviour, and expand-and-contract safety.
- Treat partitioning as evidence-driven and review its effect on compound uniqueness, foreign keys, migration locks, retention, and stable identifiers.
- Do not introduce Kafka, Kubernetes, Valkey, a dedicated search engine, a vector database, GraphQL, or another service without the evidence and ADR required by `docs/architecture/deferred-choices.md`.

## Required verification

Run `make check` before declaring work complete. Report the exact checks run and any skipped check. Never claim the repository is green when a required command failed or was not run.
