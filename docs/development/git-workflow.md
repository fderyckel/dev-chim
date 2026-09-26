# Git and push conventions

## Local repository settings

The repository uses branch `main`, fast-forward-only pulls, automatic pruning of deleted remote branches, automatic upstream setup for a new branch's first push, and LF-normalized text. User identity and authentication remain user-owned global settings.

## Branches and pushes

Use `type/short-description` branches. Before the first push:

```sh
git remote add origin <repository-url>
git remote -v
gh auth status
git push -u origin main
```

Do not store tokens in remotes, `.env` files, scripts, or documentation. Prefer the GitHub CLI credential helper when GitHub is selected. For another host, use its supported credential manager or SSH setup.

`make bootstrap` configures the versioned Git hooks. When a commit contains staged Elixir files,
the pre-commit hook formats and restages them, then runs `make check-staged`. Commits without staged
Elixir skip that gate. The pre-push hook runs `make check` before Git sends commits. Do not bypass
either hook to publish a failing change.

For a short feedback loop before committing, run:

```sh
make check-staged
```

It checks formatting of staged Elixir files, compiles with warnings as errors, runs core Credo and
Dialyzer, runs the fast core test suite, and checks staged whitespace. Dialyzer findings require a
deliberate code or contract correction; they are not rewritten automatically. This gate
complements, but never replaces, `make check` before a push.

Use one Git worktree per concurrent coding task. Multiple tasks in one checkout can change files
while a check is running and contend for the same Elixir build directory.

Before making a public repository, select an explicit license and confirm that no architecture document or evidence has incompatible distribution terms.

Before every push:

```sh
git status --short
git diff --check
make check
git diff --stat
```

Do not force-push shared branches, bypass required checks, or rewrite another contributor's work. Configure branch protection and required `make check` status after the remote exists.
