# Toolchain contract

- Status: Active for Phase 0
- Owner: Platform engineering
- Review trigger: runtime security advisory, package incompatibility, or Phase 1 workspace start

## Ownership

| Concern | Owner | Source of truth |
| --- | --- | --- |
| macOS CLIs and PostgreSQL service | Homebrew | `Brewfile` |
| language runtime versions | mise | `mise.toml` |
| Python virtual environment and packages | uv | `pyproject.toml` and `uv.lock` |
| Elixir dependencies | Mix/Hex | spike `mix.exs` and `mix.lock` |
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
| Node.js | 24.15.0 | Pinned now; used from Phase 1 |

Java and a container runtime are not Phase 0 dependencies. Select and pin a supported JDK before the scheduling-service spike, and select a supported container runtime before tests require Gotenberg, Tika, ClamAV, or S3-compatible services. Their absence must not be hidden by a passing Phase 0 check.

## Upgrade policy

- Never use floating versions in automation.
- Update runtime declarations and lock files together.
- Read release and security notes, run `make check`, and record migration or compatibility effects.
- For Ash or another architectural dependency, attach upgrade evidence to ADR 0002.
- Do not perform broad dependency upgrades inside an unrelated feature change.

