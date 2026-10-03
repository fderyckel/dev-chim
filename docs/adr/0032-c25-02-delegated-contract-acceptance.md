# ADR 0032: C25-02 delegated corporate/legal contract acceptance

- Status: Accepted
- Date: 2026-10-03
- Accountable owner: François — Project Owner
- Decider: Codex — AI reviewer exercising François's explicit delegated authority for C25-02
- Supersedes: ADR 0025 C25-02's required reviewer route and ADR 0031's provisional C25-02 contract disposition only; all other implementation and release boundaries remain binding
- Decision evidence: [Completed C25-02 review](../phase-2/c25-02-corporate-governance-finance-review.md)

## Context

ADR 0025 required a named corporate-governance/finance disposition before legal relationships,
management-reporting parentage, and corporate units could proceed. ADR 0031 subsequently permitted
only synthetic L1 Slice 2.1-C1 while leaving the specialist review outstanding. Two supplied AI
responses did not settle the catalogue and overstated either professional experience or approval.

On 2026-10-03 François explicitly instructed: “I am delegating my power to your expertise to close
that C25-02. Go use your best expertise on the domain and close it.” This authorizes the AI reviewer
to decide and record this gate's outcome without a further approval round. It does not establish
human professional qualifications, independent external assurance, or authority for other gates.

The accompanying review supplies all seven common answers, all thirteen corporate/finance
answers, an eleven-field first-slice catalogue, LS-01 through LS-10 findings, Sources C through F
dispositions, and an attributable approval. The uncommitted 2.1-C code and migration are excluded
from the domain acceptance evidence.

## Decision drivers

- Close the actual logical-contract decision using the Project Owner's explicit delegation.
- Identify the AI review and its authority honestly, without inventing a qualified human reviewer.
- Separate direct legal rights, management navigation, internal organization, and accounting.
- Preserve tenant, authority, temporal, records, and later-release controls.
- Make the decision reviewable independently of implementation success.

## Considered options

1. Keep C25-02 open until a qualified human reviewer responds. This retains the original review
   route but does not implement the Project Owner's explicit subsequent delegation.
2. Treat an AI response as qualified independent human review. Rejected: this would misstate the
   evidence and the reviewer's identity.
3. Supersede the review route explicitly, complete the domain assessment, and close C25-02 under
   delegated Project Owner authority while preserving later adoption and implementation gates.

## Decision

Adopt option 3. **C25-02 is closed on 2026-10-03 with disposition `approve` under delegated
Project Owner authority.** The normative contract is the completed review linked above, including
its common catalogue rules, each row's include/defer/reject decision, and its temporal and
evidence qualifications. No further C25-02 approver, ratification, or unanswered catalogue item
is required for this accepted first-slice contract.

This is a governance supersession, not a claim that the original qualified-human review occurred.
François remains the accountable delegating owner; Codex is the AI assessor and delegated decider.
This delegation applies only to this C25-02 decision and does not grant continuing authority to
waive other gates.

### Accepted domain boundary

- Include the four direct types `equity_interest`, `governing_body_appointment`,
  `statutory_control`, and `contractual_control` with the exact restricted meanings in the review.
- Include optional `primary_consolidation_parent` only as management-reporting navigation;
  include corporate-unit membership and same-entity canonical parentage.
- Adopt the review's precise equity denominator, direct-right scope, per-type cycle treatment,
  evidence, non-inference, cardinality, and Date interpretation rules. Unsupported inputs stay
  outside the first-slice contract rather than being rounded, inferred, or given a generic edge.
- Primary operator, educational parentage, site associations, and other responsibilities remain
  outside C1. Answers about those subjects are explicit recommendations to their later owners;
  they do not close C25-03 or C25-04.

### Effect on existing permissions and later gates

ADR 0031's authorization remains limited to synthetic, private L1 C1 establishment/registration
and exact reads. This decision adds no implementation action, endpoint, migration authority, real
record, connected workflow, report, pilot, or deployment. End, move, transfer, correction, import,
and public workflows remain later bounded work. C1 exit still requires implementation conformity
and the complete repository checks; this domain review does not certify the current candidate.

ADR 0031 condition 3's external validation remains a **later adoption gate**, due by 2026-12-15
and before L2, real data, migration, external financial reporting, pilot, deployment, or a claim of
jurisdictional/accounting correctness, whichever is earlier. That validation assesses the actual
jurisdiction, instruments, reporting framework, and use case. It is not an unfinished C25-02
approval or a reason to relabel this completed logical-contract gate as open. A contradictory
finding requires a superseding decision before the affected use proceeds; a deadline does not
auto-approve anything.

ADR 0025 C25-03 through C25-06, independent security/privacy review, institution-side records
ownership, and other production gates are unchanged.

## Plain-English summary

### What this means

The first corporate/legal relationship model has a completed decision. François delegated this
specific decision to Codex, which completed the review and approved the bounded contract.

### What was agreed

The product can distinguish an equity holding, appointment right, statutory power, contractual
power, chosen management parent, and internal corporate unit. None establishes permission to
access data, operate a school, or publish consolidated accounts. Existing synthetic implementation
limits and later release reviews remain in place.

### Context

The earlier responses left important meanings unsettled. Changing the name of the reviewer could
not solve that. This decision records the authority actually delegated and the completed evidence.

### Examples

- A synthetic 60% holding can be recorded with its stated equity basis; it does not decide who
  controls the investee for accounting purposes.
- A finance department belongs to one legal entity without becoming a legal person or a ledger.
- A future school-operator transfer still needs its own C25-04 workflow decision.

## Consequences

### Positive

- C25-02 has a complete, attributable disposition rather than provisional answers.
- Every included relationship has an explicit meaning and bounded evidence requirement.
- Review-route changes and remaining release conditions are visible to later reviewers.

### Negative

- The decision lacks independent human corporate-governance/finance assurance.
- The first-slice model deliberately excludes complex equity, beneficial ownership, and many
  jurisdiction-specific arrangements. Unknown does not mean absent.
- Implementers must check conformity to this contract; prior focused checks do not prove it.

## Security, privacy, operability, and migration effects

TM-17 and AC-18 remain binding. Structural facts create no access, placement, module, reporting,
configuration, workflow, or legal-operator authority. Tenant-qualified endpoints, named actions,
current writer authorization, separate module gates, exact replay, audit, transactional outbox,
bounded reads, and database-backed invariants remain mandatory.

Only synthetic evidence is admitted at C1. Protected legal documents remain outside structure,
logs, audit payloads, and events. Unresolved source meaning cannot publish; Sources C–F are
compare-only review evidence, not an authorized migration. No code, schema, migration, or real
tenant policy is changed by this ADR.

## Validation evidence

- [Completed C25-02 review](../phase-2/c25-02-corporate-governance-finance-review.md): catalogue,
  thirteen answers, seven common answers, ten scenarios, four sources, and decision record.
- [Review packet](../phase-2/institutional-structure-review-packet.md).
- [Linked scenarios](../phase-2/linked-structure-scenario-addendum.md).
- [Security/migration addendum](../phase-2/linked-structure-security-migration-addendum.md).
- [IFRS 10 overview](https://www.ifrs.org/issued-standards/list-of-standards/ifrs-10-consolidated-financial-statements/)
  and [IPSAS 35 overview](https://www.ipsasb.org/publications/ipsas-35-consolidated-financial-statements-1),
  checked on 2026-10-03: accounting control requires its own assessment, not a navigation edge.

Repository validation is recorded separately in the completed review. A passing check does not
turn this AI review into independent professional assurance; a failing implementation check does
not erase the recorded logical decision, but blocks the affected implementation exit.

## Fallback and exit cost

If later evidence contradicts a meaning, stop the affected expansion and supersede this contract.
Synthetic-only changes have bounded document, fixture, and implementation cost. After any later
authorized real-data adoption, changes require versioned meanings, retained provenance,
expand-and-contract migration, downstream reconciliation, and separate release approval.

## Review triggers

- A real jurisdiction, instrument, or reporting purpose cannot fit the accepted meaning.
- More than one equity basis, finer precision, beneficial ownership, or joint-control inference is
  requested.
- A relationship requires natural-person endpoints, treasury/self-holdings, exact-time effect,
  cross-entity corporate parentage, or more than one management parent.
- A consumer derives control, authority, reporting scope, or operation from a structure fact.
- The Project Owner changes the delegated decision or a later reviewer provides contradictory
  evidence.

## Related records

- [ADR 0025](0025-learning-institution-operating-system-and-institutional-structure.md).
- [ADR 0031](0031-bounded-cross-jurisdiction-legal-structure-foundation.md).
- [ADR 0018](0018-temporal-records-correction-audit-and-evidence-semantics.md).
- [Phase 2 entry register](../phase-2/entry-decision-register.md).
- [Threat model](../security/threat-model.md) and [abuse cases](../security/abuse-cases.md).
