# Documentation

Documentation is part of the platform contract and changes with the code or decision it describes.

- [Architecture](architecture/README.md): stable boundaries, quality targets, and deferred choices.
- [Architecture decisions](adr/README.md): numbered decisions and their evidence.
- Development:
  - [Getting started](development/getting-started.md)
  - [Toolchain contract](development/toolchain.md)
  - [Testing conventions](development/testing.md)
  - [Code conventions](development/code-conventions.md)
  - [Git and push conventions](development/git-workflow.md)
- [Phase 0](phase-0/README.md): scope, decision register, risks, review, and evidence.
- [Phase 1](phase-1/README.md): provisional core-foundation scope and unresolved entry conditions.
- [Security](security/threat-model.md): data classification, trust boundaries, and abuse cases.
- Plans: [Phase 0](plans/phase-0-implementation-plan.md) and the provisional [Phase 1 core foundation](plans/phase-1-core-foundation-plan.md).

## Documentation conventions

- Use Markdown with one H1, sentence-case headings, relative repository links, and fenced code blocks with a language.
- State document status, owner role, and review trigger when the content governs a decision.
- Separate facts, proposals, accepted decisions, and evidence.
- Use examples made from synthetic data only.
- Keep links relative so they work in local clones and hosting platforms.
- Run `make docs-check` after changing documentation.
