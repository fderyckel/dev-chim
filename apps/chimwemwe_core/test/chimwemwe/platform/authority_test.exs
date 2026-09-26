defmodule Chimwemwe.Platform.AuthorityTest do
  use ExUnit.Case, async: false

  alias Ash.Resource.Info, as: ResourceInfo
  alias Chimwemwe.Platform

  alias Chimwemwe.Platform.{
    Authority,
    AuthorityError,
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceError,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.Policy.HasCapability
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @actor_unassigned "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @correlation_id "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  @authority_tables [
    "platform_authority_action_idempotency",
    "platform_outbox_consumer_receipts",
    "platform_outbox_deliveries",
    "platform_outbox_events",
    "platform_authority_audit_events",
    "platform_role_inclusions",
    "platform_role_capability_grants",
    "platform_actor_role_assignments",
    "platform_capabilities",
    "platform_roles",
    "platform_tenant_memberships"
  ]

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_tenants(runtime)
    fixture = seed_authority_graph(runtime)
    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "resolves direct and composed capabilities without depending on role names", fixture do
    assert :ok = Authority.authorize(fixture.runtime, context_a(), "records.read")
    assert :ok = Authority.authorize(fixture.runtime, context_a(), "records.write")

    assert {:ok, true} =
             Persistence.with_writer(fixture.runtime, context_a(), fn ->
               HasCapability.match?(context_a().actor, %{}, capability: "records.read")
             end)

    assert {:ok, _result} =
             Persistence.with_writer(fixture.runtime, context_a(), fn ->
               Repo.query!(
                 """
                 UPDATE platform_roles
                 SET name = 'Renamed tenant-defined role',
                     lock_version = lock_version + 1,
                     updated_at = NOW()
                 WHERE tenant_id = $1 AND id = $2
                 """,
                 [dump(@tenant_a), dump(fixture.assigned_role)]
               )
             end)

    assert :ok = Authority.authorize(fixture.runtime, context_a(), "records.read")
    assert :ok = Authority.authorize(fixture.runtime, context_a(), "records.write")
  end

  test "denies missing membership, missing grant, and malformed capability input", fixture do
    assert {:error, %AuthorityError{code: :forbidden}} =
             Authority.authorize(fixture.runtime, context_unassigned(), "records.read")

    assert {:error, %AuthorityError{code: :forbidden}} =
             Authority.authorize(fixture.runtime, context_a(), "records.delete")

    assert {:error, %AuthorityError{code: :invalid_capability}} =
             Authority.authorize(fixture.runtime, context_a(), "caller selected role")

    refute Authority.actor_has_capability?(context_a().actor, "records.read")
  end

  test "rejects raw, tenant-mismatched, stale, and unavailable context before authority lookup",
       fixture do
    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Authority.authorize(
               fixture.runtime,
               %{tenant_id: @tenant_a},
               "records.read"
             )

    mismatched = put_in(context_a().placement.tenant_id, @tenant_b)

    assert {:error, %ContextError{code: :tenant_mismatch}} =
             Authority.authorize(fixture.runtime, mismatched, "records.read")

    stale = put_in(context_a().placement.routing_version, 6)

    assert {:error, %PersistenceError{code: :route_not_available}} =
             Authority.authorize(fixture.runtime, stale, "records.read")

    Process.unlink(fixture.runtime)
    :ok = Supervisor.stop(fixture.runtime)

    assert {:error, %PersistenceError{code: :retryable_dependency}} =
             Authority.authorize(fixture.runtime, context_a(), "records.read")
  end

  test "compound foreign keys reject every cross-tenant authority edge", fixture do
    assert_constraint(
      fixture.runtime,
      "actor_role_assignments_role_tenant_fkey",
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      [UUID.generate(), @tenant_a, fixture.membership_a, fixture.role_b]
    )

    assert_constraint(
      fixture.runtime,
      "role_capability_grants_capability_tenant_fkey",
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      [UUID.generate(), @tenant_a, fixture.assigned_role, fixture.capability_b]
    )

    assert_constraint(
      fixture.runtime,
      "role_inclusions_included_role_tenant_fkey",
      """
      INSERT INTO platform_role_inclusions
        (id, tenant_id, role_id, included_role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      [UUID.generate(), @tenant_a, fixture.assigned_role, fixture.role_b]
    )
  end

  test "database graph integrity rejects direct and indirect cycles", fixture do
    assert_constraint(
      fixture.runtime,
      "platform_role_inclusions_acyclic",
      """
      INSERT INTO platform_role_inclusions
        (id, tenant_id, role_id, included_role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      [UUID.generate(), @tenant_a, fixture.assigned_role, fixture.assigned_role]
    )

    assert_constraint(
      fixture.runtime,
      "platform_role_inclusions_acyclic",
      """
      INSERT INTO platform_role_inclusions
        (id, tenant_id, role_id, included_role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      [UUID.generate(), @tenant_a, fixture.included_role, fixture.assigned_role]
    )

    assert {:ok, [[1]]} =
             Persistence.with_writer(fixture.runtime, context_a(), fn ->
               Repo.query!(
                 "SELECT count(*) FROM platform_role_inclusions WHERE tenant_id = $1",
                 [dump(@tenant_a)]
               ).rows
             end)
  end

  test "authority resources are tenant-owned and expose only governed private actions" do
    assert :ok = ResourceContract.validate_domain(Platform)

    assert 21 == length(Ash.Domain.Info.resources(Platform))

    for resource <- Ash.Domain.Info.resources(Platform) do
      assert :tenant_owned == resource.__chimwemwe_resource_ownership__()
    end

    role_action = ResourceInfo.action(Chimwemwe.Platform.Authority.Role, :rename_role)
    assert role_action.type == :action
    refute role_action.public?

    assignment_action =
      ResourceInfo.action(
        Chimwemwe.Platform.Authority.ActorRoleAssignment,
        :assign_role
      )

    assert assignment_action.type == :action
    refute assignment_action.public?

    temporal_actions =
      ResourceInfo.actions(Chimwemwe.Platform.TemporalQualification.Aggregate)

    assert Enum.map(temporal_actions, & &1.name) == [:publish_revision, :correct_revision]
    assert Enum.all?(temporal_actions, &(not &1.public?))

    fact_actions = ResourceInfo.actions(Chimwemwe.Platform.TemporalQualification.Fact)

    assert Enum.map(fact_actions, & &1.name) == [:record_entry, :reverse_and_replace]
    assert Enum.all?(fact_actions, &(not &1.public?))

    consumer_actions =
      ResourceInfo.actions(Chimwemwe.Platform.TemporalQualification.ConsumerBasis)

    assert Enum.map(consumer_actions, & &1.name) == [:pin_revision, :reconcile_revision]
    assert Enum.all?(consumer_actions, &(not &1.public?))

    activation_action =
      ResourceInfo.action(
        Chimwemwe.Platform.ModuleLifecycle.ModuleActivation,
        :activate_module
      )

    assert activation_action.type == :action
    refute activation_action.public?

    extension_action =
      ResourceInfo.action(
        Chimwemwe.Platform.GovernedExtension.ExtensionDefinition,
        :publish_definition
      )

    assert extension_action.type == :action
    refute extension_action.public?

    for resource <-
          Ash.Domain.Info.resources(Platform) --
            [
              Chimwemwe.Platform.Authority.Role,
              Chimwemwe.Platform.Authority.ActorRoleAssignment,
              Chimwemwe.Platform.Authority.Membership,
              Chimwemwe.Platform.TemporalQualification.Aggregate,
              Chimwemwe.Platform.TemporalQualification.Fact,
              Chimwemwe.Platform.TemporalQualification.ConsumerBasis,
              Chimwemwe.Platform.ModuleLifecycle.ModuleActivation,
              Chimwemwe.Platform.GovernedExtension.ExtensionDefinition
            ] do
      assert [] == ResourceInfo.actions(resource)
    end

    assert Code.ensure_loaded?(Authority)
    assert function_exported?(Authority, :rename_role, 3)
    assert function_exported?(Authority, :assign_role, 3)
    refute function_exported?(Authority, :assign_role, 4)
    refute function_exported?(Authority, :grant_capability, 4)
    refute function_exported?(Authority, :include_role, 4)
  end

  defp seed_authority_graph(runtime) do
    ids = %{
      membership_a: UUID.generate(),
      membership_b: UUID.generate(),
      assigned_role: UUID.generate(),
      included_role: UUID.generate(),
      capability_read: UUID.generate(),
      capability_write: UUID.generate(),
      role_b: UUID.generate(),
      capability_b: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               insert_membership(ids.membership_a, @tenant_a, @actor_a)
               insert_role(ids.assigned_role, @tenant_a, "Tenant-defined circle")
               insert_role(ids.included_role, @tenant_a, "Nested access circle")
               insert_capability(ids.capability_read, @tenant_a, "records.read")
               insert_capability(ids.capability_write, @tenant_a, "records.write")

               insert_assignment(
                 UUID.generate(),
                 @tenant_a,
                 ids.membership_a,
                 ids.assigned_role
               )

               insert_grant(
                 UUID.generate(),
                 @tenant_a,
                 ids.assigned_role,
                 ids.capability_write
               )

               insert_grant(
                 UUID.generate(),
                 @tenant_a,
                 ids.included_role,
                 ids.capability_read
               )

               insert_inclusion(
                 UUID.generate(),
                 @tenant_a,
                 ids.assigned_role,
                 ids.included_role
               )

               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_b(), fn ->
               insert_membership(ids.membership_b, @tenant_b, @actor_b)
               insert_role(ids.role_b, @tenant_b, "Other tenant circle")
               insert_capability(ids.capability_b, @tenant_b, "records.read")
               :seeded
             end)

    ids
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

  defp insert_role(id, tenant_id, name) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), name]
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

  defp insert_assignment(id, tenant_id, membership_id, role_id) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([id, tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(id, tenant_id, role_id, capability_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([id, tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp insert_inclusion(id, tenant_id, role_id, included_role_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_inclusions
        (id, tenant_id, role_id, included_role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([id, tenant_id, role_id, included_role_id], &dump/1)
    )
  end

  defp assert_constraint(runtime, constraint, statement, values) do
    error =
      assert_raise PostgrexError, fn ->
        Persistence.with_writer(runtime, context_a(), fn ->
          Repo.query!(statement, Enum.map(values, &dump_if_uuid/1))
        end)
      end

    assert to_string(error.postgres.constraint) == constraint
  end

  defp clear_tenants(runtime) do
    for context <- [context_a(), context_b()] do
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end
  end

  defp clear_tenant(runtime, context) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    Persistence.with_writer(runtime, context, fn ->
      for table <- @authority_tables do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [dump(tenant_id)])
      end

      :cleared
    end)
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 2]],
      placements: [
        placement(@tenant_a, "pooled-authority", :pooled),
        placement(@tenant_b, "pooled-authority", :pooled)
      ],
      per_tenant_limit: 2,
      per_placement_limit: 4
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 7,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  defp context_a, do: context(@actor_a, @tenant_a)
  defp context_b, do: context(@actor_b, @tenant_b)
  defp context_unassigned, do: context(@actor_unassigned, @tenant_a)

  defp context(actor_id, tenant_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-authority"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: @correlation_id,
        purpose: "tenant authority test",
        locale: "en"
      )

    context
  end

  defp dump_if_uuid(value) when is_binary(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> dump(uuid)
      :error -> value
    end
  end

  defp dump_if_uuid(value), do: value
  defp dump(uuid), do: UUID.dump!(uuid)
end
