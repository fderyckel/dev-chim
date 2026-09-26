# Phase 2: entry closure and recursive institutional structure

- Status: Phase 2 implementation sequence authorized; Slice 2.0-A in progress and later slices
  remain gated by their stated entry conditions
- Owner: Product and platform engineering, with learning-institution domain and security/privacy
  review
- Start basis: explicit project-owner direction on 2026-09-26
- Review trigger: entry into another Phase 2 slice or a change to an entry-gate disposition

## Current boundary

Phase 2 has started at release level L0 with the entry decision register only. This first slice
reconciles the existing conditional gates, records which release level each gate blocks, names the
decision and review owners, and keeps missing evidence fail closed.

No institutional resource, module declaration, migration, capability, public route, production
session, support grant, dispatcher, consumer, deployment configuration, or real data is added by
Slice 2.0-A. The production core and local browser boundaries remain those documented in Phase 1.

The project owner's 2026-09-26 direction accepts the
[Phase 2 proposal](../plans/phase-2-entry-and-school-structure-proposal.md) for the Phase 2.0
and Phase 2.1 implementation sequence. No additional project-owner authorization is pending for a
listed slice; each slice becomes eligible only when its stated entry conditions are satisfied. The
same-day product clarification and
[ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
replace the former flat-school Phase 2.1 candidate with a recursive institutional-structure
proposal.

## Release-level status

| Level | Current status | Permitted now | Principal blockers |
| --- | --- | --- | --- |
| L0 — paper and prototype | Active | Entry register, Slice 2.1-A scenarios, ADR work, and synthetic prototypes | Slice 2.0-A exit decisions and ADR 0025 acceptance evidence are incomplete |
| L1 — synthetic module proof | Blocked | Phase 2.0 foundation work may proceed, but no institutional module may cross into L1 yet | Operational outbox/drain, temporal completion/recovery, and accepted ADR 0025 |
| L2 — connected synthetic workflow | Blocked | Existing UI-0 and UI-1A qualification only; neither is a Phase 2 production candidate | Production identity/session/support and public browser/API decisions plus L1 gates |
| L3 — controlled real-data pilot | Blocked | No real institutional or Restricted data | Selected-deployment qualification, independent security/privacy review, learning-institution records ownership, and all lower-level gates |
| L4 — production release | Blocked | No general availability | Accepted operating envelope, production release decision, and all lower-level gates |

## Slice 2.0-A deliverable

The authoritative working artifact is the
[entry decision register](entry-decision-register.md). A future update may close Slice 2.0-A only
after its missing decisions and owners are recorded with evidence. Merely naming a planned test,
owner role, or later slice does not satisfy a gate.

## Navigation

- [Entry decision register](entry-decision-register.md)
- [Phase 2 entry and institutional-structure proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [ADR 0025: learning-institution operating system and recursive institutional structure](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Phase 1 foundation status](../phase-1/README.md)
- [Phase 0 binding later gates](../phase-0/README.md#binding-later-gates)
- [ADR index](../adr/README.md)
- [Threat model](../security/threat-model.md)
