# ADR 0057: Local Classroom workspace navigation

- Status: Proposed
- Date: 2026-10-27
- Owners: Product experience and classroom/client engineering
- Decider: François — Project Owner
- Authority: Explicit CW-1 implementation request on 2026-10-27
- Supplements: ADRs 0030, 0038, 0041, 0048 and 0055; no Accepted decision superseded

## Context

The approved navigation proposal needs a staff-owned entrance around the existing daily-register
workflow, while the four fictional institution viewers remain independently runnable.

## Decision drivers

Keep flexible labels, explicit class/date context, short daily-work paths, phone access and honest
draft/request recovery without broadening domain authority or disclosure.

## Considered options

1. Reuse demo Home/Apps with classroom records: rejected because it mixes proof sources.
2. Add a new top-level tab per task: rejected because navigation grows without a workspace.
3. Add two staff-owned entrances and bounded presentation composition: selected.

## Decision

Implement the bounded [CW-1 proposal](../plans/classroom-workspace-integration-proposal.md).
Add `/staff/home` and `/staff/apps` behind the existing local staff harness guard. Display
identity and optional destinations only after current session and own-preferences reads succeed.
Hints grant no authority. Home/Apps read no class, roster, count or mark and never probe Accounts.
Keep login landing choices and existing action/session contracts unchanged.

Code-owned bounded group/section IDs and labels refer to stable allowlisted destinations.
Groups can be renamed, reordered and populated independently of destination/action identity.
CW-1 has no connected arrangement editor, storage, arbitrary URL or layout-preferences payload.
The four fictional institution viewers and their memory-only editors remain independent.

Classroom provides My classes and selected-register Attendance, with a compact desktop task
menu and a labelled phone disclosure. Show source labels and per-class local dates; block
ambiguous label/date pairs for source clarification. Infer no campus, year, subject or register
type. Calendar is omitted until an owned educator read exists.

Known drafts require Stay/Discard before controlled departure, switching or destructive reload.
Stay restores focus; Escape means Stay. Pending writes and uncertain results require authoritative
reconciliation before another class/write or controlled departure. Sign-out remains available
and does not claim cancellation. Full-document departures warn where supported; forced departure
can lose memory. No request locator is persisted. Reject stale responses after departure,
logout or authority loss. A new-day read cannot reconcile the previous day's request; retain
its original date and show the authorized-follow-up limitation without replay or guessed success.

## Consequences

Daily classroom work gains a stable entrance and local task menu. Composition is configurable in
code; connected editing and durable personal arrangements remain later increments.

## Security, privacy, operability, and migration effects

Existing domain authorization, tenant context, module gates, CSRF, bounded reads, exposure
accounting, pinned roster/calendar basis, idempotency and append-only correction remain intact.
No new core API, resource, migration, role, permission, generic navigation service or production
surface is introduced. The staff presentation routes are disabled with the existing harness.
TM-01/02/04/09/13/16/17/19/20 remain applicable under the
[threat model](../security/threat-model.md).

## Validation evidence

Require primary, secondary and UI read-only specialist review; lifecycle/recovery and denial
regressions; staff Home/Apps/Classroom at desktop and phone widths; all four institution suites;
and one coordinated full `make check`. Record actual results in
[CW-1 evidence](../phase-2/classroom-workspace-evidence.md). Human usability, independent
security/privacy, real-data and release gates remain separate.

## Fallback and exit cost

Remove the presentation routes
and wrapper to roll back without changing domain records or the fictional viewers.

## Review triggers

New destinations or data reads; connected composition editing/persistence; broader date/history
reconciliation; real records, identity, deployment or representative-user findings.

## Related records

- [CW-1 proposal](../plans/classroom-workspace-integration-proposal.md)
- [Staff presentation](0055-staff-self-presentation-and-navigation.md)
- [Attendance recovery](0041-local-attendance-correction-and-recovery.md)
- [Local shell](0048-local-demo-application-shell.md)
