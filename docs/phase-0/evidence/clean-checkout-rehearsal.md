# Clean-checkout rehearsal

- Status: Passed
- Owner: Platform engineering
- Rehearsed: 2026-09-26
- Machine record: [`clean-checkout-rehearsal.json`](../../../spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json)
- Harness: [`rehearse_phase0_clean_checkout.py`](../../../tools/rehearse_phase0_clean_checkout.py)

## Result

The current candidate is materialized in a temporary clone as a local-only commit. The clone must be
clean before bootstrap, remain clean after `./bin/bootstrap`, and remain clean after
`make check-changed`. The rehearsal proves that declared inputs reproduce bootstrap and the suites
selected by that candidate's changed boundaries; it is not an automatic repository-wide test run.

The rehearsal copies the staged candidate into the disposable clone, commits it only there, and deletes that clone after the run. It does not include unrelated unstaged work or commit, clean, or rewrite the source working tree.

## Reproduction

```sh
mise exec -- uv run python tools/rehearse_phase0_clean_checkout.py \
  --output spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json
```

The machine record binds the harness, bootstrap, Phase 0 check, core check, and top-level Makefile by SHA-256. The repository checker rejects the record if any of those executable inputs changes.

## Boundary

This closes the local clean-checkout reproducibility gate. It does not establish remote CI, branch protection, a second operating system or architecture, or live managed-service availability. Ignored dependency and build directories are allowed during execution; tracked and non-ignored source status must remain clean.
