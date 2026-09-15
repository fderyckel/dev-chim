# Phase 1 core-foundation implementation plan

- Status: Active for slice 1A only
- Owner: Platform engineering
- Decision posture: provisional Ash assumption; Phase 0 and all required ADRs remain unaccepted
- Review trigger: completion of slice 1A or any proposal to add persistence, a public interface, another app, or a school domain

## Inputs consumed

| Input | What slice 1A carries forward | What remains unresolved |
| --- | --- | --- |
| [ADR 0001](../adr/0001-modular-monolith-and-service-boundaries.md) | One production core with a small mandatory platform boundary | Accountable acceptance and production module lifecycle |
| [ADR 0002](../adr/0002-ash-adoption-criteria-and-fallback.md) | Exact pressure-tested Ash release and global authorization | Full scorecard, acceptance, and fallback trigger |
| [ADR 0003](../adr/0003-tenant-model-and-optional-postgresql-rls.md) | Mandatory tenant identity separated from trusted placement and routing version | Production registry, database routing, movement, recovery, and RLS |
| [ADR 0005](../adr/0005-domain-action-and-state-transition-convention.md) | No generic business mutation or CRUD surface | First production named action and accountable acceptance of the action/error convention |
| [Trusted-routing evidence](../phase-0/evidence/trusted-routing.md) | Raw request placement is not accepted; missing or stale routing fails closed | Live registry and repository selection |
| [Threat model](../security/threat-model.md) | TM-01, TM-02, TM-09, and TM-11 shape context, authorization, and non-disclosure tests | Accountable review and later interface-specific suites |

These are working inputs, not accepted decisions. The explicit start direction permits only the reversible work below.

## Slice 1A implementation

1. Establish the root Elixir umbrella and one `chimwemwe_core` OTP app.
2. Pin the production core to Ash 3.33.3, the exact Phase 0 pressure-tested release.
3. Define the empty production Ash domain with authorization forced to `:always`.
4. Define trusted actor, trusted placement, and execution-context types without role constants or request-selected infrastructure.
5. Validate the complete context before invoking core work and return typed errors without echoing identifiers.
6. Add positive, missing-context, malformed-input, stale-routing, and tenant-mismatch tests.
7. Extend bootstrap, format, lint, test, documentation, dependency-audit, type-analysis, and full-check entrypoints to cover the production core.
8. Preserve the Phase 0 exit validator and explicitly allow only this documented app while the start exception is active.

## Acceptance checks

- `Ash.Domain.Info.authorize(Chimwemwe.Platform)` returns `:always`.
- A complete context from matching trusted sources reaches the supplied operation.
- Missing context and a raw map fail before the operation runs.
- A non-positive routing version fails before the operation runs.
- Authenticated and routed tenant mismatch returns a non-disclosing typed error.
- No school role, business module, persistence layer, HTTP route, worker, or external service is added.
- The production core never imports `AshFoundationLab`.
- `make check` passes, while the Phase 0 exit review continues to fail for the recorded unresolved placeholders and Proposed ADRs.

## Rollback and next gate

Slice 1A can be removed by deleting the root umbrella files and `apps/chimwemwe_core` while retaining all Phase 0 evidence. The execution-context concepts survive an Ash fallback because they depend on platform trust semantics rather than an Ash resource.

Do not add PostgreSQL persistence or the first platform resource until its tenant keys, compound constraints, authorization policy, migration path, ownership, and negative tests are proposed as the next bounded slice. Do not add a school business module until Phase 0 acceptance and an explicit module authorization are recorded.
