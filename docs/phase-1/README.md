# Phase 1: provisional core foundation

- Status: Slices 1A through 1C verified provisionally; Phase 0 remains incomplete
- Owner: Platform engineering
- Start basis: explicit user direction on 2026-09-14 to focus on the core foundation and assume Ash for now
- Entry exception: implementation may proceed only within the bounded scope below; this is not Phase 0 exit approval

## Why this can start narrowly

Phase 0 has direct evidence for named actions, tenant and capability denial, tenant-defined role composition, global authorization requirements, optimistic concurrency, transactional rollback and idempotency, generated-interface policy preservation, trusted placement input, module-gate separation, telemetry redaction, migration generation, and a patch upgrade. The current working verification contract passes.

Phase 0 still lacks accountable architecture acceptance, numeric quality targets, production identity and durable routing/movement integration, production-shaped retained-data migration measurements, measured capacity/recovery evidence, bounded-condition disposition, and the accountable Ash adoption outcome. Those gaps prevent broad production scaffolding and any school business module.

## Slice 1A boundary

Slice 1A creates one production Elixir umbrella app, `apps/chimwemwe_core`, containing:

- a globally authorized, actor-required, but resource-empty `Chimwemwe.Platform` Ash domain;
- separate opaque types for trusted actor identity and trusted tenant placement;
- a validated execution context that requires actor, tenant, current routing version, correlation, purpose, and locale;
- typed, non-disclosing failures for missing, malformed, invalid, or mismatched context; and
- negative tests proving core work is not invoked for raw, missing, non-positive-routing, or cross-tenant context;
- a code-owned Ash base resource that requires explicit tenant-owned or global-reference ownership and installs the policy authorizer; and
- an automated domain audit that rejects missing policies, wrong-domain registration, unsafe tenant shape, and generic state-changing action names.

The slice does not reuse code from the disposable Ash spike. It pins the exact pressure-tested Ash and PicoSAT releases so the production assumption and policy-verification dependency are visible and replaceable. Synthetic in-memory resources exercise the authoring guard only in tests; the production domain remains empty.

## Slice 1B boundary

Slice 1B promotes one stable seam from the completed Phase 0 authoring scenario: a Chimwemwe-owned, versioned resource descriptor derived from an explicitly allowlisted Ash resource surface. The descriptor builder:

- accepts only resources that already satisfy the production resource contract;
- derives tenant scope from code-owned resource ownership rather than caller input;
- exposes only explicitly allowlisted public attributes, public named actions, public action arguments, stable references, supported portable types and constraints, and an accountable data classification;
- excludes Ash module names, source attribute and action names, policies, tenant keys, private fields, executable behavior, and infrastructure details; and
- sorts its public surface and canonicalizes object keys so the content revision and encoded artifact are deterministic.

The slice is exercised only with neutral, test-only resources. It adds no production resource and no descriptor artifact because the production domain is still empty. Report datasets, definition persistence, tenant customization, metadata validation or execution, rendering, and custom fields remain outside the production core.

## Slice 1C boundary

Slice 1C adds one trusted invocation path from `Chimwemwe.Platform.ExecutionContext` to a public named Ash read action. It:

- validates the opaque execution context before inspecting the requested resource or action;
- accepts only resources registered in an actor-required, always-authorized Ash domain and passing the production resource contract;
- derives actor and tenant scope exclusively from the trusted context, omitting tenant scope only for explicitly global-reference resources;
- reserves actor, tenant, placement, routing, correlation, purpose, locale, domain, scope, repository, and authorization input keys so action input cannot replace platform context;
- propagates a minimal namespaced correlation, purpose, locale, and routing-version context into Ash; and
- invokes only a public action whose Ash type is `:read`, with no caller-supplied Ash options.

Neutral in-memory tenant-owned and global-reference resources exercise real Ash policy and tenancy behavior in tests. Mutation invocation is deliberately absent: production writes still require the first resource's persistence, migration, idempotency, outbox, concurrency, and recovery contract.

## Guardrails while Phase 0 remains open

- Every Phase 0 ADR remains Proposed unless its named deciders accept it.
- `make check` proves repository consistency only; it does not close Phase 0.
- Only `apps/chimwemwe_core` is allowed during slices 1A through 1C. A second production app or service needs explicit later-slice authorization.
- The core contains no production data or secrets and introduces no persistence, experience-metadata engine, or public interface.
- If ADR 0002 rejects Ash, the core Ash domain and dependency are replaced before business modules depend on them; the execution-context contract remains framework-neutral.

See the [implementation plan](../plans/phase-1-core-foundation-plan.md), [core boundary](../architecture/core-foundation-boundary.md), [domain-model authoring boundary](../architecture/domain-model-authoring-and-metadata.md), [slice 1A evidence](evidence/core-foundation.md), [slice 1B evidence](evidence/resource-descriptor.md), [slice 1C evidence](evidence/action-invocation.md), [Phase 0 status](../phase-0/README.md), and [review record](../phase-0/review-record.md).
