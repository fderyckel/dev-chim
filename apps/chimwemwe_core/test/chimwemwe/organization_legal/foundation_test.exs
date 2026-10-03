defmodule Chimwemwe.OrganizationLegal.FoundationTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.OrganizationLegal.{
    ActionResult,
    ConsolidationParentageView,
    CorporateUnitView,
    Demo,
    DemoData,
    Error,
    Foundation,
    LegalEntityRelationshipView,
    LegalEntityView,
    Structure
  }

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "31313131-3131-4131-8131-313131313131"
  @tenant_b "32323232-3232-4232-8232-323232323232"
  @actor_a "a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1"
  @actor_a_peer "a2a2a2a2-a2a2-42a2-82a2-a2a2a2a2a2a2"
  @actor_a_denied "a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3"
  @actor_b "b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1"
  @module_key "organization.legal"
  @manage_capability "organization.legal.entities.manage"
  @read_capability "organization.legal.entities.read"
  @relationships_capability "organization.legal.relationships.manage"
  @corporate_units_capability "organization.legal.corporate_units.manage"
  @register_action "organization.legal.entity.register"
  @revise_action "organization.legal.entity.profile.revise"
  @relationship_action "organization.legal.relationship.establish"
  @relationship_end_action "organization.legal.relationship.end"
  @consolidation_action "organization.legal.consolidation_parent.set"
  @corporate_unit_action "organization.legal.corporate_unit.register"
  @corporate_unit_revise_action "organization.legal.corporate_unit.profile.revise"

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_fixture(runtime)
    fixture = seed_foundation(runtime)
    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "declares the bounded module and valid tenant-owned resources" do
    assert {:ok, %{version: "1.2.0", dependencies: []}} =
             Foundation.release_manifest()
             |> ReleaseManifest.fetch(@module_key)

    assert :ok = ResourceContract.validate_domain(Chimwemwe.OrganizationLegal)
  end

  test "seeds the bounded synthetic legal-entity demonstration through named actions", fixture do
    assert {:ok, entities} = Demo.seed_entities(fixture.runtime, context_a())
    assert Enum.map(entities, & &1.key) == Enum.map(DemoData.entities(), & &1.key)
    assert length(entities) == 6

    assert Enum.all?(entities, fn entity ->
             entity.lock_version == 1 and entity.id != "" and entity.official_name != "" and
               entity.display_name != ""
           end)

    assert {:ok, ^entities} = Demo.seed_entities(fixture.runtime, context_a())
    assert {:ok, [[6, 6, 6]]} = fact_counts(fixture.runtime, context_a())

    assert {:ok, structure} = Demo.seed_structure(fixture.runtime, context_a(), entities)
    assert length(structure.relationships) == 4
    assert length(structure.relationship_terminations) == 1
    assert length(structure.consolidation_parentages) == 3
    assert length(structure.corporate_units) == 6
    assert length(structure.corporate_unit_profile_revisions) == 1

    assert [termination] = structure.relationship_terminations
    assert termination.status == :ended
    assert termination.effective_until == ~D[2027-06-30]
    assert termination.lock_version == 2

    assert [profile_revision] = structure.corporate_unit_profile_revisions
    assert profile_revision.official_name == "Mphamvu Group Shared Services"
    assert profile_revision.display_name == "Group Shared Services"
    assert profile_revision.lock_version == 2

    assert {:ok, ^structure} = Demo.seed_structure(fixture.runtime, context_a(), entities)

    assert {:ok, [[4, 1, 3, 6, 7, 15, 15, 15]]} =
             structure_counts(fixture.runtime, context_a())
  end

  test "registers one entity with immutable profile, audit, outbox, and exact read", fixture do
    input = register_input("  Mphamvu Education Operations Limited  ", "  Mphamvu Operations  ")

    assert {:ok,
            %ActionResult{
              id: entity_id,
              status: :active,
              lock_version: 1,
              audit_reference: audit_reference,
              event_id: event_id
            } = first} = Foundation.register_legal_entity(fixture.runtime, context_a(), input)

    assert {:ok, ^first} =
             Foundation.register_legal_entity(fixture.runtime, context_a(UUID.generate()), input)

    assert {:ok,
            %LegalEntityView{
              id: ^entity_id,
              official_name: "Mphamvu Education Operations Limited",
              display_name: "Mphamvu Operations",
              status: :active,
              lock_version: 1,
              recorded_at: %DateTime{}
            }} = Foundation.current_legal_entity(fixture.runtime, context_a(), entity_id)

    assert {:ok,
            [
              [
                "active",
                1,
                1,
                "Mphamvu Education Operations Limited",
                "Mphamvu Operations",
                @register_action,
                0,
                1,
                %{"changed_fields" => ["display_name", "official_name"]},
                "organization.legal.entity.registered",
                %{
                  "legal_entity_id" => ^entity_id,
                  "lock_version" => 1,
                  "status" => "active"
                },
                "completed"
              ]
            ]} =
             read_committed_facts(
               fixture.runtime,
               context_a(),
               entity_id,
               audit_reference,
               event_id,
               input.idempotency_key
             )
  end

  test "revises by expected version while preserving identity and earlier history", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Mphamvu Education Operations Limited", "Mphamvu Operations")
             )

    revision =
      revise_input(
        registered.id,
        1,
        "Mphamvu Learning Operations Limited",
        "Mphamvu Learning"
      )

    assert {:ok, %ActionResult{id: entity_id, lock_version: 2} = revised} =
             Foundation.revise_legal_entity_profile(fixture.runtime, context_a(), revision)

    assert entity_id == registered.id

    assert {:ok, ^revised} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(UUID.generate()),
               revision
             )

    assert {:ok,
            %LegalEntityView{
              id: ^entity_id,
              official_name: "Mphamvu Learning Operations Limited",
              display_name: "Mphamvu Learning",
              lock_version: 2
            }} = Foundation.current_legal_entity(fixture.runtime, context_a(), entity_id)

    assert {:ok,
            [
              [1, "Mphamvu Education Operations Limited", "Mphamvu Operations"],
              [2, "Mphamvu Learning Operations Limited", "Mphamvu Learning"]
            ]} = profile_history(fixture.runtime, context_a(), entity_id)

    assert {:error, %Error{code: :conflict}} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(),
               revise_input(
                 entity_id,
                 2,
                 "Mphamvu Learning Operations Limited",
                 "Mphamvu Learning"
               )
             )
  end

  test "denies absent authority, missing context, cross-tenant identifiers, and malformed input",
       fixture do
    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a_denied(),
               register_input("Denied Legal Entity", "Denied")
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               %{tenant_id: @tenant_a},
               register_input("Raw Context Entity", "Raw context")
             )

    assert {:ok, tenant_b_entity} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_b(),
               register_input("Tenant B Legal Entity", "Tenant B")
             )

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), tenant_b_entity.id)

    assert {:error, %Error{code: :not_found}} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(),
               revise_input(tenant_b_entity.id, 1, "Cross Tenant", "Cross tenant")
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               Map.put(register_input("Unexpected", "Unexpected"), :tenant_id, @tenant_b)
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), "not-a-uuid")

    assert {:ok, [[0, 0, 0]]} = fact_counts(fixture.runtime, context_a())
  end

  test "binds idempotency to normalized request, action, actor, and tenant", fixture do
    idempotency_key = UUID.generate()
    input = register_input("Bound Entity", "Bound", idempotency_key)

    assert {:ok, %ActionResult{} = first} =
             Foundation.register_legal_entity(fixture.runtime, context_a(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               %{input | display_name: "Changed replay"}
             )

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_legal_entity(fixture.runtime, context_a_peer(), input)

    assert {:ok, %ActionResult{id: tenant_b_id}} =
             Foundation.register_legal_entity(fixture.runtime, context_b(), input)

    refute tenant_b_id == first.id

    assert {:ok, [[1, 1, 1]]} = fact_counts(fixture.runtime, context_a())
    assert {:ok, [[1, 1, 1]]} = fact_counts(fixture.runtime, context_b())
  end

  test "serializes concurrent revisions and rejects the stale contender", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Concurrent Entity", "Concurrent")
             )

    parent = self()

    tasks =
      for {official_name, display_name} <- [
            {"Concurrent Entity Alpha", "Alpha"},
            {"Concurrent Entity Beta", "Beta"}
          ] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              Foundation.revise_legal_entity_profile(
                fixture.runtime,
                context_a(),
                revise_input(registered.id, 1, official_name, display_name)
              )
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %ActionResult{lock_version: 2}}, &1))
    assert 1 == Enum.count(results, &match?({:error, %Error{code: :stale}}, &1))

    assert {:ok, [[2]]} = profile_count(fixture.runtime, context_a(), registered.id)
  end

  test "rolls back entity, profile, audit, and outbox after a late database failure", fixture do
    input = register_input("Rollback Entity", "Rollback")
    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.register_legal_entity(fixture.runtime, context_a(), input)

      assert {:ok, [[0, 0, 0]]} = fact_counts(fixture.runtime, context_a())
      assert {:ok, [[0, 0]]} = entity_and_profile_counts(fixture.runtime, context_a())
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %ActionResult{lock_version: 1}} =
             Foundation.register_legal_entity(fixture.runtime, context_a(), input)
  end

  test "fails closed when the module is inactive and retains committed state", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Retained Entity", "Retained")
             )

    other = register_entity!(fixture.runtime, context_a(), "Retained relationship peer")

    relationship =
      establish_relationship!(
        fixture.runtime,
        context_a(),
        registered.id,
        other.id,
        :contractual_control,
        :contract,
        nil
      )

    assert {:ok, corporate_unit} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(),
               corporate_unit_input(registered.id, nil, "Retained corporate unit")
             )

    deactivate_module(fixture.runtime, context_a())

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Inactive Module Entity", "Inactive")
             )

    assert {:error, %Error{code: :module_unavailable}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_end_input(relationship.id, 1, ~D[2027-01-01])
             )

    assert {:error, %Error{code: :module_unavailable}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(),
               corporate_unit_revise_input(
                 corporate_unit.id,
                 1,
                 "Unavailable corporate unit",
                 "Unavailable"
               )
             )

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), registered.id)

    assert {:error, %Error{code: :module_unavailable}} =
             Structure.establish_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_input(
                 registered.id,
                 other.id,
                 :equity_interest,
                 :registered_equity,
                 5_000
               )
             )

    assert {:ok, [[2, 2]]} = entity_and_profile_counts(fixture.runtime, context_a())
  end

  test "database constraints reject cross-tenant profile links and identity/history mutation",
       fixture do
    assert {:ok, registered_a} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Constraint Entity A", "Constraint A")
             )

    assert {:ok, registered_b} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_b(),
               register_input("Constraint Entity B", "Constraint B")
             )

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          INSERT INTO organization_legal_entity_profile_revisions (
            id, tenant_id, legal_entity_id, revision_number, official_name,
            display_name, recorded_by_actor_id, recorded_at, inserted_at
          )
          VALUES ($1, $2, $3, 99, 'Cross tenant', 'Cross tenant', $4, NOW(), NOW())
          """,
          Enum.map([UUID.generate(), @tenant_a, registered_b.id, @actor_a], &dump/1)
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_entity_profile_revisions
          SET display_name = 'Mutated history'
          WHERE tenant_id = $1 AND legal_entity_id = $2 AND revision_number = 1
          """,
          [dump(@tenant_a), dump(registered_a.id)]
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_entities
          SET tenant_id = $1
          WHERE tenant_id = $2 AND id = $3
          """,
          [dump(@tenant_b), dump(@tenant_a), dump(registered_a.id)]
        )
      end)
    end)
  end

  test "establishes only the closed direct relationship catalogue with exact replay and read",
       fixture do
    source = register_entity!(fixture.runtime, context_a(), "Relationship source")
    target = register_entity!(fixture.runtime, context_a(), "Relationship target")

    catalogue = [
      {:equity_interest, :registered_equity, 6_000},
      {:governing_body_appointment, :governing_instrument, nil},
      {:statutory_control, :statute, nil},
      {:contractual_control, :contract, nil}
    ]

    results =
      Enum.map(catalogue, fn {type, basis, interest_bps} ->
        input = relationship_input(source.id, target.id, type, basis, interest_bps)

        assert {:ok, %ActionResult{lock_version: 1} = first} =
                 Structure.establish_legal_entity_relationship(
                   fixture.runtime,
                   context_a(),
                   input
                 )

        assert {:ok, ^first} =
                 Structure.establish_legal_entity_relationship(
                   fixture.runtime,
                   context_a(UUID.generate()),
                   input
                 )

        assert {:ok,
                %LegalEntityRelationshipView{
                  id: relationship_id,
                  source_legal_entity_id: source_id,
                  target_legal_entity_id: target_id,
                  relationship_type: ^type,
                  basis_key: ^basis,
                  interest_bps: ^interest_bps,
                  effective_from: ~D[2026-10-03],
                  effective_until: nil,
                  status: :active,
                  lock_version: 1
                }} =
                 Structure.current_legal_entity_relationship(
                   fixture.runtime,
                   context_a(),
                   first.id
                 )

        assert relationship_id == first.id
        assert source_id == source.id
        assert target_id == target.id

        assert {:ok, [payload]} = outbox_payload(fixture.runtime, context_a(), first.event_id)
        refute Map.has_key?(payload, "interest_bps")
        refute Map.has_key?(payload, "evidence_reference")

        {input, first}
      end)

    {equity_input, _equity_result} = hd(results)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Structure.establish_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               %{equity_input | interest_bps: 5_000}
             )

    assert {:error, %Error{code: :invalid_input}} =
             Structure.establish_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_input(
                 source.id,
                 target.id,
                 :governing_body_appointment,
                 :governing_instrument,
                 5_100
               )
             )

    assert {:error, %Error{code: :forbidden}} =
             Structure.establish_legal_entity_relationship(
               fixture.runtime,
               context_a_denied(),
               relationship_input(
                 source.id,
                 target.id,
                 :equity_interest,
                 :registered_equity,
                 1_000
               )
             )

    tenant_b_entity = register_entity!(fixture.runtime, context_b(), "Tenant B relationship")

    assert {:error, %Error{code: :not_found}} =
             Structure.establish_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_input(
                 source.id,
                 tenant_b_entity.id,
                 :equity_interest,
                 :registered_equity,
                 1_000
               )
             )
  end

  test "ends a direct relationship once while preserving its immutable fact", fixture do
    source = register_entity!(fixture.runtime, context_a(), "Relationship ending source")
    target = register_entity!(fixture.runtime, context_a(), "Relationship ending target")

    relationship =
      establish_relationship!(
        fixture.runtime,
        context_a(),
        source.id,
        target.id,
        :contractual_control,
        :contract,
        nil
      )

    input = relationship_end_input(relationship.id, 1, ~D[2027-03-31])

    assert {:ok, %ActionResult{status: :ended, lock_version: 2} = ended} =
             Structure.end_legal_entity_relationship(fixture.runtime, context_a(), input)

    assert {:ok, ^ended} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(UUID.generate()),
               input
             )

    assert {:ok,
            %LegalEntityRelationshipView{
              id: relationship_id,
              source_legal_entity_id: source_id,
              target_legal_entity_id: target_id,
              relationship_type: :contractual_control,
              basis_key: :contract,
              interest_bps: nil,
              effective_from: ~D[2026-10-03],
              effective_until: ~D[2027-03-31],
              status: :ended,
              lock_version: 2
            }} =
             Structure.current_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship.id
             )

    assert relationship_id == relationship.id
    assert source_id == source.id
    assert target_id == target.id

    assert {:ok, [payload]} = outbox_payload(fixture.runtime, context_a(), ended.event_id)
    assert payload["effective_until"] == "2027-03-31"
    assert payload["status"] == "ended"
    refute Map.has_key?(payload, "evidence_reference")

    assert {:error, %Error{code: :idempotency_conflict}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               %{input | effective_until: ~D[2027-04-01]}
             )

    assert {:error, %Error{code: :conflict}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_end_input(relationship.id, 2, ~D[2027-04-01])
             )

    stale_relationship =
      establish_relationship!(
        fixture.runtime,
        context_a(),
        source.id,
        target.id,
        :statutory_control,
        :statute,
        nil
      )

    assert {:error, %Error{code: :stale}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_end_input(stale_relationship.id, 2, ~D[2027-04-01])
             )

    invalid_relationship =
      establish_relationship!(
        fixture.runtime,
        context_a(),
        source.id,
        target.id,
        :governing_body_appointment,
        :governing_instrument,
        nil
      )

    assert {:error, %Error{code: :invalid_input}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_end_input(invalid_relationship.id, 1, ~D[2026-10-03])
             )

    assert {:error, %Error{code: :forbidden}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a_denied(),
               relationship_end_input(stale_relationship.id, 1, ~D[2027-04-01])
             )

    tenant_b_source = register_entity!(fixture.runtime, context_b(), "Tenant B ending source")
    tenant_b_target = register_entity!(fixture.runtime, context_b(), "Tenant B ending target")

    tenant_b_relationship =
      establish_relationship!(
        fixture.runtime,
        context_b(),
        tenant_b_source.id,
        tenant_b_target.id,
        :contractual_control,
        :contract,
        nil
      )

    assert {:error, %Error{code: :not_found}} =
             Structure.end_legal_entity_relationship(
               fixture.runtime,
               context_a(),
               relationship_end_input(tenant_b_relationship.id, 1, ~D[2027-04-01])
             )

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_entity_relationship_terminations
          SET effective_until = '2027-04-30'
          WHERE tenant_id = $1 AND relationship_id = $2
          """,
          [dump(@tenant_a), dump(relationship.id)]
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          INSERT INTO organization_legal_entity_relationship_terminations (
            id, tenant_id, relationship_id, effective_until, evidence_reference,
            recorded_by_actor_id, recorded_at, inserted_at
          )
          VALUES ($1, $2, $3, '2026-10-03', 'SYNTHETIC:INVALID-END', $4, NOW(), NOW())
          """,
          Enum.map([UUID.generate(), @tenant_a, invalid_relationship.id, @actor_a], &dump/1)
        )
      end)
    end)
  end

  test "serializes management-reporting parentage and rejects direct, indirect, and concurrent cycles",
       fixture do
    entity_a = register_entity!(fixture.runtime, context_a(), "Consolidation A")
    entity_b = register_entity!(fixture.runtime, context_a(), "Consolidation B")
    entity_c = register_entity!(fixture.runtime, context_a(), "Consolidation C")

    input_ab = consolidation_input(entity_a.id, entity_b.id)

    assert {:ok, %ActionResult{} = parentage_ab} =
             Structure.set_primary_consolidation_parent(fixture.runtime, context_a(), input_ab)

    assert {:ok, ^parentage_ab} =
             Structure.set_primary_consolidation_parent(
               fixture.runtime,
               context_a(UUID.generate()),
               input_ab
             )

    assert {:ok,
            %ConsolidationParentageView{
              id: parentage_id,
              child_legal_entity_id: child_id,
              parent_legal_entity_id: parent_id,
              reporting_basis: :management_reporting
            }} =
             Structure.current_primary_consolidation_parent(
               fixture.runtime,
               context_a(),
               entity_a.id
             )

    assert parentage_id == parentage_ab.id
    assert child_id == entity_a.id
    assert parent_id == entity_b.id

    assert {:ok, %ActionResult{}} =
             Structure.set_primary_consolidation_parent(
               fixture.runtime,
               context_a(),
               consolidation_input(entity_b.id, entity_c.id)
             )

    assert {:error, %Error{code: :conflict}} =
             Structure.set_primary_consolidation_parent(
               fixture.runtime,
               context_a(),
               consolidation_input(entity_c.id, entity_a.id)
             )

    assert {:error, %Error{code: :invalid_input}} =
             Structure.set_primary_consolidation_parent(
               fixture.runtime,
               context_a(),
               consolidation_input(entity_a.id, entity_a.id)
             )

    entity_x = register_entity!(fixture.runtime, context_a(), "Concurrent consolidation X")
    entity_y = register_entity!(fixture.runtime, context_a(), "Concurrent consolidation Y")

    parent = self()

    tasks =
      for {child, proposed_parent} <- [{entity_x.id, entity_y.id}, {entity_y.id, entity_x.id}] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              Structure.set_primary_consolidation_parent(
                fixture.runtime,
                context_a(),
                consolidation_input(child, proposed_parent)
              )
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %ActionResult{}}, &1))
    assert 1 == Enum.count(results, &match?({:error, %Error{code: :conflict}}, &1))
  end

  test "registers corporate-unit roots and children without crossing legal-entity ownership",
       fixture do
    entity_a = register_entity!(fixture.runtime, context_a(), "Corporate owner A")
    entity_b = register_entity!(fixture.runtime, context_a(), "Corporate owner B")

    root_input = corporate_unit_input(entity_a.id, nil, "Group shared services")

    assert {:ok, %ActionResult{} = root} =
             Structure.register_corporate_unit(fixture.runtime, context_a(), root_input)

    assert {:ok, ^root} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(UUID.generate()),
               root_input
             )

    assert {:ok, %ActionResult{} = child} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(),
               corporate_unit_input(entity_a.id, root.id, "Finance operations")
             )

    assert {:ok,
            %CorporateUnitView{
              id: child_id,
              legal_entity_id: legal_entity_id,
              parent_corporate_unit_id: parent_id,
              official_name: "Finance operations",
              display_name: "Finance operations",
              status: :active,
              lock_version: 1
            }} = Structure.current_corporate_unit(fixture.runtime, context_a(), child.id)

    assert child_id == child.id
    assert legal_entity_id == entity_a.id
    assert parent_id == root.id

    assert {:error, %Error{code: :not_found}} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(),
               corporate_unit_input(entity_b.id, root.id, "Invalid cross-owner child")
             )

    tenant_b_entity = register_entity!(fixture.runtime, context_b(), "Tenant B corporate owner")

    assert {:ok, tenant_b_unit} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_b(),
               corporate_unit_input(tenant_b_entity.id, nil, "Tenant B root")
             )

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          INSERT INTO organization_legal_corporate_units (
            id, tenant_id, legal_entity_id, parent_corporate_unit_id,
            status, lock_version, inserted_at, updated_at
          )
          VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW())
          """,
          Enum.map([UUID.generate(), @tenant_a, entity_a.id, tenant_b_unit.id], &dump/1)
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_corporate_units
          SET parent_corporate_unit_id = NULL
          WHERE tenant_id = $1 AND id = $2
          """,
          [dump(@tenant_a), dump(child.id)]
        )
      end)
    end)
  end

  test "revises corporate-unit names as consecutive immutable profiles", fixture do
    entity = register_entity!(fixture.runtime, context_a(), "Corporate profile owner")

    assert {:ok, unit} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(),
               corporate_unit_input(entity.id, nil, "Initial shared services")
             )

    input =
      corporate_unit_revise_input(
        unit.id,
        1,
        "Mphamvu Shared Services",
        "Shared Services"
      )

    assert {:ok, %ActionResult{status: :active, lock_version: 2} = revised} =
             Structure.revise_corporate_unit_profile(fixture.runtime, context_a(), input)

    assert {:ok, ^revised} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(UUID.generate()),
               input
             )

    assert {:ok,
            %CorporateUnitView{
              id: unit_id,
              legal_entity_id: entity_id,
              parent_corporate_unit_id: nil,
              official_name: "Mphamvu Shared Services",
              display_name: "Shared Services",
              status: :active,
              lock_version: 2
            }} = Structure.current_corporate_unit(fixture.runtime, context_a(), unit.id)

    assert unit_id == unit.id
    assert entity_id == entity.id

    assert {:ok,
            [
              [1, "Initial shared services", "Initial shared services"],
              [2, "Mphamvu Shared Services", "Shared Services"]
            ]} = corporate_unit_profile_history(fixture.runtime, context_a(), unit.id)

    assert {:ok, [payload]} = outbox_payload(fixture.runtime, context_a(), revised.event_id)
    assert payload["lock_version"] == 2
    refute Map.has_key?(payload, "official_name")
    refute Map.has_key?(payload, "display_name")

    assert {:error, %Error{code: :idempotency_conflict}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(),
               %{input | display_name: "Changed replay"}
             )

    assert {:error, %Error{code: :invalid_input}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(),
               corporate_unit_revise_input(
                 unit.id,
                 2,
                 "Mphamvu Shared Services",
                 "Shared Services"
               )
             )

    assert {:error, %Error{code: :stale}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(),
               corporate_unit_revise_input(unit.id, 1, "Stale profile", "Stale")
             )

    assert {:error, %Error{code: :forbidden}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a_denied(),
               corporate_unit_revise_input(unit.id, 2, "Denied profile", "Denied")
             )

    tenant_b_entity = register_entity!(fixture.runtime, context_b(), "Tenant B profile owner")

    assert {:ok, tenant_b_unit} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_b(),
               corporate_unit_input(tenant_b_entity.id, nil, "Tenant B corporate unit")
             )

    assert {:error, %Error{code: :not_found}} =
             Structure.revise_corporate_unit_profile(
               fixture.runtime,
               context_a(),
               corporate_unit_revise_input(
                 tenant_b_unit.id,
                 1,
                 "Cross tenant profile",
                 "Cross tenant"
               )
             )

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          INSERT INTO organization_legal_corporate_unit_profile_revisions (
            id, tenant_id, corporate_unit_id, revision_number, official_name,
            display_name, recorded_by_actor_id, recorded_at, inserted_at
          )
          VALUES ($1, $2, $3, 4, 'Skipped revision', 'Skipped', $4, NOW(), NOW())
          """,
          Enum.map([UUID.generate(), @tenant_a, unit.id, @actor_a], &dump/1)
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_corporate_unit_profile_revisions
          SET display_name = 'Mutated profile'
          WHERE tenant_id = $1 AND corporate_unit_id = $2 AND revision_number = 1
          """,
          [dump(@tenant_a), dump(unit.id)]
        )
      end)
    end)
  end

  test "serializes concurrent corporate-unit profile revisions", fixture do
    entity = register_entity!(fixture.runtime, context_a(), "Concurrent unit owner")

    assert {:ok, unit} =
             Structure.register_corporate_unit(
               fixture.runtime,
               context_a(),
               corporate_unit_input(entity.id, nil, "Concurrent corporate unit")
             )

    parent = self()

    tasks =
      for {official_name, display_name} <- [
            {"Concurrent Corporate Unit Alpha", "Alpha"},
            {"Concurrent Corporate Unit Beta", "Beta"}
          ] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              Structure.revise_corporate_unit_profile(
                fixture.runtime,
                context_a(),
                corporate_unit_revise_input(unit.id, 1, official_name, display_name)
              )
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %ActionResult{lock_version: 2}}, &1))
    assert 1 == Enum.count(results, &match?({:error, %Error{code: :stale}}, &1))

    assert {:ok, [[1], [2]]} =
             corporate_unit_profile_versions(fixture.runtime, context_a(), unit.id)
  end

  test "rolls back a relationship, audit, outbox, and claim after late failure", fixture do
    source = register_entity!(fixture.runtime, context_a(), "Rollback relationship source")
    target = register_entity!(fixture.runtime, context_a(), "Rollback relationship target")

    input =
      relationship_input(
        source.id,
        target.id,
        :equity_interest,
        :registered_equity,
        5_000
      )

    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Structure.establish_legal_entity_relationship(fixture.runtime, context_a(), input)

      assert {:ok, [[0, 0, 0, 0, 0, 0, 0, 0]]} =
               structure_counts(fixture.runtime, context_a())
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %ActionResult{}} =
             Structure.establish_legal_entity_relationship(fixture.runtime, context_a(), input)
  end

  test "rolls back relationship ending and its evidence after a late failure", fixture do
    source = register_entity!(fixture.runtime, context_a(), "Rollback ending source")
    target = register_entity!(fixture.runtime, context_a(), "Rollback ending target")

    relationship =
      establish_relationship!(
        fixture.runtime,
        context_a(),
        source.id,
        target.id,
        :contractual_control,
        :contract,
        nil
      )

    input = relationship_end_input(relationship.id, 1, ~D[2027-12-31])
    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Structure.end_legal_entity_relationship(fixture.runtime, context_a(), input)

      assert {:ok, %LegalEntityRelationshipView{status: :active, lock_version: 1}} =
               Structure.current_legal_entity_relationship(
                 fixture.runtime,
                 context_a(),
                 relationship.id
               )

      assert {:ok, [[0]]} =
               relationship_termination_count(fixture.runtime, context_a(), relationship.id)
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %ActionResult{status: :ended, lock_version: 2}} =
             Structure.end_legal_entity_relationship(fixture.runtime, context_a(), input)
  end

  defp seed_foundation(runtime) do
    ids = %{
      membership_a: UUID.generate(),
      membership_a_peer: UUID.generate(),
      membership_a_denied: UUID.generate(),
      membership_b: UUID.generate(),
      role_a: UUID.generate(),
      role_b: UUID.generate(),
      manage_capability_a: UUID.generate(),
      read_capability_a: UUID.generate(),
      relationships_capability_a: UUID.generate(),
      corporate_units_capability_a: UUID.generate(),
      manage_capability_b: UUID.generate(),
      read_capability_b: UUID.generate(),
      relationships_capability_b: UUID.generate(),
      corporate_units_capability_b: UUID.generate()
    }

    seed_tenant(
      runtime,
      context_a(),
      @tenant_a,
      [
        {ids.membership_a, @actor_a, true},
        {ids.membership_a_peer, @actor_a_peer, true},
        {ids.membership_a_denied, @actor_a_denied, false}
      ],
      ids.role_a,
      %{
        manage: ids.manage_capability_a,
        read: ids.read_capability_a,
        relationships: ids.relationships_capability_a,
        corporate_units: ids.corporate_units_capability_a
      }
    )

    seed_tenant(
      runtime,
      context_b(),
      @tenant_b,
      [{ids.membership_b, @actor_b, true}],
      ids.role_b,
      %{
        manage: ids.manage_capability_b,
        read: ids.read_capability_b,
        relationships: ids.relationships_capability_b,
        corporate_units: ids.corporate_units_capability_b
      }
    )

    ids
  end

  defp seed_tenant(
         runtime,
         context,
         tenant_id,
         memberships,
         role_id,
         capability_ids
       ) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_role(role_id, tenant_id)

               Enum.each(
                 memberships,
                 &seed_membership(&1, tenant_id, role_id)
               )

               insert_capability(capability_ids.manage, tenant_id, @manage_capability)
               insert_capability(capability_ids.read, tenant_id, @read_capability)

               insert_capability(
                 capability_ids.relationships,
                 tenant_id,
                 @relationships_capability
               )

               insert_capability(
                 capability_ids.corporate_units,
                 tenant_id,
                 @corporate_units_capability
               )

               insert_grant(tenant_id, role_id, capability_ids.manage)
               insert_grant(tenant_id, role_id, capability_ids.read)
               insert_grant(tenant_id, role_id, capability_ids.relationships)
               insert_grant(tenant_id, role_id, capability_ids.corporate_units)
               insert_active_module(tenant_id)
               :seeded
             end)
  end

  defp seed_membership({membership_id, actor_id, assigned?}, tenant_id, role_id) do
    insert_membership(membership_id, tenant_id, actor_id)
    if assigned?, do: insert_assignment(tenant_id, membership_id, role_id)
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships
        (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, 'Legal structure manager', 1, NOW(), NOW())
      """,
      Enum.map([id, tenant_id], &dump/1)
    )
  end

  defp insert_capability(id, tenant_id, key) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities
        (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), key]
    )
  end

  defp insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, 1, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp insert_active_module(tenant_id) do
    entitlement_id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      """,
      [dump(entitlement_id), dump(tenant_id), @module_key]
    )

    Repo.query!(
      """
      INSERT INTO platform_module_activations (
        id, tenant_id, entitlement_id, module_version, state, lock_version,
        activated_at, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, '1.2.0', 'active', 1, NOW(), NOW(), NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, entitlement_id], &dump/1)
    )
  end

  defp deactivate_module(runtime, context) do
    assert {:ok, :deactivated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations AS activation
                 SET state = 'inactive',
                     lock_version = lock_version + 1,
                     deactivated_at = NOW(),
                     replay_from_cursor = consumer_cursor,
                     projection_ready = false,
                     reconciliation_required = true,
                     updated_at = NOW()
                 FROM platform_module_entitlements AS entitlement
                 WHERE entitlement.tenant_id = activation.tenant_id
                   AND entitlement.id = activation.entitlement_id
                   AND activation.tenant_id = $1
                   AND entitlement.module_key = $2
                 """,
                 [dump(TrustedActor.tenant_id(context.actor)), @module_key]
               )

               :deactivated
             end)
  end

  defp read_committed_facts(runtime, context, entity_id, audit_reference, event_id, key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT entity.status, entity.lock_version, profile.revision_number,
               profile.official_name, profile.display_name,
               audit.action_name, audit.before_version, audit.after_version,
               audit.change_summary, outbox.event_type, outbox.payload, claim.status
        FROM organization_legal_entities AS entity
        JOIN organization_legal_entity_profile_revisions AS profile
          ON profile.tenant_id = entity.tenant_id
         AND profile.legal_entity_id = entity.id
         AND profile.revision_number = entity.lock_version
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = entity.tenant_id AND audit.aggregate_id = entity.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE entity.tenant_id = $1 AND entity.id = $2
          AND audit.id = $3 AND outbox.id = $4 AND claim.idempotency_key = $5
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            entity_id,
            audit_reference,
            event_id,
            key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp profile_history(runtime, context, entity_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT revision_number, official_name, display_name
        FROM organization_legal_entity_profile_revisions
        WHERE tenant_id = $1 AND legal_entity_id = $2
        ORDER BY revision_number
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(entity_id)]
      ).rows
    end)
  end

  defp profile_count(runtime, context, entity_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT count(*)
        FROM organization_legal_entity_profile_revisions
        WHERE tenant_id = $1 AND legal_entity_id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(entity_id)]
      ).rows
    end)
  end

  defp corporate_unit_profile_history(runtime, context, corporate_unit_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT revision_number, official_name, display_name
        FROM organization_legal_corporate_unit_profile_revisions
        WHERE tenant_id = $1 AND corporate_unit_id = $2
        ORDER BY revision_number
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(corporate_unit_id)]
      ).rows
    end)
  end

  defp corporate_unit_profile_versions(runtime, context, corporate_unit_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT revision_number
        FROM organization_legal_corporate_unit_profile_revisions
        WHERE tenant_id = $1 AND corporate_unit_id = $2
        ORDER BY revision_number
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(corporate_unit_id)]
      ).rows
    end)
  end

  defp relationship_termination_count(runtime, context, relationship_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT count(*)
        FROM organization_legal_entity_relationship_terminations
        WHERE tenant_id = $1 AND relationship_id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(relationship_id)]
      ).rows
    end)
  end

  defp fact_counts(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND action_name IN ($2, $3)),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_type = 'organization.legal.entity'),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name IN ($2, $3))
        """,
        [tenant_id, @register_action, @revise_action]
      ).rows
    end)
  end

  defp entity_and_profile_counts(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM organization_legal_entities WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_entity_profile_revisions WHERE tenant_id = $1)
        """,
        [tenant_id]
      ).rows
    end)
  end

  defp structure_counts(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM organization_legal_entity_relationships
           WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_entity_relationship_terminations
           WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_entity_consolidation_parentages
           WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_corporate_units
           WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_corporate_unit_profile_revisions
           WHERE tenant_id = $1),
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND action_name IN ($2, $3, $4, $5, $6)),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_type IN ($7, $8, $9)),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name IN ($2, $3, $4, $5, $6))
        """,
        [
          tenant_id,
          @relationship_action,
          @relationship_end_action,
          @consolidation_action,
          @corporate_unit_action,
          @corporate_unit_revise_action,
          "organization.legal.relationship",
          "organization.legal.consolidation_parentage",
          "organization.legal.corporate_unit"
        ]
      ).rows
    end)
  end

  defp outbox_payload(runtime, context, event_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT payload
        FROM platform_outbox_events
        WHERE tenant_id = $1 AND id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(event_id)]
      ).rows
      |> Enum.map(fn [payload] -> payload end)
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_organization_legal_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_organization_legal_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_organization_legal_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'organization.legal.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_organization_legal_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_organization_legal_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_organization_legal_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_organization_legal_completion()")
               :removed
             end)
  end

  defp clear_fixture(runtime) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("""
               TRUNCATE
                 organization_legal_entity_relationship_terminations,
                 organization_legal_corporate_unit_profile_revisions,
                 organization_legal_corporate_units,
                 organization_legal_entity_relationships,
                 organization_legal_entity_consolidation_parentages,
                 organization_legal_entity_profile_revisions,
                 organization_legal_entities
               """)

               :cleared
             end)

    Enum.each([context_a(), context_b()], fn context ->
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end)
  end

  defp clear_tenant(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      for table <- [
            "platform_governed_extension_definitions",
            "platform_authority_action_idempotency",
            "platform_outbox_consumer_receipts",
            "platform_outbox_deliveries",
            "platform_outbox_events",
            "platform_authority_audit_events",
            "platform_module_work_items",
            "platform_module_activations",
            "platform_module_entitlements",
            "platform_role_inclusions",
            "platform_role_capability_grants",
            "platform_actor_role_assignments",
            "platform_capabilities",
            "platform_roles",
            "platform_tenant_memberships"
          ] do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [tenant_id])
      end

      :cleared
    end)
  end

  defp register_input(
         official_name,
         display_name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      official_name: official_name,
      display_name: display_name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp register_entity!(runtime, context, name) do
    assert {:ok, %ActionResult{} = result} =
             Foundation.register_legal_entity(
               runtime,
               context,
               register_input("#{name} Limited", name)
             )

    result
  end

  defp relationship_input(
         source_legal_entity_id,
         target_legal_entity_id,
         relationship_type,
         basis_key,
         interest_bps,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      source_legal_entity_id: source_legal_entity_id,
      target_legal_entity_id: target_legal_entity_id,
      relationship_type: relationship_type,
      basis_key: basis_key,
      interest_bps: interest_bps,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:RELATIONSHIP",
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp relationship_end_input(
         relationship_id,
         expected_version,
         effective_until,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      relationship_id: relationship_id,
      expected_version: expected_version,
      effective_until: effective_until,
      evidence_reference: "SYNTHETIC:RELATIONSHIP-END",
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp establish_relationship!(
         runtime,
         context,
         source_id,
         target_id,
         relationship_type,
         basis_key,
         interest_bps
       ) do
    assert {:ok, %ActionResult{} = result} =
             Structure.establish_legal_entity_relationship(
               runtime,
               context,
               relationship_input(
                 source_id,
                 target_id,
                 relationship_type,
                 basis_key,
                 interest_bps
               )
             )

    result
  end

  defp consolidation_input(
         child_legal_entity_id,
         parent_legal_entity_id,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      child_legal_entity_id: child_legal_entity_id,
      parent_legal_entity_id: parent_legal_entity_id,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:MANAGEMENT-REPORTING",
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp corporate_unit_input(
         legal_entity_id,
         parent_corporate_unit_id,
         name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      legal_entity_id: legal_entity_id,
      parent_corporate_unit_id: parent_corporate_unit_id,
      official_name: name,
      display_name: name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp corporate_unit_revise_input(
         corporate_unit_id,
         expected_version,
         official_name,
         display_name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      corporate_unit_id: corporate_unit_id,
      expected_version: expected_version,
      official_name: official_name,
      display_name: display_name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp revise_input(
         legal_entity_id,
         expected_version,
         official_name,
         display_name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      legal_entity_id: legal_entity_id,
      expected_version: expected_version,
      official_name: official_name,
      display_name: display_name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-organization-legal", :pooled),
        placement(@tenant_b, "pooled-organization-legal", :pooled)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 9,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  defp context_a(correlation_id \\ UUID.generate()),
    do: context(@actor_a, @tenant_a, correlation_id)

  defp context_a_peer, do: context(@actor_a_peer, @tenant_a, UUID.generate())
  defp context_a_denied, do: context(@actor_a_denied, @tenant_a, UUID.generate())
  defp context_b, do: context(@actor_b, @tenant_b, UUID.generate())

  defp context(actor_id, tenant_id, correlation_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 9,
        profile: :pooled,
        placement_ref: "pooled-organization-legal"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "organization.legal.entity",
        locale: "en"
      )

    context
  end

  defp assert_postgres_error(operation) do
    assert_raise Postgrex.Error, operation
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
