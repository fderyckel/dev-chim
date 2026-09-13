# Testing conventions

## Test layers

- Repository tests validate documentation, ADR structure, links, and phase boundaries.
- Unit tests cover deterministic logic without services.
- Integration tests use the local synthetic PostgreSQL database and exercise Ash/PostgreSQL behaviour.
- Security tests include negative authorization and cross-tenant cases alongside positive cases.
- Later end-to-end, accessibility, performance, recovery, and adversarial tests are added when their platform capability exists.

## Commands

```sh
make test
make lint
make docs-check
make check
```

Focused commands:

```sh
mise exec -- uv run pytest tests/tools
mise exec -- uv run python tools/check_phase0.py
cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test
cd spikes/ash-foundation-lab && mise exec -- mix credo --strict
cd spikes/ash-foundation-lab && mise exec -- mix dialyzer
```

## Rules

- Tests are deterministic, isolated, and safe to rerun.
- Use synthetic tenant IDs and records; never copy production data.
- Database tests use SQL Sandbox transactions where possible.
- Test names describe behaviour and expected denial, not implementation details.
- Every policy change needs a permitted case, a denied case, a cross-tenant case, and a missing-context case where applicable.
- Do not weaken an assertion to make an unsafe implementation pass.
- Record an intentionally skipped test with its owner and unblock condition.

`make check` is the required pre-push proof. A clean exit means the current Phase 0 checks passed; it does not certify later foundation gates that have not been implemented.
