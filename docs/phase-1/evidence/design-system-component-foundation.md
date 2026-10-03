# DS-2 design-system component foundation evidence

- Status: Implemented with focused local verification; the repository-wide gate is blocked by an
  unpatched development-tool advisory
- Owner: Product experience and web engineering
- Evidence date: 2026-10-03
- Governing records: [proposed ADR 0028](../../adr/0028-experience-design-system-and-governed-personalization.md), the [experience design-system proposal](../../plans/experience-design-system-and-governed-personalization-proposal.md), and [ADR 0020](../../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- Review trigger: a second profile, new primitive or escape hatch, font asset, preference control,
  browser persistence, core connection, public-client use, or a change to component semantics

## Authorization and boundary

The 2026-10-03 next-slice instruction authorizes only DS-2: split component ownership, the smallest
repeated semantic React APIs, a reviewed refinement of the default, and adoption on Home, UI
preview, and one neutral dense reference page.

This slice adds no dark, high-contrast, typography, scale, density, accent, or motion choice. It
adds no preference screen, browser persistence, font file, third-party styling dependency, core
resource, Ash action, authentication path, API, production data, school module, or public
deployment. ADR 0028 remains Proposed.

## Implemented contract

The former 1,487-line component stylesheet is now six explicit, ordered families:

- `shell.css` owns the application shell and navigation;
- `primitives.css` owns headings, panels, statuses, and actions;
- `home.css` owns the Home composition;
- `structure.css` owns the neutral dense institutional-structure specimen;
- `preview.css` owns the UI-preview specimen and state demonstrations; and
- `bridge.css` owns the separately bounded UI-1A read-only bridge presentation.

The shared React boundary exposes four constrained APIs: `PageHeading`, `Panel`, `StatusBadge`, and
`ActionLink` or `ActionButton`. Their public props describe product meaning through fixed tones,
variants, and icon choices. They do not expose arbitrary class names, raw colors, inline styles,
radius, shadow, or spacing overrides. `PageHeading` owns the page-level `h1`; `Panel` provides a
labelled `section` with an `h2`; statuses always retain written meaning; and actions preserve link
versus button semantics.

The style contract registers every component family and fails on an unregistered component CSS
file. Product screens also fail the check if they hand-author the core `c-button`,
`c-page-heading`, `c-panel`, or `c-status` classes outside the design-system component directory.

## Route adoption and reviewed default

Home and UI preview now use the shared headings, panels, statuses, and actions. The dense
institutional-structure page uses shared headings, panels, and statuses. The UI preview remains the
living product specimen; no Storybook or parallel component platform was added.

The refined default keeps the established calm off-white canvas, dark ink, and restrained teal
accent while making shared hierarchy more legible:

- panels receive one consistent header boundary and description rhythm;
- semantic status tones are written, bordered, and token-backed;
- attention panels use a quiet semantic rail rather than ornamental decoration; and
- page headings share spacing and line-length constraints across the three reference pages.

Six production-build screenshots were reviewed at 1440-pixel and 320-pixel widths. They show no
horizontal overflow, clipped controls, competing heading hierarchy, or color-only status meaning.
The screenshots are transient review artifacts rather than committed golden files:

| Route and viewport                    | SHA-256                                                            |
| ------------------------------------- | ------------------------------------------------------------------ |
| Home, 1440 by 1000                    | `bf42ad8b4a01b385118f61cf949006377afaccb53f04318140c2d77f6f3de615` |
| UI preview, 1440 by 1200              | `655f65ce231ebae86ec9b8df9cd2e03c8939766deaca5e9379ba0b5254abbde1` |
| Institutional structure, 1440 by 1100 | `8fbe908f73e9b0f4f7d692012293755e77476a00720093f79383ca41ea9029c0` |
| Home, 320 by 900                      | `b29f4a5c71e4d70478bc84e58cf0e22093a703317fe7ba10328815bded09a74a` |
| UI preview, 320 by 900                | `de5863bb13540269f5d9a39fffccceba6f7d4f94ab6a16ad295702c981a915e1` |
| Institutional structure, 320 by 900   | `2492247b0d61210bb310a9f287008d91df5ae264e49f325ff496c19d17dc1dde` |

This is a reviewed visual refinement, not an assertion that automated checks prove excellent
design or that representative people have validated it.

## Focused verification

The focused browser checks prove:

- generated token output is current;
- ESLint, Stylelint, and the eight-layer CSS ownership contract pass;
- TypeScript accepts the constrained component APIs;
- six unit files with 23 tests pass, including semantic heading, labelled panel, tone, variant,
  and disabled-action coverage; and
- the guarded production build emits Home, UI preview, institutional structure, and the existing
  UI-1A route successfully.

The 15-case UI-0 browser suite passed at wide, medium, and 320-pixel viewports. Its first run found
that the small priority-card assurance detail had only 3.92:1 contrast on the refined white
surface. The text was moved to the approved secondary-text role, the production artifact was
rebuilt, and all navigation, keyboard, reflow, and automated accessibility cases then passed. The
six connected UI-1A browser cases and its one unavailable-state case also passed.

The repository-wide `make check` passed documentation validation, all 12 Phase 0 stages including
25 Python tests and 106 Ash spike tests, repository tooling, and all nine production-core stages
including 182 tests. It then stopped at the browser all-dependency audit on
`GHSA-vfj7-8cjw-p6xm`, the same high-severity `braces` development-tool advisory recorded by DS-1.
The registry still reports no patched `braces` release and proposes only a breaking
`stylelint@7.7.0` downgrade, so no forced downgrade was applied.

The browser production-dependency audit reports zero vulnerabilities. The shell-tooling gate and
Git whitespace check pass when run directly. Because the mandatory all-dependency audit remains
red, the repository is not described as green.

## Remaining gates

DS-3 requires separate authorization before any additional local profile or in-memory choice UI.
The profile matrix, contrast analysis, cross-profile screenshots, font licensing and language
review, representative learner and accessibility sessions, first-paint proof, and security review
remain open before ADR 0028 can be accepted or any choice can enter a public client.
