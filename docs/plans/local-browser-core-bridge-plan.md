# UI-1A local browser-to-core bridge plan

- Status: Authorized for implementation on 2026-09-25
- Owner: Product experience and platform engineering
- Governing decision: [ADR 0022](../adr/0022-local-read-only-browser-core-bridge.md)
- Review trigger: any mutation, real authentication, real data, public deployment, or browser
  persistence

## Outcome

A local reviewer can start Chimwemwe, open a read-only assignment-preparation screen, and inspect
real PostgreSQL-backed membership and role options authorized through the production-core
boundary. All identities and records remain synthetic. The screen cannot submit an assignment.

## Implementation boundary

1. Add a guarded local Phoenix endpoint inside `chimwemwe_core`; add no second production app or
   service.
2. Generate one ephemeral bridge token at local startup. Resolve it on the server to one fixed
   synthetic actor, tenant, placement, and routing version. Reject missing or invalid tokens.
3. Seed a dedicated local database idempotently with two tenants, an authorized actor, a denied
   actor, memberships, tenant-defined roles, and the assignment-management capability.
4. Add named public Ash reads for assignment candidate memberships and roles. Require
   `platform.authority.assignments.create` on both and execute them through the trusted writer
   boundary.
5. Expose only `GET /api/v1/authority/assignment-options`. Return minimal opaque option IDs,
   synthetic membership labels, tenant-defined role labels, contract version, and connection
   status. Return no tenant, actor, capability, repository, placement, or routing identifiers.
6. Check in the OpenAPI contract and generate the TypeScript client with a TypeScript-6-compatible
   generator. Add drift checks to the stable repository commands.
7. Add a `server-only` Next.js data-access module. The browser never receives the bridge URL or
   token and never calls Phoenix directly.
8. Add `/authority/assignments` as a separate UI-1A route. Render accessible membership and role
   controls, written local/synthetic status, and a disabled action explaining that writes belong
   to UI-1B.
9. Keep `/` and `/ui-preview` available through UI-0. Do not reinterpret their fixture evidence
   as core integration evidence.

## Required negative evidence

- local bridge startup without the explicit guard;
- local bridge startup without a non-empty token;
- missing and incorrect bearer token;
- denied assignment-management capability;
- stale or mismatched routing context;
- cross-tenant membership and role non-disclosure;
- unrecognized response shape or contract version in the Next.js adapter;
- token or internal identifier appearance in rendered content;
- any enabled write control, POST route, or mutation method; and
- keyboard, accessibility, and 320-pixel reflow regression.

## Verification

- focused core bridge tests;
- OpenAPI semantic drift check;
- generated-client drift check and TypeScript compilation;
- UI unit and real-browser tests for ready, denied, retryable, and unavailable states;
- local human smoke test with the server-owned authorized synthetic persona; and
- complete `make check`.

## Explicit non-goals

- role assignment submission or any other mutation;
- production authentication, cookies, tenant switching, support access, or account management;
- real school, child, employee, or identity data;
- production deployment, TLS termination, cross-origin browser API access, or external services;
- browser storage, caching, offline queues, analytics, realtime, notifications, or service
  workers; and
- membership, role, capability, grant, inclusion, or revoke administration.

