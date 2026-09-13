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

Each implemented capability must convert relevant abuse cases into automated negative tests and link them from the threat model.

