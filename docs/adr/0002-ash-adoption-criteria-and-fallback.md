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

## Considered options

1. Accept Ash after a pre-registered pressure-test.
2. Use Phoenix/Ecto with explicit domain services and thin adapters.
3. Continue indefinitely with both paths.

## Decision

Propose Ash as the preferred framework subject to the Phase 0 scorecard. Accept only if all mandatory tenancy, policy, action, transaction, migration, generated-interface, telemetry, and upgrade criteria pass. Do not maintain two production framework paths.

## Consequences

### Positive

- One declarative source may drive policy-preserving actions and interfaces.
- The early spike makes framework risk visible before production coupling.

### Negative

- The spike and upgrade review add work before application scaffolding.
- Ash-specific DSLs and generated artifacts require team fluency.

## Security, privacy, operability, and migration effects

Negative cross-tenant, missing-context, relationship-policy, and rollback tests are mandatory. Generated migrations and interfaces receive human review. Framework internals must not leak across every public contract.

## Validation evidence

See [Ash pressure-test evidence](../phase-0/evidence/ash-pressure-test.md) and the [dependency upgrade exercise](../phase-0/evidence/ash-upgrade-exercise.md). The current spike proves direct and generated-interface tenancy/policy behaviour, a named action, atomic outbox rollback, sanitized correlated telemetry, generated-baseline migration inspection, and a compatible three-package patch upgrade. Warning remediation, a non-patch upgrade, and the remaining scorecard categories still prevent an adoption decision.

## Fallback and exit cost

Fallback is Phoenix/Ecto with explicit action modules, policy services, schemas, and thin interface adapters. Select it before Phase 1 if any critical criterion fails or requires pervasive escape hatches.

## Review triggers

- Completion of the pressure-test scorecard.
- A major Ash upgrade or material policy/migration limitation.

## Related records

- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
