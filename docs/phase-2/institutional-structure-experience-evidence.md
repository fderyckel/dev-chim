# Institutional-structure experience and representative-review evidence

- Status: Technical prototype verified; G2 and accountable human G5 review remain open
- Date: 2026-09-27
- Gates: ADR 0025 G2 and G5
- Prototype: `/institutional-structure` in the local UI-0 workspace
- Boundary: Local, synthetic, read-only, removable; no core connection, authentication, mutation,
  persistence, production interface, or data authorization

## Implemented prototype evidence

The local UI-0 prototype renders a fixed bounded review context containing:

- three independent roots for university, community-college, and early-childhood contexts;
- nested school and department units, including one closed unit;
- stable synthetic UUIDs, local labels, current codes, parent, site, and IANA time zone;
- sites and a joint-programme affiliation as visibly separate relationships;
- an exact selected-unit context that explicitly says selection and parentage grant no authority;
- a move preview with old and proposed parents and non-colour labels for `unchanged`,
  `requires reconciliation`, and `blocks move`; and
- a deliberately unknown downstream consumer that blocks the move, with no action control exposed.

The fixture is available only when `CHIMWEMWE_UI0_SYNTHETIC=true`. Its view-data port has reads and
no mutation method. The route does not call the core, accept a tenant or actor from the browser, or
create a generic hierarchy-enumeration endpoint.

## Coverage against G5

| Requirement | Current evidence | Disposition |
| --- | --- | --- |
| Several roots and reviewed depth | Three roots and a university/school/department path | Implemented technically; representative meaning review open |
| Bounded search or direct lookup | One fixed exact-unit detail inside the bounded fixture; no caller-controlled traversal or search API | Adequate for L0 direct-context review; production query contract remains Slice 2.1-C/G |
| Containment, sites, and affiliations distinguished | Separate labelled panels and explicit boundary language | Implemented technically; user comprehension review open |
| Selector is not authority | Selected unit is presented as context; banner names all prohibited implied effects | Implemented technically; authorization remains server-side and absent here |
| Current/closed state, local labels, codes, and time zone | Visible in tree and exact-unit facts | Implemented technically |
| Governed move preview | Old/new parents and five registered impact categories, including an unknown blocker | Implemented technically; no mutation exists |
| Hierarchical semantics and keyboard safety | Native nested-list structure, semantic landmarks/headings, skip link, visible focus from shared UI-0 shell | Automated accessibility scan and browser review required below |
| Narrow reflow and non-colour status | Responsive layouts and text labels for every state | Automated viewport and accessibility checks required below |
| Loading, empty, denied, conflict, and unexpected states | Shared UI-0 state-preview route contains these synthetic states | Existing reusable state language; a production structure client must bind them to its exact contract |
| Cross-context language | University, community-college, and early-childhood terms coexist; no universal school root | Implemented technically; three-context representative review open |

## Verification record

| Check | Result |
| --- | --- |
| Synthetic adapter and component unit/accessibility tests | Passed on 2026-09-27: 5 files, 21 tests |
| Formatting, lint, style contract, types, dependency audit, generated-client drift, and production build | Passed through `make web-e2e` on 2026-09-27 |
| Browser route, reflow, and automated accessibility scan | Passed on 2026-09-27: 15 Chromium tests across wide, medium, and narrow projects |
| Local in-app browser inspection | Passed on 2026-09-27 at the default 1280-pixel viewport and a 320-pixel override: tenant/root/unit/site/affiliation/move meanings remained legible, the narrow document width matched the viewport, and no browser warning or error was recorded |
| Complete `make check` | Passed in the isolated clean-checkout rehearsal and again in the current worktree on 2026-09-27: 25 repository-tool tests, 106 Phase 0 tests, 149 production-core tests, 21 browser unit tests, 15 UI-0 browser cases, 6 connected UI-1A cases, and 1 unavailable-recovery case; both Dialyzer runs passed with zero errors, skips, or unnecessary skips |

One earlier current-worktree run overlapped another isolated clean-checkout rehearsal against the
same synthetic PostgreSQL database and failed 53 core tests with duplicate or missing fixture rows
and cross-test authorization state. No product code was changed in response. After the competing
run finished, the complete gate was rerun uncontended and passed as recorded above.

Automated accessibility checks do not replace review with representative users or assistive-
technology users. Browser evidence demonstrates only the local fixture and cannot qualify a
production navigation or sensitive-collection contract.

## Representative review packet

The same route, scenario review, and questions must be used for all three perspectives. A reviewer
record is valid only when it names the person, represented context, date, scenarios reviewed,
terminology mappings, missing structures, objections, required changes, residual risks, and one of
the allowed dispositions.

| Required perspective | Named reviewer | Date | Scenarios | Findings and terminology mapping | Disposition |
| --- | --- | --- | --- | --- | --- |
| Early-childhood or combined primary/secondary operations | Open | Open | S1, S2, S5, S7, S8 minimum | Open | Open |
| College or community-college operations | Open | Open | S4, S5, S6, S7, S8 minimum | Open | Open |
| University operations with schools/faculties/departments | Open | Open | S3, S5, S6, S7, S8 minimum | Open | Open |

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

Allowed dispositions are `approve`, `approve with implementation condition`, or `do not approve`.
A product-owner decision, repository author, job title, or blank row cannot substitute for a
representative institutional review.

## G2 and G5 disposition

G2 is **open** because no named representative review is recorded. The technical portion of G5 and
the complete repository gate have passed, but G5 remains **open** until product experience and
representative users record that they can distinguish the meanings above. Any review finding that
changes identity, tenant ownership,
parentage, or hierarchy's non-authority boundary returns to G1/G3 rather than becoming an informal
UI exception.

## Related records

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [Decision evidence plan](institutional-structure-decision-evidence.md)
- [Scenario and vocabulary review](institutional-structure-scenario-review.md)
- [Security, migration, and temporal review](institutional-structure-security-migration-review.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)
