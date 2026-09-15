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
- Clean-checkout `make check` result.

## Decisions

Record each ADR outcome without rewriting accepted history.

## Ash outcome

Select exactly one: Accepted, Conditionally Accepted with bounded prerequisites, or Rejected with an accepted fallback.

## Conditions, exceptions, and expiry

Every condition or residual-risk acceptance requires an owner, deadline, expiry, and verification method.

## Phase 1 authorization

Phase 1 is not authorized until the Phase 0 exit checklist is complete.

An explicit user direction on 2026-09-14 permits one provisional exception: Phase 1 slice 1A may establish the production core foundation under the working assumption that Ash will be selected. This exception is not an architecture-review outcome, does not accept any ADR or residual risk, and authorizes no school business module, persistence layer, public interface, external service, or production infrastructure. Broader Phase 1 work remains blocked on this review.
