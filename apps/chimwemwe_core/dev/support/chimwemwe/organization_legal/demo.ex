defmodule Chimwemwe.OrganizationLegal.Demo do
  @moduledoc """
  Guarded local bootstrap for the synthetic Phase 2.1-C2a legal-structure data.

  This development-only module uses the ordinary named actions after creating
  the minimum synthetic tenant authority and module-lifecycle state. It has no
  public route and is not compiled into the production environment.
  """

  alias Chimwemwe.OrganizationLegal.{DemoData, Foundation, Structure}
  alias Chimwemwe.Platform.{Persistence, PersistenceRuntime}
  alias Chimwemwe.Repo

  @module_key "organization.legal"
  @module_version "1.2.0"
  @manage_capability "organization.legal.entities.manage"
  @read_capability "organization.legal.entities.read"
  @relationships_capability "organization.legal.relationships.manage"
  @corporate_units_capability "organization.legal.corporate_units.manage"

  @membership_id "81110000-0000-4000-8000-000000000001"
  @role_id "81120000-0000-4000-8000-000000000001"
  @manage_capability_id "81130000-0000-4000-8000-000000000001"
  @read_capability_id "81130000-0000-4000-8000-000000000002"
  @relationships_capability_id "81130000-0000-4000-8000-000000000003"
  @corporate_units_capability_id "81130000-0000-4000-8000-000000000004"
  @assignment_id "81140000-0000-4000-8000-000000000001"
  @manage_grant_id "81150000-0000-4000-8000-000000000001"
  @read_grant_id "81150000-0000-4000-8000-000000000002"
  @relationships_grant_id "81150000-0000-4000-8000-000000000003"
  @corporate_units_grant_id "81150000-0000-4000-8000-000000000004"
  @entitlement_id "81160000-0000-4000-8000-000000000001"
  @activation_id "81170000-0000-4000-8000-000000000001"

  @type seeded_entity :: %{
          key: String.t(),
          id: String.t(),
          official_name: String.t(),
          display_name: String.t(),
          lock_version: pos_integer()
        }

  @type seeded_structure :: %{
          entities: [seeded_entity()],
          relationships: [map()],
          relationship_terminations: [map()],
          consolidation_parentages: [map()],
          corporate_units: [map()],
          corporate_unit_profile_revisions: [map()]
        }

  @spec seed() :: {:ok, seeded_structure()} | {:error, term()}
  def seed do
    with :ok <- require_local_guard(),
         {:ok, runtime} <- PersistenceRuntime.start_link(runtime_options()) do
      try do
        context = DemoData.context()

        with :ok <- seed_platform(runtime, context),
             {:ok, entities} <- seed_entities(runtime, context),
             {:ok, structure} <- seed_structure(runtime, context, entities) do
          {:ok, Map.put(structure, :entities, entities)}
        end
      after
        Supervisor.stop(runtime)
      end
    end
  end

  @spec seed_and_print!() :: :ok
  def seed_and_print! do
    case seed() do
      {:ok, structure} ->
        IO.puts("Seeded the local synthetic Phase 2.1-C2a legal-structure demonstration.")
        IO.puts("Relationships are direct facts; consolidation is management-reporting only.")

        Enum.each(structure.entities, fn entity ->
          IO.puts("#{entity.key}: #{entity.display_name} (#{entity.id})")
        end)

        IO.puts("Direct relationships: #{length(structure.relationships)}")

        Enum.each(structure.relationships, fn relationship ->
          IO.puts("#{relationship.key}: #{relationship.relationship_type} (#{relationship.id})")
        end)

        IO.puts("Ended relationships: #{length(structure.relationship_terminations)}")

        IO.puts("Management-reporting parentages: #{length(structure.consolidation_parentages)}")

        IO.puts("Corporate units: #{length(structure.corporate_units)}")

        Enum.each(structure.corporate_units, fn unit ->
          IO.puts("#{unit.key}: #{unit.display_name} (#{unit.id})")
        end)

        IO.puts(
          "Corporate-unit name revisions: #{length(structure.corporate_unit_profile_revisions)}"
        )

        Enum.each(structure.corporate_unit_profile_revisions, fn revision ->
          IO.puts(
            "#{revision.corporate_unit_key}: #{revision.display_name} " <>
              "(profile v#{revision.lock_version})"
          )
        end)

        IO.puts("No educational structures, real records, or public workflow were added.")

        :ok

      {:error, reason} ->
        raise "organization legal demo seed failed: #{inspect(reason)}"
    end
  end

  @doc false
  @spec seed_entities(Supervisor.supervisor(), term()) ::
          {:ok, [seeded_entity()]} | {:error, term()}
  def seed_entities(runtime, context) do
    DemoData.entities()
    |> Enum.reduce_while({:ok, []}, fn entity, {:ok, seeded} ->
      input =
        Map.take(entity, [
          :official_name,
          :display_name,
          :idempotency_key,
          :causation_id
        ])

      with {:ok, result} <- Foundation.register_legal_entity(runtime, context, input),
           {:ok, view} <- Foundation.current_legal_entity(runtime, context, result.id) do
        row = %{
          key: entity.key,
          id: view.id,
          official_name: view.official_name,
          display_name: view.display_name,
          lock_version: view.lock_version
        }

        {:cont, {:ok, [row | seeded]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, seeded} -> {:ok, Enum.reverse(seeded)}
      {:error, _reason} = error -> error
    end
  end

  @doc false
  @spec seed_structure(Supervisor.supervisor(), term(), [seeded_entity()]) ::
          {:ok, map()} | {:error, term()}
  def seed_structure(runtime, context, entities) do
    entity_ids = Map.new(entities, &{&1.key, &1.id})

    with {:ok, relationships} <- seed_relationships(runtime, context, entity_ids),
         {:ok, parentages} <- seed_consolidation_parentages(runtime, context, entity_ids),
         {:ok, corporate_units} <- seed_corporate_units(runtime, context, entity_ids),
         relationship_ids = Map.new(relationships, &{&1.key, &1.id}),
         corporate_unit_ids = Map.new(corporate_units, &{&1.key, &1.id}),
         {:ok, terminations} <-
           seed_relationship_terminations(runtime, context, relationship_ids),
         {:ok, profile_revisions} <-
           seed_corporate_unit_profile_revisions(runtime, context, corporate_unit_ids) do
      {:ok,
       %{
         relationships: relationships,
         relationship_terminations: terminations,
         consolidation_parentages: parentages,
         corporate_units: corporate_units,
         corporate_unit_profile_revisions: profile_revisions
       }}
    end
  end

  defp seed_relationships(runtime, context, entity_ids) do
    reduce_demo_data(DemoData.relationships(), fn relationship ->
      input = %{
        source_legal_entity_id: Map.fetch!(entity_ids, relationship.source_key),
        target_legal_entity_id: Map.fetch!(entity_ids, relationship.target_key),
        relationship_type: relationship.relationship_type,
        basis_key: relationship.basis_key,
        interest_bps: relationship.interest_bps,
        effective_from: relationship.effective_from,
        evidence_reference: relationship.evidence_reference,
        idempotency_key: relationship.idempotency_key,
        causation_id: relationship.causation_id
      }

      with {:ok, result} <-
             Structure.establish_legal_entity_relationship(runtime, context, input) do
        {:ok,
         %{
           key: relationship.key,
           id: result.id,
           relationship_type: relationship.relationship_type
         }}
      end
    end)
  end

  defp seed_consolidation_parentages(runtime, context, entity_ids) do
    reduce_demo_data(DemoData.consolidation_parentages(), fn parentage ->
      input = %{
        child_legal_entity_id: Map.fetch!(entity_ids, parentage.child_key),
        parent_legal_entity_id: Map.fetch!(entity_ids, parentage.parent_key),
        effective_from: parentage.effective_from,
        evidence_reference: parentage.evidence_reference,
        idempotency_key: parentage.idempotency_key,
        causation_id: parentage.causation_id
      }

      with {:ok, result} <- Structure.set_primary_consolidation_parent(runtime, context, input) do
        {:ok, %{key: parentage.key, id: result.id}}
      end
    end)
  end

  defp seed_corporate_units(runtime, context, entity_ids) do
    Enum.reduce_while(DemoData.corporate_units(), {:ok, [], %{}}, fn unit,
                                                                     {:ok, seeded, unit_ids} ->
      parent_id = if unit.parent_key, do: Map.fetch!(unit_ids, unit.parent_key)

      input = %{
        legal_entity_id: Map.fetch!(entity_ids, unit.legal_entity_key),
        parent_corporate_unit_id: parent_id,
        official_name: unit.official_name,
        display_name: unit.display_name,
        idempotency_key: unit.idempotency_key,
        causation_id: unit.causation_id
      }

      case Structure.register_corporate_unit(runtime, context, input) do
        {:ok, result} ->
          row = %{key: unit.key, id: result.id, display_name: unit.display_name}
          {:cont, {:ok, [row | seeded], Map.put(unit_ids, unit.key, result.id)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, seeded, _unit_ids} -> {:ok, Enum.reverse(seeded)}
      {:error, _reason} = error -> error
    end
  end

  defp seed_relationship_terminations(runtime, context, relationship_ids) do
    reduce_demo_data(DemoData.relationship_terminations(), fn termination ->
      relationship_id = Map.fetch!(relationship_ids, termination.relationship_key)

      input = %{
        relationship_id: relationship_id,
        expected_version: termination.expected_version,
        effective_until: termination.effective_until,
        evidence_reference: termination.evidence_reference,
        idempotency_key: termination.idempotency_key,
        causation_id: termination.causation_id
      }

      with {:ok, result} <- Structure.end_legal_entity_relationship(runtime, context, input),
           {:ok, view} <-
             Structure.current_legal_entity_relationship(runtime, context, relationship_id) do
        {:ok,
         %{
           key: termination.key,
           relationship_key: termination.relationship_key,
           id: result.id,
           status: view.status,
           effective_until: view.effective_until,
           lock_version: view.lock_version
         }}
      end
    end)
  end

  defp seed_corporate_unit_profile_revisions(runtime, context, corporate_unit_ids) do
    reduce_demo_data(DemoData.corporate_unit_profile_revisions(), fn revision ->
      corporate_unit_id = Map.fetch!(corporate_unit_ids, revision.corporate_unit_key)

      input = %{
        corporate_unit_id: corporate_unit_id,
        expected_version: revision.expected_version,
        official_name: revision.official_name,
        display_name: revision.display_name,
        idempotency_key: revision.idempotency_key,
        causation_id: revision.causation_id
      }

      with {:ok, result} <- Structure.revise_corporate_unit_profile(runtime, context, input),
           {:ok, view} <- Structure.current_corporate_unit(runtime, context, corporate_unit_id) do
        {:ok,
         %{
           key: revision.key,
           corporate_unit_key: revision.corporate_unit_key,
           id: result.id,
           official_name: view.official_name,
           display_name: view.display_name,
           lock_version: view.lock_version
         }}
      end
    end)
  end

  defp reduce_demo_data(rows, operation) do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, seeded} ->
      case operation.(row) do
        {:ok, value} -> {:cont, {:ok, [value | seeded]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, seeded} -> {:ok, Enum.reverse(seeded)}
      {:error, _reason} = error -> error
    end
  end

  defp require_local_guard do
    if System.get_env("CHIMWEMWE_ORGANIZATION_LEGAL_DEMO") == "true" do
      :ok
    else
      {:error, :local_demo_disabled}
    end
  end

  defp runtime_options do
    [
      repositories: [
        organization_legal_demo: Application.fetch_env!(:chimwemwe_core, Chimwemwe.Repo)
      ],
      placements: DemoData.placements(),
      per_tenant_limit: 2,
      per_placement_limit: 2
    ]
  end

  defp seed_platform(runtime, context) do
    case Persistence.with_writer(runtime, context, fn ->
           Repo.transaction(fn ->
             insert_platform_rows()

             if platform_state_valid?() do
               :seeded
             else
               Repo.rollback(:demo_state_conflict)
             end
           end)
         end) do
      {:ok, {:ok, :seeded}} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_platform_rows do
    tenant_id = dump(DemoData.tenant_id())
    actor_id = dump(DemoData.actor_id())

    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships
        (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(@membership_id), tenant_id, actor_id]
    )

    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, 'Legal structure demonstration manager', 1, NOW(), NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(@role_id), tenant_id]
    )

    insert_capability(@manage_capability_id, @manage_capability, tenant_id)
    insert_capability(@read_capability_id, @read_capability, tenant_id)
    insert_capability(@relationships_capability_id, @relationships_capability, tenant_id)
    insert_capability(@corporate_units_capability_id, @corporate_units_capability, tenant_id)

    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, 1, NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(@assignment_id), tenant_id, dump(@membership_id), dump(@role_id)]
    )

    insert_grant(@manage_grant_id, @manage_capability_id, tenant_id)
    insert_grant(@read_grant_id, @read_capability_id, tenant_id)
    insert_grant(@relationships_grant_id, @relationships_capability_id, tenant_id)
    insert_grant(@corporate_units_grant_id, @corporate_units_capability_id, tenant_id)

    Repo.query!(
      """
      INSERT INTO platform_module_entitlements
        (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(@entitlement_id), tenant_id, @module_key]
    )

    Repo.query!(
      """
      INSERT INTO platform_module_activations
        (id, tenant_id, entitlement_id, module_version, state, lock_version,
         activated_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW(), NOW())
      ON CONFLICT (id) DO UPDATE
      SET module_version = EXCLUDED.module_version,
          state = 'active',
          lock_version = platform_module_activations.lock_version + 1,
          deactivated_at = NULL,
          updated_at = NOW()
      WHERE platform_module_activations.tenant_id = EXCLUDED.tenant_id
        AND platform_module_activations.entitlement_id = EXCLUDED.entitlement_id
        AND (
          platform_module_activations.module_version <> EXCLUDED.module_version OR
          platform_module_activations.state <> 'active'
        )
      """,
      [dump(@activation_id), tenant_id, dump(@entitlement_id), @module_version]
    )
  end

  defp insert_capability(id, key, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities
        (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(id), tenant_id, key]
    )
  end

  defp insert_grant(id, capability_id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      ON CONFLICT DO NOTHING
      """,
      [dump(id), tenant_id, dump(@role_id), dump(capability_id)]
    )
  end

  defp platform_state_valid? do
    tenant_id = dump(DemoData.tenant_id())

    case Repo.query!(
           """
           SELECT
             membership.actor_id = $2,
             role.name = 'Legal structure demonstration manager',
             activation.module_version = $3 AND activation.state = 'active',
             array_agg(capability.key ORDER BY capability.key) = ARRAY[$4, $5, $6, $7]::text[]
           FROM platform_tenant_memberships AS membership
           JOIN platform_actor_role_assignments AS assignment
             ON assignment.tenant_id = membership.tenant_id
            AND assignment.membership_id = membership.id
           JOIN platform_roles AS role
             ON role.tenant_id = assignment.tenant_id
            AND role.id = assignment.role_id
           JOIN platform_role_capability_grants AS capability_grant
             ON capability_grant.tenant_id = role.tenant_id
            AND capability_grant.role_id = role.id
           JOIN platform_capabilities AS capability
             ON capability.tenant_id = capability_grant.tenant_id
            AND capability.id = capability_grant.capability_id
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = membership.tenant_id
            AND entitlement.module_key = $8
           JOIN platform_module_activations AS activation
             ON activation.tenant_id = entitlement.tenant_id
            AND activation.entitlement_id = entitlement.id
           WHERE membership.tenant_id = $1
             AND membership.id = $9
             AND role.id = $10
             AND activation.id = $11
           GROUP BY membership.actor_id, role.name, activation.module_version, activation.state
           """,
           [
             tenant_id,
             dump(DemoData.actor_id()),
             @module_version,
             @corporate_units_capability,
             @manage_capability,
             @read_capability,
             @relationships_capability,
             @module_key,
             dump(@membership_id),
             dump(@role_id),
             dump(@activation_id)
           ]
         ).rows do
      [[true, true, true, true]] -> true
      _other -> false
    end
  end

  defp dump(value), do: Ecto.UUID.dump!(value)
end
