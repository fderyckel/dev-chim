# GitHub Actions CI-readiness proposal

- Status: Proposed; no workflow is authorized by this document
- Owner: Platform engineering
- Decision scope: independent verification readiness, not product testing or delivery
- Review trigger: portable bootstrap evidence, first workflow proposal, repository-policy change, or a requirement for secrets or a non-GitHub-hosted runner

## Purpose

This proposal defines the evidence required before Chimwemwe adds GitHub Actions. It does not
create a workflow, make a status required, enable branch protection, or treat automated checks as
product, pilot, security-review, accessibility-certification, or production-deployment evidence.

The existing local checks use synthetic data. Future CI would independently repeat the declared
repository contract; it would not change the current pre-testing status of the platform.

## Current evidence and gap

As observed on 2026-09-25, GitHub Actions is enabled for the repository, but no workflow is
checked in. `main` has no branch protection, the repository allows all third-party actions, and
GitHub does not require actions to be pinned by commit SHA.

The declared local contract is `make check`. Its bootstrap path is verified only on Apple-silicon
macOS: `bin/bootstrap` requires Homebrew, starts Homebrew PostgreSQL 18, and installs the pinned
toolchain through mise. A GitHub-hosted Linux runner is therefore not yet a qualified execution
environment. Copying the current command into a workflow would create a brittle automation claim,
not independent evidence.

## Local pre-commit boundary

The versioned pre-commit hook applies `mix format` only to staged `.ex` and `.exs` files and stages
those mechanical changes. When Elixir is staged, it then requires `make check-staged`: formatting,
warnings-as-errors compilation, core Credo, Dialyzer, the synthetic fast suite, and staged
whitespace. Non-Elixir commits skip this gate. It catches the common local Elixir failures before
the commit exists without running browser tests or contacting external services.

`make check-staged` remains a bounded developer gate, not a replacement for the complete
pre-push `make check` contract or future independent CI.

## Readiness sequence

1. Qualify a clean GitHub-hosted Linux candidate locally or in an isolated disposable environment.
   Record every required system dependency, PostgreSQL setup detail, browser dependency, runtime
   version, and command difference from the macOS contract. The candidate must keep the same
   `make check` entry point and synthetic-only data rule.
2. Make bootstrap portable through an explicit platform-owned change. It must install or start the
   supported PostgreSQL service without relying on Homebrew, install the declared mise toolchain,
   use locked Python/Mix/npm dependencies, and provision Playwright Chromium. Do not hide
   platform differences behind an unreviewed shell branch.
3. Demonstrate at least three clean, independent Linux runs. Record command outcomes, durations,
   cache-miss versus cache-hit behaviour, flake/retry count, generated-artifact drift behaviour,
   and clean source status after each run. A passing run must not write source artifacts.
4. Submit a separate workflow proposal for a manually triggered, non-blocking qualification run.
   It must name the exact runner, setup actions pinned to immutable commit SHAs, dependency-cache
   policy, artifact-retention policy, and the exact repository command. The initial workflow may
   be `workflow_dispatch` only.
5. Only after the manual workflow is repeatable may a separately authorized change add
   `pull_request` and `push` triggers. Required checks, `main` branch protection, action allowlists,
   and mandatory SHA pinning remain later governance choices.

## Proposed first workflow, after authorization

The first workflow should run one repository-owned command, `make check`, from a clean
GitHub-hosted Linux runner. It should start as a manually triggered, non-blocking verification
candidate. Splitting it into repository, core, and browser jobs is deferred until baseline timing
evidence demonstrates a meaningful benefit and preserves the command contract.

It must use `permissions: {contents: read}`, no secrets, no deployment environment, no write
token, no `pull_request_target`, and no user-controlled shell interpolation. Dependency caching
is out of scope for the first workflow. If introduced later, cache writes must be limited to
trusted `push` runs, caches must contain no credentials or production data, and pull-request runs
must have restore-only access. A branch-scoped concurrency group may cancel superseded runs only
after the workflow exists and is measured.

## Explicit non-goals

- production deployment, release, package publication, or environment promotion;
- real school, child, employee, identity, or credential data;
- external-service, broker, cloud, or production-database access;
- approval of GitHub Actions as a required merge gate;
- branch protection or any automatic repository-settings change; and
- duplicating the repository checks as independent YAML commands.

## Acceptance evidence for the next slice

- one documented Linux bootstrap design with the owner and operating boundary;
- three clean independent candidate runs using only synthetic data;
- a recorded comparison with the macOS contract, including any unresolved variance;
- a threat review of tokens, action provenance, cache contents, pull-request triggers, and
  generated artifacts; and
- explicit authorization for a manually triggered, non-blocking workflow before any
  `.github/workflows` file is added.
