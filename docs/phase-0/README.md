# Phase 0 archive: what, how, and why

- Status: Complete and archived
- Decision date: 2026-09-16
- Accountable approver: François — Project Owner
- Outcome: the architecture baseline was decided, Ash was conditionally accepted, and the remaining production gates were transferred to later phases

## Why Phase 0 existed

Phase 0 reduced the largest architectural and operational risks before production work began. It was a decision-and-pressure-test phase, not a product implementation phase. It established which boundaries the platform must keep, which technology choices were acceptable, and which questions had to remain closed until real deployment evidence existed.

## What was done

- Decided the initial architecture records and accepted the security and privacy engineering baseline.
- Pressure-tested Ash through a disposable, synthetic Foundation Lab rather than treating a framework choice as an assumption.
- Defined tenant isolation, trusted placement, fail-closed authorization, named domain actions, transactional outbox, and independent module gates.
- Measured local synthetic capacity, admission, migration, failover, recovery, and full-horizon restore behaviour.
- Set numeric quality targets and a provider-neutral PostgreSQL operating contract.
- Proved the repository could be bootstrapped and checked from a clean checkout.

## How it was done

The work used synthetic data, disposable databases, generated-artifact drift checks, negative authorization and tenant-isolation tests, migration apply/rollback/reapply exercises, dependency audits, static analysis, and repeated local measurements. Accountable review then separated what the evidence proved from what still required a selected deployment, real integration, independent review, or representative users.

The disposable lab remains under `spikes/ash-foundation-lab` only as historical engineering material. It is not a production framework API and is no longer part of routine Phase 2 verification.

## Decisions that still govern current work

- Tenant context is mandatory for tenant-owned work and missing or stale context fails closed.
- Authorization is enforced at the domain boundary; interface hiding is not authorization.
- PostgreSQL remains authoritative, while caches, projections, and search surfaces must be rebuildable.
- Durable side effects use a transactional outbox.
- Release availability, tenant entitlement, module activation, and actor authorization remain separate server-side gates.
- Ash remains conditionally accepted. Its eight bounded conditions must be rechecked when the relevant production capability becomes real.
- A selected deployment, real restricted data, production identity, and production operations each require their own later evidence.

The live architectural rules are maintained in the [ADR index](../adr/README.md), [architecture index](../architecture/README.md), and [threat model](../security/threat-model.md). Those records were not retired because they govern current work rather than merely describe Phase 0 activity.

## What Phase 0 did not authorize

Phase 0 did not authorize a school business module, public or production browser surface, production identity, scheduler, AI gateway, analytics plane, production infrastructure, or real restricted data.

## Retained proof

The consolidated [Phase 0 handover evidence](handover-evidence.md) records the exit decision, the verification results needed by later phases, and the gates that were intentionally carried forward. The deleted detailed reports remain recoverable from Git history.
