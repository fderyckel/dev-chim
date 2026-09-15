# Phase 1: provisional core foundation

- Status: Slice 1A started provisionally; Phase 0 remains incomplete
- Owner: Platform engineering
- Start basis: explicit user direction on 2026-09-14 to focus on the core foundation and assume Ash for now
- Entry exception: implementation may proceed only within the bounded scope below; this is not Phase 0 exit approval

## Why this can start narrowly

Phase 0 has direct evidence for named actions, tenant and capability denial, tenant-defined role composition, global authorization requirements, optimistic concurrency, transactional rollback and idempotency, generated-interface policy preservation, trusted placement input, module-gate separation, telemetry redaction, migration generation, and a patch upgrade. The current working verification contract passes.

Phase 0 still lacks accountable architecture acceptance, numeric quality targets, production identity and routing integration, retained-data migration and movement rehearsals, measured capacity/recovery evidence, and the complete Ash adoption scorecard. Those gaps prevent broad production scaffolding and any school business module.

## Slice 1A boundary

Slice 1A creates one production Elixir umbrella app, `apps/chimwemwe_core`, containing:

- a globally authorized but resource-empty `Chimwemwe.Platform` Ash domain;
- separate opaque types for trusted actor identity and trusted tenant placement;
- a validated execution context that requires actor, tenant, current routing version, correlation, purpose, and locale;
- typed, non-disclosing failures for missing, malformed, stale, or mismatched context; and
- negative tests proving core work is not invoked for raw, missing, stale, or cross-tenant context.

The slice does not reuse code from the disposable Ash spike. It pins the exact pressure-tested Ash version so the production assumption is visible and replaceable.

## Guardrails while Phase 0 remains open

- Every Phase 0 ADR remains Proposed unless its named deciders accept it.
- `make check` proves repository consistency only; it does not close Phase 0.
- Only `apps/chimwemwe_core` is allowed during slice 1A. A second production app or service needs explicit later-slice authorization.
- The core contains no production data or secrets and introduces no persistence or public interface.
- If ADR 0002 rejects Ash, the core Ash domain and dependency are replaced before business modules depend on them; the execution-context contract remains framework-neutral.

See the [implementation plan](../plans/phase-1-core-foundation-plan.md), [core boundary](../architecture/core-foundation-boundary.md), [Phase 0 status](../phase-0/README.md), and [review record](../phase-0/review-record.md).
