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

`make bootstrap` configures the versioned Git hooks. The pre-commit hook formats staged Elixir files,
then runs `make check-staged`; the pre-push hook runs `make check-changed`. Both select only the
affected boundary suites and always check the relevant diff for whitespace. Do not bypass either
hook to publish a failing change.

For a short feedback loop before committing, run:

```sh
make check-changed
```

It maps changed paths to their owned suites: documentation, Phase 0 Foundation Lab,
repository tools, production core, browser workspace, or shell tooling. A dependency lock change
selects both Phase 0 and core because both consume it. An unknown path fails closed until its
boundary is classified. Dialyzer findings require a deliberate code or contract correction; they
are not rewritten automatically.

## Shared-checkout coordination

Use one Git worktree per concurrent coding task. Multiple tasks in one checkout can change files
while a check is running and contend for the same Elixir build directory, synthetic test database,
or browser-test port.

Workers run focused tests while editing and the one boundary suite selected by their changed paths
before handoff. They do not run every repository suite by default. A verification owner collects
the changed-path report and may run an explicit cross-boundary or integration check only when the
candidate actually spans those boundaries.

The verification lease is resource-specific: Phase 0, the core synthetic database, the browser
qualification workspace, and the clean-checkout rehearsal each have independent leases. A second
user of the same resource exits with the current owner's PID, start time, owner label, and command.
Unrelated documentation, core, and browser checks may proceed independently. If the recorded PID
has exited, the next user safely recovers that stale lease; malformed metadata is left in place for
human investigation. The lease does not weaken a selected check or permit a hook bypass.

Run `make check-clean-rehearsal` only when changing bootstrap, toolchain, Phase 0 verification, or
clean-checkout inputs. It materializes the candidate and runs `make check-changed` there; it is not
a routine pre-push or repository-wide check for core, web, or documentation work.

Before making a public repository, select an explicit license and confirm that no architecture document or evidence has incompatible distribution terms.

Before every push:

```sh
git status --short
git diff --check
make check-changed
git diff --stat
```

Do not force-push shared branches, bypass required checks, or rewrite another contributor's work. Configure branch protection for the changed-boundary gate after the remote exists.
