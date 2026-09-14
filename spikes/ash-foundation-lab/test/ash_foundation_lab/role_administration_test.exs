defmodule AshFoundationLab.RoleAdministrationTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.AccessControl
  alias AshFoundationLab.Actor
  alias AshFoundationLab.Repo
  alias AshFoundationLab.RoleAdministration
  alias AshFoundationLab.RoleAdministration.TrustedContext
  alias Ecto.Adapters.Postgres
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @migrations_path Path.expand("../../priv/repo/migrations", __DIR__)
  @migrations [
    {20_260_913_000_000, AshFoundationLab.Repo.Migrations.CreateFoundationRecords},
    {20_260_913_010_000, AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow},
    {20_260_913_020_000, AshFoundationLab.Repo.Migrations.AddTransactionalOutbox},
    {20_260_913_030_000, AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle},
    {20_260_913_040_000, AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity}
  ]

  setup_all do
    ensure_migrations_loaded!()

    database = "ash_foundation_lab_role_graph_#{System.unique_integer([:positive])}"

    {primary_repository, secondary_repository, config, rollback_verified?} =
      start_database!(database)

    on_exit(fn -> stop_database!(primary_repository, secondary_repository, config) end)

    {:ok,
     primary_repository: primary_repository,
     secondary_repository: secondary_repository,
     rollback_verified?: rollback_verified?}
  end

  setup fixture do
    Repo.put_dynamic_repo(fixture.primary_repository)
    {:ok, Map.merge(fixture, role_fixture())}
  end

  test "the role-graph migration rolls back cleanly and reapplies its safety primitives",
       fixture do
    assert fixture.rollback_verified?

    assert [[1]] =
             Repo.query!(
               "SELECT count(*) FROM pg_trigger WHERE tgname = 'role_inclusions_enforce_acyclicity'"
             ).rows

    assert [["NO", "1"]] =
             Repo.query!("""
             SELECT is_nullable, column_default
             FROM information_schema.columns
             WHERE table_name = 'roles' AND column_name = 'lock_version'
             """).rows

    constraints =
      Repo.query!("""
      SELECT conname
      FROM pg_constraint
      WHERE conname IN (
        'role_lock_version_must_be_positive',
        'role_administration_events_actor_tenant_fkey',
        'role_administration_events_role_tenant_fkey',
        'role_administration_events_related_role_tenant_fkey'
      )
      ORDER BY conname
      """).rows

    assert length(constraints) == 4
  end

  test "an authorized named action renames tenant role data and records audit and outbox facts",
       fixture do
    context = trusted_context(fixture)

    assert {:ok, %{id: id, name: "Renamed synthetic circle", lock_version: 2}} =
             RoleAdministration.rename_role(
               context,
               fixture.managed_role,
               "  Renamed synthetic circle  ",
               1
             )

    assert id == fixture.managed_role

    assert role_snapshot(fixture.tenant_id, fixture.managed_role) == [
             "Renamed synthetic circle",
             2
           ]

    assert [
             ["audit", "role.renamed", nil, %{"lock_version" => 2}],
             ["outbox", "role.renamed", nil, %{"lock_version" => 2}]
           ] = summarized_events(fixture.tenant_id, fixture.managed_role)

    assert [context.correlation_id, context.correlation_id] ==
             event_correlation_ids(fixture.tenant_id, fixture.managed_role)
  end

  test "a stale rename and a duplicate name return stable conflicts without side effects",
       fixture do
    assert {:error, :role_version_conflict} =
             RoleAdministration.rename_role(
               trusted_context(fixture),
               fixture.managed_role,
               "Stale rename",
               2
             )

    assert {:error, :role_name_conflict} =
             RoleAdministration.rename_role(
               trusted_context(fixture),
               fixture.managed_role,
               "Existing role name",
               1
             )

    assert role_snapshot(fixture.tenant_id, fixture.managed_role) == ["Managed role", 1]
    assert summarized_events(fixture.tenant_id, fixture.managed_role) == []
  end

  test "missing, mismatched, and unauthorized context fail before role existence is disclosed",
       fixture do
    unknown_role = UUID.generate()

    assert {:error, :missing_context} =
             RoleAdministration.rename_role(nil, fixture.managed_role, "Denied", 1)

    mismatched_context = %TrustedContext{
      tenant_id: fixture.tenant_id,
      actor: fixture.other_tenant_actor,
      correlation_id: UUID.generate()
    }

    assert {:error, :actor_tenant_mismatch} =
             RoleAdministration.include_role(
               mismatched_context,
               fixture.managed_role,
               fixture.included_role
             )

    unauthorized_context = %TrustedContext{
      tenant_id: fixture.tenant_id,
      actor: fixture.unauthorized_actor,
      correlation_id: UUID.generate()
    }

    assert {:error, :actor_unauthorized} =
             RoleAdministration.rename_role(
               unauthorized_context,
               fixture.managed_role,
               "Denied existing role",
               1
             )

    assert {:error, :actor_unauthorized} =
             RoleAdministration.rename_role(
               unauthorized_context,
               unknown_role,
               "Denied unknown role",
               1
             )

    assert role_snapshot(fixture.tenant_id, fixture.managed_role) == ["Managed role", 1]
  end

  test "a named inclusion action composes capabilities without depending on role names",
       fixture do
    capability = insert_capability(fixture.tenant_id, "synthetic.graph.allowed")
    insert_role_capability(fixture.tenant_id, fixture.included_role, capability)
    insert_actor_role(fixture.tenant_id, fixture.beneficiary_actor.id, fixture.managed_role)

    refute AccessControl.actor_has_capability?(
             fixture.beneficiary_actor,
             "synthetic.graph.allowed"
           )

    assert {:ok, %{role_id: role_id, included_role_id: included_role_id}} =
             RoleAdministration.include_role(
               trusted_context(fixture),
               fixture.managed_role,
               fixture.included_role
             )

    assert role_id == fixture.managed_role
    assert included_role_id == fixture.included_role

    assert AccessControl.actor_has_capability?(
             fixture.beneficiary_actor,
             "synthetic.graph.allowed"
           )

    rename_role_directly(fixture.tenant_id, fixture.managed_role, "Renamed composed circle")

    assert AccessControl.actor_has_capability?(
             fixture.beneficiary_actor,
             "synthetic.graph.allowed"
           )

    included_role = fixture.included_role

    assert [
             ["audit", "role.inclusion_added", ^included_role, %{}],
             ["outbox", "role.inclusion_added", ^included_role, %{}]
           ] = summarized_events(fixture.tenant_id, fixture.managed_role)
  end

  test "direct and indirect cycles are rejected without writing event facts", fixture do
    assert {:error, :role_cycle} =
             RoleAdministration.include_role(
               trusted_context(fixture),
               fixture.managed_role,
               fixture.managed_role
             )

    assert {:ok, _inclusion} =
             RoleAdministration.include_role(
               trusted_context(fixture),
               fixture.managed_role,
               fixture.included_role
             )

    assert {:error, :role_cycle} =
             RoleAdministration.include_role(
               trusted_context(fixture),
               fixture.included_role,
               fixture.managed_role
             )

    assert inclusion_count(fixture.tenant_id) == 1
    assert event_count(fixture.tenant_id, "role.inclusion_added") == 2
  end

  test "the database rejects an indirect cycle through an alternate write", fixture do
    insert_role_inclusion_directly(
      fixture.tenant_id,
      fixture.managed_role,
      fixture.included_role
    )

    error =
      assert_raise PostgrexError, fn ->
        insert_role_inclusion_directly(
          fixture.tenant_id,
          fixture.included_role,
          fixture.managed_role
        )
      end

    assert error.postgres.constraint == "role_inclusions_acyclic"
    assert inclusion_count(fixture.tenant_id) == 1
  end

  test "compound keys reject a cross-tenant inclusion in both action and alternate paths",
       fixture do
    assert {:error, :role_not_found} =
             RoleAdministration.include_role(
               trusted_context(fixture),
               fixture.managed_role,
               fixture.other_tenant_role
             )

    assert_raise PostgrexError, fn ->
      insert_role_inclusion_directly(
        fixture.tenant_id,
        fixture.managed_role,
        fixture.other_tenant_role
      )
    end

    assert inclusion_count(fixture.tenant_id) == 0
  end

  test "opposing concurrent actions serialize so exactly one edge survives", fixture do
    parent = self()

    first =
      Task.async(fn ->
        Repo.put_dynamic_repo(fixture.primary_repository)

        RoleAdministration.include_role(
          trusted_context(fixture),
          fixture.managed_role,
          fixture.included_role,
          after_graph_lock: fn ->
            send(parent, :first_graph_lock_acquired)

            receive do
              :release_first_graph_lock -> :ok
            end
          end
        )
      end)

    assert_receive :first_graph_lock_acquired

    second =
      Task.async(fn ->
        Repo.put_dynamic_repo(fixture.secondary_repository)

        RoleAdministration.include_role(
          trusted_context(fixture),
          fixture.included_role,
          fixture.managed_role
        )
      end)

    assert Task.yield(second, 100) == nil
    send(first.pid, :release_first_graph_lock)

    assert {:ok, _inclusion} = Task.await(first)
    assert {:error, :role_cycle} = Task.await(second)
    assert inclusion_count(fixture.tenant_id) == 1
  end

  test "a failure after durable fact insertion rolls back the role change and both channels",
       fixture do
    assert {:error, :injected_event_failure} =
             RoleAdministration.rename_role(
               trusted_context(fixture),
               fixture.managed_role,
               "Must roll back",
               1,
               inject_event_failure?: true
             )

    assert role_snapshot(fixture.tenant_id, fixture.managed_role) == ["Managed role", 1]
    assert summarized_events(fixture.tenant_id, fixture.managed_role) == []
  end

  defp role_fixture do
    tenant_id = insert_tenant("Synthetic role tenant")
    other_tenant_id = insert_tenant("Other synthetic role tenant")

    manager_actor = insert_actor(tenant_id, "Role manager")
    unauthorized_actor = insert_actor(tenant_id, "Unprivileged actor")
    beneficiary_actor = insert_actor(tenant_id, "Composed-role beneficiary")
    other_tenant_actor = insert_actor(other_tenant_id, "Other tenant actor")

    manager_role = insert_role(tenant_id, "Role management capability holder")
    managed_role = insert_role(tenant_id, "Managed role")
    included_role = insert_role(tenant_id, "Included role")
    _existing_role = insert_role(tenant_id, "Existing role name")
    other_tenant_role = insert_role(other_tenant_id, "Other tenant role")
    manage_capability = insert_capability(tenant_id, "role.manage")

    insert_role_capability(tenant_id, manager_role, manage_capability)
    insert_actor_role(tenant_id, manager_actor.id, manager_role)

    %{
      tenant_id: tenant_id,
      other_tenant_id: other_tenant_id,
      manager_actor: manager_actor,
      unauthorized_actor: unauthorized_actor,
      beneficiary_actor: beneficiary_actor,
      other_tenant_actor: other_tenant_actor,
      managed_role: managed_role,
      included_role: included_role,
      other_tenant_role: other_tenant_role
    }
  end

  defp trusted_context(fixture) do
    %TrustedContext{
      tenant_id: fixture.tenant_id,
      actor: fixture.manager_actor,
      correlation_id: UUID.generate()
    }
  end

  defp role_snapshot(tenant_id, role_id) do
    assert [snapshot] =
             Repo.query!(
               "SELECT name, lock_version FROM roles WHERE tenant_id = $1 AND id = $2",
               [dump_uuid(tenant_id), dump_uuid(role_id)]
             ).rows

    snapshot
  end

  defp summarized_events(tenant_id, role_id) do
    Repo.query!(
      """
      SELECT channel, event_type, related_role_id::text, payload
      FROM role_administration_events
      WHERE tenant_id = $1 AND role_id = $2
      ORDER BY channel
      """,
      [dump_uuid(tenant_id), dump_uuid(role_id)]
    ).rows
  end

  defp event_count(tenant_id, event_type) do
    [[count]] =
      Repo.query!(
        """
        SELECT count(*)
        FROM role_administration_events
        WHERE tenant_id = $1 AND event_type = $2
        """,
        [dump_uuid(tenant_id), event_type]
      ).rows

    count
  end

  defp event_correlation_ids(tenant_id, role_id) do
    Repo.query!(
      """
      SELECT correlation_id::text
      FROM role_administration_events
      WHERE tenant_id = $1 AND role_id = $2
      ORDER BY channel
      """,
      [dump_uuid(tenant_id), dump_uuid(role_id)]
    ).rows
    |> List.flatten()
  end

  defp inclusion_count(tenant_id) do
    [[count]] =
      Repo.query!(
        "SELECT count(*) FROM role_inclusions WHERE tenant_id = $1",
        [dump_uuid(tenant_id)]
      ).rows

    count
  end

  defp insert_tenant(name) do
    id = UUID.generate()

    Repo.query!(
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, NOW(), NOW())",
      [dump_uuid(id), name]
    )

    id
  end

  defp insert_actor(tenant_id, name) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO actors (id, tenant_id, name, kind, inserted_at, updated_at)
      VALUES ($1, $2, $3, 'human', NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), name]
    )

    struct!(Actor, id: id, tenant_id: tenant_id, name: name, kind: :human)
  end

  defp insert_role(tenant_id, name) do
    insert_tenant_scoped_named_record("roles", "name", tenant_id, name)
  end

  defp insert_capability(tenant_id, key) do
    insert_tenant_scoped_named_record("capabilities", "key", tenant_id, key)
  end

  defp insert_tenant_scoped_named_record(table, column, tenant_id, value) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO #{table} (id, tenant_id, #{column}, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), value]
    )

    id
  end

  defp insert_actor_role(tenant_id, actor_id, role_id) do
    insert_join("actor_roles", tenant_id, "actor_id", actor_id, "role_id", role_id)
  end

  defp insert_role_capability(tenant_id, role_id, capability_id) do
    insert_join(
      "role_capabilities",
      tenant_id,
      "role_id",
      role_id,
      "capability_id",
      capability_id
    )
  end

  defp insert_join(table, tenant_id, left_column, left_id, right_column, right_id) do
    Repo.query!(
      """
      INSERT INTO #{table} (
        id, tenant_id, #{left_column}, #{right_column}, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [
        dump_uuid(UUID.generate()),
        dump_uuid(tenant_id),
        dump_uuid(left_id),
        dump_uuid(right_id)
      ]
    )
  end

  defp insert_role_inclusion_directly(tenant_id, role_id, included_role_id) do
    insert_join(
      "role_inclusions",
      tenant_id,
      "role_id",
      role_id,
      "included_role_id",
      included_role_id
    )
  end

  defp rename_role_directly(tenant_id, role_id, name) do
    Repo.query!(
      "UPDATE roles SET name = $1, updated_at = NOW() WHERE tenant_id = $2 AND id = $3",
      [name, dump_uuid(tenant_id), dump_uuid(role_id)]
    )
  end

  defp start_database!(database) do
    config =
      Repo.config()
      |> Keyword.put(:database, database)
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 4)

    :ok = Postgres.storage_up(config)
    {:ok, primary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(primary_repository)

    rollback_verified? =
      with_repository(primary_repository, fn ->
        Ecto.Migrator.run(Repo, @migrations, :up, all: true, log: false)
        Ecto.Migrator.run(Repo, @migrations, :down, step: 1, log: false)

        [[events_table, lock_version, trigger_function]] =
          Repo.query!("""
          SELECT
            to_regclass('role_administration_events') IS NULL,
            NOT EXISTS (
              SELECT 1
              FROM information_schema.columns
              WHERE table_name = 'roles' AND column_name = 'lock_version'
            ),
            to_regprocedure('enforce_role_inclusion_acyclicity()') IS NULL
          """).rows

        Ecto.Migrator.run(Repo, @migrations, :up, all: true, log: false)
        events_table and lock_version and trigger_function
      end)

    {:ok, secondary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(secondary_repository)

    {primary_repository, secondary_repository, config, rollback_verified?}
  end

  defp stop_database!(primary_repository, secondary_repository, config) do
    Enum.each([secondary_repository, primary_repository], fn repository ->
      if Process.alive?(repository) do
        GenServer.stop(repository)
      end
    end)

    :ok = Postgres.storage_down(config)
  end

  defp with_repository(repository, operation) do
    previous_repository = Repo.put_dynamic_repo(repository)

    try do
      operation.()
    after
      Repo.put_dynamic_repo(previous_repository)
    end
  end

  defp ensure_migrations_loaded! do
    migration_files = [
      {AshFoundationLab.Repo.Migrations.CreateFoundationRecords,
       "20260913000000_create_foundation_records.exs"},
      {AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow,
       "20260913010000_add_access_model_and_record_workflow.exs"},
      {AshFoundationLab.Repo.Migrations.AddTransactionalOutbox,
       "20260913020000_add_transactional_outbox.exs"},
      {AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle,
       "20260913030000_add_synthetic_module_lifecycle.exs"},
      {AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity,
       "20260913040000_add_role_graph_integrity.exs"}
    ]

    Enum.each(migration_files, fn {migration, filename} ->
      unless Code.ensure_loaded?(migration) do
        Code.require_file(Path.join(@migrations_path, filename))
      end
    end)
  end

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
end
