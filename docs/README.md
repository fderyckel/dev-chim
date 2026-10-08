# Documentation

Documentation is part of the platform contract and changes with the code or decision it describes.

- [Active six-week classroom plan](plans/classroom-first-six-week-plan.md): calendar, people,
  enrolment, and daily attendance; approved priority for 5 October–15 November 2026.
- [Architecture](architecture/README.md): stable boundaries, quality targets, and deferred choices.
- [Architecture decisions](adr/README.md): numbered decisions and their evidence.
- Development:
  - [Getting started](development/getting-started.md)
  - [Toolchain contract](development/toolchain.md)
  - [Testing conventions](development/testing.md)
  - [Production-core migration discipline](development/migrations.md)
  - [Code conventions](development/code-conventions.md)
  - [Git and push conventions](development/git-workflow.md)
- [Phase 0 archive](phase-0/README.md): what was decided, how it was tested, why it mattered,
  and the consolidated handover evidence.
- [Phase 1 archive](phase-1/README.md): what was implemented, how it was verified, why it
  mattered, and the consolidated handover evidence.
- [Phase 2](phase-2/README.md): entry-gate reconciliation and the recursive
  institutional-structure sequence.
- [Security](security/threat-model.md): data classification, trust boundaries, and abuse cases.
- [Operations](operations/README.md): bounded dispatch, replay, drain, temporal retention, and
  recovery runbooks.
- Plans: the accepted [Phase 2 entry sequence and revised institutional-structure proposal](plans/phase-2-entry-and-school-structure-proposal.md), the proposed [local browser experience foundation](plans/local-browser-experience-foundation-proposal.md), and the proposed [GitHub Actions CI-readiness path](plans/github-actions-ci-readiness-proposal.md).

## Documentation conventions

- Use Markdown with one H1, sentence-case headings, relative repository links, and fenced code blocks with a language.
- State document status, owner role, and review trigger when the content governs a decision.
- Separate facts, proposals, accepted decisions, and evidence.
- Use examples made from synthetic data only.
- Keep links relative so they work in local clones and hosting platforms.
- Run `make docs-check` after changing documentation.
