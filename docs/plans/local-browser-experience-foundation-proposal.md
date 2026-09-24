# Local browser experience foundation proposal

- Status: Authorized and implemented as a local synthetic slice on 2026-09-24; representative human review remains pending
- Proposed slice: UI-0, separate from the numbered production-core sequence
- Owner: Product experience and web engineering
- Proposed date: 2026-09-24
- Review trigger: approval to add a browser workspace, a public interface, real authentication, or the first school workflow
- Governing records: [ADR 0014](../adr/0014-primary-api-and-generated-typescript-client.md), [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md), and [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md)

## Implementation outcome

The product owner authorized implementation on 2026-09-24. UI-0 now exists under `clients/web` with the bounded routes, guarded synthetic adapter, semantic CSS contract, repository commands, unit and accessibility tests, and real-browser viewport checks described below. The exact implementation evidence and remaining human-review gate are recorded in [the UI-0 evidence note](../phase-1/evidence/local-browser-experience.md).

The remaining proposal language is retained as the implementation contract. It does not expand the authorization boundary.

## Authorized decision

Implement one bounded, local-only browser slice that gives people a real Chimwemwe screen to open, resize, navigate, and evaluate while the production action and public API boundaries remain closed.

The slice should create a Next.js, React, and TypeScript workspace at `clients/web`. It should contain a responsive application shell, a small semantic design system, explicit interface states, and synthetic local fixtures. It should not connect to PostgreSQL, call the production core, simulate authority, or add a school business module.

This is an experience-validation slice, not a production client. Its purpose is to turn ADR 0020 from prose into inspectable local evidence without presenting fixture-backed screens as working school software.

## Why this slice now

Slices 1A through 1F establish trusted context, read invocation, database admission, persistence routing, and a closed tenant-authority graph. They deliberately provide no browser app, public route, authentication integration, or state-changing action. Slice 1G still owns the first governed mutation path.

A full API-backed UI would therefore cross several unapproved boundaries at once. A static image would be too weak: it cannot prove keyboard behaviour, responsive reflow, focus, real CSS structure, interface states, or local startup. A local fixture-backed browser harness is the narrow middle path.

It also respects the existing client decision:

- Next.js and React remain the primary browser direction.
- The browser stays a client of the Phoenix/Ash core rather than gaining its own policy engine.
- Expo and native mobile remain deferred.
- Resource descriptors may later supply safe field primitives, but this slice does not build a generic renderer.
- Hidden controls, navigation, fixture data, and CSS never imply authorization.

## Proposed user outcome

After one local startup command, a reviewer can open `http://localhost:3000` and:

1. recognize the Chimwemwe product and the active synthetic tenant context;
2. understand that the screen is a local prototype using synthetic data;
3. navigate the shell with a mouse, keyboard, or narrow touch viewport;
4. inspect ready, loading, empty, denied, rate-limited, retryable, conflict, and unexpected-error states;
5. judge hierarchy, density, typography, contrast, focus, status language, and recovery actions; and
6. record human feedback against explicit tasks rather than commenting on a screenshot alone.

The first view should feel calm, capable, and trustworthy. It should avoid the usual noisy administration dashboard: no wall of equal-weight cards, no decorative charts, no role-specific menu assumptions, and no colour-only status.

## Initial view

The `/` route should be a complete responsive shell with deliberately modest content:

- a skip link and semantic page landmarks;
- a compact product header;
- a visible synthetic-tenant context summary, without a placement or repository selector;
- a small primary navigation containing only `Home` and `UI preview`;
- a `Today` main region with one primary next step, a short attention list, and recent activity using clearly synthetic examples;
- written connection and prototype status;
- an account/control area that is visibly non-functional in UI-0; and
- a mobile layout that becomes a focused single-column task view instead of a compressed desktop grid.

The `/ui-preview` route should exercise the product primitives and states used by `/`. It is a review surface, not a second product or a generic component platform. It should include buttons, links, form fields, notices, status markers, cards, list rows, empty states, skeletons, focus order, validation messages, and the public error vocabulary already defined by the core architecture.

No navigation item should name an unimplemented school module. No fixed role such as administrator, educator, learner, or guardian should be used to decide what appears.

## Strong CSS contract

Use plain CSS compiled by Next.js, with CSS custom properties, cascade layers, and semantic class names. Do not begin with a utility framework, CSS-in-JS runtime, or component library. The first slice is small enough that owning the visual contract directly is lower-cost and easier to inspect.

### Layer order

Keep the cascade intentional and fixed:

```css
@layer reset, tokens, base, layout, components, utilities, states, overrides;
```

- `tokens` defines semantic colour, typography, spacing, radius, border, shadow, motion, and width variables.
- `base` styles document defaults and native controls without class-specific product layouts.
- `layout` owns page composition.
- `components` owns reusable product elements.
- `utilities` contains a very small reviewed set such as visually hidden text.
- `states` owns explicit visual states.
- `overrides` is reserved and should be empty in UI-0.

### Class grammar

Class names should be readable in browser tools and state their ownership:

| Prefix | Meaning | Examples |
| --- | --- | --- |
| `l-` | page and region layout | `l-app-shell`, `l-page-grid` |
| `c-` | reusable component | `c-button`, `c-status`, `c-attention-list` |
| `u-` | narrow utility | `u-visually-hidden`, `u-truncate` |
| `is-` | current state | `is-loading`, `is-selected`, `is-disabled` |
| `has-` | state derived from content | `has-error`, `has-leading-icon` |

Use a BEM-like element and modifier shape only inside a component, for example `c-button__icon` and `c-button--quiet`. Keep selectors flat, class-based, and no more specific than needed. Avoid element chains, IDs, `!important`, layout tied to DOM position, and selectors such as `:nth-child()` for product meaning.

Variant attributes such as `aria-current`, `aria-expanded`, `disabled`, and `data-tone` may carry semantic state. CSS classes remain the named styling contract; ARIA exists for semantics, not as a substitute for maintainable class ownership.

Automated style checks should enforce the prefix grammar, prevent unknown custom properties, reject invalid layer order, and report excessive selector specificity. User-interface tests should query accessible role, name, and status text rather than treating CSS classes as test IDs.

### Token rules

Components should consume semantic tokens such as `--color-surface`, `--color-text`, `--color-action`, `--space-control-inline`, and `--focus-ring`, not raw palette values. Primitive palette values may exist only inside the token layer. This permits later tenant-safe theming without allowing tenant metadata to inject arbitrary CSS.

The initial visual direction should use warm neutral surfaces, deep ink text, a restrained blue-green action colour, visible borders, modest radii, and limited shadow. Use the system font stack for the first slice so local startup has no font-network dependency. Respect reduced motion, increased text size, forced colours, and high-contrast focus.

## Architecture and data boundary

The browser workspace should live at `clients/web`, not under the Elixir umbrella's `apps` directory. It has an independent package lock and is invoked through repository-owned `make` targets so local and future CI commands do not drift.

Inside the client, screen code depends on a small view-data port. UI-0 provides only a local synthetic adapter. That adapter:

- returns deterministic, non-sensitive examples;
- is excluded from production builds by an explicit build guard;
- cannot send writes;
- cannot accept actor, tenant, capability, repository, placement, or routing claims from the screen; and
- keeps every fixture visibly labelled as synthetic in the rendered experience.

The future generated TypeScript client may replace this adapter only after the public API gate is authorized and its checked OpenAPI contract, page-limit adapter, stable errors, tenant context, and negative contract tests pass. The screen must not import Ash, Ecto, database, or server-internal types.

Do not add browser persistence in UI-0. Theme, context, and fixture state can remain in memory. Authentication, tenant switching, caches, service workers, analytics, realtime, notifications, offline queues, and local storage require their own data and revocation rules.

## Accessibility and responsive acceptance

Use WCAG 2.2 AA as the UI-0 engineering target, while recording that automated checks and a small local review do not certify compliance.

The slice should prove:

- complete keyboard navigation with a visible focus indicator and logical order;
- a useful document title, headings, landmarks, labels, descriptions, and live status semantics;
- status and validation communicated in words as well as colour;
- touch targets of at least 44 by 44 CSS pixels for primary mobile controls;
- no essential interaction that requires hover;
- reflow without two-dimensional page scrolling at 320 CSS pixels, except an explicitly justified data region;
- readable 200% text zoom;
- reduced-motion behaviour; and
- usable layouts at representative narrow, medium, and wide viewports.

## Local human-test plan

The first review can be run by the product owner and collaborators on the local machine. It should be followed by representative school-user sessions before any workflow is called validated.

Ask each reviewer to complete four tasks without coaching:

1. identify which context they are viewing and whether the content is real;
2. locate the primary next step and explain why it has priority;
3. navigate to the UI preview and return using keyboard only; and
4. explain what they would do for a denied, retryable, and conflict state.

Record completion, wrong turns, time, observed confusion, confidence from one to five, keyboard blockers, viewport, and requested changes. UI-0 passes its local human check when:

- every reviewer recognizes synthetic content before attempting an action;
- every task can be completed without developer explanation;
- the median confidence score is at least four out of five;
- there is no critical keyboard, contrast, reflow, or status-comprehension blocker; and
- findings and resulting changes are recorded in a dated evidence note.

These measures validate the shell and language only. They do not validate a school workflow, authorization behaviour, or production readiness.

## Verification contract

The implementation slice should add repository commands with these meanings:

| Command | Contract |
| --- | --- |
| `make web-dev` | Start the local browser workspace with its synthetic adapter |
| `make web-check` | Run format, lint, type, unit, component, accessibility, and production-build checks |
| `make web-e2e` | Start the built app and exercise keyboard, narrow, medium, and wide browser paths |
| `make check` | Include `web-check` and the deterministic browser checks that are suitable for the full repository gate |

Use component tests for behaviour and accessible semantics, a browser runner for navigation/reflow, an accessibility engine for automated violations, and a small set of reviewed screenshots for visual-regression evidence. The exact tools and versions should be pinned during implementation, not guessed in this proposal.

## Proposed repository shape

```text
clients/
└── web/
    ├── app/
    │   ├── page.tsx
    │   └── ui-preview/page.tsx
    ├── src/
    │   ├── components/
    │   ├── fixtures/
    │   ├── ports/
    │   └── styles/
    │       ├── reset.css
    │       ├── tokens.css
    │       ├── base.css
    │       ├── layout.css
    │       ├── components.css
    │       ├── utilities.css
    │       └── states.css
    ├── tests/
    ├── package.json
    └── package-lock.json
docs/
└── phase-1/evidence/local-browser-experience.md
```

This shape is a proposal, not an instruction to create the files before UI-0 is approved.

## Explicit non-goals

UI-0 adds none of the following:

- a Phoenix endpoint, public JSON:API route, or generated production client;
- authentication, session handling, support access, or tenant switching;
- a school business module or authoritative school record;
- authority administration or any other mutation;
- a generic CRUD screen, metadata renderer, report builder, or form generator;
- Expo, React Native, installable PWA behaviour, offline writes, notifications, or device APIs;
- analytics, realtime, search, files, AI, scheduling, or external services; or
- production deployment, hosting, secrets, or real data.

## Delivery sequence after approval

1. Create the isolated browser workspace, local commands, production-build guard, and test baseline.
2. Establish tokens, cascade layers, class-name linting, document defaults, and accessibility primitives.
3. Build the responsive shell and its synthetic view-data adapter.
4. Add the UI-preview route and every required state before adding more content.
5. Verify keyboard, accessibility, build, and representative viewport behaviour in a real browser.
6. Run the local human-test script, record the findings, and make one bounded refinement pass.
7. Review the evidence and decide whether to revise the design foundation, retain it, or remove it before authorizing a real workflow.

## Risks and controls

The strongest objection is that a fixture-backed shell can become polished theatre: attractive, but detached from real school work and server behaviour. Control that risk by keeping UI-0 visibly synthetic, forbidding production API shims, limiting it to the shell and state language, and requiring the next slice to name one authorized workflow with real user research and a real public action contract.

Other risks are controlled as follows:

- **CSS grows into an ungoverned framework:** enforce the small layer and prefix contract; add a primitive only after the second real use.
- **Prototype navigation hard-codes roles:** keep navigation neutral until capability-backed server data exists.
- **Fixture types become a competing API model:** place them behind the view-data port and delete or map them when the checked generated client arrives.
- **Accessibility is claimed from automation alone:** retain keyboard and human checks and label the result as bounded evidence.
- **UI work delays the first governed mutation:** keep UI-0 independent from Slice 1G and prohibit production-core changes in this slice.

## Approval boundary

Approval of this proposal would authorize only UI-0 as described above. It would not authorize a public API, real authentication, a production browser client, a school module, or the first write workflow. Each of those remains a separate reviewed boundary.
