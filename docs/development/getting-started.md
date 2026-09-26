# Local development setup

## Supported environment

The verified development host is Apple silicon macOS. Exact versions are recorded in [toolchain.md](toolchain.md) and `mise.toml`. Homebrew installs macOS services and CLIs; mise provides reproducible language runtimes; uv creates the repository-local Python environment.

## First setup

```sh
git clone <repository-url> dev-chim
cd dev-chim
brew bundle
mise install
make bootstrap
make check
```

For this initial local repository, Git is already initialized on `main`. A remote URL is not committed because repository hosting has not yet been selected.

## Optional interactive environment activation

Project commands use `mise exec` and therefore select the pinned runtimes even when shell activation is absent. To make plain `elixir`, `python`, and `node` commands select the repository versions interactively, activate mise in zsh once outside the repository:

```sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
exec zsh
```

The bootstrap command creates `.venv` through uv. Developers do not need to activate it: all project commands use `uv run`, which selects the locked environment directly.

## PostgreSQL

Phase 0 uses the Homebrew PostgreSQL 18 service and a synthetic test database. Check it with:

```sh
brew services list
pg_isready
```

`make bootstrap` starts the service when needed and creates/migrates only the spike's test database. No production or personal data belongs in it.

## Daily loop

```sh
git status --short
make fix
make test-fast
git add path/to/changed-file ...
make check-staged
make check
```

See [testing.md](testing.md) for focused commands and [git-workflow.md](git-workflow.md) before pushing.

## Local browser qualification

Use `make web-dev` for the fixture-only UI-0 experience. To exercise the first read-only core
connection, run:

```sh
make web-core-dev
```

Then open `http://127.0.0.1:3000/authority/assignments`. The command creates and migrates the
dedicated `chimwemwe_ui1_local` database, generates a fresh local bridge token, and starts the
loopback core and browser processes together. The page uses only synthetic records and cannot
save an assignment. Stop both processes with Control-C.

The token is process-local and must not be copied into browser code, screenshots, committed
configuration, or logs. This command does not configure production identity, hosting, or data.

## Troubleshooting

- Run `mise doctor` when a pinned runtime is not selected.
- Run `brew bundle check` to identify missing macOS dependencies.
- Run `uv sync --group dev --locked` if `.venv` is missing.
- Run `pg_isready`; if it fails, use `brew services start postgresql@18`.
- Run the failing command from `bin/phase0-check` directly for full output.
- Do not delete lock files or databases as a first troubleshooting step.
