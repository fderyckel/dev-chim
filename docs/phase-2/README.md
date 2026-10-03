# Phase 2: entry closure and separated corporate/legal and educational structure

- Status: Phase 2.0 conditionally approved and closed at L1; Slices 2.0-B, 2.0-C, internal D.2a
  through D.2c, the bounded D.3 public-session adapter, and the minimal Slice 2.1-B legal-entity
  aggregate have synthetic evidence; ADR 0031 authorizes bounded synthetic Slice 2.1-C1 and ADR
  0033 authorizes append-only Slice 2.1-C2a; C2a focused migration, action, and demo evidence is
  passing while its complete repository gate is blocked by the concurrent web candidate's
  dependency audit; revised ADR 0021 conditionally accepts the calendar contract for bounded
  synthetic L1 and its first executable validation/resolution increment passes; 2.0-E is a dated
  deferred condition and L2 remains gated
- Owner: Product and platform engineering, with learning-institution domain and security/privacy
  review
- Start basis: explicit project-owner direction on 2026-09-26
- Review trigger: entry into another Phase 2 slice or a change to an entry-gate disposition

## Current boundary

On 2026-10-03 François approved the
[classroom-first six-week plan](../plans/classroom-first-six-week-plan.md). It is the active
delivery order for 5 October–15 November: minimal institutional prerequisites, academic calendar,
people and class preparation, enrolment, and daily attendance. Further corporate/legal expansion
is paused. The [first-slice brief](classroom-first-slice-contract.md) defines the calendar-to-classroom
contract and planned evidence. Existing decisions and release gates below remain binding; this
course change is now in its first executable calendar increment, not yet persistent or connected
educational functionality.

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
minimal synthetic Slice 2.1-B entry. The prototype refresh and focused G5 checks now pass. The
separately recorded C25-01 entry disposition permits and closes the minimal
synthetic Slice 2.1-B `LegalEntity` proof: stable identity, immutable name-profile history, two
named actions, one exact read, lifecycle/capability gates, concurrency, replay, audit, outbox, and
rollback. This small Phase 2.1 dependency was implemented only to apply the Phase 2.0 foundation
to a business aggregate.

On 2026-10-03, the Project Owner directed a best-judgement cross-country legal-structure start.
ADR 0031 conditionally accepts the closed direct relationship catalogue,
management-reporting-only parentage, and corporate-unit identity for synthetic L1 Slice 2.1-C1.
Focused and production-core evidence passes; the complete repository gate is blocked because the
clean-checkout rehearsal reaches the concurrent web candidate's dependency audit and reports nine
high-severity transitive advisories. The C25-02 review and ADR index now pass focused document
validation. No
qualified reviewer is invented, and external corporate/finance validation remains due before L2,
real data, migration, external financial reporting, pilot, deployment, or
jurisdictional/accounting claims. The later ADR 0034 closes C25-03 for synthetic L1 only;
C25-03-R and C25-05/C25-06 remain open; ADR 0035 below subsequently closes synthetic C25-04.
No educational implementation is claimed here.

The subsequent [ADR 0032](../adr/0032-c25-02-delegated-contract-acceptance.md) and
[completed corporate/finance review](c25-02-corporate-governance-finance-review.md) close C25-02
on 2026-10-03 under François’s explicitly delegated authority. All catalogue fields, thirteen
specialist answers, scenarios, and migration findings have a disposition. This closes the logical
contract, not the current candidate’s implementation exit or the later adoption/release gates.

François then confirmed that consultants are reviewing C25-02, instructed the project to consider
it approved for now, and directed work to the next slice. [ADR 0033](../adr/0033-append-only-legal-structure-lifecycle-foundation.md)
therefore authorizes bounded synthetic Slice 2.1-C2a: one append-only relationship-ending action
and one append-only corporate-unit name-profile revision action. Focused clean-database and demo
evidence passes. That legal lifecycle decision does not authorize structural moves,
consolidation-parent changes, educational persistence, or later releases.

On the same date, [ADR 0034](../adr/0034-c25-03-delegated-educational-structure-acceptance.md)
and the [five-context educational review](c25-03-educational-structure-review.md) close C25-03
for synthetic L1 under explicit delegated Project Owner authority. Unpublished educational identity,
initial containment, sites/associations, and terminology become eligible within the existing
sequence and its other prerequisites. ADR 0035 below closes its temporary C25-04 dependency.
Actual external representative validation remains C25-03-R before connected use, real data/import,
pilot, or deployment; the packet's 2026-12-15 or first-affected-gate deadline is retained.

[ADR 0035](../adr/0035-c25-04-delegated-primary-operator-acceptance.md) and the
[completed primary-operator review](c25-04-primary-operator-review.md) close C25-04 for synthetic
L1 on 2026-10-03, disposition `approve`. The compliance/governance owner owns retrospective review
within 14 calendar days; revoked evidence creates immediate restrictions/case/alert obligations
and requires human reconciliation within 72 elapsed hours. Bounded operator implementation and
internal publication become eligible within the authorized sequence, with their own required
proof. External adoption, connected-use and real-data/deployment gates remain unchanged.

François then instructed the project to start calendar construction. Revised
[ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md) conditionally accepts
the exact-unit, multiple-calendar, pinned-publication contract for bounded private synthetic L1.
`Chimwemwe.AcademicCalendar` now validates and canonicalizes a publication candidate, calculates
instructional dates, and resolves terms, gaps, weekdays, and closures. This pre-persistence
increment adds no table, publication action, module activation, public route, or connected screen.
CF-1's minimal institutional/operator writer remains the next prerequisite for persistent calendar
publication.

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
| L1 — synthetic module proof | Closed for the minimal candidate; 2.1-C2a exit blocked at repository integration | Slice 2.0-B outbox/drain, Accepted ADR 0018 temporal evidence, internal Slice 2.0-D foundations, and the Slice 2.1-B `LegalEntity` proof pass; ADRs 0031/0033 permit bounded synthetic 2.1-C1/C2a | Complete repository gate for 2.1-C2a, currently blocked by the concurrent web dependency audit; external finance validation at ADR 0031's later boundary; C25-03-R blocks connected adoption; ADR 0035 closes the synthetic C25-04 operator decision; ADRs 0034/0035 admit bounded educational/operator work subject to implementation proof |
| L2 — connected synthetic workflow | Conditionally deferred; not released | ADRs 0029/0030, D.2a–D.2c, bounded D.3 adapter evidence, and the minimal business aggregate are complete; UI-0/UI-1A remain qualification-only | C25-03-R external five-context validation plus C25-05 expert/representative comprehension and product-experience disposition by 2026-12-15 or the first affected gate, the first complete accessible 2.0-E browser workflow, and deployment-specific D.3 qualification |
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
- [Slice 2.1-C1 bounded legal-structure foundation evidence](legal-structure-foundation-evidence.md)
- [Slice 2.1-C2a append-only lifecycle evidence](legal-structure-lifecycle-evidence.md)
- [Academic calendar executable-contract evidence](academic-calendar-contract-evidence.md)
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
