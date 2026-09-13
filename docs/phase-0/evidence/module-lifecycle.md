# Module-lifecycle evidence

- Status: Evidence required
- Owner: Platform engineering with product and security architecture
- Review date: DATE_REQUIRED

## Synthetic contract under test

Use neutral synthetic kernel and module names. This evidence must not introduce a school business module or a production module registry.

The test fixture records release availability, entitlement, activation state, actor capability, dependency state, lifecycle version, queued work, event cursor, retained record, and projection version independently.

## Required scenarios

| Scenario | Required result | Evidence |
| --- | --- | --- |
| Module is absent from the release | Deny before module code or routes are invoked | EVIDENCE_REQUIRED |
| Module is present but unentitled | Deny even when the actor is authorized and a client requests activation | EVIDENCE_REQUIRED |
| Module is entitled but inactive | Deny ordinary module actions | EVIDENCE_REQUIRED |
| Module is active but actor is unauthorized | Deny without revealing hidden records | EVIDENCE_REQUIRED |
| Module is present, entitled, active, and actor is authorized | Permit only the named action and allowed fields | EVIDENCE_REQUIRED |
| Required dependency is absent or inactive | Reject activation with a stable error | EVIDENCE_REQUIRED |
| Active dependent exists during deactivation | Reject or execute only an explicitly reviewed cascade | EVIDENCE_REQUIRED |
| Mutation races deactivation | Produce one deterministic, authorized outcome with no partial state | EVIDENCE_REQUIRED |
| Jobs and event consumers are in flight | Drain, cancel, or park according to the declared contract; retain replay position | EVIDENCE_REQUIRED |
| Audit, outbox, retention, or legal-hold work remains | Continue mandatory work without ordinary module authority | EVIDENCE_REQUIRED |
| Module becomes inactive | Remove ordinary entry points and invalidate disposable projections without deleting retained data | EVIDENCE_REQUIRED |
| Module is reactivated after a release change | Validate compatibility, rebuild, replay, reconcile, and open actions only after success | EVIDENCE_REQUIRED |

## Review outcome

- Accountable decider: OWNER_REQUIRED
- Decision: DECISION_REQUIRED
- Conditions, owner, and expiry: DECISION_REQUIRED

See [module activation and lifecycle](../../architecture/module-activation-and-lifecycle.md) and [ADR 0001](../../adr/0001-modular-monolith-and-service-boundaries.md).
