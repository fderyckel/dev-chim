# Chimwemwe patched braces package

This directory vendors `braces` 3.0.3 from `micromatch/braces` under its MIT
license. It retains the upstream API and source, with a local security patch:
the parser and recursive AST entry points reject pattern nesting deeper than
100 levels, and cyclic ASTs, before a walker can exhaust the JavaScript call
stack. The patch also removes an upstream debug log from the compiler.

The package is versioned `3.0.4-chimwemwe.0` and installed through the root
`overrides` entry as defense-in-depth hardening. GitHub withdrew
`GHSA-vfj7-8cjw-p6xm` on 2026-10-23 as not practically exploitable, so no active
advisory requires this fork. Remove the override and its regression test through
an explicit dependency review, or replace it with a compatible upstream release
that includes an equivalent depth guard.
