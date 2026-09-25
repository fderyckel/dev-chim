.DEFAULT_GOAL := help

.PHONY: help bootstrap format lint test-fast test docs-check web-dev web-core-dev web-check web-e2e web-core-e2e check

help:
	@echo "bootstrap  Install and prepare local workspace dependencies"
	@echo "format     Format maintained source files"
	@echo "lint       Run non-mutating static checks"
	@echo "test-fast  Run the provisional production-core tests only"
	@echo "test       Run Python and Elixir tests"
	@echo "docs-check Validate repository and ADR documentation"
	@echo "web-dev    Start the local synthetic UI-0 browser workspace"
	@echo "web-core-dev Start the local read-only UI-1A core connection"
	@echo "web-check  Verify UI-0 formatting, styles, types, tests, and build"
	@echo "web-e2e    Exercise the built UI-0 workspace in a real browser"
	@echo "web-core-e2e Exercise the local UI-1A browser-to-core connection"
	@echo "check      Run the complete local verification suite"

bootstrap:
	./bin/bootstrap

format:
	mise exec -- uv run ruff format tools tests/tools
	mise exec -- mix format
	cd spikes/ash-foundation-lab && mise exec -- mix format
	cd clients/web && mise exec -- npm exec -- prettier --write .

lint:
	mise exec -- uv run ruff format --check tools tests/tools
	mise exec -- uv run ruff check tools tests/tools
	shellcheck .githooks/pre-push bin/bootstrap bin/phase0-check bin/core-check bin/ui1-local bin/ui1-test-backend
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
	mise exec -- env MIX_ENV=test mix run tools/check_ui1_openapi.exs
	cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
	cd apps/chimwemwe_core && mise exec -- mix credo --strict
	cd apps/chimwemwe_core && mise exec -- mix hex.audit
	cd apps/chimwemwe_core && mise exec -- mix deps.unlock --check-unused
	mise exec -- mix dialyzer
	cd clients/web && mise exec -- npm run format:check
	cd clients/web && mise exec -- npm run lint
	cd clients/web && mise exec -- npm run typecheck
	cd clients/web/openapi-client-generator && mise exec -- npm run generate:check

test-fast:
	mise exec -- env MIX_ENV=test mix ecto.create --quiet
	mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
	mise exec -- env MIX_ENV=test mix test

test:
	mise exec -- uv run pytest
	cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test
	cd spikes/ash-foundation-lab/typescript-client-review && mise exec -- npm test
	mise exec -- env MIX_ENV=test mix ecto.create --quiet
	mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
	mise exec -- env MIX_ENV=test mix test
	cd clients/web && CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run test:unit

docs-check:
	mise exec -- uv run python tools/check_phase0.py

web-dev:
	cd clients/web && CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run dev

web-core-dev:
	./bin/ui1-local

web-check:
	cd clients/web/openapi-client-generator && mise exec -- npm run generate:check
	cd clients/web/openapi-client-generator && mise exec -- npm audit --audit-level=high
	cd clients/web && mise exec -- npm audit --audit-level=high
	cd clients/web && CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run check

web-e2e: web-check
	cd clients/web && CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run test:e2e

web-core-e2e: web-check
	cd clients/web && mise exec -- npm run test:e2e:ui1
	cd clients/web && mise exec -- npm run test:e2e:ui1-unavailable

check:
	./bin/phase0-check
	./bin/core-check
	$(MAKE) web-e2e web-core-e2e
