# ADR 0012: Report templates, Gotenberg, and campaign model

- Status: Proposed
- Date: 2026-09-13
- Accountable owner: Platform engineering and operations
- Deciders: Architecture review group and product owner
- Supersedes: None

## Context

Schools can generate large, sensitive report campaigns. Synchronous rendering or unversioned templates would be fragile and unreproducible.

## Decision drivers

- Deterministic, versioned output.
- Bounded asynchronous work with progress and retry.
- Renderer isolation and manifest reconciliation.

## Considered options

1. Versioned HTML/CSS templates rendered through isolated Gotenberg/Chromium jobs.
2. In-process synchronous PDF generation.
3. Per-module report engines.

## Decision

Propose versioned report definitions and templates, asynchronous bounded campaigns, immutable manifests, idempotent items, cancellation, retry, checksums, and output validation. Per-tenant quotas and fair scheduling prevent report workloads from consuming the database and connection budget reserved for synchronized operational writes. Gotenberg/Chromium is the preferred renderer subject to an accepted capacity target and mixed-workload benchmark.

## Consequences

### Positive

- Reports are reproducible, observable, and reconcilable.
- Modules share one governed artifact lifecycle.

### Negative

- Campaign orchestration and renderer operations are additional platform work.
- Templates require compatibility and publication governance.

## Security, privacy, operability, and migration effects

Rendering runs with resource/network isolation. Input and output retain tenant, trusted placement, classification, template version, module lifecycle, and authorization context. Bulk access requires appropriate assurance and audit. Historical analytics or reporting copies remain outside authoritative OLTP and cannot become an authorization source.

## Validation evidence

Numeric campaign and file targets are recorded in [quality targets](../architecture/quality-attribute-targets.md). The benchmark includes overlap with the accepted peak operational-write profile; isolated renderer throughput is insufficient. Production benchmark evidence belongs to Phase 6.

## Fallback and exit cost

Retain the versioned campaign contract if the renderer changes. Provider replacement must reproduce the accepted fixtures before cutover.

## Review triggers

- Gotenberg benchmark failure or renderer security issue.
- Report complexity or campaign size materially changes.
- Reports materially affect a tenant-placement or connection-pool decision.

## Related records

- [ADR 0010](0010-file-ownership-storage-pipeline-and-external-drives.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
