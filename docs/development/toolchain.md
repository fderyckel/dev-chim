# Toolchain contract

- Status: Active for Phase 0, Phase 1 core slices 1A through 1F, and UI-0
- Owner: Platform engineering
- Review trigger: runtime security advisory, package incompatibility, or Phase 1 workspace start

## Ownership

| Concern | Owner | Source of truth |
| --- | --- | --- |
| macOS CLIs and PostgreSQL service | Homebrew | `Brewfile` |
| language runtime versions | mise | `mise.toml` |
| Python virtual environment and packages | uv | `pyproject.toml` and `uv.lock` |
| Elixir dependencies | Mix/Hex | spike `mix.exs` and `mix.lock` |
| Production core Elixir dependencies | Mix/Hex | root `mix.exs`, `mix.lock`, and `apps/chimwemwe_core/mix.exs` |
| UI-0 browser dependencies | npm | `clients/web/package.json` and `clients/web/package-lock.json` |
| project commands | Make and scripts | `Makefile` and `bin/` |

## Verified Phase 0 versions

| Tool | Version | Required now |
| --- | --- | --- |
| Git | 2.55.0 | Yes |
| GitHub CLI | 2.100.0 | Yes for GitHub-hosted pushes |
| mise | 2026.9.6 | Yes |
| Erlang/OTP | 29.0.5 | Yes |
| Elixir | 1.20.3 on OTP 29 | Yes |
| PostgreSQL | 18.6 | Yes |
| Python | 3.14.5 | Yes |
| uv | 0.12.13 | Yes |
| Ruff | 0.16.7 | Yes |
| pytest | 9.1.1 | Yes |
| ShellCheck | 0.11.0 | Yes |
| Node.js | 24.15.0 | Yes for the generated-client review and UI-0 |
| npm | 11.12.1 | Yes for the generated-client review and UI-0 |

UI-0 pins Next.js, React, TypeScript, its test runners, and its style tools exactly
in the browser workspace lock. `bin/bootstrap` installs the locked dependency tree
and the pinned Playwright Chromium browser. The browser workspace is local-only:
development, verification, and browser builds require
`CHIMWEMWE_UI0_SYNTHETIC=true`, and an unflagged production build fails closed.

Java and a container runtime are not Phase 0 dependencies. Select and pin a supported JDK before the scheduling-service spike, and select a supported container runtime before tests require Gotenberg, Tika, ClamAV, or S3-compatible services. Their absence must not be hidden by a passing Phase 0 check.

## Upgrade policy

- Never use floating versions in automation.
- Update runtime declarations and lock files together.
- Read release and security notes, run `make check`, and record migration or compatibility effects.
- For Ash or another architectural dependency, attach upgrade evidence to ADR 0002.
- Keep the production core on the exact pressure-tested Ash release until an explicit dependency-review slice changes it.
- Keep UI-0 dependencies exact and update `clients/web/package.json` and its lock together; do not allow ranges to turn a local prototype check into a floating contract.
- Do not perform broad dependency upgrades inside an unrelated feature change.
