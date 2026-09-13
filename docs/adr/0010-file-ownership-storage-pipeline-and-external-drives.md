# ADR 0010: File ownership, storage pipeline, and external drives

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering and security architecture
- Deciders: Architecture review group and privacy owner
- Supersedes: None

## Context

School files contain sensitive data, while parsers and renderers create a large attack surface. External-drive permissions may drift from platform policy.

## Decision drivers

- Policy and metadata remain authoritative in the core.
- Binary storage is replaceable and versioned.
- Unsafe content is isolated before ordinary access.

## Considered options

1. S3-compatible binaries with Ash/PostgreSQL metadata and a quarantine pipeline.
2. Binaries stored directly in PostgreSQL.
3. External-drive folders as the authorization source.

## Decision

Propose PostgreSQL/Ash ownership, relationships, classification, version, retention, checksum, and lifecycle metadata with S3-compatible binary storage. New uploads remain quarantined through type validation, scanning, extraction, and safe derivative generation. External drives are connectors, not the platform policy engine. Storage namespaces come from trusted tenant placement and routing version, never a request path or module-supplied bucket.

## Consequences

### Positive

- Binary storage can change without losing governance.
- Access, retention, and provenance remain inspectable.

### Negative

- Scanning and rendering require isolated utilities and reconciliation.
- Connector ownership modes need explicit user communication.

## Security, privacy, operability, and migration effects

Object keys are opaque and tenant-qualified. Signed URLs are short-lived and issued only after policy, entitlement, and activation evaluation where applicable. Parser containers receive resource/network limits. Tenant movement requires metadata/object reconciliation before routing changes become final. Deletion, legal hold, versioning, deactivation, and metadata/object reconciliation require runbooks.

## Validation evidence

See upload, export, and external-provider entries in the [threat model](../security/threat-model.md). Implementation and malicious-file corpus tests belong to Phase 6.

## Fallback and exit cost

The S3-compatible contract permits provider replacement. A connector may remain link-only if managed-copy ownership cannot meet security or reconciliation requirements.

## Review triggers

- Storage or external-drive provider selection.
- A parser vulnerability, residency rule, or new file class.
- Tenant placement, movement, or module-retained-data semantics change.

## Related records

- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0015](0015-ai-gateway-tool-exposure-and-evaluation-policy.md)
