# Chimwemwe — operating system for learning institutions

Chimwemwe is an operating system for learning institutions: kindergartens, primary and secondary
schools, combined schools, colleges, community colleges, universities, and other governed learning
environments. The learner and the learner's context remain central regardless of age, while each
institution may operate through its own nested structure, terminology, programmes, and policies.

This repository is establishing that governed modular foundation. Phase 0 completed its
architecture, security-baseline, pressure-test, and accountable decision package on 2026-09-16.
Ash is conditionally accepted as the default production-core framework, with eight binding
production gates. Phase 1 is complete at its bounded repository boundary: Slices 1A through 1J-B,
ADR 0018 T1-A/T1-B/T1-C, UI-0, and UI-1A are implemented and verified. Slices 1H-A and 1H-B add
neutral module lifecycle; Slices 1I-A and 1I-B add governed presentation definitions and exact
internal resolution; Slices 1J-A and 1J-B add internal delivery leases, supervised database-local
consumption, durable receipts, and exact governed dead-letter replay. Phase 2 has started with the
L1 foundation now closed. Slice 2.0-B completes the local operational-outbox foundation, and
Slice 2.0-C completes the neutral temporal retention/recovery engineering boundary. ADR 0018 is
Accepted at the platform level after its 2026-09-27 accountable post-evidence review. Production
identity architecture is accepted in provider-neutral ADR 0029, including Microsoft Entra ID,
hybrid/on-premises Active Directory, Google Workspace, generic OIDC, and qualified SAML gateway
paths. The internal provider-neutral identity/session/support foundations and bounded public
session adapter are implemented but not enabled as an L2 release. Conditionally Accepted ADR 0025
governs the stable institutional-structure direction; ADR 0031 authorizes the bounded synthetic
`organization.legal` Slice 2.1-C1 start. [ADR 0032](docs/adr/0032-c25-02-delegated-contract-acceptance.md)
closes C25-02’s logical contract through the Project Owner’s expressly delegated review; it does
not expand implementation or release authority. [ADR 0033](docs/adr/0033-append-only-legal-structure-lifecycle-foundation.md)
authorizes bounded Slice 2.1-C2a lifecycle work. The module now separates stable legal entities,
four explicit direct relationship meanings, management-reporting parentage, and corporate units,
and can append one relationship end or the next corporate-unit name profile. It
adds no public business route, educational structure, real-data authority, statutory consolidation
claim, or production deployment.

[ADR 0034](docs/adr/0034-c25-03-delegated-educational-structure-acceptance.md) closes C25-03 for
synthetic L1 under delegated Project Owner authority. Its five-context review makes unpublished
educational identity, initial parentage, sites, and terminology eligible within the bounded
sequence. [ADR 0035](docs/adr/0035-c25-04-delegated-primary-operator-acceptance.md) closes C25-04
for synthetic L1 operator assignment, publication and controlled transfer/reconciliation proof.
Actual representative validation remains C25-03-R before connected workflows, real data, or
deployment; existing legal adoption and release gates remain. These are contract decisions,
not implementation claims.

## Start here

The active delivery priority is the authorized
[classroom-first six-week plan](docs/plans/classroom-first-six-week-plan.md), covering 5 October
through 15 November 2026: academic calendar, people, enrolment, and daily attendance in one usable
journey. Further corporate/legal expansion is paused. The plan changes sequencing, preserves
existing work, and retains domain and connected-release gates. Calendar construction has now begun
with the accepted synthetic L1 definition/preview/resolution
contract and a local preparation prototype. The private synthetic
[institutional/operator writer](docs/phase-2/institutional-foundation-evidence.md) and
[people/participation foundation](docs/phase-2/people-foundation-evidence.md) are implemented.
The [classroom setup foundation](docs/phase-2/classroom-foundation-evidence.md) now adds class
registers, enrolment, teaching assignments and dated placements, tested against the named
[calendar publication writer](docs/phase-2/academic-calendar-contract-evidence.md). Connected
preparation and the educator roster/attendance workflow remain separate work.

1. Read [the Phase 0 outcome](docs/phase-0/README.md) and its binding later gates.
2. Read [the Phase 1 core scope](docs/phase-1/README.md).
3. Read [the Phase 2 entry status](docs/phase-2/README.md) before proposing a learning-institution
   module or production boundary.
4. Read [the architecture index](docs/architecture/README.md) and [ADR index](docs/adr/README.md).
5. Follow [local setup](docs/development/getting-started.md).
6. Run the suite selected by `make check-changed` before sharing changes; reserve `make check` for an explicit integration check.

The completed foundations are summarized in the [Phase 0 handover](docs/phase-0/handover-evidence.md)
and [Phase 1 handover](docs/phase-1/handover-evidence.md). Current work follows the accepted
[Phase 2 sequencing proposal](docs/plans/phase-2-entry-and-school-structure-proposal.md).

## Stable commands

```sh
make bootstrap
make fix
make format
make lint
make check-changed
make check-staged
make test-fast
make test
make docs-check
make legal-demo
make web-dev
make web-core-dev
make web-check
make web-e2e
make web-core-e2e
make check
```

These commands are the project contract. Editor tasks and future CI jobs must call them rather than recreating different check sequences.
`make fix` applies Ruff's safe fixes, then runs the repository-owned Python, Elixir, and web formatters.
`make check-changed` selects documentation, Phase 0, repository-tool, core, web, and shell-tooling suites from changed paths. `make check-staged` applies the same policy to staged paths for the pre-commit hook.
`make test-fast` is the short production-core feedback loop during development; it does not replace the selected core boundary suite before sharing a core change.
`make legal-demo` creates a dedicated local database and idempotently seeds six synthetic legal
entities, four direct relationships, three management-reporting parentages, and six corporate
units from the Phase 2.1 review fixture. One relationship is ended and one corporate unit receives
a second name profile through append-only lifecycle actions. It adds no educational structure, public route, statutory
consolidation conclusion, or real data.
`make web-dev` starts the explicitly synthetic, local-only UI-0 experience at `http://127.0.0.1:3000`.
`make web-core-dev` starts the guarded UI-1A qualification at
`http://127.0.0.1:3000/authority/assignments`, backed by a dedicated local synthetic database
and a server-owned ephemeral session. It is read-only and is not production authentication.

## Current boundaries

- Phoenix/PostgreSQL and the modular-monolith shape are the firm base.
- Ash is conditionally accepted as the default production-core framework; every retained exception has a production gate, verification method, and fallback.
- The production core and Foundation Lab use the reviewed Ash 3.33.11 security-patch baseline.
- The accepted authoring model keeps Ash resources, actions, policies, and migrations authoritative while derived metadata may configure views and reports; it does not add a second runtime ORM.
- Roles and access scopes are tenant-defined data, never a fixed list of institutional job titles.
- Conditionally Accepted ADRs 0025 and 0031 separate tenant-owned legal entities and corporate units from educational
  institutions and units. Legal ownership/control may be a typed graph with an optional
  consolidation tree; educational units may nest to any reviewed depth. Every published
  educational institution requires one effective primary legal operator. No relationship or
  hierarchy grants access or silently supplies finance/reporting, workflow/configuration, site,
  module, or placement semantics. See
  [ADR 0025](docs/adr/0025-learning-institution-operating-system-and-institutional-structure.md)
  and [ADR 0031](docs/adr/0031-bounded-cross-jurisdiction-legal-structure-foundation.md).
- Logical tenant controls remain mandatory in pooled databases, dedicated databases, and dedicated cells; physical placement is evidence-driven.
- Module release availability, entitlement, tenant activation, and actor authorization are separate server-side gates.
- All examples and tests use synthetic data.
- Slice 1A contains trusted context, the initially empty globally-authorized Ash platform domain, and a code-owned resource-authoring guard. Slice 1B adds the deterministic, allowlisted resource-descriptor builder. Slice 1C adds only trusted invocation of public named read actions. Slice 1D adds trusted pre-checkout tenant and placement admission. Slice 1E adds the explicitly configured PostgreSQL repository runtime, immutable current-route check, and scoped repository selection that wires admission before checkout. Slice 1F adds tenant memberships, tenant-defined roles and capabilities, tenant-qualified assignments and grants, cycle-safe role composition, and writer-only capability resolution. Slice 1G-A adds capability-protected role rename; Slice 1G-B adds capability-protected assignment of an existing membership to an existing role. Both use exact idempotent replay, immutable audit evidence, and a transactional outbox fact. ADR 0018 T1-A/T1-B/T1-C qualify neutral temporal state, governed revision and fact actions, and explicit consumer reconciliation. Slice 1H-A adds a trusted immutable module manifest, closed tenant entitlement and activation state, one private initial-activation action, and an ordinary server-side gate that independently requires release, entitlement, compatible activation/dependencies, and actor capability. Slice 1H-B adds deterministic dependency-safe drain, queue-neutral ordinary and mandatory work state, retained cursor/projection/reconciliation state, and private compatible reactivation. Slice 1I-A adds released extension-contract declarations, a trusted descriptor-derived registry, and one private exact-versioned publication path for bounded presentation definitions with minimized atomic evidence. Slice 1I-B adds exact tenant-qualified internal resolution with separate read authority, current module gates, exact descriptor/content/classification revalidation, and explicit compatible-release handling. It adds no enumeration, renderer, action execution, domain-record read, custom fields, runtime schema, public API, or learning-institution module. Generic or public write invocation, membership/role/grant/composition/revoke administration, interface/rendering consumers, business modules, production web applications, scheduler services, runtime AI, and analytics remain outside this boundary.
- UI-0 under `clients/web` is a local Next.js/React experience harness with deterministic synthetic fixtures, semantic CSS, and no core connection, authentication, persistence, storage, or production deployment authority.
- UI-1A adds one guarded, loopback-only, read-only assignment-options connection from that
  harness to the existing core. It uses synthetic server-owned context, checked OpenAPI and
  generated TypeScript types, and exposes no assignment write or production identity path.
- Phase 2's bounded implementation sequence is authorized. Phase 2.0 is conditionally approved and
  closed at L1: Slices 2.0-B/2.0-C, bounded provider-neutral 2.0-D engineering, and the minimal
  Slice 2.1-B legal-entity proof pass their synthetic gates. ADR 0031 authorizes the bounded
  synthetic Slice 2.1-C1 implementation, and ADR 0033 authorizes the append-only Slice 2.1-C2a
  lifecycle increment, while retaining external finance/governance validation before L2, real
  data, migration, or jurisdictional/accounting claims. Slice 2.0-E is a dated C25-05 residual
  condition: expert/representative comprehension and accountable product-experience review is due
  by 2026-12-15 or before the first connected/public institutional-structure workflow, whichever
  is earlier. The deferral does not authorize the connected workflow, educational-structure
  persistence, deployment, or real data.
