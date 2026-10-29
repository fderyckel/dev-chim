# Repository instructions for coding agents

## Read before changing code

Read `README.md`, `docs/phase-0/README.md`, `docs/phase-1/README.md`, `docs/architecture/README.md`, and `docs/adr/README.md`. For structural or security-sensitive work, read every linked ADR and threat-model section first.

## Scope

- Phase 0 is complete as of 2026-09-16. Its evidence and disposable Ash pressure-test remain non-production artifacts.
- The completed Phase 1 foundation is limited to the production core under `apps/chimwemwe_core`, as summarized in `docs/phase-1/README.md`; later core expansion requires explicit authorization.
- UI-0 is authorized only as the local, synthetic browser experience under `clients/web`, bounded by `docs/plans/local-browser-experience-foundation-proposal.md`. It is not a production client, public interface, authentication path, or school module.
- Ash is conditionally accepted as the default production-core framework. The eight production gates in `docs/phase-0/handover-evidence.md` remain binding.
- Do not connect UI-0 to the core, add real authentication or data, or add another school business module, production web surface, scheduler, AI gateway, analytics plane, production infrastructure, or production app until its later slice is explicitly authorized.
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

## Delegated specialist reviews

- Use the four reusable profiles in `docs/development/specialist-review-team.md` for material education, admissions, audience-language, and UI decisions. François authorized this AI review team on 2026-10-23.
- Delegate a bounded, read-only review to the relevant profiles; use both education profiles for shared classroom or student-communication decisions, and the UI profile for material interface decisions. Do not launch the full team for mechanical changes.
- Specialists may approve choices within an already authorized slice, attach conditions, or challenge a proposal. Record their reasons and evidence; unresolved material challenges return to François with a concrete recommendation.
- AI approval is delegated design review. It cannot fabricate representative testimony, satisfy required independent security/privacy or safeguarding review, name real-world owners, authorize a new slice such as COMM-1, or grant connected, real-data, pilot, or production release.
- Keep the UI concise and audience-specific. Use optional question-mark help for secondary detail, accessible by focus and touch as well as hover. Keep necessary labels, action consequences, errors, and saved/blocked states visible.
- Follow `docs/plans/specialist-review-next-steps.md` for the initial authentication and COMM-0 assignments; existing ADR and release gates retain precedence.

## Required verification

Run `make check` before declaring work complete. Report the exact checks run and any skipped check. Never claim the repository is green when a required command failed or was not run.
