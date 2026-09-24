# Clean-checkout rehearsal

- Status: Passed
- Owner: Platform engineering
- Rehearsed: 2026-09-24
- Machine record: [`clean-checkout-rehearsal.json`](../../../spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json)
- Harness: [`rehearse_phase0_clean_checkout.py`](../../../tools/rehearse_phase0_clean_checkout.py)

## Result

The complete current candidate was materialized in a temporary clone as a local-only commit. The clone was clean before bootstrap, remained clean after `./bin/bootstrap`, and remained clean after `make check`. Bootstrap and the full Phase 0, production-core, and UI-0 verification all exited successfully.

The rehearsal copies the current tracked patch and every non-ignored untracked source file, commits them only inside the disposable clone, and deletes that clone after the run. It does not commit, clean, or rewrite the source working tree.

## Reproduction

```sh
mise exec -- uv run python tools/rehearse_phase0_clean_checkout.py \
  --output spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json
```

The machine record binds the harness, bootstrap, Phase 0 check, core check, and top-level Makefile by SHA-256. The repository checker rejects the record if any of those executable inputs changes.

## Boundary

This closes the local clean-checkout reproducibility gate. It does not establish remote CI, branch protection, a second operating system or architecture, or live managed-service availability. Ignored dependency and build directories are allowed during execution; tracked and non-ignored source status must remain clean.
