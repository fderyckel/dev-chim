# Phase 1 core-foundation implementation plan

- Status: Slices 1A through 1C verified provisionally; accountable review remains
- Owner: Platform engineering
- Decision posture: provisional Ash assumption; Phase 0 and all required ADRs remain unaccepted
- Review trigger: completion of slice 1C or any proposal to add persistence, write invocation, a metadata consumer, a public interface, another app, or a school domain

## Inputs consumed

| Input | What the core slices carry forward | What remains unresolved |
| --- | --- | --- |
| [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md) | One production core with a small mandatory platform boundary | Accountable acceptance and production module lifecycle |
| [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md) | Exact pressure-tested Ash and policy-solver releases plus global authorization | Full scorecard, acceptance, and fallback trigger |
| [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md) | Mandatory tenant identity separated from trusted placement and routing version | Production registry, database routing, movement, recovery, and RLS |
| [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md) | No generic business mutation or CRUD surface | First production named action and accountable acceptance of the action/error convention |
| [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md) | Code-owned base-resource convention, structural audit, and a small derived descriptor contract proven by disposable Phase 0 evidence | Descriptor consumers, governed metadata, persistence, closure-gate decisions, and accountable acceptance |
| [Retained-data migration evidence](../phase-0/evidence/retained-data-migration-rehearsal.md) | Keep migration choreography explicit and resource-specific | Production-shaped measurements, mixed-release deployment, recovery proof, and an authorized persistent resource |
| [Trusted-routing evidence](../phase-0/evidence/trusted-routing.md) | Raw request placement is not accepted; missing or stale routing fails closed | Live registry and repository selection |
| [Threat model](../security/threat-model.md) | TM-01, TM-02, TM-09, and TM-11 shape context, authorization, and non-disclosure tests | Accountable review and later interface-specific suites |

These are working inputs, not accepted decisions. The explicit start direction permits only the reversible work below.

## Slice 1A implementation

1. Establish the root Elixir umbrella and one `chimwemwe_core` OTP app.
2. Pin the production core to Ash 3.33.3 and PicoSAT 0.2.3, the exact Phase 0 pressure-tested releases.
3. Define the empty production Ash domain with authorization forced to `:always` and actor presence required.
4. Define trusted actor, trusted placement, and execution-context types without role constants or request-selected infrastructure.
5. Validate the complete context before invoking core work and return typed errors without echoing identifiers.
6. Add positive, missing-context, malformed-input, non-positive-routing, and tenant-mismatch tests.
7. Extend bootstrap, format, lint, test, documentation, dependency-audit, type-analysis, and full-check entrypoints to cover the production core.
8. Preserve the Phase 0 exit validator and explicitly allow only this documented app while the start exception is active.
9. Add a code-owned Ash base resource with an explicit tenant-owned or global-reference declaration and fixed policy authorizer.
10. Audit domain authorization, actor presence, domain registration, resource policies, tenant shape, global-reference separation, and named state-changing actions.
11. Exercise the authoring contract with test-only, synthetic, in-memory resources while keeping the production domain resource-empty.

## Slice 1B implementation

1. Add a production-core descriptor builder whose only inputs are a contract-controlled Ash resource and an explicit code-owned allowlist.
2. Require the resource to pass `Chimwemwe.Platform.ResourceContract` before deriving anything.
3. Validate positive schema and model versions, stable Chimwemwe references, unique source and public references, supported types, and the full platform classification vocabulary.
4. Derive ownership and tenant-scope characteristics from the resource base contract; do not accept caller-supplied tenancy characteristics.
5. Derive only explicitly allowlisted public attributes, public named actions, and public action arguments. Do not serialize Ash modules, source names, policies, tenant keys, or executable behavior.
6. Sort fields and actions by stable reference and canonicalize object keys before calculating a SHA-256 content revision or encoding an artifact.
7. Exercise the boundary with neutral, in-memory test resources, including private-field, private-action, unsupported-type, malformed-reference, duplicate-reference, invalid-resource, and deterministic-evolution cases.
8. Keep the production domain resource-empty and add no generated descriptor artifact until an authorized production resource exists.

Slice 1B deliberately does not promote the Phase 0 report-dataset registry or governed-metadata executor. Those need their own action, authorization, persistence, compatibility, classification, and lifecycle boundary.

## Slice 1C implementation

1. Add a read-only invocation boundary between the validated production execution context and Ash.
2. Validate context before resource or action lookup so unauthenticated input cannot probe the model surface.
3. Require the requested resource to be registered in an always-authorized, actor-required domain and to satisfy the production resource contract.
4. Accept only a public named read action and a plain map of action input; expose no Ash option passthrough.
5. Derive the actor and tenant exclusively from trusted context. Omit tenant scope only for a resource explicitly declared as global reference data.
6. Reject reserved context and authority keys in action input before Ash executes.
7. Propagate only correlation ID, purpose, locale, and routing version in a namespaced Ash context; do not expose placement coordinates.
8. Exercise real policy denial, tenant filtering, global-reference behavior, invalid context, private or wrong-type actions, invalid resources, and reserved-input denial with neutral in-memory resources.
9. Add no mutation API, production resource, persistence, migration, interface, worker, or external service.

## Acceptance checks

- `Ash.Domain.Info.authorize(Chimwemwe.Platform)` returns `:always`.
- `Ash.Domain.Info.require_actor?(Chimwemwe.Platform)` returns `true`.
- A complete context from matching trusted sources reaches the supplied operation.
- Missing context and a raw map fail before the operation runs.
- A non-positive routing version fails before the operation runs.
- Authenticated and routed tenant mismatch returns a non-disclosing typed error.
- A valid tenant-owned resource and a valid global-reference resource pass the structural audit.
- Missing base ownership, policy authorizer, policies, tenant attribute, or correct domain registration fails the audit.
- Nullable or public tenant keys, tenant resources with global fallback, and generic state-changing action names fail the audit.
- No school role, business module, persistence layer, HTTP route, worker, or external service is added.
- The production core never imports `AshFoundationLab`.
- Descriptor derivation rejects a resource that fails the production resource contract.
- Tenant scope is derived from resource ownership and cannot be supplied in the descriptor allowlist.
- Private or unallowlisted fields and actions, unsupported types or classifications, generic mutations, malformed or duplicate stable references, and invalid versions fail closed.
- Equivalent allowlists derive the same ordered descriptor, encoding, and revision; a model-version or public-surface change changes the revision.
- The descriptor contains no Ash module or source names, tenant key, policy implementation, persistence detail, or executable behavior.
- A valid trusted context can invoke a public named read and sees only its tenant's records.
- A denied actor remains forbidden and a global-reference read remains actor-authorized without tenant multitenancy.
- Raw, missing, malformed, mismatched, or non-positive-routing context fails before resource or action discovery.
- Unregistered or structurally invalid resources and private, missing, or non-read actions fail with one non-disclosing invocation error.
- Reserved authority or context keys and non-map input fail before the Ash action runs.
- No write invocation function is exported.
- `make check` passes, while the Phase 0 exit review continues to fail for the recorded unresolved placeholders and Proposed ADRs.

## Rollback and next gate

Slice 1A can be removed by deleting the root umbrella files, `apps/chimwemwe_core`, and its Phase 1 documentation and validator allowance while retaining all Phase 0 evidence. The execution-context, explicit-ownership, and named-action concepts survive an Ash fallback because they depend on platform trust semantics rather than an Ash resource.

Do not add PostgreSQL persistence, write invocation, or the first platform resource until its tenant keys, compound constraints, authorization policy, migration path, idempotency, outbox, concurrency, ownership, and negative tests are proposed as the next bounded slice. The descriptor builder and trusted read invoker are production foundation; the Phase 0 descriptor artifact, report registry, and governed experience-metadata implementation remain disposable evidence and are not production APIs. Do not add a school business module until Phase 0 acceptance and an explicit module authorization are recorded.
