# Contributing

## Workflow

1. Start from an up-to-date `main` branch.
2. Create a short-lived branch named `type/short-description`, for example `docs/adr-process` or `spike/ash-tenancy`.
3. Make one coherent change. Update documentation and tests in the same change as behaviour.
4. Use `make fix` and `make test-fast` while iterating. Stage the candidate, run `make check-staged`, then run `make check` before sharing the change.
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

## Change governance

Choose the review lane from the effect of the change, not from whether its code sits in a platform or business-module directory:

1. **Routine implementation** stays inside an existing action, policy, schema, interface, and ownership contract. It needs a focused, reviewable pull request and the relevant tests, but no new ADR.
2. **Governed contract evolution** adds or changes a resource, named action, report dataset, migration, or public contract inside an existing architectural boundary. It needs compatibility, migration, authorization, tenant-isolation, and operational evidence as applicable. It needs an ADR only if it also changes a stable boundary.
3. **Architecture or trust-boundary change** changes a source of truth, authorization or tenancy model, module ownership, transaction or outbox boundary, public API semantics, persistence placement, service topology, or framework dependency. It needs a new or superseding ADR, linked evidence, and accountable review before acceptance.

A domain change can belong to the third lane when it changes safeguarding, statutory evidence, financial integrity, retained-data ownership, or another platform-wide guarantee. Conversely, ordinary work inside the core does not require an ADR merely because it is platform code. The pull request states its selected lane and why.

## Review and merge

Require review before merge. Prefer a linear history and squash only when it preserves useful decision context. The repository uses fast-forward pulls locally. Branch protection, required checks, and review counts are configured when a remote repository is attached.
