# ADR 0023: Sensitive-collection enumeration and bulk-export boundary

- Status: Proposed
- Date: 2026-09-25
- Accountable owner: Security architecture with platform and product engineering
- Deciders: Project owner, security/privacy owner, platform engineering, and product engineering
- Supersedes: None

## Context

ADR 0014 conditionally accepts a generated public interface with a bounded page-limit adapter.
The Phase 0 pressure-test proves that the adapter can reject one oversized page, but a small page
limit does not prevent bulk extraction: a caller can follow every cursor or vary filters, searches,
sorts, and concurrent requests until it reconstructs a tenant-wide sensitive collection.

Interactive permission to see a record is not automatically permission to download a roster or
another complete collection. This distinction matters most for Confidential and Restricted data,
including child, guardian, safeguarding, health, employment, and sensitive operational records.
The boundary must prevent an ordinary list or search API from becoming an undeclared export path
while preserving deliberately bounded school tasks.

This proposal is a candidate treatment for the **Page-limit edge adapter** production condition in
the [Ash bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md).
It does not authorize a public API, a school module, or a production export.

## Decision drivers

- Prevent ordinary API pagination from reconstructing a whole tenant-wide sensitive collection.
- Keep interactive read authority distinct from bulk-export authority.
- Preserve legitimate, named, task-scoped reads such as one assigned class or attendance session.
- Apply the same rule to browser, integration, job, and other non-HTTP callers.
- Keep OpenAPI and generated clients aligned with the enforced server contract.
- Fail closed without treating a small per-page maximum as sufficient protection.

## Considered options

1. Retain only a numeric maximum page size. This limits one response but still permits complete
   traversal, so it is insufficient for a sensitive collection.
2. Prohibit pagination for every endpoint. This prevents traversal but is unnecessarily broad for
   public reference data and for deliberately bounded, authorized task sets.
3. Apply a classification- and scope-aware non-enumeration boundary, with separate bulk-export
   authority. This is the proposed option.
4. Depend only on rate limiting or an API gateway. These are useful defence-in-depth controls but
   do not define record authority and can be bypassed by another interface or slow extraction.

## Decision

Adopt, subject to accountable review and evidence, the following invariant:

> An ordinary API must not provide a pagination or query path that lets a caller reconstruct a
> whole tenant-wide Confidential or Restricted collection. Bulk extraction is a separate named,
> authorized, and audited capability.

Every proposed public or non-HTTP read must be classified before exposure:

- Public or non-sensitive reference data may use bounded pagination when its contract and resource
  controls pass the existing page-limit gate.
- Confidential or Restricted collections expose only named reads with a server-derived purpose and
  scope. A generic tenant-wide `list all` action is prohibited.
- Pagination is allowed for sensitive data only when the complete traversable set is itself the
  deliberately authorized, naturally bounded task scope. One assigned class or one attendance
  session may qualify; a tenant-wide learner, guardian, staff, health, safeguarding, or complete
  roster collection does not qualify as an ordinary interactive list.
- Page size, cursor shape, ordering, filters, and searchable fields are code-owned. The caller
  cannot widen tenant, placement, module, relationship, organizational, or purpose scope.
- Total counts, unrestricted sorting, wildcard or empty searches, arbitrary filters, and reusable
  cursors are omitted when they would help enumerate a sensitive collection.
- Search results are fixed and small, require sufficient specificity, disclose only task-required
  fields, and provide no continuation path across the collection. Repeated overlapping search or
  scope requests are subject to actor- and tenant-qualified cumulative abuse controls.
- The server re-authorizes every page or task read. A prior cursor, cached result, hidden control,
  or client-side decision never preserves authority after context, capability, module, or
  relationship state changes.

The OpenAPI description and generated client must expose only the supported named contract. They
must not publish a generic sensitive-collection traversal method or raw Ash pagination, filter,
sort, tenant, repository, or placement options.

A legitimate bulk download, if later authorized, uses a separate named export workflow governed by
the data classification and threat model. It requires distinct capability and purpose checks,
server-derived tenant and record scope, field minimization, bounded manifest, attributable audit,
appropriate assurance or approval, expiring delivery, and explicit retention and deletion rules.
Ordinary interactive read authority does not imply this export authority.

## Consequences

### Positive

- A small page size can no longer be mistaken for protection against cumulative extraction.
- Sensitive endpoints are shaped around school tasks instead of database tables.
- Bulk access becomes explicit, reviewable, attributable, and independently revocable.
- Generated clients cannot silently turn ordinary reads into a general download mechanism.

### Negative

- Some list and search endpoints require purpose-specific contracts instead of generic generation.
- Product and security owners must define the natural task scope and acceptable cumulative exposure
  for each sensitive workflow.
- Users with a legitimate bulk need require a separately designed export path rather than repeated
  interactive calls.
- Abuse detection and cumulative limits add operational calibration and support work.

## Security, privacy, operability, and migration effects

Tenant isolation remains mandatory but is not the whole control: an actor can remain inside the
correct tenant and still extract more sensitive data than the interactive purpose allows. Named
reads therefore enforce relationship, organizational, module, purpose, field, and cumulative scope
in addition to tenant and capability checks.

Errors, metrics, and audit evidence must not contain unredacted child data, raw search results, or
cross-tenant existence signals. Operational evidence may record safe actor, tenant, action, purpose,
scope, result-count, and abuse-decision references according to the classification and retention
contract. Rate limiting is defence in depth, not authorization.

Existing internal or generated routes do not become accepted by documentation alone. Before real
restricted data, route inventories must identify every path capable of reading the collection,
including integrations, jobs, reports, search, support tools, and direct generated interfaces.

## Validation evidence

No production sensitive-collection endpoint or export currently supplies acceptance evidence for
this proposal. The Phase 0 page-limit test remains useful but proves only single-request bounds.

Acceptance for each production candidate requires:

1. route, action, OpenAPI, and generated-client inventories with no generic sensitive `list all` or
   raw pagination/query escape hatch;
2. positive proof for the named, naturally bounded task and its minimum returned fields;
3. missing-context, capability, module, relationship, purpose, cross-scope, and cross-tenant denial;
4. an adversarial traversal test that follows all cursors and varies page size, filters, searches,
   sorts, identifiers, timing, and parallel requests without reconstructing the protected tenant-wide
   collection;
5. repeated-request and cumulative-exposure tests proving that request splitting does not turn the
   ordinary read contract into a bulk-export contract;
6. OpenAPI drift and strict generated-client checks proving unsupported traversal controls are
   absent or rejected;
7. explicit denial tests showing ordinary read authority cannot invoke the bulk-export workflow;
8. separate export authorization, assurance, manifest, audit, expiry, replay, and retention tests
   before any legitimate bulk-download path is enabled; and
9. independent security/privacy review before real Restricted child data is used.

Passing these checks closes the page-limit condition only for the named production capability and
candidate tested. It is not blanket approval for another collection, query shape, interface, or
data classification.

## Fallback and exit cost

If a generated route cannot preserve this boundary, block that route and use ADR 0014's thin,
purpose-built Phoenix/REST/OpenAPI adapter over the same named and authorized domain read. If no
ordinary API can preserve the intended scope, keep the workflow server-rendered or unavailable
until a safe contract exists.

If cumulative controls cannot distinguish legitimate work from extraction reliably, reduce the
interactive scope and fields and require the explicit export workflow for the larger result. A
generic tenant-wide sensitive list is not a fallback.

## Review triggers

- The first production API, search, report, integration, or support tool can traverse Confidential
  or Restricted records.
- A workflow proposes tenant-wide pagination, arbitrary filters or sorting, total counts, reusable
  cursors, bulk selection, or client-controlled page size.
- A new data class, relationship scope, or legitimate bulk-download requirement enters scope.
- Abuse testing shows that repeated or parallel ordinary reads can reconstruct the protected
  collection.
- Ash, Phoenix, OpenAPI, or generated-client behaviour changes the enforced query contract.

## Related records

- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [Data classification](../security/data-classification.md)
- [Threat model](../security/threat-model.md)
- [Security abuse cases](../security/abuse-cases.md)
- [Ash bounded-condition disposition](../phase-0/evidence/ash-bounded-condition-disposition.md)
