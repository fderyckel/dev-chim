# Academic calendar preparation prototype evidence

- Status: Local synthetic preparation and preview slice implemented; no connected write or persistence claim
- Evidence date: 2026-10-03
- Owner: Product and application engineering
- Governing decision: [ADR 0021](../adr/0021-academic-calendar-authority-and-template-adoption.md)
- Related core evidence: [Academic calendar executable contract](academic-calendar-contract-evidence.md)
- Review trigger: first same-origin calendar writer connection or a change to the accepted calendar definition

## Demonstrable task

Open `/academic-calendar` in the explicitly enabled local UI-0 experience. A reviewer can change:

- the academic-year label, code, start date, end date, and explicit time zone;
- the instructional weekdays;
- the two example term names and boundaries; and
- the two example closure names and dates.

`Preview calendar` validates the candidate without mutation and refreshes the term summary,
instructional-date count, closure summary, and exact local-date explanation. The included date
resolver demonstrates an instructional weekday, an ordinary weekday off, a named closure, a term
gap, and a date outside the year. Overlapping terms, duplicate closure dates, invalid year or term
ranges, an empty weekday pattern, and incomplete labels are explained before a preview can replace
the last valid result.

The route is linked from the primary navigation and Home. It reflows at the repository's narrow
320 CSS-pixel viewport and uses the existing design-system primitives and semantic tokens.

## Explicit boundary

The page says `Not saved`, `Local browser calculation · no core connection`, and `No save or
publish action exists in this prototype`. It has:

- no core bridge call, API route, mutation method, storage use, cookie, or database write;
- no actor, tenant, capability, placement, module, or routing claim supplied by the browser;
- no institution creation or publication-eligibility claim;
- no stable calendar, year, period, closure, version, idempotency, audit, or outbox result; and
- no authority to replace the production-core contract or the future connected writer.

The browser calculation intentionally mirrors the accepted local-date examples so the preparation
experience can be reviewed while CF-1 is developed separately. It is UX qualification evidence,
not a substitute for CF-1, persistent calendar actions, authoritative read-after-write, or CF-3's
same-origin connection.

## Verification

Run the local web checks from `clients/web`:

```text
CHIMWEMWE_UI0_SYNTHETIC=true npm run check
npm run test:e2e
```

The first command covers formatting, generated-token drift, JavaScript and CSS lint, the style
ownership contract, TypeScript, token tests, all unit tests, and a production build. The E2E suite
covers the calendar interaction at wide, medium, and 320-pixel viewports and includes the route in
the no-horizontal-overflow and automated-accessibility sweeps.

Both commands passed on 2026-10-03. The flagged web check passed 8 unit-test files / 27 tests and
generated the static `/academic-calendar` route. The full browser suite passed 33 tests across its
three configured viewports.

The required repository-wide `make check` was also run. Documentation validation and repository
tooling passed. Core formatting, compilation, OpenAPI drift, and migration drift passed before the
core lint stage stopped on three Credo nesting opportunities in the concurrently developed
`Chimwemwe.InstitutionalStructure.Foundation` (`current_institution/1`, `mutate/2`, and
`transition/2`). No later full-core or repository web stage ran. This prototype's isolated web
checks are green; the shared repository is not claimed green while that separate CF-1 work remains
in progress.

## What remains

The planned connected calendar slice is not complete. CF-1 and the private CF-2B writer are now
implemented with their separate evidence. The browser step still requires the accepted human and
identity-connection dispositions, same-origin session protections, exact named-action adapters,
accessible failure and recovery states, and confirmation refreshed from committed writer state.
It remains fail closed pending the completed
[CF-3 connected calendar entry review packet](cf-3-connected-calendar-entry-review-packet.md).
