# Phase 2: entry closure and separated corporate/legal and educational structure

- Status: Phase 2.0 conditionally approved and closed at L1; Slices 2.0-B, 2.0-C, internal D.2a
  through D.2c, the bounded D.3 public-session adapter, and the minimal Slice 2.1-B legal-entity
  aggregate have synthetic evidence; 2.0-E is a dated deferred condition and L2 remains gated
- Owner: Product and platform engineering, with learning-institution domain and security/privacy
  review
- Start basis: explicit project-owner direction on 2026-09-26
- Review trigger: entry into another Phase 2 slice or a change to an entry-gate disposition

## Current boundary

Phase 2 has started at release level L0. Slice 2.0-B closes the provider-neutral local
operational-outbox and module-drain foundation contract. Slice 2.0-C completes the neutral temporal
engineering for TR-01 through TR-07, including retention, legal hold, erasure receipt, import
provenance, migration, restore, and projection convergence. ADR 0018 is Accepted after its
2026-09-27 accountable post-evidence review approved all six recorded residual risks as bounded
downstream conditions. ADR 0029 is Accepted after the same-day accountable correction superseded
ADR 0027's provider selection and fixed provider-neutral identity connection, application-session,
and non-impersonating support boundaries. Microsoft Entra ID, hybrid/on-premises Active Directory,
Google Workspace, generic OIDC, and qualified SAML gateway paths are supported candidates, not
prequalified providers. Slices 2.0-D.2a through D.2c now complete the internal synthetic
connection/link/invitation, opaque-session/tenant-selection, and bounded support-grant foundations.
Accepted [ADR 0030](../adr/0030-same-origin-public-session-and-named-action-boundary.md) now fixes
the same-origin public boundary. D.3 adds a disabled-by-default Phoenix callback/session surface,
secure encrypted cookie, current writer revalidation, origin/CSRF controls, visible support-state
contract, checked OpenAPI, and generated TypeScript declarations. It adds no enabled provider,
deployed endpoint, real-data authority, or L2 release claim.
The entry register continues to record which other gates block each release level.

No institutional resource, module declaration, migration, capability, public route, production
session, support grant, dispatcher, consumer, deployment configuration, or real data is added by
Slice 2.0-A. The production core and local browser boundaries remain those documented by the
completed bounded Phase 1 implementation. Phase 1 closure does not change any L1-L4 gate in this
document.

The project owner's 2026-09-26 direction accepts the
[Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md) for the Phase 2.0
and Phase 2.1 implementation sequence. No additional project-owner authorization is pending for a
listed slice; each slice becomes eligible only when its stated entry conditions are satisfied. The
same-day product clarification and
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
replace the former flat-school Phase 2.1 candidate with separate linked corporate/legal and
educational-structure modules.

On 2026-09-27, Slice 2.1-A produced the original educational scenario/vocabulary walkthrough,
TM-17/AC-18 control matrix, compare-only migration fixtures, temporal disposition, and a local
read-only synthetic hierarchy/move-preview prototype. The Product Owner then approved the refined
separation of legal entities, corporate units, educational institutions, and educational units,
with corporate/legal structure first. The linked technical scenario, control, and migration
addenda are prepared. François then conditionally accepted ADR 0025 for the logical direction and
minimal synthetic Slice 2.1-B entry. The prototype refresh and focused G5 checks now pass; named
specialist/representative reviews remain open under C25-02 through C25-06 and are not reported as
completed. The separately recorded C25-01 entry disposition now permits and closes the minimal
synthetic Slice 2.1-B `LegalEntity` proof: stable identity, immutable name-profile history, two
named actions, one exact read, lifecycle/capability gates, concurrency, replay, audit, outbox, and
rollback. This small Phase 2.1 dependency was implemented only to apply the Phase 2.0 foundation
to a business aggregate. No 2.1-C or educational persistence has started.

On 2026-09-28, the Project Owner conditionally approved Phase 2.0 at the completed L1 foundation
boundary. Slice 2.0-E is carried as a dated deferred condition: C25-05's expert/representative
comprehension and accountable product-experience disposition is due by 2026-12-15 or before the
first connected/public institutional-structure workflow, whichever is earlier. The deferral closes
Phase 2.0 for planning but does not authorize that workflow or an L2 release. A missed review date
requires explicit renewal, amendment, or withdrawal; it never becomes automatic approval.
Selected deployment, real data, pilot, and production release remain later gates.

## Release-level status

| Level | Current status | Permitted now | Principal blockers |
| --- | --- | --- | --- |
| L0 — paper and prototype | Closed for current entry scope | Slices 2.0-D.2a through D.2c and bounded D.3 engineering are complete; ADR 0025's technical evidence, refreshed prototype, and conditional G6 decision are recorded | Named reviews remain conditions on their first affected later slices, not claims of completed evidence |
| L1 — synthetic module proof | Closed for the minimal candidate | Slice 2.0-B outbox/drain, Accepted ADR 0018 temporal evidence, internal Slice 2.0-D foundations, and the Slice 2.1-B `LegalEntity` proof pass | C25-02 blocks 2.1-C; this closure does not authorize educational persistence |
| L2 — connected synthetic workflow | Conditionally deferred; not released | ADRs 0029/0030, D.2a–D.2c, bounded D.3 adapter evidence, and the minimal business aggregate are complete; UI-0/UI-1A remain qualification-only | C25-05 expert/representative comprehension and product-experience disposition by 2026-12-15 or the first affected gate, the first complete accessible 2.0-E browser workflow, and deployment-specific D.3 qualification |
| L3 — controlled real-data pilot | Blocked | No real institutional or Restricted data | Selected-deployment qualification, independent security/privacy review, learning-institution records ownership, and all lower-level gates |
| L4 — production release | Blocked | No general availability | Accepted operating envelope, production release decision, and all lower-level gates |

## Slice 2.0-A deliverable

The authoritative working artifact is the
[entry decision register](entry-decision-register.md). Slice 2.0-A is closed for L1 synthetic entry;
the register keeps L2–L4 gates and ADR 0025 C25-01 through C25-06 explicit. Merely naming a planned
test, owner role, or later slice does not satisfy one of those later gates.

## Navigation

- [Entry decision register](entry-decision-register.md)
- [Institutional-structure decision evidence plan](institutional-structure-decision-evidence.md)
- [Institutional-structure scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Institutional-structure security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Institutional-structure experience evidence](institutional-structure-experience-evidence.md)
- [Slice 2.1-B minimal legal-entity foundation evidence](legal-entity-foundation-evidence.md)
- [Slice 2.0-B operational outbox and module-drain evidence](operational-outbox-and-module-drain-evidence.md)
- [Slice 2.0-C temporal completion and recovery evidence](temporal-completion-and-recovery-evidence.md)
- [Temporal retention and recovery runbook](../operations/temporal-retention-and-recovery.md)
- [Identity, session, and support-access decision review](identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access implementation evidence](identity-session-and-support-access-implementation-evidence.md)
- [ADR 0030: same-origin public session and named-action boundary](../adr/0030-same-origin-public-session-and-named-action-boundary.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Proposed identity, people, relationships, and access plan](../plans/phase-2-identity-people-relationships-and-access-proposal.md) — companion planning only; it does not expand the authorized Phase 2.0/2.1 implementation scope
- [ADR 0025: learning-institution operating system with separated corporate/legal and educational structure](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Phase 1 foundation status](../phase-1/README.md)
- [Phase 0 binding later gates](../phase-0/README.md#binding-later-gates)
- [ADR index](../adr/README.md)
- [Threat model](../security/threat-model.md)
