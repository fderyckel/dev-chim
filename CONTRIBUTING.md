# Contributing

## Workflow

1. Start from an up-to-date `main` branch.
2. Create a short-lived branch named `type/short-description`, for example `docs/adr-process` or `spike/ash-tenancy`.
3. Make one coherent change. Update documentation and tests in the same change as behaviour.
4. Run `make format` and `make check`.
5. Review the diff for secrets, generated noise, tenant-safety regressions, and accidental business-module scope.
6. Push the branch and open a pull request. Do not push directly to a protected `main` branch.

## Commits

Use an imperative subject that explains the outcome. Conventional Commit prefixes are encouraged:

- `feat:` new behaviour;
- `fix:` defect correction;
- `docs:` documentation only;
- `test:` tests only;
- `build:` dependencies or build tooling;
- `ci:` delivery automation; and
- `chore:` maintenance that changes no product behaviour.

Keep commits reviewable. Do not mix unrelated cleanup with a functional change, commit secrets, or commit local build artifacts.

## Pull requests

A pull request must state:

- the problem and intended outcome;
- scope and explicit non-goals;
- relevant ADRs and threats;
- tests and manual verification performed;
- migrations, compatibility, rollback, and operational effects; and
- follow-up work or known limitations.

Security-sensitive changes require negative tests. Architectural changes require an ADR. A passing check suite is necessary but not sufficient for architecture or security approval.

## Review and merge

Require review before merge. Prefer a linear history and squash only when it preserves useful decision context. The repository uses fast-forward pulls locally. Branch protection, required checks, and review counts are configured when a remote repository is attached.

