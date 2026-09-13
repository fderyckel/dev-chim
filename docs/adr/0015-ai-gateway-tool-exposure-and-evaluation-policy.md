# ADR 0015: AI gateway tool exposure and evaluation policy

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Security architecture
- Deciders: Architecture review group, privacy owner, and product owner
- Supersedes: None

## Context

AI can assist users and development, but models must not gain implicit database authority, cross-tenant retrieval, unrestricted files, or automatic evidence-verification power.

## Decision drivers

- Provider independence and explicit data policy.
- Curated tools using the same actor/tenant authorization as other clients.
- Human confirmation and deterministic validation for writes.

## Considered options

1. Provider-neutral gateway with typed allowlisted tools and evaluations.
2. Direct provider calls from modules.
3. Raw SQL or broad file/retrieval access for agents.

## Decision

Propose a gateway outside domain authority. It may expose curated Ash actions through typed tools using the real actor, tenant, classification, purpose, and confirmation state. Models cannot verify evidence, bypass policy, access raw SQL, or write without an explicitly approved action.

## Consequences

### Positive

- Providers and agent experiences can change without weakening the domain boundary.
- Tool use is auditable and testable.

### Negative

- Tool registry, redaction, evaluation, cost, latency, and kill-switch operations require ownership.
- Some useful but unsafe capabilities remain unavailable.

## Security, privacy, operability, and migration effects

Use dataset allowlists, minimization, egress controls, provider-retention policy, prompt/tool traces with redaction, cross-tenant and injection evaluations, explicit confirmations, and an emergency kill switch. Production data is prohibited from generic evaluation.

## Validation evidence

See AI abuse cases in the [threat model](../security/threat-model.md). Runtime implementation and red-team evidence belong to Phase 11.

## Fallback and exit cost

Disable runtime AI without disabling deterministic platform actions. Provider adapters remain replaceable.

## Review triggers

- New model provider, tool, writable action, data class, or retention policy.
- Prompt-injection or cross-tenant evaluation failure.

## Related records

- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)

