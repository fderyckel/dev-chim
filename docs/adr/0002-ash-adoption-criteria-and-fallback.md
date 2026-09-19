# ADR 0002: Ash adoption criteria and fallback

- Status: Conditionally Accepted
- Date: 2026-09-13
- Decision date: 2026-09-16
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

Conditionally adopt Ash as the default framework for the authoritative application core. The mandatory Phase 0 tenancy, policy, action, transaction, migration, generated-interface, telemetry, and upgrade criteria passed. The eight accepted production conditions in the [bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md) remain fail-closed gates for the capabilities they govern. Do not maintain two production framework paths.

Apply the base-resource convention and automated resource-contract audit described by [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md) before adding a persistent resource. Thin Phoenix/Ecto or SQL adapters remain permitted only at inventoried boundaries that preserve trusted context, Ash authorization, transaction, tenant, and recovery contracts. A condition failure blocks the affected capability; pervasive failure requires this ADR to be superseded with the explicit Phoenix/Ecto domain-service fallback.

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

See [Ash pressure-test evidence](../phase-0/evidence/ash-pressure-test.md), the [bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md), the [patch dependency upgrade exercise](../phase-0/evidence/ash-upgrade-exercise.md), the [non-patch AshJsonApi upgrade](../phase-0/evidence/ash-nonpatch-upgrade-exercise.md), the [dependency-warning baseline](../phase-0/evidence/ash-dependency-warning-baseline.md), the [retained-data migration rehearsal](../phase-0/evidence/retained-data-migration-rehearsal.md), the [annual-envelope migration measurement](../phase-0/evidence/retained-data-migration-measurement.md), the [test and maintenance ergonomics evidence](../phase-0/evidence/ash-test-and-maintenance-ergonomics.md), the [resource-authoring evidence](../phase-0/evidence/resource-authoring-and-governed-metadata.md), the [trusted-routing and movement evidence](../phase-0/evidence/trusted-routing.md), and the [core-foundation evidence](../phase-1/evidence/core-foundation.md). The current spike proves direct and generated-interface tenancy/policy behaviour, a named action, atomic outbox rollback, sanitized correlated telemetry, generated-baseline migration inspection, and a compatible three-package patch upgrade. The migration rehearsal adds nullable expansion, mixed-version reads and writes, typed tenant-scoped bounded backfill, lock-timeout failure without residue, separate constraint validation, retained-row comparison, rollback before contract, and an explicitly irreversible destructive cleanup. The three-run annual-envelope follow-up processes 1,312,000 synthetic rows per run, preserves a control tenant and retained fingerprint, and measures time, batch latency, WAL, storage, a concurrent support index, and lock acquisition. It exposes a bounded production obligation: the enforcement gate needed 43-108 attempts under the retained `250ms` per-attempt lock budget, so index lifecycle, observability, retry scheduling, old-version drain, and destructive-contract approval remain platform-owned. The maintenance contract adds a warning-as-error application compile, repeatable seeded and isolated tests, actionable feedback for the exercised invalid DSL, and machine-checked ownership of eight current custom boundaries. The warning follow-up records the complete locked dependency graph, toolchain, command, and normalized compiler-warning groups and rejects every added or removed group. The non-patch follow-up upgrades AshJsonApi 1.6.6 to 1.7.1 on the same schema with no application, migration, OpenAPI, descriptor, test, or advisory regression; preceding Ash and AshPostgres minors were correctly rejected because Hex reports security advisories. Scenario 15 adds a checked, stable-reference descriptor; tenant view/report validation; policy-protected filtered execution; forbidden-reference negatives; and controlled rename/patch-upgrade evidence without adding a second authority engine. The routing follow-up adds capability-gated, versioned movement with source authority, quiescence, code-owned reconciliation, cutover, rollback, and stale-route rejection across ten non-HTTP interface classes. The production core separately verifies the authoring contract against synthetic in-memory resources while keeping the production domain resource-empty. All mandatory scorecard criteria and the annual-envelope measurement have direct Phase 0 evidence. François accepted all eight owned conditions on 2026-09-16 with named production gates, fallbacks, and a 2026-12-15 review date.

On 2026-09-16, refreshed Hex metadata reported [EEF-CVE-2026-86338](https://osv.dev/vulnerability/EEF-CVE-2026-86338) against Ash 3.33.3. The coordinated [Ash 3.33.4 security-patch review](../phase-0/evidence/ash-security-patch.md) updates the production and Foundation Lab locks, adds a focused forbidden-calculation filter regression, refreshes the warning baseline, preserves generated artifacts, and restores passing audit and complete verification gates. That patch closed the advisory blocker; the separate accountable review made the broader conditional-adoption decision.

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
