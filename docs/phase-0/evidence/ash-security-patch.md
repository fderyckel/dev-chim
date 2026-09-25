# Ash security-patch reviews

- Status: Current candidate passes focused regression and both Hex audits; complete verification pending
- Owner: Platform engineering
- Latest review: 2026-09-25
- Machine record: [`ash-security-patch.json`](../../../spikes/ash-foundation-lab/priv/maintenance/ash-security-patch.json)
- Current advisory: [EEF-CVE-2026-93477](https://osv.dev/vulnerability/EEF-CVE-2026-93477)
- Prior advisory: [EEF-CVE-2026-86338](https://osv.dev/vulnerability/EEF-CVE-2026-86338)

## Current decision: Ash 3.33.11

Upgrade both the Phase 0 Foundation Lab and production core from Ash 3.33.4 to 3.33.11. The current advisory affects Ash from 2.17.15 through 3.33.10. On bulk update and bulk destroy paths, user parameter maps could set an action argument declared `public? false`; an argument used by a change or validation could therefore become an integrity or privilege-escalation input.

Ash 3.33.11 is the first fixed release. The upstream patch requires `public?` while matching user parameter keys on both bulk paths and preserves trusted server-side input through `:private_arguments`. The resolver also moved Multigraph from 0.16.1-mg.4 to 0.16.1-mg.5; no other Foundation Lab package changed.

## Focused regression

The synthetic ETS resource declares the private `internal_reason` argument on one bulk update and one bulk destroy action, then copies it to an observable field. On Ash 3.33.4, the two attacker-controlled cases failed the regression because the supplied string-keyed value was applied; the trusted server-option case passed. On Ash 3.33.11, all three cases pass: neither user parameter map controls the private argument, while `:private_arguments` remains effective.

```sh
cd spikes/ash-foundation-lab
MIX_ENV=test mix test test/ash_foundation_lab/bulk_private_argument_regression_test.exs
```

## Warning and compatibility review

The forced dependency compile remains at 38 normalized warning groups. The Ash and Multigraph patch releases add or remove no warning group; four locations move with upstream source lines. The checked baseline records Ash 3.33.11, Multigraph 0.16.1-mg.5, the new lock digest, and those reviewed location moves.

The regenerated Phase 0 OpenAPI and TypeScript declarations remove only `range_adjacent`, `range_contains`, and `range_overlaps` from filters for the existing UUID, integer, string, and enum fields. They add no filter property and change no public path. The descriptor remains byte-stable. The machine record binds the current generated artifacts, while the earlier AshJsonApi non-patch record remains an immutable comparison of its own baseline and candidate.

Both Hex audits pass. Complete repository verification is pending before this evidence is marked complete.

## Prior review: Ash 3.33.4

On 2026-09-16, both locks moved from Ash 3.33.3 to 3.33.4 for EEF-CVE-2026-86338. That advisory permitted a forbidden calculation or aggregate to act as a filter oracle when field policies denied the field but an interface exposed filtering. The focused ETS regression proves a restricted actor receives no matching record while an authorized actor receives the expected record. That test remains in the complete suite.

The earlier resolver also moved Reactor 1.0.6 to 1.0.7 and Spark 2.7.2 to 2.7.3. The forced dependency compile moved from 39 to 38 normalized warning groups by removing Spark's `Kernel.ParallelCompiler.async/1` deprecation. The complete verification contract passed at that boundary.

## Boundary

These patches close the recorded advisories; they do not authorize a new production business resource, direct exposure of Ash bulk APIs, or a waiver of the eight bounded adoption conditions. Application interfaces must still expose Chimwemwe-owned named actions, accept only public caller input, and set private arguments exclusively from trusted server context. Advisory freshness remains time-dependent and is checked on every complete run.
