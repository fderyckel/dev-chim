# ADR 0055: Staff self presentation and navigation

- Status: Proposed
- Date: 2026-10-25
- Accountable owner: Identity and product experience engineering
- Deciders: François — Project Owner
- Implementation authority: François authorized the scoped navigation, wording, signed-in identity
  and fictional-roster repairs, followed by specialist login review; the request-lifetime repair
  and full verification were subsequently authorized on 2026-10-26. The latest coordinated
  `make check` passed after the initial dependency-audit stop was repaired
- Supersedes: None; supplements ADRs 0030, 0049 and 0050

## Context

The local specialist walkthrough found unavailable Accounts/My classes links, no visible signed-in
person, account creation below the initial viewport, singular wording and weak fictional rosters.
The existing own-preferences response already supplies the current staff display name. Navigation
needs bounded current availability without probing the privileged inventory or inferring roles.

## Decision drivers

- Clear individual identity on shared devices and audience-specific, concise navigation.
- Retain current session, tenant, staff-source, module and action authorization.
- Preserve local credentials outside Git and review fictional records only.

## Considered options

1. Always show every destination. Retains the observed misleading navigation.
2. Infer access from titles or fetch the inventory to decide whether to show its link. Rejected:
   titles are not authority and inventory access is an unnecessary disclosure/audit side effect.
3. Add two fixed destination hints to the existing own-preferences response. Selected for this
   bounded local repair; no new endpoint, collection or policy engine is introduced.

## Decision

Extend the own-preferences representation with `navigation.accounts` and `navigation.classroom`.
Compute each on the writer from its existing current module/dependency/capability gate, after
the own staff-source checks. A dependency failure refuses the response; a denied/unavailable
destination is false. Existing display-name fields remain the source for the signed-in label.
Never expose a capability list, role graph, other staff identity, credential or placement.

The browser renders feature links only for true hints and clears self presentation on session
loss, identity transitions and page departure. Missing hints hide optional destinations. An
authenticated staff member without either destination lands on My preferences. These are
disposable presentation hints: direct/stale requests still require every original domain check.
They grant no authority and do not hide errors or eliminate blocked-state recovery.

The account page exposes an early Create staff account jump action without bypassing identity
review/confirmation. Classroom wording handles singular/plural pupils. Local reviewer fixtures
use distinguishable daily-class names and several fictional pupils, within unchanged caps.
Changing classes asks before discarding unsaved marks; cancelling preserves the current draft,
and an uncertain result must be reconciled before switching.
No new school policy, lesson/subject audience, identity provider, session or publication path is added.

## Plain-English summary

### What this means

Staff see who is signed in and links to work currently available to them. Administrators can find
account creation promptly; fictional class lists support meaningful roster review.

### What was agreed

Repair these four findings, run scoped checks and obtain another specialist review using local
logins. Credentials stay outside Git. The later authorized request-lifetime/dependency repair
and passing full verification are recorded in the linked implementation evidence.

### Context

Successful login does not mean every task is available. The interface should make that distinction
clear while the server continues to protect each action.

### Examples

- Illustrative: an ordinary staff reviewer sees their name and preferences without an Accounts link.
- Illustrative: a teacher can open assigned daily registers; an unassigned register remains denied.
- Illustrative: a stale link never overrides a revoked grant or suspended account.

## Consequences

### Positive

- Current identity and destination availability use existing self-owned data and server checks.
- No privileged inventory is fetched solely for navigation.

### Negative

- Hints may become stale immediately; every destination/action still revalidates authority.
- The additive response requires updated OpenAPI/types and fail-closed old-server behaviour.
- A stronger fictional fixture is still not representative human evidence or capacity proof.

## Security, privacy, operability, and migration effects

No migration, new persisted field, credential or authorization grant is introduced. Requests remain
same-origin, session-bound, tenant-qualified and no-store. Preferences writes accept only their
existing closed input; submitted navigation/name hints cannot grant access. Named login/session
checks remain independent. Local review databases and owner-only credentials are retained outside
Git. No secret enters screenshots, traces, logs, evidence or prompts.

## Validation evidence

The separately authorized [request-lifetime repair](../phase-2/staff-directory-request-lifetime-evidence.md)
records the access-profile reset reproduction, current-page/request ownership, departure safety
and retry recovery. It changes no public action or authorization contract.

Record executed domain/HTTP denial and revocation checks, generated-contract drift, focused web
checks, local sign-in/switch/logout/direct-denial checks and four specialist dispositions in
[repair evidence](../phase-2/staff-review-presentation-evidence.md). Planned tests are not passes.
Full `make check`, representative users, production/release and publication remain separate.

## Fallback and exit cost

Hide optional links and omit unconfirmed self identity when presentation cannot be loaded.
Keep direct authorization and explicit blocked recovery. Remove the additive hints if necessary;
existing preferences data/actions remain compatible and no data migration is required.

## Review triggers

- Additional destinations, generic capability serialization or privileged identity fields.
- Session/tenant/authority redesign, real records, production release or representative findings.

## Related records

- [ADR 0030](0030-same-origin-public-session-and-named-action-boundary.md)
- [ADR 0049](0049-privileged-synthetic-staff-account-directory.md)
- [ADR 0050](0050-local-credential-application-session.md)
- [Specialist team](../development/specialist-review-team.md)
