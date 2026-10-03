.DEFAULT_GOAL := help

.PHONY: help bootstrap fix format lint check-changed check-staged test-fast test docs-check check-docs check-archive-phase0 check-repository-tools check-core check-web check-tooling check-clean auth-demo legal-demo web-dev web-core-dev web-check web-e2e web-core-e2e check

help:
	@echo "bootstrap  Install and prepare local workspace dependencies"
	@echo "fix        Apply safe formatter and linter fixes"
	@echo "format     Format maintained source files"
	@echo "lint       Run non-mutating static checks"
	@echo "check-changed Run only the suites selected by changes since upstream"
	@echo "check-staged Run only the suites selected by staged changes"
	@echo "test-fast  Run the core-platform tests only"
	@echo "test       Run maintained repository, core, and web unit tests"
	@echo "docs-check Validate repository and ADR documentation"
	@echo "check-archive-phase0 Verify the retired Phase 0 lab after archive changes"
	@echo "check-clean Reproduce staged changes in a temporary clean checkout"
	@echo "auth-demo  Start the local database-backed authentication administration proof"
	@echo "legal-demo Seed the local synthetic Phase 2.1-C2a legal-structure demonstration"
	@echo "web-dev    Start the local synthetic UI-0 browser workspace"
	@echo "web-core-dev Start the local read-only UI-1A core connection"
	@echo "web-check  Verify UI-0 formatting, styles, types, tests, and build"
	@echo "web-e2e    Exercise the built UI-0 workspace in a real browser"
	@echo "web-core-e2e Exercise the local UI-1A browser-to-core connection"
	@echo "check      Run every boundary suite (explicit integration use only)"

bootstrap:
	./bin/bootstrap

fix:
	mise exec -- uv run ruff check --fix tools tests/tools
	$(MAKE) format

format:
	mise exec -- uv run ruff format tools tests/tools
	mise exec -- mix format
	cd clients/web && mise exec -- npm exec -- prettier --write .

lint:
	mise exec -- uv run ruff format --check tools tests/tools
	mise exec -- uv run ruff check tools tests/tools
	shellcheck .githooks/pre-commit .githooks/pre-push bin/auth-demo bin/bootstrap bin/check-changed bin/core-check bin/format-staged-elixir bin/organization-legal-demo bin/ui1-local bin/ui1-test-backend bin/with-verification-lock
	mise exec -- mix format --check-formatted
	mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
	mise exec -- env MIX_ENV=test mix run tools/check_ui1_openapi.exs
	mise exec -- env MIX_ENV=test mix run tools/check_public_openapi.exs
	cd apps/chimwemwe_core && mise exec -- mix ash_postgres.generate_migrations --check --migration-path priv/repo/migrations --snapshot-path priv/resource_snapshots
	cd apps/chimwemwe_core && mise exec -- mix credo --strict
	cd apps/chimwemwe_core && mise exec -- mix hex.audit
	cd apps/chimwemwe_core && mise exec -- mix deps.unlock --check-unused
	mise exec -- mix dialyzer
	cd clients/web && mise exec -- npm run format:check
	cd clients/web && mise exec -- npm run lint
	cd clients/web && mise exec -- npm run typecheck
	cd clients/web/openapi-client-generator && mise exec -- npm run generate:check

check-changed:
	./bin/check-changed --upstream

check-staged:
	./bin/check-changed --staged

test-fast:
	mise exec -- env MIX_ENV=test mix ecto.create --quiet
	mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
	mise exec -- env MIX_ENV=test mix test

test:
	mise exec -- uv run pytest tests/tools/test_check_docs.py
	mise exec -- env MIX_ENV=test mix ecto.create --quiet
	mise exec -- env MIX_ENV=test mix ecto.migrate --quiet
	mise exec -- env MIX_ENV=test mix test
	cd clients/web && CHIMWEMWE_UI0_SYNTHETIC=true mise exec -- npm run test:unit

docs-check:
	mise exec -- uv run python tools/check_docs.py

check-docs: docs-check

check-archive-phase0:
	./bin/with-verification-lock --resource archive-phase0 -- ./bin/phase0-check

check-repository-tools:
	mise exec -- uv run ruff format --check tools tests/tools
	mise exec -- uv run ruff check tools tests/tools
	mise exec -- uv run pytest tests/tools/test_check_docs.py

check-core:
	./bin/with-verification-lock --resource core-test -- ./bin/core-check

check-web:
	./bin/with-verification-lock --resource web-qualification -- $(MAKE) web-e2e web-core-e2e

check-tooling:
	shellcheck .githooks/pre-commit .githooks/pre-push bin/auth-demo bin/bootstrap bin/check-changed bin/core-check bin/format-staged-elixir bin/organization-legal-demo bin/ui1-local bin/ui1-test-backend bin/with-verification-lock
	$(MAKE) -n check-changed check-staged

check-clean:
	./bin/with-verification-lock --resource clean-checkout -- mise exec -- uv run python tools/rehearse_clean_checkout.py

auth-demo:
	./bin/auth-demo

legal-demo:
	./bin/organization-legal-demo

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
	$(MAKE) check-docs
	$(MAKE) check-repository-tools
	$(MAKE) check-core
	$(MAKE) check-web
	$(MAKE) check-tooling
