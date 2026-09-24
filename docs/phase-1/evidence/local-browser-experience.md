# UI-0 local browser experience evidence

- Status: Implemented and locally verified; representative human usability review pending
- Owner: Product experience and web engineering
- Evidence date: 2026-09-24
- Governing records: [ADR 0014](../../adr/0014-primary-api-and-generated-typescript-client.md), [ADR 0020](../../adr/0020-human-interface-experience-and-client-platform-boundary.md), and the [UI-0 proposal](../../plans/local-browser-experience-foundation-proposal.md)
- Review trigger: first public API, authentication path, real workflow, browser persistence, representative user study, or production deployment proposal

## Implemented boundary

UI-0 adds a local Next.js, React, and TypeScript workspace at `clients/web`. It renders:

- a responsive Home route with a primary next step, attention list, recent activity, tenant-context display, and persistent synthetic-data warning;
- a UI-preview route containing the shared controls, form semantics, content containers, and eight public response states; and
- narrow, medium, and wide layouts using one semantic design language without treating the phone view as a compressed data grid.

The client reads only deterministic synthetic fixtures through a `ViewDataPort` with `getHome/0` and `getPreview/0`. It exports no mutation method and accepts no actor, tenant, capability, repository, placement, or routing input. The adapter throws unless `CHIMWEMWE_UI0_SYNTHETIC=true`. An unflagged production build also fails closed.

There is no Phoenix endpoint, public API, authentication, session, database call, browser persistence, analytics, realtime connection, service worker, external service, or production deployment configuration.

## CSS and accessibility contract

The workspace owns its CSS directly. The canonical layer order is `reset`, `tokens`, `base`, `layout`, `components`, `utilities`, `states`, then reserved `overrides`. A custom style-contract check verifies the layer entry point, class grammar, token ownership, and custom-property references. Stylelint rejects IDs, `!important`, excessive specificity, and classes outside the `l-`, `c-`, `u-`, `is-`, and `has-` ownership grammar.

The rendered interface includes a skip link, semantic landmarks, labelled navigation, written status and recovery language, visible focus, at least 44-pixel primary controls, reduced-motion handling, forced-colour support, and layouts that reflow without page-level horizontal scrolling at 320 CSS pixels.

## Verification evidence

The focused UI-0 verification completed successfully on 2026-09-24:

- Prettier formatting check passed.
- ESLint and Stylelint passed.
- The CSS contract passed with seven active layers and 76 owned tokens; the overrides layer remains empty.
- TypeScript type checking passed.
- Three unit files containing seven tests passed, covering accessible component semantics, state recovery, the read-only deterministic adapter, and both build guards.
- The guarded Next.js production build passed and statically generated `/` and `/ui-preview`.
- The same production build without `CHIMWEMWE_UI0_SYNTHETIC=true` failed closed as designed.
- Twelve Playwright cases passed across 1440, 768, and 320 CSS-pixel viewports.
- The browser cases covered written synthetic context, the primary next step, keyboard navigation, state recovery, Axe checks, and page-level reflow.
- `npm audit --audit-level=high` reported zero vulnerabilities.
- The complete `make check` gate passed in the working tree and again after bootstrap in an isolated clean checkout; both runs included Phase 0, production core, and UI-0.

The repository commands are `make web-dev`, `make web-check`, and `make web-e2e`. The complete `make check` gate includes UI-0 after the Phase 0 and production-core gates.

## Manual inspection

The implementation was rendered locally at desktop and narrow-phone widths. The product hierarchy, single-column phone reflow, visible synthetic boundary, primary action, navigation, forms, and state explorer were inspected. This is developer verification, not representative human usability evidence.

## Remaining evidence

UI-0 has not completed the proposal's human-test threshold. Before calling the shell human-validated, run the four-task script with the product owner and collaborators, then with representative school users. Record task completion, wrong turns, time, confidence, viewport, keyboard blockers, confusion, and resulting changes.

This evidence does not authorize or validate a school workflow, public API, authentication, production data, production deployment, or client-side authority. Slice 1G remains the first governed mutation boundary.
