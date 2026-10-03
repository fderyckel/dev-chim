# DS-3 design-system governed-choice technical evidence

- Status: Technical proof implemented with focused local verification; representative human
  evidence remains open, and the required repository-wide check is blocked by stale
  clean-checkout rehearsal evidence
- Review disposition: Revised profiles approved by the product owner on 2026-10-03 to advance to
  representative testing; they are not yet accepted as final public choices
- Owner: Product experience and web engineering
- Evidence date: 2026-10-03
- Governing records: [proposed ADR 0028](../../adr/0028-experience-design-system-and-governed-personalization.md), the [experience design-system proposal](../../plans/experience-design-system-and-governed-personalization-proposal.md), and [ADR 0020](../../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- Review trigger: representative session findings, a profile addition or removal, a font asset,
  persistence, a core connection, a public client, or a change to profile precedence

## Authorization and boundary

The 2026-10-03 next-slice instruction authorizes DS-3's local governed-choice proof: one dark
profile, one readability-focused profile, an in-memory preview and reset, the complete technical
matrix, and rendered review. It does not authorize DS-4.

This slice adds no cookie, browser storage, remote font, preference resource, Ash action,
authentication path, API, production data, school module, or public deployment. Leaving or
reloading UI preview returns to the built-in default. ADR 0028 remains Proposed.

## Three complete profiles

The deterministic source now compiles 101 reference tokens and the same 30-token semantic contract
for three allowlisted profile identifiers:

| Profile       | Purpose                       | Typography                                                                       | Appearance                                                                |
| ------------- | ----------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Quiet Light   | Built-in Chimwemwe default    | Standard system interface stack and scale                                        | Warm near-white canvas, white surfaces, restrained teal                   |
| Calm Dark     | Low-glare alternative         | Same hierarchy and type scale as the default                                     | Neutral midnight canvas, quiet cornflower-blue action, fixed status tones |
| Clear Reading | Readability-focused candidate | Platform-owned Verdana/Arial fallback stack, larger scale, and 1.72 copy leading | Muted paper canvas, softened state surfaces, strong text contrast         |

Every profile supplies all color, type-family, type-scale, and line-height roles. Status meaning is
fixed: neutral, information, positive, attention, and critical remain written and use the same
semantic role names in every profile. The compiler still rejects incomplete profiles, changed
token types, unsafe CSS extensions, unresolved aliases, cycles, and generated-output drift.

No downloaded font is included. Clear Reading deliberately uses a platform-owned stack until an
exact self-hosted font, license, language coverage, rendering, and performance review is separately
completed.

## Preview, reset, and first paint

The UI-preview route renders the real shell, panels, actions, form controls, public states, and all
five status tones around one native radio group. Selecting a profile applies only its generated ID
to the document root. A visible reset returns to Quiet Light. Selection cleanup removes the ID when
the component unmounts, and browser tests prove that reload, navigation, local storage, session
storage, and cookies retain nothing.

The built-in default remains the generated `:root` contract. A JavaScript-disabled production
browser renders the complete Quiet Light page with no theme attribute, proving that hydration is
not required for the first paint. Profile changes suppress component transitions for one atomic
style recalculation, preventing a temporary mixture of old and new palette values.

## Accessibility and interaction matrix

The 30-case UI-0 browser suite exercises wide, medium, and 320-pixel viewports. At each viewport it
proves keyboard selection and reset, non-persistence, automated accessibility for all profiles,
forced-colour operation, reduced-motion animation suppression, JavaScript-free default paint, and
reflow. The 320 CSS-pixel check is the layout-equivalent proxy for a 1280-pixel viewport at 400%
browser zoom; it is not a claim that every browser/operating-system zoom combination was manually
tested.

The first matrix pass found two defects and drove repairs:

- profile switching allowed existing hover transitions to mix old and new palettes briefly, so
  the change is now atomic; and
- the existing generic reduced-motion rule did not override the spinner's more-specific animation,
  so the loading animations now receive an explicit reduced-motion override.

All three final profiles pass the living-specimen Axe scan at all three viewports. The profile
chooser remains a native fieldset/radio interaction with a visible focus treatment and does not
depend on colour to communicate selection.

## Rendered review

Nine production-build screenshots were reviewed. The first six cover each profile at wide and
narrow page viewports; the last three bring the profile controls themselves into the narrow
viewport. They are transient review artifacts rather than committed golden files.

| Profile and viewport              | SHA-256                                                            |
| --------------------------------- | ------------------------------------------------------------------ |
| Quiet Light, 1440 by 1200         | `6e463776d4a8ebb21530d5faa5d5eba5b92dfe47ee6d714bac79f804b8420a51` |
| Calm Dark, 1440 by 1200           | `21630064ccea63dd48d9d4c849ac8fefc20ac0ca8d02d62aa087efb18e3151b8` |
| Clear Reading, 1440 by 1200       | `37731392159eb5afc17bf80679bc1fc513371165f687f8986c6720f0e241a70b` |
| Quiet Light, 320 by 900           | `a93032751aa4354df27195c9e5edaf94235ba5a987b6a54fb9c8325a8716e446` |
| Calm Dark, 320 by 900             | `543d4cb70c74d6d12cd262b17f2d1b7ef7381ce879e5af9c37707183aace422c` |
| Clear Reading, 320 by 900         | `6f59e56db9c378ad1b94b0fda4f968f10244310385f97c9ffbe43eda5c889316` |
| Quiet Light chooser, 320 by 900   | `8c6306b24e4c04a61adc575c84aa0dc246d0349054d4258288d0db18e98d273e` |
| Calm Dark chooser, 320 by 900     | `737bd5c0696a61e14d0e63a4d7ac395191d5dc0f6d137d61d0928ff3759174ac` |
| Clear Reading chooser, 320 by 900 | `c8db66b33c380aa6ff03deed0f3a289b6fe12f3ec0fc37e71ba9c0a8fda8014c` |

The first owner review rejected Clear Reading as too bright and Calm Dark as too green. The second
rendered pass replaced pure-white reading surfaces with a muted warm-paper range, softened its
large state surfaces, and moved the dark foundation to neutral midnight/graphite with a restrained
cornflower-blue accent. Semantic positive green remains confined to positive status meaning. The
product owner approved the revised profiles on 2026-10-03 to advance to representative testing.
The revised review found a coherent default, a calmer reading alternative, and a more refined dark
alternative without route-local styling or changed semantic emphasis. This approval covers owner
and product-design review of the rendered local specimen, not representative-user acceptance.

## Verification

Focused verification passed:

- generated output is current at revision
  `sha256:68edef14420daf28877107a9fd4289b92b6aaf38d2950f30961e908566ebceaf`;
- ESLint, Stylelint, TypeScript, and the eight-layer CSS contract with 131 owned properties pass;
- eight generator tests and 24 unit tests pass;
- the guarded production build emits the existing five routes;
- all 30 UI-0 browser cases, six connected UI-1A cases, and one unavailable-state case pass;
- the production-dependency audit reports zero vulnerabilities;
- shell tooling and Git whitespace checks pass; and
- the uncompressed production static output contains 42,222 bytes of CSS and 589,648 bytes of
  JavaScript, 631,870 bytes combined, with no bundled font file. No reliable pre-DS-3 production
  artifact was retained for a byte-delta comparison, so only the current measured size is claimed.

The all-dependency browser audit remains red on `GHSA-vfj7-8cjw-p6xm`, the same high-severity
`braces` development-tool advisory recorded by DS-1. The registry still offers no patched
`braces` release and proposes only a breaking `stylelint@7.7.0` downgrade, so no forced downgrade
was applied.

The required repository-wide `make check` was attempted after the focused checks. It stopped in
the first documentation stage because the repository reports that its clean-checkout rehearsal is
stale or did not preserve a clean pass. Later Phase 0, core, and integrated web stages did not run
in that invocation. The repository must not be described as green.

## Open representative-human gate

No learner, school staff member, screen-magnification user, high-contrast user, or person choosing
readability-focused type was represented by the automated or internal rendered review. DS-3's
outcome exit therefore remains open.

The first sessions should ask participants to find the chooser, compare the three profiles,
distinguish information/attention/critical meaning, complete a recovery-state task, reset to the
default, and explain whether the choice was saved. Record task completion, time, wrong turns,
status comprehension, preference discovery, reset success, confidence, visual comfort, and any
disliked or rejected profile. Weak profiles should be changed or removed rather than retained to
create an illusion of choice.

DS-4 requires separate authorization even after those sessions. Human evidence does not itself
authorize persistence, production identity, an Ash resource, a public API, or a production client.
