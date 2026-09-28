# Institutional-structure experience and representative-review evidence

- Status: Current-contract and five-context prototype implemented and technically verified; G2
  representative findings and accountable human G5 review remain conditions C25-03/C25-05
- Date: 2026-09-27
- Gates: ADR 0025 G2 and G5
- Prototype: `/institutional-structure` in the local UI-0 workspace
- Boundary: Local, synthetic, read-only, removable; no core connection, authentication, mutation,
  persistence, production interface, or data authorization

## Implemented prototype evidence

The local UI-0 prototype renders a fixed bounded review context containing:

- separate legal-entity consolidation, corporate-unit containment, and educational-containment
  views rather than one universal organization tree;
- one exact corporate-unit legal-entity membership;
- one exact primary legal operator for an educational institution, plus separately labelled
  property and joint-control relationships;
- an explicit consolidation-versus-ownership explanation and one legal relationship outside the
  consolidation tree;
- five representative roots for primary/early-years, secondary, combined formal education,
  college/community-college, and university contexts;
- nested sections, school, department, and centre units at four reviewed levels, including one
  closed unit;
- stable synthetic UUIDs, local labels, current codes, parent, site, and IANA time zone;
- sites and a joint-programme affiliation as visibly separate relationships;
- an exact selected-unit context that explicitly says selection and parentage grant no authority;
- a move preview with old and proposed parents and non-colour labels for `unchanged`,
  `requires reconciliation`, and `blocks move`; and
- a full operator-governance sequence showing proposal, evidence verification, distinct approval,
  effective-boundary revalidation, and activation, plus the governed single-controller exception;
- separate blocked and ready-for-boundary-check primary-operator previews; and
- one legal-accountability-under-review state that distinguishes continuing learner-facing work
  from operator-dependent and unknown actions that fail closed, with four named resolution paths.

The fixture is available only when `CHIMWEMWE_UI0_SYNTHETIC=true`. Its view-data port has reads and
no mutation method. The route does not call the core, accept a tenant or actor from the browser, or
create a generic hierarchy-enumeration endpoint.

## Coverage against G5

| Requirement | Current evidence | Disposition |
| --- | --- | --- |
| Several roots and reviewed depth | Five representative roots and a university/school/department/centre path | Implemented technically; representative meaning review remains C25-03 |
| Bounded search or direct lookup | One fixed exact-unit detail inside the bounded fixture; no caller-controlled traversal or search API | Adequate for L0 direct-context review; production query contract remains Slice 2.1-C/G |
| Containment, sites, and affiliations distinguished | Separate labelled panels and explicit boundary language | Implemented technically; user comprehension review open |
| Selector is not authority | Selected unit is presented as context; banner names all prohibited implied effects | Implemented technically; authorization remains server-side and absent here |
| Current/closed state, local labels, codes, and time zone | Visible in tree and exact-unit facts | Implemented technically |
| Governed move preview | Old/new parents and five registered impact categories, including an unknown blocker | Implemented technically; no mutation exists |
| Hierarchical semantics and keyboard safety | Native nested-list structure, semantic landmarks/headings, skip link, and only five shell navigation focus stops in logical DOM order | Focused automated accessibility and in-app browser inspection passed; representative assistive-technology review remains C25-05 |
| Narrow reflow and non-colour status | Responsive layouts and text labels for every state | Wide, medium, narrow, and 720-pixel 200%-equivalent reflow checks passed without page-level overflow |
| Loading, empty, denied, conflict, and unexpected states | Shared UI-0 state-preview route contains these synthetic states | Existing reusable state language; a production structure client must bind them to its exact contract |
| Cross-context language | Primary/early-years, secondary, combined formal education, college/community-college, and university terms coexist; no universal school root or fixed type ladder | Implemented technically; five-context representative review remains C25-03 |
| Legal/corporate and educational distinction | Separate legal consolidation, corporate containment, and educational containment views; exact primary operator; secondary legal relationships; consolidation-versus-ownership explanation | Implemented technically; accountable corporate/finance and representative comprehension review open |
| Operator-governance states | Proposal, verified evidence metadata, normal distinct approval, governed exception, future-effective revalidation, activation, blocked and ready previews, accountability review, action classification, and resolution paths | Implemented technically; named policy and comprehension review remains C25-04/C25-05 |

## Verification record

| Check | Result |
| --- | --- |
| Focused synthetic adapter and component tests | Passed on 2026-09-27 after the current-contract refresh: 2 files, 5 tests, including component accessibility checks |
| Focused format, lint, style, and types | Passed on 2026-09-27 for the changed TypeScript, TSX, CSS, and test files |
| Production build | Passed on 2026-09-27 with the required local-only synthetic flag |
| Browser route, reflow, and automated accessibility scan | Passed on 2026-09-27: 15 Chromium tests across 1440-pixel wide, 768-pixel medium, and 320-pixel narrow projects |
| Local in-app browser inspection | Passed on 2026-09-27 at 1440, 320, and 720 CSS pixels: all five contexts, four-level depth, operator workflow, normal and exception approval paths, blocked and ready previews, accountability review, and resolution paths were semantically exposed; no page-level horizontal overflow occurred |
| Keyboard-focus inspection | Passed for the read-only page: focus order is skip link, home brand, Home, Structure prototype, and UI preview; the evidence panels expose no misleading action control |
| Prior clean-checkout rehearsal and complete `make check` | Passed earlier on 2026-09-27 before this prototype refresh. Per Product Owner instruction, neither heavyweight check was rerun for this refresh; the focused checks above are the current evidence |

One earlier current-worktree run overlapped another isolated clean-checkout rehearsal against the
same synthetic PostgreSQL database and failed 53 core tests with duplicate or missing fixture rows
and cross-test authorization state. No product code was changed in response. After the competing
run finished, the complete gate was rerun uncontended and passed as recorded above.

Automated accessibility checks do not replace review with representative users or assistive-
technology users. Browser evidence demonstrates only the local fixture and cannot qualify a
production navigation or sensitive-collection contract.

## Current product-experience audit

The 2026-09-27 internal wide/narrow audit confirmed that the original fixture has a clear
read-only boundary, understandable separation of legal, corporate, educational, site, and
affiliation meanings, textual non-colour impact outcomes, semantic headings and nested lists, and
usable responsive reflow. The refresh resolves its four technical gaps: it adds the complete
IS-17 through IS-21 operator story, all five contexts, a ready comparison beside blocked previews,
and deeper responsive hierarchy evidence at wide, narrow, and a 720-pixel 200%-equivalent viewport.

This is sufficient technical G5 readiness for the conditionally accepted L0 decision. It is not
representative comprehension or assistive-technology acceptance. Those named findings remain
C25-03/C25-05 and must be recorded before their first affected educational or connected/public
slice.

## Representative review packet

The reusable [representative and accountable review packet](institutional-structure-review-packet.md)
contains the short common summary, perspective-specific scenarios and questions, specialist
checks, and the review/G6 forms. The same route, scenario review, and questions must be used for all required perspectives. A reviewer
record is valid only when it names the person, represented context, date, scenarios reviewed,
terminology mappings, missing structures, objections, required changes, residual risks, and one of
the allowed dispositions.

| Required perspective | Named reviewer | Date | Scenarios | Findings and terminology mapping | Disposition |
| --- | --- | --- | --- | --- | --- |
| Primary or early-years operations | Open | Open | S1, S1P, S5, S7, S8, LS-04, LS-06, LS-10 | Open | Open |
| Secondary operations | Open | Open | S2S, S2, S5, S7, S8, LS-04, LS-06, LS-10 | Open | Open |
| Combined formal education spanning multiple levels | Open | Open | S2, S5, S7, S8, LS-04, LS-05, LS-08, LS-10 | Open | Open |
| College or community-college operations | Open | Open | S4, S5, S6, S7, S8, LS-04, LS-07, LS-10 | Open | Open |
| University operations with schools/faculties/departments | Open | Open | S3, S5, S6, S7, S8, LS-05, LS-06, LS-08, LS-10 | Open | Open |
| Corporate governance or finance operations | Open | Open | LS-01 through LS-10 and Sources C through F | Open | Open |

For each context, the review asks the participant to:

1. identify the tenant, roots, selected unit, site, and affiliation in their own words;
2. state whether local terms map to `institution` or `organizational_unit` without losing a
   structurally important distinction;
3. find the closed unit and explain whether its retained identity is clear;
4. explain what the selected parent does and does not imply;
5. review the proposed move and identify which impacts need reconciliation or block it;
6. identify any real structure that would require two canonical parents and test whether a typed
   affiliation represents it honestly;
7. navigate at narrow and wide viewports using keyboard and, where applicable, their assistive
   technology; and
8. record missing structure, confusing language, privacy concerns, and unacceptable operational
   behavior rather than resolving them informally.

The S9 review additionally asks participants to distinguish tenant, legal entity, corporate unit,
educational institution, educational unit, primary legal operator, other legal responsibility,
and consolidation parent; explain why consolidation is not ownership or authority; and identify
the blocked effects of an operator transfer or corporate/educational move.

Allowed dispositions are `approve`, `approve with implementation condition`, or `do not approve`.
A product-owner decision, repository author, job title, or blank row cannot substitute for a
representative institutional review.

## G2 and G5 disposition

G2 is **open as C25-03** because no named representative review is recorded. Technical G5 is
**ready** for the conditionally accepted logical decision because the refreshed prototype and
focused evidence pass. Accountable product-experience and representative comprehension remain
**open as C25-05** before a connected/public structure workflow. Any review finding that changes identity,
tenant ownership, legal responsibility, parentage, consolidation meaning, or either hierarchy's
non-authority boundary returns to G1/G3 rather than becoming an informal UI exception.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Decision evidence plan](institutional-structure-decision-evidence.md)
- [Scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [Representative and accountable review packet](institutional-structure-review-packet.md)
- [Internal readiness challenge](institutional-structure-internal-readiness-review.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)
