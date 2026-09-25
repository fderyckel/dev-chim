# ADR 0022: Local read-only browser-to-core bridge

- Status: Proposed
- Date: 2026-09-25
- Accountable owner: Product experience and platform engineering
- Deciders: Product owner, architecture review group, security architecture, and web engineering
- Supersedes: None

## Context

UI-0 proves the local browser shell, semantic CSS, accessibility mechanics, and public error
language with deterministic fixtures. Slice 1G-B proves a tenant-safe role-assignment action in
the production core. Neither proves that the browser can consume a real policy-authorized core
read without accepting actor, tenant, capability, repository, placement, or routing authority
from browser input.

Connecting the existing UI directly to PostgreSQL or a private Ash action would bypass the
accepted Phoenix/Ash boundary. Adding real authentication at the same time would also make the
first interface proof depend on an unselected identity provider and session lifecycle. The next
step therefore needs a smaller local qualification boundary.

## Decision drivers

- Prove one end-to-end browser-to-core read before exposing a write.
- Preserve server-owned actor, tenant, placement, routing, purpose, locale, and correlation
  context.
- Reuse current writer-side authorization and tenant-qualified persistence routing.
- Produce a checked OpenAPI contract and generated TypeScript client without exposing Ash,
  Ecto, or repository details.
- Keep UI-0 available as an isolated synthetic experience harness.
- Make the local bridge impossible to start accidentally without an explicit guard and token.

## Considered options

1. Add a local-only Phoenix endpoint, server-owned synthetic session, one capability-protected
   assignment-options read, checked OpenAPI, generated TypeScript client, and a read-only browser
   preparation screen.
2. Connect Next.js directly to PostgreSQL or invoke core modules from Node.
3. Expose the role-assignment write and add real authentication in the first integration slice.
4. Continue with fixture-only UI work and defer all interface evidence.

## Decision

Proceed with option 1 as the UI-1A qualification slice. UI-0 remains unchanged in purpose and
continues to run from its guarded fixture adapter. UI-1A adds a separate local integration mode
that starts only when `CHIMWEMWE_UI1_LOCAL=true` and a non-empty server-side bridge token are
present.

The Phoenix edge accepts that token only over loopback in the local qualification runtime. The
token resolves through a server-owned registry to an opaque `TrustedActor`,
`TrustedPlacement`, and `ExecutionContext`. The browser and Next.js components cannot supply or
override actor, tenant, capability, repository, placement, routing version, purpose, locale, or
Ash options. The token is generated for each local start and is available only to the Next.js
server-side data-access module and the Phoenix process; it is never emitted to browser code,
HTML, logs, or the OpenAPI document.

The only public data operation is a versioned, named `assignment-options` read. It requires the
same code-owned `platform.authority.assignments.create` capability that protects the eventual
write, runs on the authoritative writer, and returns minimal membership and role option DTOs.
It returns no tenant identifier, actor identifier, capability graph, repository, placement, or
routing coordinate. Missing session, denied capability, stale placement, and cross-tenant data
fail closed with stable non-disclosing responses.

The Next.js integration is server-rendered through a `server-only` data-access module and the
generated TypeScript client. UI-1A renders the options in an assignment-preparation form but
contains no mutation function, POST route, server action, optimistic state, write retry, or
enabled submit control. UI-1B remains a separate authorization boundary.

## Consequences

### Positive

- The first browser/core proof is inspectable without selecting production identity or hosting.
- Actor and tenant authority remain outside browser-controlled input.
- The checked transport contract and generated client expose drift before a write depends on
  the interface.
- UI-0 remains a fast, deterministic design harness and can be removed independently.

### Negative

- Local startup now coordinates a Phoenix process, PostgreSQL database, and Next.js process.
- The synthetic session registry and seed data are qualification code that must never become a
  production authentication shortcut.
- A read-only preparation form does not prove role-assignment mutation behaviour or real user
  identity.

## Security, privacy, operability, and migration effects

The bridge binds only to loopback, uses synthetic identifiers and labels, sends `Cache-Control:
no-store`, and records no token or restricted data. A request without the current server-owned
token is unauthenticated. Authorization is re-evaluated on the writer for every read. Tenant
predicates and existing compound constraints remain authoritative.

The local seed is idempotent and limited to a dedicated local database. It is not included in
production releases or normal application startup. UI-1A adds no browser persistence, cookies,
analytics, realtime connection, service worker, offline queue, external identity provider, or
production deployment configuration.

The read returns current writer state and is not cacheable. It does not add a migration. Any
future production session adapter must supersede the local token registry with an independently
reviewed identity and revocation contract.

## Validation evidence

Before this ADR can be accepted, UI-1A must prove:

1. the local bridge cannot start without the explicit local guard and server token;
2. a valid server-owned session reaches only its tenant's membership and role options;
3. missing or invalid session, denied capability, stale routing, and cross-tenant fixtures fail
   closed without identifier disclosure;
4. OpenAPI and generated TypeScript artifacts fail drift checks;
5. the browser token is absent from rendered HTML, browser JavaScript, error bodies, and logs;
6. the preparation screen has no enabled mutation path and remains keyboard-accessible and
   usable at narrow, medium, and wide viewports; and
7. `make check` passes with the local integration tests included.

Representative human review remains necessary before the screen or terminology is considered
validated. This qualification uses synthetic data only.

## Fallback and exit cost

If Phoenix or the generated client cannot preserve the contract, remove the local bridge and
use ADR 0014's thin REST/OpenAPI fallback while retaining the core read boundary. If the local
session mechanism is unsafe or begins to resemble production identity, remove it and return to
UI-0 until a real identity slice is selected.

## Review triggers

- UI-1B proposes a role-assignment mutation.
- A real identity provider, session, tenant switcher, browser cache, or production deployment is
  proposed.
- The client or endpoint exposes an actor, tenant, capability, repository, placement, or routing
  selector.
- The generated contract cannot preserve stable errors or minimal DTOs.

## Related records

- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [Threat model](../security/threat-model.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)

