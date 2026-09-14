defmodule AshFoundationLab.SyntheticModuleLifecycleTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.Repo
  alias AshFoundationLab.SyntheticModuleLifecycle, as: Lifecycle
  alias AshFoundationLab.SyntheticModuleLifecycle.TrustedContext
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

    database = "ash_foundation_lab_module_lifecycle_#{System.unique_integer([:positive])}"
    {primary_repository, secondary_repository, config} = start_database!(database)

    on_exit(fn -> stop_database!(primary_repository, secondary_repository, config) end)

    {:ok, primary_repository: primary_repository, secondary_repository: secondary_repository}
  end

  setup fixture do
    Repo.put_dynamic_repo(fixture.primary_repository)
    {:ok, Map.merge(fixture, lifecycle_fixture())}
  end

  test "release absence denies before the module operation is entered", fixture do
    context = trusted_context(fixture.authorized_actor)

    assert {:error, :module_not_released} =
             Lifecycle.revise_retained_record(
               context,
               Lifecycle.new_release_manifest!([]),
               fixture.record_id,
               "Must not be written",
               1,
               %{"release_available" => true},
               after_lock: fn -> send(self(), :module_operation_entered) end
             )

    refute_received :module_operation_entered
    assert record_label(fixture) == "Retained synthetic record"
    assert lifecycle_events(fixture) == []
  end

  test "client fields cannot manufacture entitlement or activation", fixture do
    set_entitled(fixture, false)
    manager_context = trusted_context(fixture.manager_actor)
    forged_request = %{"entitled" => true, "activation_state" => "active"}

    assert {:error, :module_not_entitled} =
             Lifecycle.activate(manager_context, release_manifest(), 1, forged_request)

    authorized_context = trusted_context(fixture.authorized_actor)

    assert {:error, :module_not_entitled} =
             Lifecycle.revise_retained_record(
               authorized_context,
               release_manifest(),
               fixture.record_id,
               "Forged label",
               1,
               forged_request
             )

    assert instance_snapshot(fixture).activation_state == "inactive"
  end

  test "activation does not grant the managing actor ordinary module authority", fixture do
    manager_context = trusted_context(fixture.manager_actor)

    assert {:ok, %{activation_state: :active, lifecycle_version: 2}} =
             Lifecycle.activate(manager_context, release_manifest(), 1)

    assert {:error, :actor_unauthorized} =
             Lifecycle.revise_retained_record(
               trusted_context(fixture.manager_actor),
               release_manifest(),
               fixture.record_id,
               "Unauthorized label",
               2
             )

    assert record_label(fixture) == "Retained synthetic record"
  end

  test "an entitled but inactive module denies an authorized ordinary action", fixture do
    assert {:error, :module_inactive} =
             Lifecycle.revise_retained_record(
               trusted_context(fixture.authorized_actor),
               release_manifest(),
               fixture.record_id,
               "Inactive label",
               1
             )

    assert record_label(fixture) == "Retained synthetic record"
  end

  test "an unauthorized actor receives no record-existence signal", fixture do
    set_active(fixture)
    context = trusted_context(fixture.unauthorized_actor)

    assert {:error, :actor_unauthorized} =
             Lifecycle.revise_retained_record(
               context,
               release_manifest(),
               fixture.record_id,
               "Unauthorized label",
               1
             )

    assert {:error, :actor_unauthorized} =
             Lifecycle.revise_retained_record(
               %{context | correlation_id: UUID.generate()},
               release_manifest(),
               UUID.generate(),
               "Unknown label",
               1
             )

    assert lifecycle_events(fixture) == []
  end

  test "all four gates permit only the named action input", fixture do
    assert {:ok, %{lifecycle_version: 2}} =
             Lifecycle.activate(trusted_context(fixture.manager_actor), release_manifest(), 1)

    forged_request = %{
      "tenant_id" => fixture.other_tenant_id,
      "actor_id" => fixture.unauthorized_actor.id,
      "entitled" => false,
      "activation_state" => "inactive",
      "unexpected_field" => "must be ignored"
    }

    assert {:ok,
            %{
              record_id: record_id,
              label: "Approved synthetic label",
              lifecycle_version: 3
            }} =
             Lifecycle.revise_retained_record(
               trusted_context(fixture.authorized_actor),
               release_manifest(),
               fixture.record_id,
               "Approved synthetic label",
               2,
               forged_request
             )

    assert record_id == fixture.record_id
    assert record_label(fixture) == "Approved synthetic label"
    assert event_channels(fixture, "synthetic_module.record_revised") == ["audit", "outbox"]
  end

  test "missing and cross-tenant context fail closed", fixture do
    assert {:error, :missing_context} =
             Lifecycle.revise_retained_record(
               nil,
               release_manifest(),
               fixture.record_id,
               "Missing context",
               1
             )

    cross_tenant_context = %TrustedContext{
      tenant_id: fixture.tenant_id,
      actor: fixture.other_tenant_actor,
      correlation_id: UUID.generate()
    }

    assert {:error, :actor_tenant_mismatch} =
             Lifecycle.revise_retained_record(
               cross_tenant_context,
               release_manifest(),
               fixture.record_id,
               "Cross-tenant label",
               1
             )

    assert lifecycle_events(fixture) == []
  end

  test "a missing dependency rejects activation with a stable error", fixture do
    set_dependency_ready(fixture, false)

    assert {:error, :required_dependency_inactive} =
             Lifecycle.activate(trusted_context(fixture.manager_actor), release_manifest(), 1)

    assert instance_snapshot(fixture).activation_state == "inactive"
    assert lifecycle_events(fixture) == []
  end

  test "an active dependent rejects deactivation", fixture do
    set_active(fixture)
    set_active_dependents(fixture, 1)

    assert {:error, :active_dependents_present} =
             Lifecycle.deactivate(
               trusted_context(fixture.manager_actor),
               release_manifest(),
               1
             )

    assert instance_snapshot(fixture).activation_state == "active"
    assert lifecycle_events(fixture) == []
  end

  test "an ordinary mutation that wins the lifecycle lock commits fully", fixture do
    set_active(fixture)
    test_process = self()

    action_task =
      Task.async(fn ->
        with_repository(fixture.primary_repository, fn ->
          Lifecycle.revise_retained_record(
            trusted_context(fixture.authorized_actor),
            release_manifest(),
            fixture.record_id,
            "Committed before drain",
            1,
            %{},
            after_lock: fn ->
              send(test_process, {:action_locked, self()})

              receive do
                :continue -> :ok
              end
            end
          )
        end)
      end)

    assert_receive {:action_locked, action_pid}

    deactivation_task =
      Task.async(fn ->
        send(test_process, :deactivation_started)

        with_repository(fixture.secondary_repository, fn ->
          Lifecycle.deactivate(
            trusted_context(fixture.manager_actor),
            release_manifest(),
            1
          )
        end)
      end)

    assert_receive :deactivation_started
    send(action_pid, :continue)

    assert {:ok, %{lifecycle_version: 2}} = Task.await(action_task)
    assert {:error, :lifecycle_conflict} = Task.await(deactivation_task)
    assert record_label(fixture) == "Committed before drain"
    assert instance_snapshot(fixture).activation_state == "active"
    assert event_types(fixture) == ["synthetic_module.record_revised"]
  end

  test "deactivation that wins the lifecycle lock closes authority atomically", fixture do
    set_active(fixture)
    test_process = self()

    deactivation_task =
      Task.async(fn ->
        with_repository(fixture.primary_repository, fn ->
          Lifecycle.deactivate(
            trusted_context(fixture.manager_actor),
            release_manifest(),
            1,
            after_lock: fn ->
              send(test_process, {:deactivation_locked, self()})

              receive do
                :continue -> :ok
              end
            end
          )
        end)
      end)

    assert_receive {:deactivation_locked, deactivation_pid}

    action_task =
      Task.async(fn ->
        send(test_process, :action_started)

        with_repository(fixture.secondary_repository, fn ->
          Lifecycle.revise_retained_record(
            trusted_context(fixture.authorized_actor),
            release_manifest(),
            fixture.record_id,
            "Must lose the race",
            1
          )
        end)
      end)

    assert_receive :action_started
    send(deactivation_pid, :continue)

    assert {:ok, %{activation_state: :inactive, lifecycle_version: 2}} =
             Task.await(deactivation_task)

    assert {:error, :module_inactive} = Task.await(action_task)
    assert record_label(fixture) == "Retained synthetic record"
    assert instance_snapshot(fixture).activation_state == "inactive"
    assert event_types(fixture) == ["synthetic_module.deactivated"]
  end

  test "deactivation parks ordinary work and retains cursors, data, and mandatory work",
       fixture do
    set_active(fixture)
    queued_id = insert_work_item(fixture, "ordinary", "queued", nil)
    running_id = insert_work_item(fixture, "ordinary", "running", 40)
    mandatory_id = insert_work_item(fixture, "mandatory", "running", nil)

    assert {:ok,
            %{
              activation_state: :inactive,
              lifecycle_version: 2,
              parked_work_count: 2,
              replay_from_cursor: 41
            }} =
             Lifecycle.deactivate(
               trusted_context(fixture.manager_actor),
               release_manifest(),
               1
             )

    assert work_status(fixture, queued_id) == "parked"
    assert work_status(fixture, running_id) == "parked"
    assert work_status(fixture, mandatory_id) == "running"

    assert %{
             activation_state: "inactive",
             event_cursor: 41,
             replay_from_cursor: 41,
             projection_ready: false,
             reconciliation_required: true
           } = instance_snapshot(fixture)

    assert retained_record?(fixture)
    assert event_channels(fixture, "synthetic_module.deactivated") == ["audit", "outbox"]
  end

  test "mandatory kernel work continues without ordinary module authority", fixture do
    set_active(fixture)
    mandatory_id = insert_work_item(fixture, "mandatory", "running", nil)

    assert {:ok, %{activation_state: :inactive, lifecycle_version: 2}} =
             Lifecycle.deactivate(
               trusted_context(fixture.manager_actor),
               release_manifest(),
               1
             )

    assert {:ok, %{status: :completed, work_item_id: ^mandatory_id}} =
             Lifecycle.complete_mandatory_work(
               trusted_context(fixture.mandatory_actor),
               mandatory_id
             )

    assert {:error, :actor_unauthorized} =
             Lifecycle.revise_retained_record(
               trusted_context(fixture.mandatory_actor),
               release_manifest(),
               fixture.record_id,
               "Ordinary authority must remain closed",
               2
             )

    assert work_status(fixture, mandatory_id) == "completed"

    assert event_channels(fixture, "synthetic_module.mandatory_work_completed") == [
             "audit",
             "outbox"
           ]
  end

  test "reactivation validates compatibility and opens only after rebuild and reconciliation",
       fixture do
    set_active(fixture)
    parked_id = insert_work_item(fixture, "ordinary", "running", 40)

    assert {:ok, %{lifecycle_version: 2}} =
             Lifecycle.deactivate(
               trusted_context(fixture.manager_actor),
               release_manifest(),
               1
             )

    incompatible_manifest = release_manifest("2.0.0", ["0.9.0"])

    assert {:error, :module_version_incompatible} =
             Lifecycle.reactivate(
               trusted_context(fixture.manager_actor),
               incompatible_manifest,
               2
             )

    compatible_manifest = release_manifest("2.0.0", ["1.0.0"])

    assert {:error, :reconciliation_failed} =
             Lifecycle.reactivate(
               trusted_context(fixture.manager_actor),
               compatible_manifest,
               2,
               inject_reconciliation_failure?: true
             )

    assert %{
             activation_state: "inactive",
             installed_version: "1.0.0",
             lifecycle_version: 2,
             projection_version: 3,
             projection_ready: false,
             reconciliation_required: true,
             replay_from_cursor: 41
           } = instance_snapshot(fixture)

    assert work_status(fixture, parked_id) == "parked"

    assert {:ok,
            %{
              activation_state: :active,
              installed_version: "2.0.0",
              lifecycle_version: 3
            }} =
             Lifecycle.reactivate(
               trusted_context(fixture.manager_actor),
               compatible_manifest,
               2
             )

    assert %{
             activation_state: "active",
             installed_version: "2.0.0",
             lifecycle_version: 3,
             projection_version: 4,
             projection_ready: true,
             reconciliation_required: false,
             replay_from_cursor: nil
           } = instance_snapshot(fixture)

    assert work_status(fixture, parked_id) == "queued"

    assert {:ok, %{lifecycle_version: 4}} =
             Lifecycle.revise_retained_record(
               trusted_context(fixture.authorized_actor),
               compatible_manifest,
               fixture.record_id,
               "Reopened after reconciliation",
               3
             )
  end

  test "compound tenant keys reject a cross-tenant retained record", fixture do
    assert_raise PostgrexError, fn ->
      Repo.query!(
        """
        INSERT INTO synthetic_module_records (
          id, tenant_id, module_instance_id, label, retained, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, 'Cross-tenant record', true, NOW(), NOW())
        """,
        [
          dump_uuid(UUID.generate()),
          dump_uuid(fixture.other_tenant_id),
          dump_uuid(fixture.instance_id)
        ]
      )
    end
  end

  defp lifecycle_fixture do
    tenant_id = insert_tenant("Synthetic lifecycle tenant")
    other_tenant_id = insert_tenant("Other synthetic lifecycle tenant")

    manager_actor = insert_actor(tenant_id, "Lifecycle manager")
    authorized_actor = insert_actor(tenant_id, "Module actor")
    unauthorized_actor = insert_actor(tenant_id, "Unauthorized actor")
    mandatory_actor = insert_actor(tenant_id, "Mandatory-work service", "service")
    other_tenant_actor = insert_actor(other_tenant_id, "Other-tenant actor")

    grant_capabilities(tenant_id, manager_actor, ["synthetic_module.manage"])
    grant_capabilities(tenant_id, authorized_actor, ["synthetic_module.use"])
    grant_capabilities(tenant_id, mandatory_actor, ["synthetic_module.mandatory_work"])

    instance_id = insert_module_instance(tenant_id)
    record_id = insert_module_record(tenant_id, instance_id)

    %{
      tenant_id: tenant_id,
      other_tenant_id: other_tenant_id,
      manager_actor: manager_actor,
      authorized_actor: authorized_actor,
      unauthorized_actor: unauthorized_actor,
      mandatory_actor: mandatory_actor,
      other_tenant_actor: other_tenant_actor,
      instance_id: instance_id,
      record_id: record_id
    }
  end

  defp release_manifest(version \\ "1.0.0", compatible_from \\ ["1.0.0"]) do
    Lifecycle.new_release_manifest!([
      %{key: Lifecycle.module_key(), version: version, compatible_from: compatible_from}
    ])
  end

  defp trusted_context(actor) do
    %TrustedContext{
      tenant_id: actor.tenant_id,
      actor: actor,
      correlation_id: UUID.generate()
    }
  end

  defp insert_tenant(name) do
    id = UUID.generate()

    Repo.query!(
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, NOW(), NOW())",
      [dump_uuid(id), name]
    )

    id
  end

  defp insert_actor(tenant_id, name, kind \\ "human") do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO actors (id, tenant_id, name, kind, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), name, kind]
    )

    %{id: id, tenant_id: tenant_id}
  end

  defp grant_capabilities(tenant_id, actor, capability_keys) do
    role_id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO roles (id, tenant_id, name, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump_uuid(role_id), dump_uuid(tenant_id), "Synthetic role #{role_id}"]
    )

    Repo.query!(
      """
      INSERT INTO actor_roles (id, tenant_id, actor_id, role_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [dump_uuid(UUID.generate()), dump_uuid(tenant_id), dump_uuid(actor.id), dump_uuid(role_id)]
    )

    Enum.each(capability_keys, fn capability_key ->
      capability_id = UUID.generate()

      Repo.query!(
        """
        INSERT INTO capabilities (id, tenant_id, key, inserted_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        """,
        [dump_uuid(capability_id), dump_uuid(tenant_id), capability_key]
      )

      Repo.query!(
        """
        INSERT INTO role_capabilities (
          id, tenant_id, role_id, capability_id, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, $4, NOW(), NOW())
        """,
        [
          dump_uuid(UUID.generate()),
          dump_uuid(tenant_id),
          dump_uuid(role_id),
          dump_uuid(capability_id)
        ]
      )
    end)
  end

  defp insert_module_instance(tenant_id) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO synthetic_module_instances (
        id,
        tenant_id,
        module_key,
        installed_version,
        entitled,
        activation_state,
        dependency_ready,
        active_dependents,
        lifecycle_version,
        event_cursor,
        replay_from_cursor,
        projection_version,
        projection_ready,
        reconciliation_required,
        inserted_at,
        updated_at
      )
      VALUES ($1, $2, $3, '1.0.0', true, 'inactive', true, 0, 1, 41, NULL, 3, false,
              true, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), Lifecycle.module_key()]
    )

    id
  end

  defp insert_module_record(tenant_id, instance_id) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO synthetic_module_records (
        id, tenant_id, module_instance_id, label, retained, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, 'Retained synthetic record', true, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), dump_uuid(instance_id)]
    )

    id
  end

  defp insert_work_item(fixture, kind, status, replay_cursor) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO synthetic_module_work_items (
        id,
        tenant_id,
        module_instance_id,
        work_kind,
        status,
        replay_cursor,
        inserted_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      """,
      [
        dump_uuid(id),
        dump_uuid(fixture.tenant_id),
        dump_uuid(fixture.instance_id),
        kind,
        status,
        replay_cursor
      ]
    )

    id
  end

  defp set_entitled(fixture, entitled) do
    update_instance(fixture, "entitled = $1", [entitled])
  end

  defp set_dependency_ready(fixture, dependency_ready) do
    update_instance(fixture, "dependency_ready = $1", [dependency_ready])
  end

  defp set_active_dependents(fixture, active_dependents) do
    update_instance(fixture, "active_dependents = $1", [active_dependents])
  end

  defp set_active(fixture) do
    update_instance(
      fixture,
      "activation_state = 'active', projection_ready = true, reconciliation_required = false",
      []
    )
  end

  defp update_instance(fixture, update_clause, values) do
    Repo.query!(
      """
      UPDATE synthetic_module_instances
      SET #{update_clause}, updated_at = NOW()
      WHERE id = $#{length(values) + 1} AND tenant_id = $#{length(values) + 2}
      """,
      values ++ [dump_uuid(fixture.instance_id), dump_uuid(fixture.tenant_id)]
    )
  end

  defp instance_snapshot(fixture) do
    [
      [
        activation_state,
        installed_version,
        lifecycle_version,
        event_cursor,
        replay_from_cursor,
        projection_version,
        projection_ready,
        reconciliation_required
      ]
    ] =
      Repo.query!(
        """
        SELECT activation_state,
               installed_version,
               lifecycle_version,
               event_cursor,
               replay_from_cursor,
               projection_version,
               projection_ready,
               reconciliation_required
        FROM synthetic_module_instances
        WHERE id = $1 AND tenant_id = $2
        """,
        [dump_uuid(fixture.instance_id), dump_uuid(fixture.tenant_id)]
      ).rows

    %{
      activation_state: activation_state,
      installed_version: installed_version,
      lifecycle_version: lifecycle_version,
      event_cursor: event_cursor,
      replay_from_cursor: replay_from_cursor,
      projection_version: projection_version,
      projection_ready: projection_ready,
      reconciliation_required: reconciliation_required
    }
  end

  defp record_label(fixture) do
    [[label]] =
      Repo.query!(
        "SELECT label FROM synthetic_module_records WHERE id = $1 AND tenant_id = $2",
        [dump_uuid(fixture.record_id), dump_uuid(fixture.tenant_id)]
      ).rows

    label
  end

  defp retained_record?(fixture) do
    [[retained]] =
      Repo.query!(
        "SELECT retained FROM synthetic_module_records WHERE id = $1 AND tenant_id = $2",
        [dump_uuid(fixture.record_id), dump_uuid(fixture.tenant_id)]
      ).rows

    retained
  end

  defp work_status(fixture, work_item_id) do
    [[status]] =
      Repo.query!(
        "SELECT status FROM synthetic_module_work_items WHERE id = $1 AND tenant_id = $2",
        [dump_uuid(work_item_id), dump_uuid(fixture.tenant_id)]
      ).rows

    status
  end

  defp lifecycle_events(fixture) do
    Repo.query!(
      """
      SELECT channel, event_type, lifecycle_version
      FROM synthetic_module_lifecycle_events
      WHERE tenant_id = $1 AND module_instance_id = $2
      ORDER BY event_type, channel
      """,
      [dump_uuid(fixture.tenant_id), dump_uuid(fixture.instance_id)]
    ).rows
  end

  defp event_channels(fixture, event_type) do
    fixture
    |> lifecycle_events()
    |> Enum.filter(fn [_channel, observed_type, _version] -> observed_type == event_type end)
    |> Enum.map(fn [channel, _event_type, _version] -> channel end)
    |> Enum.sort()
  end

  defp event_types(fixture) do
    fixture
    |> lifecycle_events()
    |> Enum.map(fn [_channel, event_type, _version] -> event_type end)
    |> Enum.uniq()
  end

  defp start_database!(database) do
    config =
      Repo.config()
      |> Keyword.put(:database, database)
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)

    :ok = Postgres.storage_up(config)
    {:ok, primary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(primary_repository)

    with_repository(primary_repository, fn ->
      Ecto.Migrator.run(Repo, @migrations, :up, all: true, log: false)
    end)

    {:ok, secondary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(secondary_repository)

    {primary_repository, secondary_repository, config}
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
