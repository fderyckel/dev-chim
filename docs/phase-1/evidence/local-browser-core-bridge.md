# UI-1A local read-only browser-to-core evidence

- Date: 2026-09-25
- Scope: proposed ADR 0022 and the authorized UI-1A plan
- Data: deterministic synthetic tenants, actors, memberships, roles, and grants only
- Human review status: local engineering smoke review completed; representative school-user
  review remains pending

## Implemented boundary

The local command starts the existing `chimwemwe_core` application with one Phoenix endpoint
bound to `127.0.0.1`, a dedicated `chimwemwe_ui1_local` database, and a fresh ephemeral token.
The token resolves inside the core to server-owned trusted actor and placement values. The Next.js
adapter is server-only, accepts only loopback HTTP origins, sends the token on a non-cacheable
server request, and rejects an unexpected contract version or shape.

The only HTTP operation is `GET /api/v1/authority/assignment-options`. It invokes public named
membership and role reads through the trusted writer boundary. Both reads require the code-owned
`platform.authority.assignments.create` capability. The response exposes browser-safe membership
labels, tenant-defined role labels, opaque option IDs, contract version, and local connection
status. It omits actor, tenant, capability, repository, placement, and routing identifiers.

The browser route `/authority/assignments` renders those options in accessible native selects.
Its save control is disabled and there is no POST route, mutation method, server action, browser
storage, production identity, or public deployment configuration.

## Negative evidence

- configuration parsing stays disabled without the exact local guard and rejects absent, short,
  or invalid tokens and ports;
- missing and incorrect bearer tokens return the same stable 401 response with no options;
- a server-owned actor without the capability receives 403 without option disclosure;
- a stale server-owned placement receives stable 503 recovery without route disclosure;
- the authorized tenant receives three memberships and three tenant-defined roles, while the
  second tenant's role is absent;
- token state stores only SHA-256 digests;
- the router and generated TypeScript path expose GET and no POST, PUT, PATCH, or DELETE method;
- the Next.js adapter rejects external origins, unrecognized contract version 2, and transport
  failure without exposing the underlying error;
- rendered HTML omits the session token and protected tenant identifiers, and the browser makes
  no direct request to the Phoenix port; and
- the disabled action remains disabled after selecting both an option and a role.

## Maintained custom boundaries

| Classification | Owner | Concrete cost | Bounded remedy | Closure gate | Recheck trigger | Source | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Local-only raw-SQL seed | Platform engineering | Seed statements track authority table names and required columns | Keep it deterministic, idempotent, synthetic, and confined to the dedicated local database; delete it with UI-1A | Remove before any production identity or data path | Authority schema or migration change; UI-1B proposal | `Chimwemwe.LocalBridge.Bootstrap` | focused bridge tests and cross-tenant response assertions |
| Local Phoenix edge adapter | Platform and web engineering | Stable status mapping and server-owned session context must remain aligned with the core | One checked read route, loopback binding, no request-owned authority, and non-disclosing errors | Supersede with the reviewed production session/API boundary | New route, mutation, real identity, or deployment proposal | `Chimwemwe.LocalBridge.Router`, `SessionPlug`, and controller | endpoint tests, route inventory assertion, and real-browser run |
| Hand-owned OpenAPI document | Platform and web engineering | The document and generated declaration can drift from controller behavior | Semantic Elixir drift check plus exact generated-client drift check in stable commands | Replace only with an equally reviewable generator after ADR review | DTO, route, status, or header change | `Chimwemwe.LocalBridge.OpenApi` and `priv/openapi/ui1-local-v1.json` | OpenAPI and TypeScript generation checks |

These are qualification boundaries, not precedents for production raw SQL, local-token
authentication, or hand-maintained public APIs.

## Verification record

- focused local-bridge core tests: 9 passed;
- UI unit and adapter tests: 20 passed;
- generated TypeScript drift check: passed;
- npm high-severity audits for the browser and generator workspaces: zero vulnerabilities;
- connected browser tests: 6 passed across 1440, 768, and 320 CSS pixels;
- unavailable browser recovery test: 1 passed;
- complete production-core suite in the combined worktree: 97 passed after one isolated retry of
  the existing database-admission timing test; the immediate full rerun passed 97 of 97;
- production-core Dialyzer: passed with zero errors, skips, or unnecessary skips;
- local in-app browser smoke review: default and 320-pixel layouts inspected; 320-pixel document
  width equalled viewport width; both selectors operated; save remained disabled; no browser
  warnings or errors were recorded; and
- complete `make check`: not green in the combined worktree. A newly applied concurrent Ash
  dependency patch still records its complete verification as pending, and the clean-checkout
  rehearsal predates this worktree, so `make docs-check` correctly reports both records as stale.
  UI-1A's connected browser command passes against the patched core, but this evidence cannot
  mark the repository gate complete.

The browser and automated checks are engineering qualification evidence. They do not validate
school terminology with representative users, accept ADR 0022, authorize UI-1B, or establish a
production authentication or deployment path.
