.DEFAULT_GOAL := help

.PHONY: help bootstrap format lint test-fast test docs-check check

help:
	@echo "bootstrap  Install and prepare local workspace dependencies"
	@echo "format     Format maintained source files"
	@echo "lint       Run non-mutating static checks"
	@echo "test-fast  Run the provisional production-core tests only"
	@echo "test       Run Python and Elixir tests"
	@echo "docs-check Validate repository and ADR documentation"
	@echo "check      Run the complete local verification suite"

bootstrap:
	./bin/bootstrap

format:
	mise exec -- uv run ruff format tools tests/tools
	mise exec -- mix format
	cd spikes/ash-foundation-lab && mise exec -- mix format

lint:
	mise exec -- uv run ruff format --check tools tests/tools
	mise exec -- uv run ruff check tools tests/tools
	shellcheck .githooks/pre-push bin/bootstrap bin/phase0-check
	cd spikes/ash-foundation-lab && mise exec -- mix format --check-formatted
	cd spikes/ash-foundation-lab && mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/generated_migration_review/migrations --snapshot-path priv/generated_migration_review/resource_snapshots
	cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix openapi.spec.json --spec AshFoundationLab.JsonApiRouter --check --pretty=true --filename priv/openapi/phase0-v1.json
	cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix phase0.descriptor.check
	cd spikes/ash-foundation-lab && mise exec -- mix credo --strict
	mise exec -- uv run python tools/check_ash_dependency_warnings.py
	cd spikes/ash-foundation-lab && mise exec -- mix hex.audit
	cd spikes/ash-foundation-lab && mise exec -- mix deps.unlock --check-unused
	cd spikes/ash-foundation-lab && mise exec -- mix dialyzer
	cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm run generate:check
	cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm run typecheck
	mise exec -- mix format --check-formatted
	mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
	cd apps/chimwemwe_core && mise exec -- mix credo --strict
	cd apps/chimwemwe_core && mise exec -- mix hex.audit
	cd apps/chimwemwe_core && mise exec -- mix deps.unlock --check-unused
	cd apps/chimwemwe_core && mise exec -- mix dialyzer

test-fast:
	mise exec -- env MIX_ENV=test mix test

test:
	mise exec -- uv run pytest
	cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test
	cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm test
	mise exec -- env MIX_ENV=test mix test

docs-check:
	mise exec -- uv run python tools/check_phase0.py

check:
	./bin/phase0-check
	./bin/core-check
