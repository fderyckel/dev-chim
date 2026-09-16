# Resource authoring and governed metadata evidence

- Status: Pass with bounded remediation
- Owner: Platform engineering
- Date: 2026-09-15
- Source revision: working tree based on `61469c9`
- Scope: disposable Ash Foundation Lab only
- Decision records: [ADR 0002](../../adr/0002-ash-adoption-criteria-and-fallback.md) and [ADR 0019](../../adr/0019-domain-model-authoring-and-governed-metadata.md)

## Implemented boundary

The scenario derives a checked, versioned descriptor from the real neutral `FoundationRecord` Ash resource and a code-owned allowlist. The descriptor contains stable Chimwemwe references, public field types and constraints, two approved actions, one policy-protected report dataset, required tenant scope, and a content revision. It excludes the private tenant key, audit reference, generic create/default-read actions, framework module names, policy implementation, database access, and executable behaviour.

Tenant-owned view and report definitions may arrange approved fields, labels, order, filters, groups, one named mutation, and one report dataset. They do not repeat field types or permissions. The validator binds tenant and attribution to trusted context, requires the exact descriptor revision, traverses nested content for forbidden authority or executable keys, and returns one non-disclosing rejection for unknown fields and actions. Report execution resolves an allowlisted dataset through code, converts only allowlisted stable filter references into sanitized Ash filter input, and performs the existing Ash read with the real actor and tenant.

The implementation remains one-way:

```text
Ash resource and policies -> checked descriptor -> validated experience definition
                                                     |
                                                     v
                                     existing authorized Ash action
```

Metadata cannot define a resource, migration, policy, capability, repository, tenant scope, query, module, arbitrary code, or SQL. It is not a second model, workflow, persistence, or authorization engine.

## Artifacts

- Descriptor derivation and code-owned execution registry: [`resource_descriptor.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/resource_descriptor.ex)
- Experience-definition validation and authorized report execution: [`governed_metadata.ex`](../../../spikes/ash-foundation-lab/lib/ash_foundation_lab/governed_metadata.ex)
- Checked descriptor: [`foundation-record.v1.json`](../../../spikes/ash-foundation-lab/priv/resource_descriptors/foundation-record.v1.json)
- Drift task: [`phase0.descriptor.check.ex`](../../../spikes/ash-foundation-lab/lib/mix/tasks/phase0.descriptor.check.ex)
- Scenario and evolution tests: [`resource_authoring_test.exs`](../../../spikes/ash-foundation-lab/test/ash_foundation_lab/resource_authoring_test.exs)
- Rename fixtures: [`resource_authoring_fixtures.ex`](../../../spikes/ash-foundation-lab/test/support/resource_authoring_fixtures.ex)

## Executed checks

From `spikes/ash-foundation-lab`:

```sh
mise exec -- env MIX_ENV=test mix compile --warnings-as-errors
mise exec -- mix credo --strict
mise exec -- env MIX_ENV=test mix test test/ash_foundation_lab/resource_authoring_test.exs --seed 0
mise exec -- env MIX_ENV=test mix phase0.descriptor.check
```

Results:

- the maintained application compiled with warnings treated as errors;
- Credo reported no issues across 42 source files;
- all 10 scenario tests passed; and
- the freshly derived descriptor matched the checked artifact byte for byte.

The tests prove:

- the descriptor comes from the real Ash resource but exposes only the explicit stable-reference allowlist;
- two tenants can choose different labels and field order without changing or duplicating model authority;
- an approved report filter drives the policy-protected Ash read rather than becoming direct query authority;
- the same valid report remains denied to an actor without the resource-read capability;
- private fields, the generic create action, injected permission/authorization keys, arbitrary SQL, code, and module references fail closed;
- a cross-tenant definition fails before reference validation can disclose whether a reference exists;
- missing trusted context and stale descriptor revisions fail closed;
- an internal source-field rename fails the old code binding, while an explicitly reviewed new model version preserves the stable metadata reference; and
- removing a stable reference prevents automatic definition upgrade.

## Representative patch upgrade

The complete spike was copied to an isolated temporary directory with build artifacts and dependencies excluded. The scenario was compiled and its descriptor drift task run first with Ash `3.33.2`, AshJsonApi `1.7.0`, and AshPostgres `2.13.0`, then with the current Ash `3.33.3`, AshJsonApi `1.7.1`, and AshPostgres `2.13.1`.

Both patch sets compiled with application warnings treated as errors, produced the same checked descriptor, passed all 10 scenario tests, and passed `mix hex.audit` with no retired or advisory-listed package. The temporary copy was moved to the macOS Trash after the comparison. This is representative patch evidence only; ADR 0002 still records a non-patch framework upgrade as a bounded condition.

The first repository-wide gate exposed that the new Mix task's callbacks were absent from the existing Dialyzer PLT. The spike now includes the built-in `:mix` application in its Dialyzer analysis set. A focused rerun reported zero Dialyzer errors, and the subsequent complete `make check` passed: 5 repository-tool tests, 88 Phase 0 lab tests, 6 TypeScript client tests, and 14 provisional Phase 1 core tests, plus all formatting, lint, drift, audit, compilation, migration, type-analysis, and whitespace gates.

## Maintenance assessment

The descriptor removes repetition where it matters: experience definitions contain stable references and presentation choices, not copied Ash types, constraints, policy rules, tenant rules, or source-module names. A source rename requires one reviewed code binding change; compatible definitions can then retain their stable references and receive a new descriptor revision.

The cost is also explicit. This proof adds a descriptor schema and allowlist, a deterministic derivation/drift task, a definition validator, a small code-owned execution/filter registry, and compatibility tests. That surface is registered in the owned-boundary manifest with a closure gate before any production descriptor or metadata consumer. It is bounded in the spike because it covers one neutral resource, two definition kinds, two scalar filter operators, and no renderer or metadata store.

The result is **Pass with bounded remediation** for the resource-authoring, descriptor-evolution, and governed-metadata scorecard category. The critical security properties exercised here pass. Before production use, platform engineering must select the actual descriptor consumers, persistence and lifecycle for tenant-owned definitions, classification propagation, module gates, and compatibility/removal policy; these are not authorized by the spike.

## Limits

- The definitions are synthetic maps, not durable production records, and no general form or report renderer was built.
- Only one neutral resource, one view shape, one report shape, one read dataset, one named mutation reference, and equality/inequality filters were exercised.
- The scenario validates and executes a report dataset; it does not authorize a reporting plane, export path, background job, or public API.
- It does not implement custom fields, tenant schema mutation, a visual model builder, a workflow language, or a schema compiler.
- Classification is derived for the dataset, but production definition-record classification, retention, recovery, and audit actions remain to be designed and tested.
- The compatible-upgrade proof covers the adjacent locked patch sets only. A non-patch Ash upgrade remains untested.
- ADR 0019 remains Proposed until accountable review; this evidence does not promote spike APIs into the production core.
