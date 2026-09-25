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

`make bootstrap` configures the versioned Git hooks. The pre-commit hook formats staged Elixir files and stages the resulting formatting-only updates. The pre-push hook runs `make check` before Git sends commits. Do not bypass it to publish a failing branch.

For a short feedback loop before committing, run:

```sh
make check-staged
```

It checks formatting of staged Elixir files, compiles with warnings as errors, runs core Credo, the fast core test suite, and checks staged whitespace. It complements, but never replaces, `make check` before a push.

Before making a public repository, select an explicit license and confirm that no architecture document or evidence has incompatible distribution terms.

Before every push:

```sh
git status --short
git diff --check
make check
git diff --stat
```

Do not force-push shared branches, bypass required checks, or rewrite another contributor's work. Configure branch protection and required `make check` status after the remote exists.
