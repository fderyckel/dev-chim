# Security abuse cases

- Status: Proposed
- Owner: Security architecture

| ID | Abuse case | Required denial or containment |
| --- | --- | --- |
| AC-01 | A tenant A actor requests or guesses tenant B identifiers | Return no unauthorized data or existence signal; audit the attempt safely |
| AC-02 | A request, job, event, cache lookup, or AI tool omits tenant context | Fail closed before data access or mutation |
| AC-03 | A tenant renames or composes roles to gain capabilities not granted by policy | Resolve capabilities from validated tenant data; reject cycles/escalation |
| AC-04 | Support accesses a tenant without approved purpose, assurance, or expiry | Deny and record an attributable security event |
| AC-05 | An upload exploits type confusion, parser bugs, decompression, or active content | Quarantine, validate, scan, isolate, limit, and reject unsafe derivatives |
| AC-06 | A user exports more data than an ordinary read permits | Re-evaluate policy, require assurance where defined, bound scope, and audit |
| AC-07 | A realtime subscription or search projection leaks a previously allowed record | Re-authorize, tenant-filter, invalidate, and deny stale access |
| AC-08 | A cache key collides across tenant/classification or survives access revocation | Include tenant and version; invalidate durably; bypass shared cache for restricted data |
| AC-09 | Uploaded text or external content injects instructions into an AI client | Treat content as data, use curated tools, minimize context, confirm writes, and deny over-broad access |
| AC-10 | Logs, traces, or evidence contain secrets or restricted payloads | Redact at source and test captured telemetry |
| AC-11 | A caller supplies another tenant's repository, cell, queue, schema, bucket, or stale routing version | Ignore untrusted placement input; resolve authenticated tenant placement centrally and fail closed on conflict or staleness |
| AC-12 | One pooled tenant floods period-start writes or reports until other tenants cannot authorize or commit work | Enforce bounded batches, per-tenant fairness, connection budgets, backpressure, and a tested dedicated-placement path |
| AC-13 | A tenant or client treats module activation as permission, bypasses entitlement, or deactivates while work is in flight | Enforce all gates server-side; drain or park work deterministically; preserve audit, outbox, retained data, and compliance access |
| AC-14 | A lagging replica still shows a revoked permission, old tenant placement, inactive module, or omits a just-committed attendance change | Keep security decisions and bounded read-your-write interactions on the writer; lag-gate approved stale reads and fail closed or delay them |
| AC-15 | A caller reuses an idempotency key with another actor, tenant, aggregate, or request envelope to duplicate or suppress a transition | Bind the claim to tenant, action, actor, aggregate, and canonical request; replay only an exact completed result and reject changed reuse without another state or outbox write |
| AC-16 | A tenant definition references a private field, forbidden action, another tenant's definition, arbitrary SQL or code, or an incompatible resource descriptor | Reject the definition or execution; disclose no protected schema or cross-tenant existence; re-authorize every allowed operation through the domain boundary |
| AC-17 | An actor follows pagination or varies searches, filters, sorts, identifiers, timing, or parallel requests to reconstruct a tenant-wide Confidential or Restricted collection that ordinary interactive access did not authorize as a bulk export | Expose only named, task-scoped reads; prohibit generic sensitive-collection traversal; bind scope server-side; enforce cumulative abuse controls; and require a separate authorized and audited export workflow for bulk access |
| AC-18 | An actor creates or moves an institutional unit beneath a visible or privileged parent, or selects a parent in the client, to inherit access, reports, configuration, modules, placement, or descendant data | Treat hierarchy as organizational containment only; require explicit separately authorized scopes and adoptions; preview and validate move impacts on the writer; reject cross-tenant parentage and cycles; and fail closed on any unclassified widening |

Each implemented capability must convert relevant abuse cases into automated negative tests and link them from the threat model.
