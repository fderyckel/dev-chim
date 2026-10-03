# Slice 2.1-B minimal legal-entity foundation evidence

- Status: Complete at L1 with synthetic local data; no public route or L2 claim
- Date: 2026-09-28
- Governing decision: Conditionally Accepted ADR 0025, condition C25-01
- Module at completion: `organization.legal` version `1.0.0` (advanced to `1.1.0` by ADR 0031)
- Boundary: private production-core candidate using synthetic test data only

## Entry disposition

The Project Owner's authorized Phase 2 sequence, ADR 0025's conditional acceptance, and the Phase
2 entry register permit exactly the minimal Slice 2.1-B proof needed to apply the Phase 2.0
foundation to one business aggregate. Entry is accepted only for:

- the immutable release declaration for `organization.legal`;
- stable tenant-qualified `LegalEntity` identity and active state;
- immutable, attributable official/display-name profile revisions;
- `register_legal_entity` and `revise_legal_entity_profile`;
- one exact `current_legal_entity` read; and
- the existing trusted writer, lifecycle, authority, audit, and transactional-outbox contracts.

This disposition does not authorize registration/jurisdiction policy, relationship types,
ownership or consolidation, corporate units, educational structure, operator responsibility,
collection reads, a public route, migration intake, real records, or deployment. ADR 0025 C25-02
through C25-06 remain unchanged.

## Implemented boundary

The new `Chimwemwe.OrganizationLegal` Ash domain declares two closed tenant-owned resources:

- `LegalEntity` owns the opaque UUID, tenant, active state, and optimistic lock version; and
- `LegalEntityProfileRevision` owns immutable official/display names, revision number, recording
  actor, and recording time.

The first slice deliberately does not guess registration-number uniqueness, jurisdiction-specific
fields, legal status catalogues, contact data, evidence types, or legal relationships. Those
meanings require the named corporate/finance and records review. Names may change without replacing
the legal-entity UUID, and the exact current read joins only the profile whose revision equals the
entity's current lock version.

Every action:

1. validates an established actor, tenant, placement, purpose, locale, and correlation context;
2. resolves the current authoritative writer through the trusted placement registry and admission
   boundary;
3. rechecks the code-owned module release, current tenant entitlement and activation, and the
   tenant-defined `organization.legal.entities.manage` or `.read` capability inside the current
   transaction;
4. binds the normalized request and actor to a tenant/action-scoped idempotency key;
5. uses exact expected-version concurrency for revision;
6. commits entity state, immutable profile history, minimized audit evidence, a minimal internal
   outbox fact, and the replay result atomically; and
7. returns stable non-disclosing errors for absent, foreign, denied, inactive, stale, conflicting,
   malformed, or dependency-failed requests.

The named writes use the previously recorded transaction-backed Ecto domain-service fallback for
the multi-table entity/profile/evidence transition. Ash remains authoritative for the domain,
tenant-owned resource shapes, policies, constraints, generated snapshots, and migration drift.
The fallback SQL is closed inside `Chimwemwe.OrganizationLegal`, accepts no repository or tenant
input, and is covered by the candidate-specific concurrency, rollback, authority, lifecycle, and
alternate-write evidence required by the Phase 0 condition register.

The checked-out platform evidence tables remain the shared transaction boundary already used by
the provider-neutral identity foundation. Legal names are absent from audit/outbox payloads; those
payloads contain only the stable entity identifier, active state, lock version, and changed field
names.

## Migration review

AshPostgres generated the reviewed migration and resource snapshots. Review found that the
generator initially placed the compound profile foreign key before the referenced entity tenant
column. The checked-in artifact corrects the order so the entity table and unique `(id,
tenant_id)` destination exist first.

The migration provides:

- non-null tenant keys on both tables;
- a compound tenant-qualified profile-to-entity foreign key;
- unique tenant/entity/revision history positions;
- positive lock and revision constraints plus bounded non-empty names;
- a database guard preventing entity UUID or tenant reassignment; and
- a database guard preventing profile update or deletion; and
- a rollback refusal once entity, history, audit, outbox, or idempotency evidence exists.

An empty rollback drops the profile history before the entity destination and removes both guard
functions. The migration applies successfully, and the Ash snapshot drift check passes.

## Executable acceptance evidence

The focused suite proves:

- registration, normalized result, exact current read, and exact replay;
- profile revision with stable identity and retained earlier revision;
- denial without capability or trusted context;
- non-disclosing cross-tenant read and revision behavior;
- malformed and caller-supplied tenant input rejection;
- idempotency binding to normalized request, action, actor, and tenant;
- concurrent same-version revision serialization with exactly one winner;
- stale-version and no-change conflict handling;
- atomic rollback after an injected failure following state, audit, and outbox writes;
- inactive-module denial while committed rows remain retained; and
- alternate-write rejection for cross-tenant profile references, profile mutation, and identity
  reassignment.

Verification on 2026-09-28:

| Check | Result |
| --- | --- |
| Focused legal-entity suite | Passed: 9 tests |
| `make test-fast` | Passed: 181 tests |
| Ash migration/snapshot drift check | Passed |
| Isolated clean-checkout rehearsal | Passed for the exact current candidate |
| Complete repository `make check` | Passed: 25 repository-tool, 106 Phase 0, 6 Phase 0 TypeScript, 181 production-core, 21 web-unit, 15 synthetic browser, 6 connected UI-1A browser, and 1 unavailable-core recovery tests |

## Phase 2 effect

C25-01 and the L1 first-business-aggregate gate are satisfied by this bounded proof. This removes
the minimal persistence dependency that preceded Slice 2.0-E, but it does not satisfy C25-05.
The connected/public structure workflow remains prohibited until the named representative
comprehension and accountable product-experience dispositions are recorded. At this Slice 2.1-B
evidence's original completion, no Slice 2.1-C or educational-structure implementation had
started. ADR 0031 later authorizes and separately evidences only bounded synthetic Slice 2.1-C1.

## Local synthetic demonstration

On 2026-10-03, the bounded slice gained a development-only demonstration invoked with
`make legal-demo`. It uses a dedicated `chimwemwe_organization_legal_demo` database and is guarded
by `CHIMWEMWE_ORGANIZATION_LEGAL_DEMO=true`. The original boundary creates the synthetic
membership, tenant-defined role and capabilities, module entitlement, and activation needed to
enter the action boundary. It then registers these review aliases through
`register_legal_entity`: `LE-GROUP`, `LE-OPS`, `LE-PROPERTY`, `LE-JOINT`, `LE-NEW-OPS`, and
`LE-INDEPENDENT`.

Fixed idempotency and causation identifiers make repeated runs return the original six committed
entities without duplicate state or automatic write retry. ADR 0031 later expands the same local
command with explicit synthetic relationships, management-reporting parentage, and corporate
units. That expansion is governed and evidenced separately by
[Slice 2.1-C1](legal-structure-foundation-evidence.md); it does not retroactively enlarge the
completed Slice 2.1-B boundary.

Demo verification on 2026-10-03:

| Check | Result |
| --- | --- |
| Focused legal-entity suite at initial completion | Passed: 10 tests |
| Initial `make legal-demo`, repeated against the same database | Passed: the same six entity UUIDs were returned without duplicate facts |
| Isolated clean-checkout rehearsal for the exact demo candidate | Passed: bootstrap, selected checks, and 182 production-core tests |
| `make docs-check` | Passed before the concurrent ADR-index reformat; the current combined checkout later reports every padded ADR-table entry as missing |
| Production-core portion of `make check` | Passed: 182 tests, with formatting, drift, lint, dependency, and type checks |
| Complete repository `make check` | Stopped later at the current web dependency audit: 9 high-severity `braces` findings in the style-tool dependency chain |

## References

- [ADR 0025](../adr/0025-learning-institution-operating-system-and-institutional-structure.md)
- [ADR 0031](../adr/0031-bounded-cross-jurisdiction-legal-structure-foundation.md)
- [Phase 2 entry register](entry-decision-register.md)
- [Institutional-structure decision evidence](institutional-structure-decision-evidence.md)
- [Institutional-structure experience evidence](institutional-structure-experience-evidence.md)
- [Phase 2 implementation proposal](../plans/phase-2-entry-and-school-structure-proposal.md)
- [Slice 2.1-C1 bounded legal-structure evidence](legal-structure-foundation-evidence.md)
