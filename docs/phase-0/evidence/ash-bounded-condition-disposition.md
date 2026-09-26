# Ash bounded-condition disposition

- Status: Conditionally accepted
- Prepared on: 2026-09-16
- Decided on: 2026-09-16
- Accountable approver: François — Project Owner
- Decision: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md)
- Source: [`owned-boundaries.json`](../../../spikes/ash-foundation-lab/priv/maintenance/owned-boundaries.json)
- Machine record: [`ash-bounded-condition-disposition.json`](../../../spikes/ash-foundation-lab/priv/maintenance/ash-bounded-condition-disposition.json)

## Outcome

Ash is **conditionally accepted as the default production-core framework**. Every mandatory scorecard property has direct Phase 0 evidence, and none of the eight current escape hatches displaces domain authorization, tenant scoping, named actions, or PostgreSQL authority. Each limitation is confined to a named seam with a production gate, verification method, recheck trigger, and fallback. There is no parallel second-framework implementation requirement.

François accepted the conditions on 2026-09-16 as Project Owner and interim Platform Owner. Each condition remains binding until its production gate is verified or the documented fallback is selected. The review date is 2026-12-15, or earlier when a dependent production capability reaches its gate.

## Disposition register

| Boundary | Accepted disposition | Production gate | Required verification | Fallback trigger |
| --- | --- | --- | --- | --- |
| Transaction-backed non-atomic action | Retain as a bounded prerequisite: the named action keeps its explicit transaction, optimistic lock, stable errors, and rollback suite | Before a production state transition uses the pattern | Re-run positive, stale, invalid, and injected-rollback cases on the production candidate; review the first action | Use an explicit Phoenix/Ecto domain service if the safety properties cannot be preserved or this becomes the default mutation path |
| Dynamic-repository SQL | Retain only inside inventoried, tenant-qualified transactional adapters | Before an adapter is promoted or reimplemented in the production core | Tenant, routed-repository, rollback, concurrency, and new-source inventory gates | Stop the affected Ash promotion if SQL becomes caller-visible, bypasses routing/authorization, or spreads beyond the inventory |
| Page-limit edge adapter | Retain the thin pre-dispatch guard | Before exposing a generated public list route | Invalid/boundary request tests plus OpenAPI and TypeScript drift checks | Own the route in a thin Phoenix adapter if documented and enforced limits cannot stay aligned |
| Failure-header edge adapter | Retain the allowlisted transport adapter | Before exposing the proposed public error contract | Verify status, body, cache/retry headers, correlation, and non-disclosure | Own transient-error translation in a thin transport layer if the complete contract becomes inconsistent or leaks internals |
| OpenAPI contract modifier | Retain one reproducible modifier for the measured pagination and error gaps | Before generating a production client | Regenerate and review byte-stable OpenAPI; regenerate and type-check the client | Move contract ownership to an explicit interface layer if the modifier grows, becomes order-sensitive, or stops being reproducible |
| Retained-data migration choreography | Retain explicit operator-owned expand/backfill/validate/contract choreography around generated schema intent | Before the first production retained-data contraction | Repeat in the selected deployment environment with representative load; rehearse index, lock retry, drain, monitoring, backup/restore, and repair gates | Defer contract and use an explicit migration runner when targets, bounded locks, or recovery fail; reject Ash only if schema ownership becomes unsafe or pervasive |
| Resource descriptor and metadata validator | Retain the one-way, derived, code-owned allowlist adapter | Before any production descriptor consumer, definition store, or renderer | Descriptor evolution, forbidden/stale/cross-tenant negatives, authorized execution, and security review per consumer | Stop metadata and keep explicit code-owned presentation contracts if policy is duplicated, authority-bearing references appear, or a second runtime schema engine is needed |
| Tenant movement and non-HTTP routing | Retain the platform control-plane adapter; Ash remains the re-entered authorization boundary | Before a production registry, movement control plane, or non-HTTP adapter | Durable-registry movement, reconciliation, rollback, stale/forged/missing context, cross-placement, interface-class, and recovery cases | Keep placement static and block movement/adapter activation if the control plane cannot fail closed; request-selected placement is never a fallback |

### Proposed closure direction for the page-limit boundary

[ADR 0023](../../adr/0023-sensitive-collection-enumeration-and-bulk-export-boundary.md)
proposes a stronger, classification- and scope-aware treatment for the third condition. A numeric
page maximum remains necessary where pagination is allowed, but it is not sufficient when following
all pages or varying searches, filters, sorts, or parallel requests can reconstruct a tenant-wide
Confidential or Restricted collection. The proposal separates ordinary interactive reads from an
explicitly authorized and audited bulk-export capability.

This later proposal does not rewrite the Phase 0 evidence or close the condition. Until it is
accepted and verified against a named production candidate, the retained page-limit guard and
fail-closed fallback remain binding. Verification would close the condition only for the exact
collection, task scope, interface, and data classification tested.

## Approval contract

The machine record binds these rows one-to-one to the eight entries in the owned-boundary manifest and records:

- the binding conditional-acceptance decision;
- François as named accountable person;
- the 2026-09-16 decision date;
- the 2026-12-15 review/expiry date; and
- the production gate, verification method, fallback, and recheck trigger for every condition.

Verification closes a condition only for the named capability and production candidate that was tested. A relevant framework, interface, routing, or deployment change reopens it. A missed production gate fails closed: the dependent production capability does not ship.

## Interpretation

This register closes the accountable Ash-adoption decision for Phase 0. Conditional acceptance is not blanket approval of future adapters: a critical property failure, a pervasive escape hatch, or a fallback that cannot preserve the platform invariants blocks the affected production capability and triggers reconsideration of Ash for that boundary.
