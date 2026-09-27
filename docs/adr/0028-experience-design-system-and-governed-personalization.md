# ADR 0028: Experience design system and governed personalization

- Status: Proposed
- Date: 2026-09-27
- Accountable owner: Product experience and client engineering
- Deciders: Product owner, product experience, accessibility ownership, platform engineering, and security architecture
- Supersedes: None

## Context

People experience Chimwemwe through its interface, not through its internal architecture. The
interface therefore needs a product-owned visual language that can remain coherent across school
workflows while still giving people, especially learners, meaningful control over how the product
looks and feels to them.

UI-0 already proves a useful local foundation: semantic CSS custom properties, fixed cascade
layers, owned class prefixes, explicit interface states, accessible reflow, and an empty override
layer. It is nevertheless a synthetic browser harness, not a production design system. Its current
token file is hand-authored CSS, its component stylesheet has grown with the prototype, and it has
no contract for dark mode, typography choices, user preferences, tenant defaults, portable token
generation, theme completeness, or visual regression across choices.

Unbounded theming would solve the wrong problem. Arbitrary CSS, user-supplied colors, font URLs,
or per-tenant component overrides could make warning and error meaning inconsistent, damage
accessibility, introduce content or network dependencies, and make every screen combination a
separate product to test. A completely fixed appearance would preserve consistency but would deny
users useful control over contrast, brightness, typography, text size, density, and motion.

This decision defines the stable boundary between product-owned meaning and governed visual
choice. It does not authorize a production client, identity path, preference resource, public API,
or school workflow.

## Decision drivers

- A clear, crisp, calm, and recognizably Chimwemwe default experience.
- Consistent hierarchy, components, status meaning, recovery behavior, and accessibility across
  every supported appearance.
- Meaningful learner and user choice without arbitrary styling or a combinatorial test surface.
- One portable design vocabulary without forcing browser and future native clients into one
  component tree.
- Fast workflow delivery through reusable, well-documented components and patterns.
- Static, inspectable output with no runtime CSS engine or remote theme execution.
- A governed preference boundary that fits Ash named actions, tenant context, and server-owned
  authority.
- A reversible path that does not make a styling framework or component vendor the source of
  Chimwemwe's product language.

## Considered options

1. Evolve the owned semantic CSS contract into a token-compiled design system with curated user
   profiles and Ash-governed preference identifiers.
2. Adopt a utility-first CSS framework as the visual system and allow screens to compose their
   appearance directly from utilities.
3. Adopt a pre-styled component library and customize its theme as Chimwemwe's product language.
4. Permit arbitrary tenant or user CSS, raw color values, font uploads, or unrestricted theme
   objects.
5. Keep one fixed appearance with no user-controlled visual preferences.

## Proposed decision

Adopt option 1: evolve the existing owned semantic CSS contract into the Chimwemwe experience
design system. Keep the decision Proposed until the linked evidence gates pass.

### Product-owned meaning

Chimwemwe owns one semantic vocabulary across every supported appearance:

- hierarchy roles such as page title, section title, field label, supporting copy, and data value;
- surfaces such as canvas, panel, inset region, raised overlay, and interactive row;
- action roles such as primary, secondary, quiet, and destructive;
- status tones `neutral`, `information`, `positive`, `attention`, and `critical`;
- focus, selected, disabled, loading, empty, denied, retryable, conflict, and error behavior; and
- spacing, target size, radius, border, elevation, motion, and responsive rules.

A user's accent or font choice must not redefine a critical state, turn an error into a decorative
accent, alter heading order, hide focus, remove written status, or change component behavior.
Color remains redundant with text, iconography, position, and accessible semantics.

### Token architecture

Use a versioned, typed token source compatible with the Design Tokens Community Group 2025.10
format. The source separates:

1. **reference tokens**: product-owned palette and raw scales;
2. **semantic tokens**: roles such as text, surface, action, border, focus, and status;
3. **component tokens**: exceptional stable mappings used by a named shared component; and
4. **experience profiles**: allowlisted aliases selecting complete semantic token sets.

Only generated static assets are consumed at runtime. The browser output is CSS custom
properties; a typed manifest supplies valid profile identifiers to TypeScript. A future native
client may add a platform-specific generated output from the same semantic source without sharing
the browser component tree. Token generation must be deterministic and drift-checked.

The browser cascade becomes:

```css
@layer reset, tokens, themes, base, layout, components, utilities, states, overrides;
```

The current `l-`, `c-`, `u-`, `is-`, and `has-` class grammar remains. Product CSS consumes only
semantic or approved component tokens. Raw colors, undeclared custom properties, ID selectors,
`!important`, positional meaning, unreviewed inline styles, and application-level styling outside
the owned layers fail the style contract. The `overrides` layer remains empty by default; every
temporary exception requires an owner, reason, removal condition, and regression test.

### Components and workflow patterns

CSS tokens are necessary but not sufficient. The design system also owns accessible React
components and documented product patterns:

- foundations: type, color, spacing, focus, iconography, motion, and responsive behavior;
- primitives: text, heading, link, button, field, select, checkbox, badge, notice, surface, divider,
  stack, and grid;
- composite components: page heading, action bar, form section, data row, empty state, dialog,
  table shell, pagination boundary, and recovery panel; and
- workflow patterns: review and confirm, correction, conflict recovery, pending/saved/failed
  state, and dense browser comparison.

Components expose semantic variants such as `tone="critical"` or `emphasis="strong"`, not raw
color, shadow, radius, or padding props. Product screens compose supported components and layout
primitives. A headless accessibility primitive may be wrapped after a concrete need is proven,
but its DOM, behavior, version, and exit path remain owned. A utility framework or third-party
visual library does not become the public styling API.

### Governed user choice

The initial supported preference axes are deliberately finite:

- appearance: `system`, `light`, or `dark`;
- contrast: `standard` or a product-tested high-contrast profile;
- typography: the Chimwemwe default, one readability-focused self-hosted family, or the system
  UI family;
- text scale: a small allowlisted scale that does not interfere with browser zoom;
- density: `comfortable` or `compact`, where the workflow and input method permit it;
- accent family: a small curated set that changes actions and decorative emphasis but never
  status meaning; and
- motion: `system` or `reduced`, with an operating-system reduced-motion request always winning.

Forced-colour mode, browser zoom, user styles, and platform accessibility settings remain
supported. A tenant may choose a default and may add a reviewed brand profile, but cannot disable
product accessibility choices or replace semantic status colors. Every preference screen provides
a live preview, plain-language description, immediate reset, and a safe default.

Resolution order is explicit: user-agent and operating-system accessibility requirements, product
accessibility invariants, the user's accessibility choices, the user's cosmetic choices, the
tenant default, then the Chimwemwe default. Unsupported, incomplete, stale, or invalid selections
fall back to the last compatible profile or the Chimwemwe default; they never produce partially
styled screens.

### Ash and server boundary

The design-token manifest remains code-owned client architecture. Ash does not store CSS, token
values, selectors, arbitrary JSON theme objects, font files, font URLs, or component definitions.

When production identity and interface gates permit implementation, add only bounded tenant-owned
preference state:

- a tenant experience policy containing stable default cosmetic identifiers and any separately
  reviewed tenant-brand profile identifier, without disabling product accessibility choices;
- an actor experience preference containing that actor's selected identifiers in the current
  tenant context; and
- named actions to update, reset, and resolve the current actor's experience profile.

Every action requires trusted actor and tenant context, accepts only product identifiers from the
current code-owned manifest or a currently compatible reviewed tenant-brand profile, and fails
closed for stale or unknown values. No role name decides who may personalize their own experience.
Tenant default administration uses a separate capability; it does not grant access to another
actor's preference record.

The server resolves a complete profile and renders only allowlisted profile attributes on the
document root before first paint. Browser storage or a cookie may later serve only as a versioned,
non-authoritative paint hint after its privacy and revocation rules are approved. It never carries
tenant authority or arbitrary CSS. Any cross-device cache invalidation or asynchronous preference
effect uses the platform's transactional outbox contract.

### Default visual direction

The default is restrained and school-neutral: a warm near-white canvas, quiet white surfaces, deep
ink text, a restrained teal action color, separate blue information, amber attention, and brick
critical tones, one-pixel borders, modest radii, and shadow only when elevation communicates
layering. The default type candidate is self-hosted Source Sans 3, with tabular numerals and the
system stack as fallback; the readability profile candidate is Atkinson Hyperlegible Next.
Headings rely on weight, size, and space rather than novelty. Pages have one obvious primary
action, limited simultaneous emphasis, and fewer purposeful surfaces rather than a wall of equal
cards.

The final font files, theme values, and component details require license review, contrast checks,
rendered prototypes, and representative user judgment. This ADR records the direction, not a claim
that the present UI already meets it.

## Consequences

### Positive

- Users gain real control without losing a stable product language.
- Workflow teams can move faster with tested components and recovery patterns instead of restyling
  each page.
- Static generated themes remain inspectable, cacheable, CSP-compatible, and portable.
- Browser and future native clients can share semantic decisions while retaining device-appropriate
  layouts and interactions.
- Ash governs durable choices through familiar named actions without becoming a CSS or rendering
  engine.

### Negative

- Every additional profile axis multiplies the visual and accessibility test matrix, so choices
  must remain few and evidence-backed.
- Token generation, component documentation, screenshot baselines, and governance add ongoing
  product work.
- A custom visual system requires design ownership; engineering rules cannot decide whether an
  experience feels excellent.
- Some tenant branding requests will be rejected because they would weaken consistency,
  accessibility, or maintainability.
- Existing UI-0 CSS must be split and migrated rather than treated as the final component system.

## Security, privacy, operability, and migration effects

No profile may include executable code, HTML, selectors, external URLs, uploaded fonts, data URLs,
or arbitrary CSS values. Fonts and icons are code-owned, licensed, self-hosted, subset where
appropriate, and covered by the content-security policy. Theme attributes are inert allowlisted
identifiers and do not grant authority.

Preference records are tenant-qualified and actor-qualified. Reads and writes re-enter the named
domain boundary. Telemetry uses approved low-cardinality profile identifiers only when needed and
does not include child data, labels, user-supplied CSS, or unrestricted preference payloads.

Theme generation rejects incomplete semantic token sets, alias cycles, unsupported values, and
contrast failures. Releases retain a compatibility map for renamed profile identifiers and a
deterministic default for removed profiles. A theme failure must not block sign-in, recovery, or a
critical workflow; the server can fall back to the built-in default without a database migration.

The existing UI-0 stylesheet remains in place until a bounded migration is authorized. Migration
is expand-and-contract: introduce generated tokens and compatibility aliases, migrate components,
prove all supported profile matrices, then remove old aliases. Do not combine the migration with a
new school workflow or production identity boundary.

## Validation evidence

Current evidence proves only the UI-0 CSS and accessibility contract recorded in the
[local browser evidence](../phase-1/evidence/local-browser-experience.md). The
[DTCG 2025.10 format](https://www.designtokens.org/TR/2025.10/format/) is a stable Community Group
report for interoperable typed token data; it is not itself proof that a Chimwemwe token compiler
or theme is correct. [WCAG 2.2](https://www.w3.org/TR/WCAG22/) is the minimum conformance baseline,
while representative human use, platform accessibility settings, and visual review remain
necessary.

Before acceptance, the linked proposal requires:

1. a deterministic token source and generated-output drift check;
2. a complete semantic-token matrix for every supported profile;
3. visual regression and interaction checks across supported profiles and representative
   viewports;
4. WCAG 2.2 AA checks plus the stronger focus, contrast, zoom, text-spacing, forced-colour, and
   reduced-motion targets declared by the proposal;
5. at least one dense browser workflow, one narrow task workflow, and one error/correction flow
   composed from the system without local visual invention;
6. representative sessions including learners and users with accessibility needs, with findings
   and changes recorded; and
7. a security review of the manifest, generated assets, font supply chain, profile bootstrap, and
   future persistence boundary before a public client uses it.

## Fallback and exit cost

If the portable token format or generator costs more than it removes, retain the same semantic
contract in reviewed CSS custom properties and typed profile constants. If owned component
maintenance becomes disproportionate, wrap a selected headless accessibility library behind
Chimwemwe components without ceding visual tokens or product semantics.

If personalization harms comprehension, performance, or accessibility, reduce or remove the
affected preference axis while retaining the stable default and compatibility mapping. Preference
records contain only stable identifiers, so rollback does not require interpreting or migrating
arbitrary CSS.

## Review triggers

- A supported profile changes the meaning or visibility of a status, action, focus, or error.
- A tenant asks for arbitrary CSS, custom font or icon uploads, raw colors, or per-component
  overrides.
- A second client requires portable tokens and exposes a semantic mismatch with the browser.
- A theme or font materially worsens task completion, accessibility, rendering performance, or
  first-paint stability.
- A component library or styling dependency becomes difficult to wrap, test, patch, or replace.
- Experience metadata begins to control authorization, workflow meaning, or executable rendering.

## Related records

- [Experience design-system proposal](../plans/experience-design-system-and-governed-personalization-proposal.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [ADR 0020](0020-human-interface-experience-and-client-platform-boundary.md)
- [ADR 0027](0027-production-identity-session-and-support-access.md)
- [UI-0 proposal](../plans/local-browser-experience-foundation-proposal.md)
- [Threat model](../security/threat-model.md)
