# Phase 0 architecture review record

- Status: Not scheduled
- Review date: DATE_REQUIRED
- Accountable approver: OWNER_REQUIRED

## Participants

- Architecture: OWNER_REQUIRED
- Platform engineering: OWNER_REQUIRED
- Security/privacy: OWNER_REQUIRED
- Product/operations: OWNER_REQUIRED

## Evidence reviewed

- ADR index and decision register.
- Ash pressure-test scorecard and commands.
- Versioned generated-interface routes, the complete proposed public error taxonomy and retry headers, keyset pagination, transactional idempotency, and checked-in OpenAPI/TypeScript client drift evidence.
- Tenant-defined authorization graph, cycle, field-policy, and relationship-policy evidence.
- Threat model, abuse cases, and residual risks.
- Numeric quality targets and accountable owners.
- Tenant-placement capacity profile, five-school decision, routing/movement tests, and recovery evidence.
- PostgreSQL availability, consistency routing, connection budget, synchronized-burst, failover, replica-lag, and point-in-time-restore evidence.
- Module lifecycle, dependency, deactivation-drain, retained-data, and reactivation evidence.
- Retained-data expand/contract, lock-budget, mixed-version, tenant-batch, validation, and irreversible-cleanup evidence.
- Test and maintenance ergonomics, compile feedback, seeded and isolated runs, the complete dependency-warning zero-delta baseline, and the owned-boundary manifest.
- Resource-authoring, descriptor evolution, governed view/report metadata, and forbidden-reference evidence.
- Clean-checkout `make check` result.

## Decisions

Record each ADR outcome without rewriting accepted history.

## Ash outcome

Select exactly one: Accepted, Conditionally Accepted with bounded prerequisites, or Rejected with an accepted fallback.

## Conditions, exceptions, and expiry

Every condition or residual-risk acceptance requires an owner, deadline, expiry, and verification method.

## Phase 1 authorization

Phase 1 is not authorized until the Phase 0 exit checklist is complete.

An explicit user direction on 2026-09-14 permits Phase 1 slice 1A to establish the production core foundation under the working assumption that Ash will be selected. Further explicit directions on 2026-09-15 permit slice 1B to add only the production-core, code-derived resource-descriptor seam supported by Phase 0 scenario 15 and slice 1C to add only trusted invocation of public named read actions over test-only resources. These exceptions are not architecture-review outcomes, do not accept any ADR or residual risk, and authorize no production resource, write invocation, descriptor consumer, experience-metadata engine, school business module, persistence layer, public interface, external service, or production infrastructure. Broader Phase 1 work remains blocked on this review.
