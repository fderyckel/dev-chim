# Phase 2: entry closure and recursive institutional structure

- Status: Phase 2 implementation sequence authorized; Slices 2.0-B, 2.0-C, and internal
  2.0-D.2a through D.2c engineering are complete, provider-neutral ADR 0029 is accepted, and later
  implementation/release gates remain explicit
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
They add no production connection, public route, L2 evidence, or real-data authority. Connected
D.3 remains behind the public-interface gate.
The entry register continues to record which
other gates block each release level.

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
replace the former flat-school Phase 2.1 candidate with a recursive institutional-structure
proposal.

On 2026-09-27, Slice 2.1-A produced the scenario/vocabulary walkthrough, TM-17/AC-18 control
matrix, compare-only migration fixtures, temporal disposition, and a local read-only synthetic
hierarchy/move-preview prototype. These are review inputs, not approvals. The named accountable
reviews, three representative-institution reviews, and final G6 decision remain open, so ADR 0025
is still Proposed and L1 persistence remains blocked.

## Release-level status

| Level | Current status | Permitted now | Principal blockers |
| --- | --- | --- | --- |
| L0 — paper and prototype | Active | Slices 2.0-D.2a through D.2c are complete; ADR 0025 decision evidence and prepared Slice 2.1-A reviews may proceed separately | Named G1/G3/G4/G5 reviewers, three representative-institution reviews for G2, and G6 accountable decision |
| L1 — synthetic module proof | Blocked | Slice 2.0-B outbox/drain, accepted ADR 0018 temporal evidence, and internal Slice 2.0-D foundations are complete; remaining Phase 2.0 and 2.1-A work may proceed | Accepted ADR 0025 and Slice 2.1-B's candidate-specific entry disposition |
| L2 — connected synthetic workflow | Blocked | ADR 0029 and internal D.2a through D.2c evidence are complete; existing UI-0 and UI-1A remain qualification-only | An accepted public browser/API candidate, connected D.3 evidence, and all L1 gates |
| L3 — controlled real-data pilot | Blocked | No real institutional or Restricted data | Selected-deployment qualification, independent security/privacy review, learning-institution records ownership, and all lower-level gates |
| L4 — production release | Blocked | No general availability | Accepted operating envelope, production release decision, and all lower-level gates |

## Slice 2.0-A deliverable

The authoritative working artifact is the
[entry decision register](entry-decision-register.md). A future update may close Slice 2.0-A only
after its missing decisions and owners are recorded with evidence. Merely naming a planned test,
owner role, or later slice does not satisfy a gate.

## Navigation

- [Entry decision register](entry-decision-register.md)
- [Institutional-structure decision evidence plan](institutional-structure-decision-evidence.md)
- [Institutional-structure scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Institutional-structure security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Institutional-structure experience evidence](institutional-structure-experience-evidence.md)
- [Slice 2.0-B operational outbox and module-drain evidence](operational-outbox-and-module-drain-evidence.md)
- [Slice 2.0-C temporal completion and recovery evidence](temporal-completion-and-recovery-evidence.md)
- [Temporal retention and recovery runbook](../operations/temporal-retention-and-recovery.md)
- [Identity, session, and support-access decision review](identity-session-and-support-access-decision-review.md)
- [Identity, session, and support-access implementation evidence](identity-session-and-support-access-implementation-evidence.md)
- [Identity, session, and support-access operating runbook](../operations/identity-session-and-support-access.md)
- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Proposed identity, people, relationships, and access plan](../plans/phase-2-identity-people-relationships-and-access-proposal.md) — companion planning only; it does not expand the authorized Phase 2.0/2.1 implementation scope
- [ADR 0025: learning-institution operating system and recursive institutional structure](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Phase 1 foundation status](../phase-1/README.md)
- [Phase 0 binding later gates](../phase-0/README.md#binding-later-gates)
- [ADR index](../adr/README.md)
- [Threat model](../security/threat-model.md)
