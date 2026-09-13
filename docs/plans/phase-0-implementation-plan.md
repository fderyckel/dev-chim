# Phase 0 implementation plan

- Status: In progress
- Scope: Architecture decisions and risk spikes
- Repository: `/Users/francois/dev-chim`
- Source: *School ERP Platform Architecture - Foundation Roadmap*
- Exit decision: Accept the architecture and Ash, conditionally accept Ash with bounded follow-up work, or select the fallback before production framework APIs depend on it.

## 1. Outcome

Phase 0 will turn the architecture direction into reviewable decisions and evidence. It will leave behind:

- a small, navigable documentation and ADR workspace;
- an approved set of foundational architecture decisions;
- a threat model covering the platform's highest-risk trust boundaries;
- measurable per-domain burst, retained-footprint, tenant-placement, latency, recovery, and availability targets;
- a distinct PostgreSQL writer, HA, read-scaling, connection-budget, point-in-time-recovery, and regional-recovery contract;
- a reviewed cell and database-placement contract with a five-school evidence record;
- a module lifecycle contract separating release, entitlement, activation, and authorization;
- a disposable Ash pressure-test with negative tenant and authorization tests;
- a repeatable Phase 0 verification command; and
- an architecture review record that either accepts Ash or names and approves a fallback.

Phase 0 does not build a school business module. It also does not build the production Phoenix umbrella, Next.js application, scheduler service, AI gateway, analytics plane, or full infrastructure baseline. Those belong to later phases after the decisions in this phase are accepted.

## 2. Current-state findings and boundary decision

Before this plan was added, the target directory existed but was not a Git repository and contained no project files. That makes it safe to establish conventions, but repository initialization and remote hosting still need an explicit implementation action.

Implementation checkpoint on 2026-09-13:

- P0.0 is implemented locally except for remote hosting and branch protection.
- P0.1 ADR governance and the initial Proposed record set are implemented.
- P0.5 scenarios 1-12 have direct Ash/PostgreSQL evidence, including generated migration and patch-upgrade review; trusted routing, module lifecycle, and the adoption scorecard remain incomplete.
- P0.6 local toolchain, Ruff, ShellCheck, documentation validation, Credo, dependency audit, Dialyzer, database migrations, and test entrypoints are implemented and passing.
- P0.3, P0.4, and P0.7 still require accountable human review and approved decisions before Phase 0 can close.

The roadmap separates two concerns:

1. Phase 0: ADRs, the Ash pressure-test, threat modelling, and measurable quality targets.
2. Phase 1: the complete multi-language workspace, pinned production toolchains, one-command platform startup, comprehensive CI, and the full template set.

This plan keeps that boundary. It creates only the lightweight repository structure needed to execute and review Phase 0. It does not disguise Phase 1 scaffolding as Phase 0 progress.

Ruff is included, but only for Python support scripts and tests. It cannot lint Elixir or TypeScript. Elixir code in the Ash spike will use `mix format`, Credo, Dialyzer, and tests. TypeScript tooling will be selected when the web workspace is created in Phase 1.

## 3. Governing constraints

- Phoenix, PostgreSQL, and the modular-monolith shape are the firm starting point.
- Ash remains provisional until the pressure-test passes.
- All mutations are named actions; generic CRUD is not the domain contract.
- Tenant context is mandatory and non-null at every tested boundary.
- Logical tenant controls remain mandatory across pooled databases, dedicated databases, and dedicated cells. Trusted authenticated context selects placement and missing or stale routing fails closed.
- Tenant placement is based on per-domain volume, burst, amplification, retention, reporting, integrations, recovery, residency, and isolation evidence. Student count alone is not a placement rule.
- Production roles are tenant-defined, hierarchical, nested, renameable, and composable data. Terms such as learner, guardian, and educator may describe principals or relationships, but must not become hard-coded role names.
- Release availability, entitlement, tenant activation, and actor authorization are independent server-side gates. Deactivation never drops shared tables or implicitly erases retained tenant data.
- Policies must protect reads and writes. UI hiding is never evidence of authorization.
- Domain state and durable post-commit facts use an atomic transaction and an outbox model.
- Sensitive or restricted data must not enter shared caches, broad search projections, logs, or AI tools by default.
- The Phase 0 spike uses synthetic data only.
- No production abstraction may depend on Ash until ADR 0002 is accepted.
- Deferred technology choices remain deferred unless a measured requirement justifies them.

## 4. Planned repository shape

The following is the intended Phase 0 tree. The production folders explicitly excluded below are deliberately left for later phases.

```text
dev-chim/
├── README.md
├── AGENTS.md
├── CONTRIBUTING.md
├── SECURITY.md
├── .editorconfig
├── .gitignore
├── mise.toml
├── Makefile
├── pyproject.toml
├── uv.lock
├── bin/
│   └── phase0-check
├── docs/
│   ├── README.md
│   ├── plans/
│   │   └── phase-0-implementation-plan.md
│   ├── architecture/
│   │   ├── README.md
│   │   ├── system-context.md
│   │   ├── service-boundaries.md
│   │   ├── tenant-placement-and-capacity.md
│   │   ├── module-activation-and-lifecycle.md
│   │   ├── quality-attribute-targets.md
│   │   └── deferred-choices.md
│   ├── adr/
│   │   ├── README.md
│   │   ├── 0000-template.md
│   │   ├── 0001-modular-monolith-and-service-boundaries.md
│   │   ├── 0002-ash-adoption-criteria-and-fallback.md
│   │   ├── 0003-tenant-model-and-optional-postgresql-rls.md
│   │   ├── 0005-domain-action-and-state-transition-convention.md
│   │   ├── 0007-transactional-outbox-and-event-envelope.md
│   │   ├── 0009-cache-taxonomy-invalidation-and-valkey-trigger.md
│   │   ├── 0010-file-ownership-storage-pipeline-and-external-drives.md
│   │   ├── 0012-report-templates-gotenberg-and-campaign-model.md
│   │   ├── 0014-primary-api-and-generated-typescript-client.md
│   │   ├── 0015-ai-gateway-tool-exposure-and-evaluation-policy.md
│   │   └── 0016-scheduling-service-contract-and-publication-boundary.md
│   ├── security/
│   │   ├── threat-model.md
│   │   ├── data-classification.md
│   │   └── abuse-cases.md
│   └── phase-0/
│       ├── README.md
│       ├── decision-register.md
│       ├── risk-register.md
│       ├── review-record.md
│       └── evidence/
│           ├── README.md
│           ├── ash-pressure-test.md
│           ├── threat-model-review.md
│           ├── tenant-placement-capacity.md
│           ├── module-lifecycle.md
│           └── quality-targets-approval.md
├── spikes/
│   └── ash-foundation-lab/
│       ├── README.md
│       ├── mix.exs
│       ├── mix.lock
│       ├── config/
│       ├── lib/
│       ├── priv/
│       └── test/
├── tools/
│   └── check_phase0.py
└── tests/
    └── tools/
        └── test_check_phase0.py
```

The ADR numbers intentionally preserve the architecture document's backlog numbering. Gaps are reserved records, not missing Phase 0 deliverables.

Do not create these production folders in Phase 0: `apps/`, `web/`, `services/scheduler/`, `services/ai-gateway/`, `analytics/`, or production `infra/`. A local PostgreSQL fixture for the disposable spike may live inside the spike folder.

## 5. Work packages

### P0.0 - Establish the Phase 0 decision workspace

Purpose: make Phase 0 work reviewable without prematurely creating the production platform.

Actions:

1. Confirm `/Users/francois/dev-chim` is the intended repository root.
2. Initialize Git with the agreed default branch and connect a remote only when its location is known.
3. Add `.gitignore` entries for Elixir build output, Python environments and caches, macOS files, coverage, editor state, local databases, secrets, and generated evidence.
4. Add `.editorconfig` for UTF-8, LF, final newlines, and language-appropriate indentation.
5. Add the documentation tree, indexes, contribution rules, security contact process, and repository-level `AGENTS.md`.
6. In `AGENTS.md`, record the architectural guardrails from section 3 and require contributors and Codex to read the ADR index before structural changes.
7. Add `docs/phase-0/README.md` with scope, deliverables, status, review owner, and exit gate.

Acceptance criteria:

- Every committed document is reachable from `README.md` or `docs/README.md`.
- The repository states clearly that no business module may be added in Phase 0.
- The repository does not imply that Ash has already been accepted.
- No secret, real school record, or production identifier is present.

### P0.1 - Create ADR governance and the decision register

Purpose: make decisions durable, reviewable, and replaceable without rewriting history.

Actions:

1. Create `docs/adr/0000-template.md` with these required fields:
   - title and number;
   - status: Proposed, Accepted, Conditionally Accepted, Rejected, Superseded, or Deferred;
   - date, accountable owner, and deciders;
   - context and decision drivers;
   - considered options;
   - decision and boundaries;
   - positive and negative consequences;
   - security, privacy, operability, and migration effects;
   - validation evidence;
   - fallback or exit cost;
   - review triggers; and
   - links to related ADRs, threats, tests, and evidence.
2. Create `docs/adr/README.md` as the authoritative index. It must show each ADR's status, owner, last review date, evidence, and superseding record.
3. Create `docs/phase-0/decision-register.md` to map every Phase 0 decision to its ADR, evidence, unresolved questions, and exit-gate state.
4. Add a documentation check that fails for duplicate ADR numbers, missing required headings, broken relative links, or an index/status mismatch.
5. Never edit an Accepted ADR to change its decision. Create a superseding ADR and link both records.

Acceptance criteria:

- The template supports a complete decision, not only a narrative preference.
- The index and ADR front matter agree.
- A new proposed ADR can be added and validated using documented commands.
- Accepted records are immutable except for clearly labelled metadata or link corrections.

### P0.2 - Draft and decide the Phase 0 ADR set

Purpose: resolve the choices that later framework APIs would make expensive to reverse.

All records begin as Proposed. Only the architecture review may mark them Accepted. Evidence-dependent decisions must link to the relevant spike or threat-model result.

| ADR | Decision required in Phase 0 | Required evidence or boundary |
| --- | --- | --- |
| 0001 | Modular monolith, permitted service boundaries, and module lifecycle | Context map; independent release/entitlement/activation/authorization gates; dependencies; drain; retained-data and reactivation tests |
| 0002 | Ash adoption criteria and fallback | Pressure-test scorecard; upgrade review; fallback shape using Phoenix/Ecto with explicit domain contracts |
| 0003 | Tenant model, placement profiles, trusted routing, and optional PostgreSQL RLS | Per-domain capacity model; routing and cross-placement tests; movement, backup, restore, connection-pool and job-context analysis; application-policy and RLS trade-off |
| 0005 | Domain action and state-transition convention | One named transition; invariant, policy, concurrency, error, and transaction evidence |
| 0007 | Transactional outbox and event envelope | Atomic write design; envelope versioning; minimal payload and replay/idempotency rules |
| 0009 | Cache taxonomy, invalidation, and Valkey trigger | Classification rules; tenant-aware key standard; explicit measured trigger for shared L2 cache |
| 0010 | File ownership, storage pipeline, and external drives | Metadata/binary ownership; quarantine and signed-access boundaries; external-drive ownership modes |
| 0012 | Report templates, Gotenberg, and campaign model | Renderer isolation; versioned templates; bounded asynchronous campaign and manifest model |
| 0014 | Primary API and generated TypeScript client | Generated API spike; error, pagination, versioning, idempotency, and policy-preservation review |
| 0015 | AI gateway tool exposure and evaluation policy | No implicit database authority; actor/tenant propagation; read allowlist and confirmed-write boundary |
| 0016 | Scheduling service contract and publication boundary | Versioned input/output ownership; cancellation, reproducibility, and core-only publication rule |
| 0017 | PostgreSQL availability, recovery, and consistency-aware read routing | Writer/HA/read/recovery separation; consistency classes; burst batching; connection budget; lag, failover, and restore evidence |

Required decision discipline:

- ADR 0002 cannot be accepted before the pressure-test evidence is complete.
- ADR 0001 must keep module activation separate from entitlement and authorization, and must define safe deactivation without implicit data deletion.
- ADR 0003 must not hard-code school job titles as platform roles, infer placement from student count, or trust request-selected routing.
- ADR 0009 should accept an L1 abstraction and measurable Valkey trigger, not deploy Valkey speculatively.
- ADR 0014 should test the preferred generated REST or JSON:API path first. GraphQL remains deferred unless a concrete use case fails without it.
- ADRs 0010, 0012, 0015, and 0016 define contracts and boundaries only; their production services are not Phase 0 deliverables.
- ADR 0017 defines a production-topology hypothesis and evidence gates only; Phase 0 does not provision production database infrastructure or assume a read replica is required.

Acceptance criteria:

- Every row has an accountable owner, explicit decision, evidence link, consequences, and review trigger.
- A Deferred choice names the unmet requirement, evidence threshold, owner, and revisit condition.
- No record is accepted merely because the source architecture preferred it.
- The decision register has no unexplained Phase 0 gaps.

### P0.3 - Produce the security and privacy threat model

Purpose: test architecture decisions against child-data, tenant-isolation, support, file, export, cache, realtime, and AI risks.

Actions:

1. Define assets and classifications for public content, internal operational data, confidential personal data, restricted child and safeguarding data, credentials, audit evidence, and generated artifacts.
2. Identify actors: tenant users, tenant administrators, platform support, service actors, integrations, AI clients/providers, and hostile or compromised actors.
3. Draw data flows and trust boundaries for:
   - browser and Next.js edge to Phoenix/Ash;
   - Phoenix/Ash to PostgreSQL and Oban;
   - object storage, scanners, extractors, and renderers;
   - realtime subscriptions;
   - caches and read/search projections;
   - exports and external-drive connectors;
   - the scheduling boundary;
   - the AI gateway, providers, and tools; and
   - support and break-glass access.
   - the trusted tenant-placement registry and every routed database, queue, storage, cache, search, analytics, and telemetry namespace; and
   - module release, entitlement, activation, dependency, deactivation, and retained-data paths.
4. Record threats and abuse cases, including:
   - cross-tenant read, mutation, inference, and subscription leaks;
   - confused-deputy and missing-tenant context failures;
   - privilege escalation through tenant-defined role nesting;
   - support impersonation or unbounded break-glass use;
   - malicious uploads, parser exploits, unsafe derivatives, and decompression bombs;
   - export exfiltration and expired-link reuse;
   - cache-key collisions, stale authorization, and restricted shared-cache content;
   - search result leakage before policy filtering;
   - prompt injection, over-broad tools, provider retention, and unverified AI writes; and
   - audit tampering or sensitive logging.
   - cross-placement routing, stale routing versions, unsafe movement, credential fan-out, and default-database fallback;
   - synchronized write bursts and pooled-tenant resource starvation; and
   - stale or misrouted replica reads affecting authorization, placement, module gates, or immediate read-after-write confirmation;
   - connection fan-out across application nodes, Ecto repositories, Oban, and database placements;
   - failover, backup, restore, and regional recovery being treated as interchangeable; and
   - activation-as-authorization, entitlement bypass, unsafe deactivation, abandoned work, and retained data without an owner.
5. Map each high or critical threat to a preventive control, detection, negative test, owner, residual risk, and ADR.
6. Record out-of-scope threats and assumptions explicitly.
7. Review the model with architecture, security/privacy, and operations representatives.

Acceptance criteria:

- All required Phase 0 trust boundaries are shown and described.
- Every high or critical threat has an owner and testable treatment.
- Tenant isolation covers HTTP, generated APIs, jobs, events, caches, files, search, realtime, exports, telemetry, and AI tools.
- Tenant isolation covers pooled and dedicated placements, movement, routing-version conflict, and separate operational identities.
- The role model remains tenant-defined and relationship-aware.
- Module availability, entitlement, activation, and actor authorization remain independent at every applicable boundary.
- Residual risk is accepted by an accountable person, not silently marked resolved.

### P0.4 - Approve measurable quality-attribute targets

Purpose: replace words such as "fast", "large", and "available" with testable targets.

Create `docs/architecture/quality-attribute-targets.md` with one row per target and these columns:

- capability and user journey;
- SLI and unit;
- numeric target and percentile where relevant;
- load and data shape;
- target device, network, and environment;
- exclusions and dependency time treatment;
- measurement tool and evidence location;
- accountable owner; and
- review date.

The following targets are mandatory before Phase 0 exits:

| Area | Decision to obtain | Evidence expected later |
| --- | --- | --- |
| Interactive latency | API read/mutation and user-visible targets, including percentile and target network/device | Repeatable benchmark definition |
| Scale | Expected launch and planning-horizon tenants, users per tenant, active sessions, concurrency, and per-domain retained footprint | Capacity profile and synthetic dataset shape |
| Peak domain writes | Committed facts/second, batch latency/error, synchronized window, retries, corrections, permission revocation, write amplification, and zero unauthorized partial commits | Repeatable mixed-load burst benchmark |
| Tenant placement | Pool wait/saturation, noisy-neighbour effect, routing conflict, movement interruption, reconciliation, backup, and restore by candidate profile | Pooled and dedicated synthetic placement scenarios |
| Database connections | Writer/reader/job pools, checkout wait, rejection, application-node and placement fan-out, administration/replication reserve, and pooler trigger | Per-placement connection budget and exhaustion scenario |
| Read consistency | Primary-required, read-your-write, bounded-staleness, and analytical classes; maximum replica lag; stale authorization and fallback behaviour | Replica-lag/outage and read-after-write scenarios |
| Reports | Maximum campaign count, page complexity, completion deadline, retry budget, and concurrency | Gotenberg benchmark scenario |
| Files | Maximum upload size, allowed types, derivative limits, scan deadline, and retention assumptions | Malicious-file and large-file test profiles |
| Database HA | Commit durability, writer failover RPO/RTO, reconnect time, idempotent retry, and outbox continuity | Failover-during-burst protocol |
| Recovery | PostgreSQL point-in-time and object-storage RPO/RTO, restore verification interval, reconciliation, and legal-hold constraints | Restore-drill protocol |
| Availability | Service-level objective, maintenance assumptions, and dependency degradation rules | SLO/error-budget definition |

Do not invent final business numbers in code. Provisional spike values must be labelled hypotheses. Attendance row-count arithmetic is a workload input, not a benchmark or placement decision. Phase 0 cannot close while a mandatory row is blank or `TBD`.

Acceptance criteria:

- Every mandatory target is numeric, measurable, owned, and dated.
- Each performance target states the load shape and environment, not just a percentile.
- Placement evidence covers peak distribution, write and storage amplification, connection pools, mixed reports, retention, movement, backup, restore, and accepted isolation requirements.
- Recovery covers the database and object storage together.
- Availability evidence distinguishes an HA standby, read replica, recoverable backup, and cross-region disaster-recovery replica.
- A read replica or pooler remains unapproved until its measured trigger and consistency or compatibility gate passes.
- The Ash pressure-test uses only targets relevant to its slice; later capacity tests retain their roadmap phase.

### P0.5 - Build the disposable Ash Foundation Lab pressure-test

Purpose: determine whether Ash is a sound centre for the platform before production contracts depend on it.

The spike must remain isolated under `spikes/ash-foundation-lab/`. It may inform production code, but it must not be moved into a production application wholesale.

#### Minimal model

Use neutral synthetic concepts rather than a disguised school module:

- `Tenant` - two synthetic tenants;
- `Actor` - synthetic human and service actors;
- tenant-defined `Role`, hierarchical role composition, `Capability`, and assignments;
- `FoundationRecord` - a tenant-owned, classified record with a lock/version field and a small controlled state machine; and
- `OutboxEvent` - a minimal durable fact written with the state change if needed to prove the transaction boundary.

Use a named action such as `submit_for_review` or `approve_record`. Do not expose a generic update as the tested contract.

#### Scenarios to implement

1. An authorized actor in tenant A reads and performs the named transition.
2. An actor in tenant A without the required capability is denied.
3. An authorized actor in tenant B cannot read, infer, mutate, or subscribe to tenant A data.
4. An actor with a composed, renamed tenant role receives the same capability without code changes.
5. A missing tenant context fails closed.
6. Invalid and stale state transitions fail with stable validation or conflict errors.
7. The state change, audit reference, and outbox fact commit atomically; an injected failure rolls all of them back.
8. Database constraints reject a deliberately unsafe alternate write.
9. The preferred generated REST or JSON:API adapter exposes the named action without weakening policy.
10. Telemetry carries correlation and safe tenant identifiers without record contents or restricted data.
11. A generated migration is inspected for tenant keys, compound uniqueness, foreign keys, constraints, indexes, reversibility, and expand-and-contract compatibility.
12. A time-boxed dependency upgrade exercise records changed code, migration output, warnings, and test results.
13. A neutral trusted-routing slice selects pooled and dedicated test databases from authenticated tenant context, ignores request-selected placement, propagates through spawned tasks and jobs, and fails closed on missing or stale routing.
14. A neutral synthetic module proves that release availability, entitlement, activation, and actor authorization are independent, and that concurrent deactivation drains safely without losing required audit or outbox work.

#### Ash evaluation scorecard

Each category is Mandatory Pass, Pass with bounded remediation, or Fail:

- action, field, filter, and relationship policy expressiveness;
- non-optional tenant scoping and failure behaviour;
- trusted placement routing across request, task, transaction, and job boundaries;
- tenant-defined hierarchical capability resolution;
- independent module entitlement, activation, and authorization gates;
- explicit state transitions, invariants, optimistic concurrency, and errors;
- transaction and rollback ergonomics;
- migration readability and operational safety;
- generated API contract quality and policy preservation;
- telemetry, redaction, and correlation support;
- test ergonomics, compile feedback, and maintainability;
- upgrade effort and dependency health; and
- ability to keep public domain contracts explicit rather than leaking framework internals everywhere.

Decision rule:

- Accept Ash only if every mandatory security, tenancy, transaction, migration, and generated-interface criterion passes.
- Conditionally accept only when every critical property passes and each remaining issue has a bounded remedy, owner, and deadline before Phase 2.
- Replace Ash when any critical property fails or requires pervasive escape hatches. The initial fallback candidate is Phoenix/Ecto with explicit domain actions and thin interface adapters; ADR 0002 must document the selected fallback before Phase 1 designs production boundaries.

Acceptance criteria:

- Tests include positive and negative cases; a happy-path demo alone is insufficient.
- The test suite proves tenant isolation and atomic rollback.
- The generated interface cannot bypass the named action or policy.
- The upgrade report records actual evidence rather than general impressions.
- `docs/phase-0/evidence/ash-pressure-test.md` links each score to code, test, command, and result.

### P0.6 - Add proportionate tooling, Ruff, and automated checks

Purpose: keep the Phase 0 evidence reproducible and make documentation drift visible.

#### Toolchain policy

- Use `mise.toml` to pin the Phase 0 runtime tools after compatibility is verified. Do not use floating `latest` versions.
- Pin Erlang/OTP, Elixir, PostgreSQL tooling or container image, Python, and `uv` only as needed for the spike and support checks.
- Defer Node/pnpm and Java toolchains until a Phase 0 decision or Phase 1 workspace actually needs them.
- Commit lock files for the Ash spike and Python tooling.

#### Ruff policy

Create a root `pyproject.toml` and `uv.lock` for repository support tooling. Configure Ruff to:

- lint and format `tools/` and `tests/tools/`;
- derive its target Python version from the pinned runtime;
- enforce core correctness, import sorting, modern syntax, common bug patterns, and Ruff-specific rules;
- exclude Elixir build artifacts, vendored dependencies, generated files, and temporary evidence;
- format locally and check without mutation in automation; and
- remain a support-tool check, not a false claim of whole-repository coverage.

The intended commands are:

```sh
mise exec -- uv sync --group dev --locked
mise exec -- uv run ruff format --check tools tests/tools
mise exec -- uv run ruff check tools tests/tools
```

The exact pinned versions are resolved during implementation against the selected runtimes and committed lock files.

#### Elixir spike policy

The Ash spike must expose stable aliases or wrapper commands for:

```sh
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

Include dependency and security audit checks supported by the selected package set, but do not claim they replace threat modelling or review.

#### Repository verification entrypoint

`bin/phase0-check` is the single reviewer entrypoint. It should:

1. run Ruff formatting and lint checks;
2. run support-tool tests;
3. validate ADR numbering, required sections, status/index consistency, and internal links;
4. fail if mandatory quality-target fields are blank or `TBD` at exit-review mode;
5. verify that every high or critical threat has an owner, treatment, and test reference;
6. run the Ash spike format, static analysis, migrations, and tests against a disposable PostgreSQL database;
7. check for accidental business-module or prohibited production-service folders; and
8. report each gate in written form as well as by exit status.

Expose the wrapper through these stable commands:

```sh
make bootstrap
make format
make lint
make test
make docs-check
make check
```

The core script must be CI-provider-neutral. Add a GitHub, GitLab, or other CI adapter only after the hosting choice is known.

Acceptance criteria:

- A clean local run uses only pinned dependencies and lock files.
- Local and CI commands call the same underlying checks.
- Automation never rewrites files in check mode.
- Failures identify the document, ADR, threat, target, or test that needs attention.
- Ruff passes for Python support code and Elixir-specific checks pass for the spike.

### P0.7 - Run the architecture review and close Phase 0

Purpose: make the decision explicit and preserve its evidence for Phase 1.

Actions:

1. Freeze the Phase 0 evidence set for review.
2. Run `make check` from a clean checkout with a disposable database.
3. Review the ADR set, threat model, unresolved risks, quality targets, and Ash scorecard.
4. Review the five-school workload assumptions, placement candidates, routing/movement evidence, and recovery results.
5. Review PostgreSQL consistency classes, connection budgets, synchronized-burst results, failover/reconnection, replica-lag behaviour, point-in-time restore, and the read-replica/pooler decisions.
6. Review the module lifecycle, dependency, drain, retained-data, and reactivation evidence.
7. Record attendees, accountable approvers, date, decisions, conditions, exceptions, and expiry dates in `docs/phase-0/review-record.md`.
8. Mark ADRs Accepted, Deferred with a measurable trigger, Rejected, or Superseded. Do not leave required records Proposed.
9. If Ash is rejected, approve its replacement and update every dependent proposed record before beginning Phase 1.
10. Create the Phase 1 input list from accepted decisions without starting the production workspace in the same change.

Acceptance criteria:

- The review record names the decision outcome and accountable approvers.
- Ash is Accepted, Conditionally Accepted with bounded prerequisites, or replaced; there is no ambiguous "continue evaluating" outcome.
- Every required quality target is approved and numeric.
- The five-school placement decision is based on approved workload, recovery, residency, cost, and isolation evidence rather than student count.
- PostgreSQL HA, recovery, read routing, connection, backpressure, and degradation targets are approved without confusing a read replica with write scaling or backup.
- Module activation, entitlement, authorization, deactivation, retained-data, and reactivation semantics are approved.
- Every high or critical threat has an accepted treatment or explicit residual-risk acceptance.
- All required ADRs have an exit status and evidence.
- The full Phase 0 verification command passes from a clean checkout.
- No school business module or production framework abstraction has been introduced.

## 6. Delivery sequence and dependency graph

Implement Phase 0 as small, reviewable slices:

| Slice | Contents | Depends on | Review focus |
| --- | --- | --- | --- |
| 0A | Repository initialization, indexes, guardrails, minimal toolchain shell | Root confirmation | Scope and navigability |
| 0B | ADR template, index, decision register, initial Proposed records | 0A | Decision quality, tenant placement, and module lifecycle completeness |
| 0C | Threat model, classifications, abuse cases | 0A; drafts of 0001/0003/0010/0015 | Trust boundaries, routed placement, module lifecycle, and child-data risk |
| 0D | Quality-attribute and per-domain capacity workshop; five-school placement plus PostgreSQL availability/read-routing decisions | 0A; drafts 0003/0017 | Ownership, burst shape, batching, connections, consistency, failover, retained footprint, recovery, and measurability |
| 0E | Ash, trusted-routing, and neutral module-lifecycle pressure-tests and evidence | Drafts of 0001/0002/0003/0005/0014; target test shape | Negative tests, routing safety, independent gates, and framework fitness |
| 0F | Ruff, Elixir checks, documentation validator, provider-neutral gate | 0A; evolves with 0B-0E | Reproducibility and useful failure output |
| 0G | ADR finalization and architecture review | 0B-0F | Accept, conditionally accept, or replace |

Slices 0C, 0D, and the non-Ash portion of 0F can proceed in parallel after 0A. Slice 0E must use agreed draft criteria rather than inventing them after the results are known. Slice 0G is the only completion point.

## 7. Verification matrix

| Requirement | Primary proof | Failure that must be caught |
| --- | --- | --- |
| ADR completeness | Documentation validator and human review | Missing option, consequence, owner, evidence, or fallback |
| Tenant isolation | Cross-tenant Ash tests | Unscoped read/write or data inference |
| Tenant placement | Pooled/dedicated routing, task/job propagation, movement, backup, and restore tests | Request-selected, stale, missing, or conflicting route; wrong placement; irreconcilable move |
| Tenant-defined roles | Rename/composition test | Hard-coded job-title or school-wide role branch |
| Module lifecycle | Independent gate matrix, dependency, concurrent drain, retained-data, and reactivation tests | Activation grants permission; deactivation loses data/work or leaves access open |
| Named actions | API and domain tests | Generic update bypasses transition or policy |
| Atomicity | Injected failure test | State commits without audit/outbox fact or vice versa |
| Migration safety | Generated migration review and apply/rollback test | Missing tenant constraint, unsafe data rewrite, or unreadable migration |
| API policy preservation | Generated-interface negative tests | Direct endpoint bypasses action policy |
| Telemetry safety | Captured telemetry assertions | Restricted content or secret logged |
| Threat traceability | Threat-control-test matrix | High/critical threat lacks owner or verification |
| Quality targets | Schema check and approval record | Blank, subjective, unowned, or environment-free target |
| Peak capacity | Synchronized mixed-load benchmark | Annual average hides burst, amplification, pool starvation, or report overlap |
| Database consistency | Replica-lag/outage and read-after-write tests | Stale authorization, placement/module state, or contradictory confirmation is served |
| Database availability | Failover-during-burst and application-reconnection drill | Committed work is lost beyond RPO, retry duplicates state, placement opens, or outbox continuity breaks |
| Database recovery | Isolated point-in-time restore and integrity/reconciliation drill | HA is mistaken for backup or the retained data cannot meet RPO/RTO |
| Connection control | Per-placement budget and exhaustion test | App/reader/Oban pools exceed capacity or overload reaches the writer unbounded |
| Python support quality | Ruff and support-tool tests | Syntax, import, bug-pattern, or formatter drift |
| Elixir spike quality | Formatter, Credo, Dialyzer, tests | Static or runtime defect hidden by happy-path demo |
| Phase boundary | Repository-structure check and review | Business module or production service scaffold appears early |

## 8. Risks and controls

| Risk | Control | Gate |
| --- | --- | --- |
| Phase 0 expands into the entire foundation | Enforce the planned tree and explicit out-of-scope folders | Phase-boundary check |
| ADRs merely restate the source document | Require options, consequences, evidence, fallback, owner, and review trigger | Architecture review |
| Ash passes only a happy-path demonstration | Pre-register the scorecard and require negative tenant, policy, rollback, migration, API, and upgrade tests | ADR 0002 |
| The spike becomes accidental production code | Keep it under `spikes/`, document disposability, and prohibit direct promotion | Phase 1 review |
| Tenant roles become hard-coded | Model roles/capabilities as tenant data and test rename/composition | ADR 0003 and spike tests |
| Student count becomes a database-placement shortcut | Require per-domain burst, retained-footprint, mixed-load, recovery, and isolation evidence | ADR 0003 and capacity approval |
| A read replica is treated as write scaling, current authorization, or backup | Require explicit consistency classes and separate HA, read-scaling, PITR, and DR evidence | ADR 0017 and threat-model review |
| Application autoscaling multiplies connections without a database budget | Calculate all Ecto/Oban/placement pools and reserve; load-test backpressure before adding a pooler | ADR 0017 and capacity approval |
| Trusted placement routing becomes a confused deputy | Resolve authenticated tenant centrally, constrain placement membership, fail closed, and rehearse movement | Threat-model and routing tests |
| Module activation becomes authorization or unsafe deletion | Enforce independent gates and controlled drain with retained-data ownership | ADR 0001 and lifecycle tests |
| Ruff creates false confidence | Scope Ruff explicitly; require language-specific and documentation checks | `phase0-check` output |
| Quality numbers are guessed by engineers | Require named business/operations owners and label temporary spike values as hypotheses | Target approval |
| Threats remain prose without proof | Link high/critical threats to negative tests and evidence | Threat-model review |
| Tool versions drift | Pin runtimes and commit lock files after compatibility verification | Clean-checkout run |
| Conditional choices quietly become permanent | Give every deferral an evidence threshold, owner, and review date | Decision register |

## 9. Phase 0 exit checklist

- [ ] Repository root and hosting approach are confirmed.
- [ ] Documentation and ADR indexes are complete and navigable.
- [ ] All Phase 0 ADRs have accountable owners, evidence, and exit statuses.
- [ ] Ash pressure-test scenarios and scorecard are complete.
- [ ] Ash is accepted, conditionally accepted with bounded prerequisites, or replaced.
- [ ] Threat boundaries, classifications, abuse cases, mitigations, and residual risks are reviewed.
- [ ] Interactive latency, scale, report, file, recovery, and availability targets are numeric and approved.
- [ ] Peak domain-write, retained-footprint, tenant-placement, and movement targets are numeric and approved.
- [ ] PostgreSQL connection, consistency, failover, restore, replica-lag, backpressure, and asynchronous-continuity targets are numeric and approved.
- [ ] Read-replica, pooler, partitioning, dedicated-placement, and cross-region-DR decisions record measured triggers rather than assumptions.
- [ ] The five-school database/cell decision has workload, recovery, residency, cost, isolation, and rollback evidence.
- [ ] Module release, entitlement, activation, authorization, dependency, drain, retained-data, and reactivation semantics are approved.
- [ ] `make check` passes from a clean checkout and disposable database.
- [ ] Ruff passes for repository Python tooling.
- [ ] Elixir formatter, Credo, Dialyzer, migrations, and tests pass for the spike.
- [ ] No production data, business module, or premature production service scaffold exists.
- [ ] The architecture review record is approved and the Phase 1 input list is prepared.

## 10. Definition of ready for Phase 1

Phase 1 may start only when the Phase 0 exit checklist is complete. Its first implementation plan must consume the accepted ADRs and quality targets. It may then create the production Elixir modular core, Next.js workspace, shared contracts, infrastructure folders, complete CI baseline, developer bootstrap, and the broader template set described by the roadmap.

If Phase 0 rejects Ash, Phase 1 must use the approved replacement from ADR 0002. It must not run a second open-ended framework selection exercise or preserve an unapproved Ash path in parallel.
