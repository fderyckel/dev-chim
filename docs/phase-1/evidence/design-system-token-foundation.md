# DS-1 design-system token foundation evidence

- Status: Implemented with focused local verification; the repository-wide gate is blocked by an
  unpatched development-tool advisory
- Owner: Product experience and web engineering
- Evidence date: 2026-10-03
- Governing records: [proposed ADR 0028](../../adr/0028-experience-design-system-and-governed-personalization.md), the [experience design-system proposal](../../plans/experience-design-system-and-governed-personalization-proposal.md), and [ADR 0020](../../adr/0020-human-interface-experience-and-client-platform-boundary.md)
- Review trigger: a second profile, font asset, preference control, component migration, browser
  persistence, core connection, public-client use, or a change to the semantic token contract

## Authorization and boundary

The 2026-10-03 implementation instruction authorizes only DS-1: typed design-token source,
deterministic browser generation, the `themes` cascade layer, stronger style enforcement, and
default-profile visual parity.

This slice does not add a dark, high-contrast, typography, scale, density, accent, or motion
choice. It adds no preference screen, browser persistence, font file, third-party styling
dependency, core resource, Ash action, authentication path, API, production data, school module,
or public deployment. ADR 0028 remains Proposed.

## Implemented contract

The browser workspace now has three reviewed source documents:

- `reference.tokens.json` owns 55 raw palette and foundation tokens;
- `semantic.tokens.json` owns the complete 21-token meaning contract for the default light
  profile; and
- `profiles.json` allowlists the profile identifier, label, color scheme, and source document.

The source declares the pinned DTCG 2025.10 format. The repository-owned generator validates the
supported typed subset, safe names and units, aliases, alias types, cycles, CSS-name collisions,
profile completeness, and restricted CSS escape values. It emits stable, sorted `tokens.css`,
`themes.css`, and typed `profiles.ts` artifacts plus a SHA-256 content revision. Check mode fails
when any generated artifact differs from its source.

The canonical cascade is now `reset`, `tokens`, `themes`, `base`, `layout`, `components`,
`utilities`, `states`, then the reserved empty `overrides` layer. The style contract reads the
generated files, rejects custom-property ownership outside `tokens` and `themes`, rejects raw
colors outside reference tokens, rejects direct palette use by product styles, and still rejects
unknown properties and classes outside the ownership grammar.

## Negative and drift evidence

Seven focused generator tests pass. In addition to stable generation, they prove rejection of:

- a profile missing a required semantic token;
- an alias cycle;
- an unresolved alias;
- an alias that changes token type; and
- an unsafe CSS extension containing a network URL; and
- an unsafe font-family value.

The normal browser lint gate runs generated-output drift detection before JavaScript, CSS, and
style-contract checks. No runtime token compiler or theme fetch was introduced.

## Exact default parity

Three production-build screenshots were captured before and after the migration with identical
routes, viewports, and timing. Each pair is byte-identical:

| Route and viewport | SHA-256 before and after |
| --- | --- |
| Home, 1440 by 1000 | `60044db07737442fb777a84a311de7dd104d22ebf61faf43a14c75c7e985de32` |
| UI preview, 1440 by 1200 | `8a521d77abddb8ab14d8016552eb985d59cfaab214aa5cda0c84177cf4ee9f59` |
| Institutional structure, 320 by 900 | `15bed397702cc29052aef3a474a85d1566e09dd2cb58b266ea6cea2b265d3dcb` |

This proves exact output parity for these representative static states. It does not prove the
quality of a future visual refinement, another profile, every interaction state, or representative
human preference.

## Verification

The browser `npm run check` gate passed with:

- generated-output drift detection;
- ESLint, Stylelint, and the eight-layer CSS contract with 76 owned properties;
- TypeScript checking;
- seven token-generator tests;
- 21 browser unit tests; and
- the guarded production build.

The repository-wide `make check` was attempted twice and is not green:

1. The first run stopped on a high-severity `brace-expansion` advisory in the existing Phase-0
   TypeScript review lock. A compatible lock-only refresh from 2.1.4 to 2.1.7 removed that
   advisory, and its all-dependency audit then passed.
2. The second run passed documentation, Phase 0, repository-tool, and production-core gates, then
   stopped at the web all-dependency audit. The registry reports
   `GHSA-vfj7-8cjw-p6xm` against every published `braces` release through 3.0.3. It enters through
   the existing Next ESLint and Stylelint development toolchains. No fixed release is published,
   and the registry's proposed `stylelint@7.7.0` downgrade is breaking, so it was not applied.

The web production-dependency audit reports zero vulnerabilities. Because the mandatory gate also
audits development dependencies, this repository must not be described as green until the upstream
toolchain has a safe resolution or the audit policy is separately reviewed. After the audit
stopped the integrated run, the 15 UI-0 browser cases, six connected UI-1A browser cases, one
UI-1A unavailable-state case, and the remaining shell-tooling gate were run directly and passed.

## Remaining gates

DS-2 requires separate authorization before component ownership or visual refinement. DS-3
requires separate authorization before any additional local profile or in-memory choice UI. The
profile matrix, contrast analysis, cross-profile screenshots, font licensing and language review,
representative learner and accessibility sessions, first-paint proof, and security review remain
open before ADR 0028 can be accepted or any choice can enter a public client.
