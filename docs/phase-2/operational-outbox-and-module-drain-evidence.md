# Slice 2.0-B operational outbox and module drain evidence

- Status: Complete for the local synthetic L1 foundation contract
- Date: 2026-09-26
- Owner: Platform engineering and operations
- Deployment boundary: no production deployment, real data, or external effect is qualified

## Delivered contract

- immutable tenant-qualified event stream positions with compatible old-writer defaults;
- supervised platform, module-ordinary, and module-mandatory consumers;
- ordinary parking while inactive and explicit reconciliation dispatch;
- atomic receipt/acknowledgement and module-cursor advancement;
- fail-closed reactivation until the code-owned ordinary consumer has converged;
- exact cursor paging and bounded range replay composed from audited idempotent exact replays;
- retry, lease expiry, dead-letter quarantine, stale-route and schema enforcement;
- sanitized tenant-qualified dispatcher telemetry; and
- an operator runbook for replay, poison events, outage, crash, restore, and convergence.

## Safety evidence

Tests cover missing/denied context, cross-tenant non-disclosure, stale route, wrong schema, exact and
changed replay, concurrent replay, malformed handler results, exception containment, database
unavailability, lease expiry, acknowledgement crash windows, inactive ordinary parking, inactive
reconciliation, mandatory lifecycle work, reactivation refusal before convergence, cursor advance,
cursor page/range idempotency, telemetry allowlisting, alternate writes, and migration constraints.

The cursor migration is an additive sequence-backed expansion. Existing rows are backfilled in
`occurred_at, id` order; old writers receive the database default. Empty rollback/reapply is
permitted. Any retained event makes rollback refuse rather than discard ordering evidence.

## Boundary

This closes Slice 2.0-B for the provider-neutral local synthetic L1 foundation. External/network
effects, retention deletion, tenant movement, production thresholds, selected-deployment restore,
staff UI, and real Restricted data remain separately gated. Those open L3 concerns do not reopen
the implemented L1 contract, but they prohibit calling it production-operational readiness.

## Verification

The focused outbox and lifecycle suites pass 29 tests with seed 0. The production-core gate passes
formatting, compilation, generated OpenAPI and migration drift, Credo across 144 source files and
1,510 modules/functions, dependency audit, Dialyzer with zero errors or skipped warnings, all 138
core tests, and whitespace validation.

An isolated PostgreSQL rehearsal applied the full migration chain, rolled the cursor expansion back
while empty, reapplied it, retained two events and two deliveries through exact range replay, and
correctly refused destructive rollback. A custom-format dump restored into a second isolated
database with the same convergence signature: two events, maximum stream position two, two
deliveries, and zero receipts for that replay-only scenario. Both isolated databases and the dump
were removed after comparison.

## References

- [ADR 0026](../adr/0026-module-aware-outbox-cursors-and-reconciliation.md)
- [Outbox recovery runbook](../operations/outbox-dispatch-and-recovery.md)
- [Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Threat model](../security/threat-model.md)
