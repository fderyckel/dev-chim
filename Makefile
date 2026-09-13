.DEFAULT_GOAL := help

.PHONY: help bootstrap format lint test docs-check check

help:
	@echo "bootstrap  Install and prepare local Phase 0 dependencies"
	@echo "format     Format maintained source files"
	@echo "lint       Run non-mutating static checks"
	@echo "test       Run Python and Elixir tests"
	@echo "docs-check Validate repository and ADR documentation"
	@echo "check      Run the complete local verification suite"

bootstrap:
	./bin/bootstrap

format:
	mise exec -- uv run ruff format tools tests/tools
	cd spikes/ash-foundation-lab && mise exec -- mix format

lint:
	mise exec -- uv run ruff format --check tools tests/tools
	mise exec -- uv run ruff check tools tests/tools
	shellcheck .githooks/pre-push bin/bootstrap bin/phase0-check
	cd spikes/ash-foundation-lab && mise exec -- mix format --check-formatted
	cd spikes/ash-foundation-lab && mise exec -- mix credo --strict
	cd spikes/ash-foundation-lab && mise exec -- mix hex.audit
	cd spikes/ash-foundation-lab && mise exec -- mix deps.unlock --check-unused
	cd spikes/ash-foundation-lab && mise exec -- mix dialyzer

test:
	mise exec -- uv run pytest
	cd spikes/ash-foundation-lab && mise exec -- env MIX_ENV=test mix test

docs-check:
	mise exec -- uv run python tools/check_phase0.py

check:
	./bin/phase0-check
