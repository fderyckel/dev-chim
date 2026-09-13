# Ash Foundation Lab

This is a disposable Phase 0 pressure-test for Ash, PostgreSQL tenancy, named actions, generated interfaces, transactions, migrations, telemetry, and upgrade ergonomics. It is not a production application or a hidden school business module.

## Run

From the repository root:

```sh
make bootstrap
make test
make check
```

All records are synthetic. PostgreSQL database names begin with `ash_foundation_lab_` and may be overridden through standard `PGHOST`, `PGUSER`, and `PGDATABASE` variables.

## Evidence rule

Passing smoke tests proves only the scenarios those tests name. Ash remains Proposed until every mandatory category in [the evidence scorecard](../../docs/phase-0/evidence/ash-pressure-test.md) has direct evidence and ADR 0002 is reviewed.

