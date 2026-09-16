# ADR 0002: Ash adoption criteria and fallback

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering
- Deciders: Architecture review group
- Supersedes: None

## Context

Ash can provide resources, named actions, policy enforcement, tenancy, migrations, and generated interfaces, but it would become expensive to remove after platform APIs depend on it.

## Decision drivers

- Policy and tenant safety at every interface.
- Explicit domain actions and stable errors.
- Readable migrations, telemetry, testability, and upgrade ergonomics.
- One code-reviewed source for resource ownership, tenancy, actions, policy, and migration intent.

## Considered options

1. Accept Ash after a pre-registered pressure-test.
2. Use Phoenix/Ecto with explicit domain services and thin adapters.
3. Continue indefinitely with both paths.

## Decision

Propose Ash as the preferred framework subject to the Phase 0 scorecard. Accept only if all mandatory tenancy, policy, action, transaction, migration, generated-interface, telemetry, and upgrade criteria pass. Do not maintain two production framework paths.

Under the explicit early Phase 1 core exception, apply the provisional base-resource convention and automated resource-contract audit described by [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md) before adding a persistent resource. This is an adoption guard and reversible evidence, not acceptance of either ADR.

## Consequences

### Positive

- One declarative source may drive policy-preserving actions and interfaces.
- The early spike makes framework risk visible before production coupling.
- A small code-owned authoring guard makes future resource drift visible before persistence is introduced.

### Negative

- The spike and upgrade review add work before application scaffolding.
- Ash-specific DSLs and generated artifacts require team fluency.
- The authoring contract adds deliberate review work and cannot prove resource-specific policy correctness by itself.

## Security, privacy, operability, and migration effects

Negative cross-tenant, missing-context, relationship-policy, and rollback tests are mandatory. Generated migrations and interfaces receive human review. Framework internals must not leak across every public contract. The base resource and domain audit are guardrails, not substitutes for action-specific authorization, database constraints, expand-and-contract rehearsal, or negative tests.

## Validation evidence

See [Ash pressure-test evidence](../phase-0/evidence/ash-pressure-test.md), the [dependency upgrade exercise](../phase-0/evidence/ash-upgrade-exercise.md), the [dependency-warning baseline](../phase-0/evidence/ash-dependency-warning-baseline.md), the [retained-data migration rehearsal](../phase-0/evidence/retained-data-migration-rehearsal.md), the [test and maintenance ergonomics evidence](../phase-0/evidence/ash-test-and-maintenance-ergonomics.md), the [resource-authoring evidence](../phase-0/evidence/resource-authoring-and-governed-metadata.md), the [trusted-routing and movement evidence](../phase-0/evidence/trusted-routing.md), and the provisional [core-foundation evidence](../phase-1/evidence/core-foundation.md). The current spike proves direct and generated-interface tenancy/policy behaviour, a named action, atomic outbox rollback, sanitized correlated telemetry, generated-baseline migration inspection, and a compatible three-package patch upgrade. The migration rehearsal adds nullable expansion, mixed-version reads and writes, typed tenant-scoped bounded backfill, lock-timeout failure without residue, separate constraint validation, retained-row comparison, rollback before contract, and an explicitly irreversible destructive cleanup. This is a bounded platform-owned remedy rather than a claim that the Ash generator owns operational choreography. The maintenance contract adds a warning-as-error application compile, repeatable seeded and isolated tests, actionable feedback for the exercised invalid DSL, and machine-checked ownership of eight current custom boundaries. The warning follow-up records the complete locked dependency graph, toolchain, command, and 39 normalized compiler-warning groups and rejects every added or removed group. Scenario 15 adds a checked, stable-reference descriptor; tenant view/report validation; policy-protected filtered execution; forbidden-reference negatives; and controlled rename/patch-upgrade evidence without adding a second authority engine. The routing follow-up adds capability-gated, versioned movement with source authority, quiescence, code-owned reconciliation, cutover, rollback, and stale-route rejection across ten non-HTTP interface classes. The production core separately verifies the authoring contract against synthetic in-memory resources while keeping the production domain resource-empty. All mandatory scorecard criteria and dependency-warning normalization now have direct Phase 0 evidence. A non-patch upgrade, production-shaped migration measurements, bounded-condition disposition, and accountable review still prevent an adoption decision.

## Fallback and exit cost

Fallback is Phoenix/Ecto with explicit action modules, policy services, schemas, and thin interface adapters. The code-owned ownership and named-action rules survive that replacement even though the Ash base resource and audit are removed. Select the fallback before school modules depend on Ash if any critical criterion fails or requires pervasive escape hatches.

## Review triggers

- Completion of the pressure-test scorecard.
- A major Ash upgrade or material policy/migration limitation.
- A proposed exception to the base resource, ownership declaration, tenant contract, or named-mutation rule.

## Related records

- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
