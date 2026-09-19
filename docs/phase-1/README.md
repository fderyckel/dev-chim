# Phase 1: core foundation

- Status: Slices 1A through 1D implemented and test-verified; Phase 0 entry decisions completed
- Owner: Platform engineering
- Start basis: explicit user direction on 2026-09-14, followed by the completed Phase 0 review on 2026-09-16
- Entry basis: Ash is conditionally accepted; implementation proceeds only in explicitly authorized bounded slices and must satisfy the retained production gates

## Why this can start narrowly

Phase 0 has direct evidence for named actions, tenant and capability denial, tenant-defined role composition, global authorization requirements, optimistic concurrency, transactional rollback and idempotency, generated-interface policy preservation, trusted placement input, module-gate separation, telemetry redaction, migration generation, and patch plus non-patch interface-framework upgrades. Ash 3.33.4 now closes the field-policy advisory with a focused forbidden-calculation filter regression, and the current complete verification contract passes.

Phase 0 now has a three-run annual-envelope retained-data migration measurement, an accepted disposition for all eight Ash bounded conditions, architect-approved numeric technical targets, a provider-neutral PostgreSQL contract, a combined local capacity/recovery run, exact full-horizon local restore, and clean-checkout rehearsal. The raw local run preserves the pooled noisy-tenant failure; the pre-checkout application-boundary candidate passes three local reruns. The accountable review accepts Ash conditionally and carries deployment, production identity, durable routing/movement, real adapter, and independent security verification into the phases where those capabilities become real. Those gates still prevent broad production scaffolding or a school business module without explicit authorization.

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

## Slice 1D boundary

Slice 1D promotes only the contract proven by the new Phase 0 pre-checkout admission evidence. A node-local `Chimwemwe.Platform.DatabaseAdmission` boundary:

- validates `ExecutionContext` before inspecting tenant or placement capacity;
- derives tenant and placement capacity keys from trusted context rather than caller input;
- requires explicit positive per-tenant and per-placement limits instead of embedding the current candidate values as production defaults;
- acquires both permits before invoking the callback that may reach Ecto or Postgrex;
- classifies tenant saturation as rate limited and placement saturation as a retryable dependency without disclosing identifiers;
- supplies retry guidance only when an explicit bounded interval is configured; and
- releases permits after normal return, exception, throw, exit, or caller termination.

The boundary is not yet attached to a repository or application supervisor because no production placement registry, repository, or accepted capacity settings exist. It is node-local rather than a distributed quota and it does not replace Ash authorization, idempotency, database constraints, or stronger tenant placement.

## Continuing guardrails

- Phase 0 ADR outcomes and conditional gates are binding; an Accepted ADR is changed only by supersession.
- `make check` proves repository consistency; it does not by itself approve a new production capability.
- Only `apps/chimwemwe_core` is allowed during slices 1A through 1D. A second production app or service needs explicit later-slice authorization.
- The core contains no production data or secrets and introduces no persistence, experience-metadata engine, or public interface.
- If a retained Ash gate fails and its explicit adapter fallback cannot preserve the platform invariants, ADR 0002 must be superseded before the affected business capability depends on it; the execution-context contract remains framework-neutral.

See the [implementation plan](../plans/phase-1-core-foundation-plan.md), [core boundary](../architecture/core-foundation-boundary.md), [domain-model authoring boundary](../architecture/domain-model-authoring-and-metadata.md), [slice 1A evidence](evidence/core-foundation.md), [slice 1B evidence](evidence/resource-descriptor.md), [slice 1C evidence](evidence/action-invocation.md), [slice 1D evidence](evidence/database-admission.md), [Phase 0 status](../phase-0/README.md), and [review record](../phase-0/review-record.md).
