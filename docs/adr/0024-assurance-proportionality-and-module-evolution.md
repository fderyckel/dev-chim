# ADR 0024: Assurance proportionality and module evolution

- Status: Proposed
- Date: 2026-09-25
- Accountable owner: Architecture review group
- Deciders: Project owner, platform engineering, security architecture, operations, and product engineering
- Supersedes: None

## Context

Chimwemwe needs to remain practical while it evolves school workflows. Treating every
module vocabulary, screen, workflow, or ordinary operational rule as an infrastructure
decision would make useful learning and iteration unnecessarily slow. Conversely,
treating infrastructure and security controls as equally changeable would weaken tenant
isolation, privacy, availability, recovery, and confidence in the authoritative record.

The platform therefore needs an explicit line between adaptable module behaviour and
strict assurance boundaries. "Agile" must not become a way to bypass a control that
exists to prevent unauthorized access, data loss, cross-tenant exposure, or unsafe
operation.

## Decision drivers

- Fast, evidence-led learning in school modules and human workflows.
- Non-negotiable protection of child data, credentials, tenant boundaries, and
  authoritative records.
- Clear ownership of freshness, availability, correction, and recovery trade-offs.
- A decision rule that interfaces, integrations, and later modules can apply consistently.

## Considered options

1. Apply the same strict architecture-review process to every module and interface change.
2. Allow each module or integration to choose its own security, consistency, and recovery
   approach for speed.
3. Keep trust, infrastructure, and irreversible-data controls strict, while allowing bounded
   module behaviour and experience design to evolve behind those controls.

## Decision

Adopt option 3: **strict foundations, adaptable modules**.

### Strict foundations

The following are platform or infrastructure assurance boundaries. They require explicit
ownership, threat and failure analysis, negative tests, operational evidence, and an ADR
when they establish or change a stable boundary:

- authentication, device or service identity, credentials, key management, and revocation;
- tenant context, placement routing, authorization, module gates, and data classification;
- encryption, secrets handling, privacy controls, audit integrity, and access logging;
- authoritative-write, idempotency, transactional outbox, backup, recovery, retention, and
  migration safety contracts;
- capacity limits, overload behaviour, availability, failover, and operational isolation; and
- new external trust boundaries, including physical devices, integrations, queues, or data
  processors.

These controls fail closed when their required trusted context or security condition is
missing. A module, client, report, cache, replica, or device never receives authority to
weaken them.

### Adaptable module behaviour

Within those foundations, modules may evolve through small, reviewable vertical slices.
They may test and refine terminology, user journeys, workflow states, ordinary business
rules, summary projections, and declared consistency or offline experience. The owning
school-domain and product owners decide these trade-offs with an explicit user outcome,
reversibility plan, and measurable acceptance criteria.

Agility remains bounded: a module uses named actions, tenant-qualified data, applicable
authorization, classification, audit, migration, correction, and recovery contracts. A
feature flag, local cache, projection, client queue, or device cannot become an alternate
authority.

### Deciding which side applies

A decision belongs to the strict foundation when it crosses a trust boundary, changes who
or what may act, changes the confidentiality or integrity of data, affects durability or
recovery, or could cause an unauthorized, unsafe, cross-tenant, or irreversible outcome.
Otherwise, it can be explored as adaptable module behaviour, provided it remains inside
the established controls and is reversible.

For a smart gate, the school's ordinary enrolment freshness policy may allow a declared
short-lived replicated or device-local eligibility snapshot. Device identity, credential
handling, tenant binding, emergency restrictions, revocation distribution, local event
protection, and reconciliation remain strict foundation concerns. The gate must expose the
chosen freshness and degradation outcome rather than silently treating stale or missing
state as authoritative.

## Consequences

### Positive

- Product teams can improve everyday school workflows without reopening infrastructure
  decisions unnecessarily.
- Security and reliability controls receive the evidence and operational ownership their
  impact requires.
- Freshness and offline choices become visible product and domain decisions rather than
  accidental technical behaviour.

### Negative

- Teams must classify a proposed change before implementing it.
- Some apparently small integration or caching requests require an ADR and stronger
  evidence because they cross a trust boundary.
- A module may not use speed of delivery as a reason to defer a required security or
  recovery control.

## Security, privacy, operability, and migration effects

Tenant context, authorization, placement, credentials, classification, and current
security-sensitive state remain server-controlled and fail closed. Only read paths whose
owner explicitly accepts a bounded staleness interval may use a replica or local snapshot;
they cannot authorize an otherwise denied action. Every external device or offline flow
requires a documented identity, replay, clock, revocation, data-minimization, encryption,
loss/recovery, and reconciliation contract before real restricted data is used.

Module evolution uses expand-and-contract migration discipline where stored data changes.
It preserves named-action, idempotency, audit, outbox, correction, and recovery semantics;
these are not optional because a module is in an exploratory stage.

## Validation evidence

Before acceptance, the architecture review must confirm that:

1. the classification rule is applied to one representative low-risk module refinement and
   one new external trust boundary;
2. the owning domain and product stakeholders approve the stated freshness and degradation
   behaviour where it affects users;
3. strict-boundary changes link their threat model, operational owner, failure handling, and
   negative tests; and
4. a proposed smart-gate or comparable device integration demonstrates the distinction in
   its device identity, revoked-credential, offline, replay, and reconciliation evidence.

## Fallback and exit cost

If the distinction proves too broad, retain the strict-foundation list and narrow only the
module behaviours that can evolve without introducing a new trust boundary. If a module
cannot meet a declared freshness or offline promise safely, route that capability back to
the authoritative online path rather than weakening the foundation.

Changing a strict control after production adoption requires a superseding ADR, compatible
rollout, and recovery plan. Module-level changes remain reversible through versioned named
actions, feature/module gates, compatible migrations, and projection rebuilds where
applicable.

## Review triggers

- A new external device, offline capability, cache, replica, or integration is proposed.
- A module asks to relax authorization, tenant, audit, privacy, durability, or recovery
  controls.
- A freshness or degradation policy produces a material safeguarding, access, or data-loss
  incident.
- Repeated module work is being escalated to architecture review without a trust-boundary
  change, or repeated exceptions are weakening a foundation control.

## Related records

- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0007](0007-transactional-outbox-and-event-envelope.md)
- [ADR 0017](0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md)
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [PostgreSQL availability, recovery, and read routing](../architecture/postgresql-availability-recovery-and-read-routing.md)
- [Threat model](../security/threat-model.md)
