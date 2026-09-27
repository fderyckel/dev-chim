# Experience design system and governed personalization proposal

- Status: Proposed; documentation only
- Proposed boundary: a governed visual-language and personalization foundation for the browser,
  with portable semantics for a future native client
- Owner: Product experience and client engineering
- Proposed date: 2026-09-27
- Review trigger: authorization to replace UI-0 tokens, add persistent user preferences, connect a
  preference screen to the core, or use the system in a public client
- Governing records: [ADR 0019](../adr/0019-domain-model-authoring-and-governed-metadata.md),
  [ADR 0020](../adr/0020-human-interface-experience-and-client-platform-boundary.md), and
  [proposed ADR 0028](../adr/0028-experience-design-system-and-governed-personalization.md)

## Bottom line

Build a strong Chimwemwe-owned design system, not merely a larger stylesheet and not a skin over a
third-party visual framework. It should give every workflow the same hierarchy, surfaces,
controls, status language, accessibility, and recovery behavior. People can then choose among a
small set of complete, tested experience profiles for appearance, font, scale, density, accent,
and motion.

The line is simple:

> People may choose how Chimwemwe feels to them. They may not change what the interface means.

This is how Chimwemwe can offer learner agency while remaining coherent and trustworthy. It also
makes interface development faster: product teams assemble tested components and patterns rather
than deciding title sizes, box styles, colors, spacing, focus, and error presentation on every
screen.

This proposal does not authorize implementation. UI-0 remains local and synthetic, and no
production preference resource, identity path, public interface, or school workflow is added.

## Why the current foundation should evolve

The current UI-0 direction is sound:

- semantic custom properties rather than raw colors in components;
- fixed cascade layers;
- explicit class ownership with `l-`, `c-`, `u-`, `is-`, and `has-`;
- an empty override layer;
- written state language rather than color-only state; and
- keyboard, reflow, reduced-motion, forced-colour, and automated accessibility checks.

It was intentionally a small experience harness. It is not yet the framework required for a
growing product:

- `tokens.css` is the source and runtime output at once;
- the current token set expresses only one light appearance;
- the component layer is one large stylesheet rather than independently owned components;
- screens can still invent combinations of classes without a component API;
- there is no theme-completeness or cross-theme visual-regression gate;
- no typography, density, dark-mode, or high-contrast choice exists; and
- there is no governed persistence or first-paint contract.

The next step should preserve the current contract and strengthen its ownership rather than
replace it with a utility framework.

## Product principles

### 1. Consistency is semantic, not identical pixels

Every supported profile retains the same information hierarchy, component behavior, spacing
rhythm, status meaning, and recovery language. Light and dark surfaces may differ in value; an
attention state is still attention. Browser and future native clients may differ in layout and
interaction while sharing the same semantic vocabulary.

### 2. Choice is curated and complete

A profile is an allowlisted set of compatible decisions, never a bag of arbitrary CSS variables.
Every selectable combination must be complete, contract-tested, and reversible. Canonical and
pairwise combinations are screenshot-tested, with additional risk-based cases for status and
accessibility interactions. Adding a choice is a product release, not a database-only change.

### 3. Accessibility choices outrank branding

Operating-system and browser accessibility settings come first. User contrast, text, and motion
choices come before a tenant's cosmetic default. Tenant branding may influence the default accent
and approved assets, but may not suppress readable modes, redefine critical colors, or remove
focus.

### 4. Components own behavior; tokens own visual decisions

Tokens answer “which approved value expresses this role?” Components answer “how does this control
behave and remain accessible?” Screens answer “how does this workflow help the person finish the
task?” None of those layers authorizes a domain action.

### 5. The default must be excellent without customization

Personalization is not a repair mechanism for a weak base design. The default must be calm,
legible, fast, responsive, and polished before additional choices ship.

## The Chimwemwe visual language

### Hierarchy

Use a small, named type hierarchy:

| Role | Use | Rule |
| --- | --- | --- |
| Display | Rare landing or major context moment | Never substitutes for the page heading |
| Page title | One per page | Maps to the page's `h1` unless document structure requires otherwise |
| Section title | Major region within a page | Keeps a consistent step below the page title |
| Component title | Card, panel, dialog, or table region | Cannot visually compete with the page title |
| Body | Instructions and working content | Default reading style |
| Supporting | Secondary explanation and metadata | Must still meet contrast and zoom requirements |
| Label | Form and data labels | Uses weight and position, not all-caps at small sizes |
| Data | Values, dates, amounts, and identifiers | Uses tabular numerals where comparison matters |

Heading semantics remain correct even when the visual role needs to differ. A `Heading` component
therefore separates document level from visual style rather than encouraging arbitrary font-size
classes.

### Surfaces and boxes

Use only five surface roles:

| Surface | Purpose | Visual treatment |
| --- | --- | --- |
| Canvas | Page background | Quiet, low chroma, no elevation |
| Panel | Groups related work | Border before shadow; comfortable internal rhythm |
| Inset | Secondary or explanatory region | Subtle contrast from its parent |
| Interactive | Clickable/selectable row or tile | Clear hover, focus, selected, and disabled states |
| Overlay | Dialog, popover, or temporary raised layer | Elevation communicates actual stacking only |

Avoid a dashboard made from equal cards. A surface exists because it groups or layers information,
not because a developer wants visual decoration.

### Importance and status

Keep importance separate from status:

- **emphasis** describes visual priority: `quiet`, `standard`, or `strong`;
- **tone** describes meaning: `neutral`, `information`, `positive`, `attention`, or `critical`;
- **interaction state** describes behavior: focused, selected, disabled, loading, pending, saved,
  retryable, conflict, denied, or failed.

The five tones have fixed meaning across every profile. Each uses a foreground, surface, border,
icon, and written label. Accent choices affect primary actions and decorative emphasis only. A red
or amber accent is not offered if it could be confused with critical or attention meaning.

### Spacing, shape, and depth

- Use one four-pixel base rhythm with named semantic spacing aliases.
- Provide comfortable and compact control metrics, but keep required target sizes independent from
  visual density.
- Use a short radius scale. Large novelty radii, pill containers, and mixed corner styles are not
  page-level choices.
- Use borders for grouping and shadows only for true elevation.
- Use motion to explain continuity or state change, not as decoration. Static behavior is the base;
  motion is progressively enabled when the user has not asked to reduce it.

### Default visual direction

The proposed default is “quiet confidence”:

- warm near-white canvas and white working surfaces;
- deep green-charcoal ink rather than pure black;
- restrained teal for primary actions and selection;
- distinct sapphire information, amber attention, and brick critical palettes;
- crisp one-pixel separators, restrained 8–12 pixel radii, and very limited shadow;
- self-hosted [Source Sans 3](https://fonts.adobe.com/fonts/source-sans-3-variable) as the default
  type candidate, with a system fallback and tabular figures;
- compact but not cramped browser information density; and
- one obvious primary action per working region.

The design should avoid glass effects, ornamental gradients, excessive floating containers,
low-contrast grey text, decorative icon noise, and “everything is important” dashboards. Exact
font and color values must be selected through rendered comparison, language coverage and
licensing review, contrast checks, and human evaluation; they are not accepted by this prose
alone.

## Governed experience profiles

### Initial choice set

Start with the smallest useful matrix:

| Axis | Initial choices | Product rule |
| --- | --- | --- |
| Appearance | System, light, dark | System is the default; no flash between server render and hydration |
| Contrast | Standard, high | Both are complete product profiles; forced-colour mode still wins |
| Typography | Source Sans 3, Atkinson Hyperlegible Next, system | The readable candidate was designed for low-vision legibility; all are self-hosted or platform-owned |
| Text scale | 100%, 112.5%, 125% | Works in addition to browser zoom, never instead of it |
| Density | Comfortable, compact | Compact cannot reduce minimum targets or touch usability |
| Accent | Default plus at most three tested families | Changes actions and decorative emphasis, never status semantics |
| Motion | System, reduced | Operating-system reduce always overrides an enabled preference |

Do not launch every axis at once. The first proof should use appearance, typography, and reset;
add contrast, scale, density, and accent only after the test matrix and user evidence show that each
choice helps more than it costs.

[Atkinson Hyperlegible Next](https://www.brailleinstitute.org/freefont/) is the proposed readable
candidate, not a claim that one font is universally best. The preview must let each person judge
it, and the release review must verify the exact license, shipped files, language coverage,
rendering, and performance of both font candidates.

### Preference precedence

From strongest to weakest:

1. browser and operating-system accessibility behavior, including forced colors and reduced
   motion;
2. Chimwemwe accessibility invariants and semantic status meaning;
3. the person's accessibility-related choices;
4. the person's cosmetic choices;
5. the tenant's approved default profile; and
6. the built-in Chimwemwe default.

No role constant controls this. A person may update only their own preference in the active trusted
tenant context. A separately authorized tenant capability controls tenant defaults.

### Safe preference experience

The settings surface should:

- preview the actual components and status tones, not isolated color swatches;
- describe each choice in plain language;
- show light, dark, loading, focus, error, attention, and critical examples;
- apply a preview without saving;
- provide a persistent “Reset to Chimwemwe default” action;
- automatically recover from an obsolete choice; and
- never place save, reset, or recovery behind color recognition alone.

## Technical policy

### One typed token source

Author tokens in a versioned JSON format compatible with the stable
[Design Tokens Community Group 2025.10 format](https://www.designtokens.org/TR/2025.10/format/).
That format supplies typed tokens, aliases, and groups suitable for deterministic portable static
generation. It is a source format, not a runtime dependency and not a W3C Recommendation.

Organize the source as:

```text
clients/web/src/design-system/
├── tokens/
│   ├── reference.tokens.json
│   ├── semantic.tokens.json
│   ├── themes/
│   │   ├── light.tokens.json
│   │   ├── dark.tokens.json
│   │   └── high-contrast.tokens.json
│   └── profiles.json
├── generated/
│   ├── tokens.css
│   ├── themes.css
│   └── profiles.ts
├── components/
├── patterns/
└── tests/
```

Keep the first source inside the authorized browser workspace. Extract a shared package only when
a second real consumer proves the need. This follows the existing rule that a reusable abstraction
must remove measured duplication rather than anticipate it.

### Static generation and checks

The generator should:

1. validate schema, types, names, and allowed units;
2. reject alias cycles and unresolved references;
3. require every theme to define the complete semantic contract;
4. reject raw application colors outside the reference token source;
5. emit stable, sorted CSS custom properties and TypeScript profile identifiers;
6. produce a content revision used for compatibility and drift checks; and
7. fail verification when checked generated output differs from the source.

Use an in-repository generator before adopting a design-token build dependency. A third-party
translator can be considered later if it clearly reduces maintenance and its output is pinned and
reviewed.

### Cascade and selector contract

Adopt this exact layer order:

```css
@layer reset, tokens, themes, base, layout, components, utilities, states, overrides;
```

- `tokens` contains generated product semantics and profile-independent defaults.
- `themes` contains generated, complete profile mappings selected through allowlisted root
  attributes.
- `base` owns document and native-control defaults.
- `layout` owns page and region composition.
- `components` owns one file per shared component family.
- `utilities` remains very small and semantic.
- `states` owns cross-component interaction and response states.
- `overrides` is an audited temporary escape hatch and is empty by default.

Retain the current prefix grammar. Strengthen the style contract to reject:

- raw color, font-family, shadow, radius, motion, or spacing values outside their owned source;
- unknown or unused custom properties;
- incomplete theme token sets;
- inline `style` props except a small documented list for measured geometry;
- direct use of reference palette tokens by product components;
- selectors above the agreed specificity budget;
- deep selectors tied to DOM position;
- `!important`, IDs, and unowned global selectors; and
- application CSS outside the design-system and route-layout ownership paths.

### Component contract

Each shared component owns:

- accessible name, semantics, keyboard behavior, focus, disabled/read-only behavior, and error
  linkage;
- supported semantic variants and invalid combinations;
- responsive and text-scaling behavior;
- every public response state it can display;
- light, dark, high-contrast, reduced-motion, and forced-colour evidence; and
- a documented removal or replacement path.

Component APIs expose meaning, for example:

```tsx
<Notice tone="attention" title="Review before publishing">
  Two records need correction.
</Notice>
```

They do not expose arbitrary visual construction such as `background="#f90"`, `radius={17}`, or
`padding="11px"`. A workflow may use layout primitives and semantic variants; a new product-wide
visual decision first enters the token or component contract.

### Third-party policy

- Do not adopt Tailwind, runtime CSS-in-JS, or a pre-styled component suite as the public visual
  language for this foundation.
- Native CSS capabilities and static generated CSS remain the default.
- A headless behavior/accessibility library may be wrapped for a complex control after native
  semantics and maintained platform primitives are insufficient.
- Product code imports only the Chimwemwe wrapper, never the dependency's styling API.
- Every dependency requires pinned versions, license and supply-chain review, accessibility tests,
  bundle measurement, and an exit path.

## Ash alignment

The product's visual source remains code-owned. Ash supplies durable, governed preference state
only after production identity and interface work is authorized.

### Proposed resources

| Resource | Ownership | Stores | Must not store |
| --- | --- | --- | --- |
| `TenantExperiencePolicy` | Tenant | Default cosmetic identifiers, optional reviewed brand-profile ID, and compatible manifest revision | CSS, token values, selectors, font URLs, arbitrary JSON, disabled product accessibility choices |
| `ActorExperiencePreference` | Tenant and actor | Selected identifiers and optimistic version | Role assertions, tenant selection, CSS, uploaded assets |

The exact names remain provisional until the implementation slice is authorized.

### Proposed named actions

- `set_tenant_experience_defaults`: separately capable tenant administration action;
- `update_my_experience_profile`: current actor updates only their own allowlisted identifiers;
- `reset_my_experience_profile`: removes actor selections and returns to the governed defaults; and
- `resolve_my_experience_profile`: returns one complete normalized profile for the trusted actor
  and tenant.

Each action validates the trusted context before input, resolves identifiers against the
code-owned current manifest, uses optimistic concurrency where state changes, and returns stable
non-disclosing errors. Any durable invalidation or cross-device synchronization effect records a
minimal transactional-outbox fact. Presentation choices never grant an action, field, module,
tenant, unit, report, or record.

### First paint and storage

After production sessions exist, the server resolves the complete profile before rendering the
document root and emits only stable attributes such as `data-theme="dark"` and
`data-typeface="readable"`. The CSS for every released profile ships with the application.

A versioned cookie or local value may later be evaluated as a paint hint, but only if it contains
allowlisted profile IDs, no actor or tenant identifier, no arbitrary values, and no authority. The
server response remains authoritative and corrects stale hints. Until that boundary is approved,
UI-0 keeps preferences in memory and visibly synthetic.

## Quality gates

### Machine-enforced design contract

Every design-system change must pass:

- token schema, alias, completeness, and generated-output drift checks;
- Stylelint and the repository style contract;
- TypeScript component API and invalid-variant tests;
- automated contrast checks for every text, control, focus, and status pairing in every profile;
- component interaction and accessibility tests;
- screenshot comparisons for canonical and pairwise profile combinations at narrow, medium, and
  wide viewports, plus risk-based combinations for status and accessibility interactions;
- the production build without runtime theme fetching or network font dependency; and
- bundle, CSS size, and font-size budgets with changes reported rather than hidden.

### Accessibility acceptance

WCAG 2.2 AA is the release floor, not the ambition ceiling. The system should also target:

- 7:1 body-text contrast in the default profile where it does not distort status meaning;
- a highly visible focus indicator meeting the WCAG 2.2 Focus Appearance geometry and contrast
  target even though that criterion is AAA;
- useful reflow at 320 CSS pixels and at 400% zoom;
- no loss under the WCAG text-spacing override;
- primary touch targets of at least 44 by 44 CSS pixels, with WCAG 2.2's minimum as the floor for
  exceptional dense controls;
- full keyboard operation and no focus obscured by sticky regions;
- screen-reader checks for component semantics and dynamic status;
- forced-colour and high-contrast operation;
- color-independent meaning; and
- motion disabled or reduced when requested.

[WCAG 2.2](https://www.w3.org/TR/WCAG22/) supplies the normative accessibility baseline. W3C also
documents that people may need to customize fonts, colors, spacing, and brightness, and that
`prefers-reduced-motion` can honor a platform request. Those standards guide checks; they do not
replace testing with people.

### Visual-quality acceptance

Automation cannot certify “classy.” Require a product-design review against rendered pages, not
token swatches, for:

- hierarchy visible within five seconds;
- one clear next action;
- calm density without wasted space;
- consistent alignment and rhythm;
- no accidental competing emphasis;
- coherent states across tables, forms, dialogs, notices, and empty/error screens;
- appropriate narrow-screen recomposition rather than desktop compression; and
- no visible first-paint theme or font jump.

Review three reference flows before calling the system credible:

1. one dense browser workflow with search, filters, rows, and batch review;
2. one focused narrow workflow with short input and immediate status; and
3. one correction/recovery workflow showing validation, conflict, retry, denied, and success.

These may remain neutral synthetic scenarios until a business workflow is separately authorized.

### Human evidence

Run sessions with representative learners, school staff, and people using at least keyboard,
screen magnification, reduced motion, high contrast, and a readability-focused type choice. Measure
task completion, time, wrong turns, comprehension of status, preference discovery, successful
reset, confidence, and visual comfort. Record disliked and rejected variants as evidence rather
than retaining every choice.

## Bounded delivery sequence

### DS-0 — Decision and baseline

- Review proposed ADR 0028 and this plan.
- Inventory current tokens, selectors, components, duplicate declarations, raw values, and visual
  regressions.
- Capture current UI-0 screenshots as migration evidence, not as the desired final target.
- Choose named owners for visual design, accessibility, component engineering, and release review.

**Exit:** the semantic vocabulary, default visual brief, initial choice axes, and ownership are
approved. No runtime change is needed.

### DS-1 — Token compiler and default parity

- Introduce the typed token source and deterministic browser generator.
- Generate the existing default profile first.
- Add the `themes` layer while preserving current UI-0 rendering through compatibility aliases.
- Extend style checks for raw values, theme completeness, and drift.

**Exit:** the default UI is visually equivalent or intentionally reviewed, the generated output is
reproducible, and no preference UI or core resource exists.

### DS-2 — Component ownership and visual refinement

- Split the component stylesheet into owned component families.
- Introduce semantic React component APIs for the smallest repeated set.
- Refine the default through rendered page comparisons.
- Use `/ui-preview` as the living specimen; do not add Storybook until a second consumer or
  documentation need justifies its operating cost.

**Exit:** Home, UI preview, and one neutral dense reference page use the shared components without
route-local visual invention.

### DS-3 — Local governed-choice proof

- Add dark and one readability-focused profile.
- Add an in-memory preference preview and reset to UI-0 only.
- Test the complete matrix, first paint, keyboard behavior, forced colours, zoom, and reduced
  motion.
- Run the first representative human sessions and remove weak options.

**Exit:** supported choices are complete and improve user outcomes. The proof remains synthetic and
non-persistent.

### DS-4 — Production preference boundary

Only after production identity, public interface, and the first relevant workflow are separately
authorized:

- add the tenant and actor preference resources;
- add the named update, reset, default, and resolution actions;
- add a versioned public contract and generated client types;
- server-render the resolved profile before first paint; and
- prove tenant isolation, self-only writes, stale-manifest fallback, revocation, cache behavior,
  and cross-device convergence.

**Exit:** durable preference state is production-qualified. This slice must not also introduce
arbitrary tenant branding or a new business module.

### DS-5 — Second-client portability

When a native client is separately justified, generate platform-native semantic token output and
validate the same vocabulary on native components. Extract a shared package only then. Do not force
the browser component tree or layout into the native client.

## Acceptance matrix

| Concern | Required proof |
| --- | --- |
| Consistency | Every reference flow uses named hierarchy, surface, emphasis, tone, and state roles |
| Choice safety | All selectable profiles are complete; status meaning and focus do not vary |
| Default quality | Product-design review and representative task evidence for the default |
| Accessibility | WCAG 2.2 AA floor plus declared stronger focus, zoom, target, color, and motion checks |
| Agility | A reference workflow is assembled without new raw tokens or route-local component CSS |
| Portability | Token source generates deterministic browser assets without browser semantics in token names |
| Security | No arbitrary CSS/code/URLs; fonts and assets are owned; identifiers are allowlisted |
| Tenancy | Future preference reads/writes require trusted actor and tenant; cross-tenant and other-actor tests deny |
| Recovery | Unknown, removed, partial, or stale profile selection falls back before rendering a broken UI |
| Performance | No network theme fetch; font and CSS budgets are measured; no first-paint profile flash |

## Explicit non-goals

This proposal does not authorize:

- a production UI, public preference API, identity/session integration, or persistent preference;
- a school business module or authoritative school record;
- arbitrary tenant CSS, user CSS, raw colors, theme JSON, font uploads, icon uploads, or remote
  assets;
- a visual theme builder, marketplace, page builder, universal form renderer, or metadata-driven
  workflow engine;
- role-name-driven navigation or personalization;
- Tailwind, runtime CSS-in-JS, a pre-styled component suite, or Storybook as a foundation
  dependency;
- a native client, PWA, offline preference synchronization, analytics, or third-party design tool
  integration; or
- a claim that token checks or automated accessibility tests prove excellent design.

## Main risks and controls

| Risk | Control |
| --- | --- |
| Choice explosion | Start with three axes, cap choices, require matrix cost in every proposal |
| Inconsistent status meaning | Keep tone tokens product-owned and outside accent profiles |
| Attractive but unusable system | Validate complete task flows with representative people |
| CSS becomes another ungoverned framework | Enforce layers, ownership, component APIs, and empty overrides |
| Ash becomes a presentation engine | Store only stable profile IDs; keep token values and rendering in code |
| Tenant branding harms accessibility | Accessibility choices and product invariants outrank tenant defaults |
| First-paint flash | Resolve server-side and ship all released profile CSS statically |
| Font privacy or availability | Self-host reviewed fonts; no runtime external font calls |
| Vendor lock-in | Own tokens and component APIs; wrap optional headless behavior dependencies |
| Design stagnation | Version tokens, keep review triggers, and use user evidence to retire weak choices |

## Approval boundary

Approval of this proposal should first authorize only DS-0: accountable review of the visual
language, token contract, preference axes, quality gates, and ownership. DS-1 and each later slice
need explicit authorization. In particular, this proposal does not authorize durable preferences
or a production browser connection.
