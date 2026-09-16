defmodule AshFoundationLab.TrustedRoutingTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.Actor
  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.Repo
  alias AshFoundationLab.TrustedRouting
  alias AshFoundationLab.TrustedRouting.AuthenticatedTenant
  alias AshFoundationLab.TrustedRouting.InterfaceRoute
  alias AshFoundationLab.TrustedRouting.Placement
  alias Ecto.Adapters.Postgres
  alias Ecto.UUID

  @migrations_path Path.expand("../../priv/repo/migrations", __DIR__)
  @migrations [
    {20_260_913_000_000, AshFoundationLab.Repo.Migrations.CreateFoundationRecords},
    {20_260_913_010_000, AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow},
    {20_260_913_020_000, AshFoundationLab.Repo.Migrations.AddTransactionalOutbox},
    {20_260_913_030_000, AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle},
    {20_260_913_040_000, AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity},
    {20_260_914_050_000, AshFoundationLab.Repo.Migrations.AddActionIdempotency}
  ]
  @movement_tables [
    {"tenants", ~w(id name inserted_at updated_at), "id"},
    {"actors", ~w(id tenant_id name kind inserted_at updated_at), "tenant_id"},
    {"roles", ~w(id tenant_id name lock_version inserted_at updated_at), "tenant_id"},
    {"capabilities", ~w(id tenant_id key inserted_at updated_at), "tenant_id"},
    {"actor_roles", ~w(id tenant_id actor_id role_id inserted_at updated_at), "tenant_id"},
    {"role_capabilities", ~w(id tenant_id role_id capability_id inserted_at updated_at),
     "tenant_id"},
    {"foundation_records",
     ~w(id tenant_id name status lock_version audit_reference inserted_at updated_at),
     "tenant_id"}
  ]

  setup_all do
    ensure_migrations_loaded!()

    suffix = System.unique_integer([:positive, :monotonic])
    pooled_database = "ash_foundation_lab_routing_pooled_#{suffix}"
    dedicated_database = "ash_foundation_lab_routing_dedicated_#{suffix}"
    movement_database = "ash_foundation_lab_routing_movement_#{suffix}"

    {pooled_repository, pooled_config} = start_database!(pooled_database)
    {dedicated_repository, dedicated_config} = start_database!(dedicated_database)
    {movement_repository, movement_config} = start_database!(movement_database)

    on_exit(fn ->
      stop_database!(movement_repository, movement_config)
      stop_database!(dedicated_repository, dedicated_config)
      stop_database!(pooled_repository, pooled_config)
    end)

    {:ok,
     pooled_database: pooled_database,
     pooled_repository: pooled_repository,
     dedicated_database: dedicated_database,
     dedicated_repository: dedicated_repository,
     movement_database: movement_database,
     movement_repository: movement_repository}
  end

  setup fixture do
    tenant_a = UUID.generate()
    tenant_b = UUID.generate()

    insert_tenant(fixture.pooled_repository, tenant_a, "Synthetic pooled tenant")
    insert_tenant(fixture.dedicated_repository, tenant_b, "Synthetic dedicated tenant")

    actor_a = insert_actor(fixture.pooled_repository, tenant_a, "Synthetic pooled actor")
    actor_b = insert_actor(fixture.dedicated_repository, tenant_b, "Synthetic dedicated actor")
    grant_capability(fixture.pooled_repository, tenant_a, actor_a.id, "foundation_record.read")
    grant_capability(fixture.pooled_repository, tenant_a, actor_a.id, "tenant_placement.manage")
    grant_capability(fixture.dedicated_repository, tenant_b, actor_b.id, "foundation_record.read")
    record_a = insert_record(fixture.pooled_repository, tenant_a, "Synthetic pooled record")
    record_b = insert_record(fixture.dedicated_repository, tenant_b, "Synthetic dedicated record")

    pooled_placement =
      placement(
        tenant_a,
        7,
        :pooled,
        fixture.pooled_repository,
        fixture.pooled_database,
        "pooled-a"
      )

    dedicated_placement =
      placement(
        tenant_b,
        11,
        :dedicated,
        fixture.dedicated_repository,
        fixture.dedicated_database,
        "dedicated-b"
      )

    registry = TrustedRouting.new_registry!([pooled_placement, dedicated_placement])

    {:ok,
     tenant_a: tenant_a,
     tenant_b: tenant_b,
     actor_a: actor_a,
     actor_b: actor_b,
     record_a: record_a,
     record_b: record_b,
     pooled_placement: pooled_placement,
     dedicated_placement: dedicated_placement,
     registry: registry,
     auth_a: authenticated_tenant(tenant_a, actor_a.id, 7),
     auth_b: authenticated_tenant(tenant_b, actor_b.id, 11)}
  end

  test "authenticated context selects pooled and dedicated databases despite request routing fields",
       fixture do
    forged_request = %{
      "tenant_id" => fixture.tenant_b,
      "database" => fixture.dedicated_database,
      "cell" => "forged-cell",
      "queue_namespace" => "forged-queue"
    }

    assert {:ok, {:pooled, "Synthetic pooled tenant", nil, "queue:pooled-a", "storage:pooled-a"}} =
             TrustedRouting.run_request(
               fixture.auth_a,
               forged_request,
               fixture.registry,
               fn placement ->
                 {
                   placement.profile,
                   tenant_name(fixture.tenant_a),
                   tenant_name(fixture.tenant_b),
                   placement.queue_namespace,
                   placement.storage_namespace
                 }
               end
             )

    assert {:ok, {:dedicated, "Synthetic dedicated tenant", nil}} =
             TrustedRouting.run_request(
               fixture.auth_b,
               %{"database" => fixture.pooled_database},
               fixture.registry,
               fn placement ->
                 {
                   placement.profile,
                   tenant_name(fixture.tenant_b),
                   tenant_name(fixture.tenant_a)
                 }
               end
             )
  end

  test "missing and unknown authenticated placement context fails closed without a default",
       fixture do
    default_repository = Repo.get_dynamic_repo()
    operation = fn _placement -> flunk("unresolved context must not run the operation") end

    assert {:error, :missing_authenticated_context} =
             TrustedRouting.run_request(nil, %{}, fixture.registry, operation)

    missing_tenant = %{fixture.auth_a | tenant_id: nil}

    assert {:error, :missing_authenticated_context} =
             TrustedRouting.run_request(missing_tenant, %{}, fixture.registry, operation)

    unknown_tenant = %{fixture.auth_a | tenant_id: UUID.generate()}

    assert {:error, :placement_not_found} =
             TrustedRouting.run_request(unknown_tenant, %{}, fixture.registry, operation)

    assert {:error, :missing_routing_context} = TrustedRouting.current()
    assert Repo.get_dynamic_repo() == default_repository
  end

  test "a stale routing version fails before repository selection", fixture do
    default_repository = Repo.get_dynamic_repo()
    stale_context = %{fixture.auth_a | routing_version: 6}

    assert {:error, :stale_routing_version} =
             TrustedRouting.run_request(
               stale_context,
               %{"routing_version" => 7},
               fixture.registry,
               fn _placement -> flunk("stale routing must not run the operation") end
             )

    assert Repo.get_dynamic_repo() == default_repository
  end

  test "an unavailable or wrong repository type fails closed", fixture do
    invalid_placement = %{fixture.pooled_placement | repository: self()}

    invalid_registry =
      TrustedRouting.new_registry!([invalid_placement, fixture.dedicated_placement])

    assert {:error, :placement_unavailable} =
             TrustedRouting.with_route(fixture.auth_a, invalid_registry, fn _placement ->
               flunk("an invalid repository must not run the operation")
             end)
  end

  test "spawned tasks receive only explicitly propagated routing context", fixture do
    expected_placement = fixture.pooled_placement
    expected_repository = fixture.pooled_repository

    assert {{:error, :missing_routing_context}, AshFoundationLab.Repo} =
             Task.async(fn -> {TrustedRouting.current(), Repo.get_dynamic_repo()} end)
             |> Task.await()

    assert {:ok, {{:ok, ^expected_placement}, ^expected_repository, "Synthetic pooled tenant"}} =
             fixture.auth_a
             |> TrustedRouting.async(fixture.registry, fn _placement ->
               {
                 TrustedRouting.current(),
                 Repo.get_dynamic_repo(),
                 tenant_name(fixture.tenant_a)
               }
             end)
             |> Task.await()

    assert {:error, :missing_routing_context} = TrustedRouting.current()
  end

  test "jobs re-resolve allowlisted tenant context and reject stale or missing versions",
       fixture do
    job_args = TrustedRouting.job_args(fixture.auth_b)

    assert Map.keys(job_args) |> Enum.sort() ==
             ["actor_id", "correlation_id", "routing_version", "tenant_id"]

    forged_job_args = Map.put(job_args, "database", fixture.pooled_database)

    assert {:ok, {:dedicated, "Synthetic dedicated tenant"}} =
             TrustedRouting.perform_job(forged_job_args, fixture.registry, fn placement ->
               {placement.profile, tenant_name(fixture.tenant_b)}
             end)

    moved_placement = %{
      fixture.dedicated_placement
      | routing_version: fixture.dedicated_placement.routing_version + 1
    }

    moved_registry =
      TrustedRouting.new_registry!([fixture.pooled_placement, moved_placement])

    assert {:error, :stale_routing_version} =
             TrustedRouting.perform_job(job_args, moved_registry, fn _placement ->
               flunk("a stale job must not run the operation")
             end)

    assert {:error, :missing_authenticated_context} =
             TrustedRouting.perform_job(%{}, fixture.registry, fn _placement ->
               flunk("a context-free job must not run the operation")
             end)
  end

  test "routing state is restored when an operation raises", fixture do
    default_repository = Repo.get_dynamic_repo()

    assert_raise RuntimeError, "synthetic routed failure", fn ->
      TrustedRouting.with_route(fixture.auth_a, fixture.registry, fn _placement ->
        raise "synthetic routed failure"
      end)
    end

    assert {:error, :missing_routing_context} = TrustedRouting.current()
    assert Repo.get_dynamic_repo() == default_repository
  end

  test "non-HTTP interfaces derive tenant and version targets and re-enter Ash policy",
       fixture do
    expected_repository = fixture.pooled_repository

    forged_input = %{
      "tenant_id" => fixture.tenant_b,
      "database" => fixture.dedicated_database,
      "queue_namespace" => "forged-queue",
      "storage_namespace" => "forged-storage",
      "routing_version" => 11
    }

    interface_args =
      fixture.auth_a
      |> TrustedRouting.job_args()
      |> Map.put("database", fixture.dedicated_database)

    for interface <- TrustedRouting.non_http_interfaces() do
      assert {:ok,
              {%InterfaceRoute{} = route, ["Synthetic pooled record"], nil, ^expected_repository}} =
               TrustedRouting.perform_interface(
                 interface,
                 interface_args,
                 forged_input,
                 fixture.registry,
                 fn route ->
                   {
                     route,
                     authorized_record_names!(fixture.actor_a, fixture.tenant_a),
                     tenant_name(fixture.tenant_b),
                     Repo.get_dynamic_repo()
                   }
                 end
               )

      assert route.interface == interface
      assert route.tenant_id == fixture.tenant_a
      assert route.actor_id == fixture.actor_a.id
      assert route.routing_version == 7
      assert route.correlation_id == fixture.auth_a.correlation_id
      assert String.ends_with?(route.target, ":v7")
      refute route.target =~ fixture.tenant_a
      refute route.target =~ "forged"
    end
  end

  test "every non-HTTP interface rejects stale, missing, and unauthorized context", fixture do
    stale_args = TrustedRouting.job_args(%{fixture.auth_a | routing_version: 6})
    operation = fn _route -> flunk("invalid interface context must not run") end

    for interface <- TrustedRouting.non_http_interfaces() do
      assert {:error, :stale_routing_version} =
               TrustedRouting.perform_interface(
                 interface,
                 stale_args,
                 %{},
                 fixture.registry,
                 operation
               )

      assert {:error, :missing_authenticated_context} =
               TrustedRouting.perform_interface(
                 interface,
                 %{},
                 %{},
                 fixture.registry,
                 operation
               )
    end

    denied_actor =
      insert_actor(fixture.pooled_repository, fixture.tenant_a, "Synthetic denied actor")

    denied_args =
      fixture.tenant_a
      |> authenticated_tenant(denied_actor.id, 7)
      |> TrustedRouting.job_args()

    assert {:ok, {:error, %Ash.Error.Forbidden{}}} =
             TrustedRouting.perform_interface(
               :search,
               denied_args,
               %{},
               fixture.registry,
               fn _route -> read_record_names(denied_actor, fixture.tenant_a) end
             )

    assert {:error, :unsupported_interface} =
             TrustedRouting.perform_interface(
               :database,
               TrustedRouting.job_args(fixture.auth_a),
               %{},
               fixture.registry,
               operation
             )
  end

  test "movement preparation requires current version, destination membership, and capability",
       fixture do
    destination = destination_for(fixture)
    stale_auth = %{fixture.auth_a | routing_version: 6}
    wrong_version = %{destination | routing_version: 9}
    wrong_tenant = %{destination | tenant_id: fixture.tenant_b}
    incomplete_destination = %{destination | queue_namespace: ""}

    occupied_destination = %{
      destination
      | repository: fixture.dedicated_repository,
        database: fixture.dedicated_database
    }

    pooled_into_dedicated_destination = %{occupied_destination | profile: :pooled}

    denied_actor =
      insert_actor(fixture.pooled_repository, fixture.tenant_a, "Movement denied actor")

    denied_auth = authenticated_tenant(fixture.tenant_a, denied_actor.id, 7)

    assert {:error, :stale_routing_version} =
             TrustedRouting.prepare_movement(
               stale_auth,
               fixture.registry,
               destination,
               "isolation_change"
             )

    assert {:error, :invalid_movement_destination} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               wrong_version,
               "isolation_change"
             )

    assert {:error, :invalid_movement_destination} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               wrong_tenant,
               "isolation_change"
             )

    assert {:error, :invalid_movement_destination} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               incomplete_destination,
               "isolation_change"
             )

    assert {:error, :invalid_movement_destination} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               occupied_destination,
               "isolation_change"
             )

    assert {:error, :invalid_movement_destination} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               pooled_into_dedicated_destination,
               "isolation_change"
             )

    assert {:error, :invalid_movement_reason} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               destination,
               "operator_note_with_sensitive_free_text"
             )

    assert {:error, :forbidden} =
             TrustedRouting.prepare_movement(
               denied_auth,
               fixture.registry,
               destination,
               "isolation_change"
             )

    assert {:error, :missing_authenticated_context} =
             TrustedRouting.prepare_movement(
               %{},
               fixture.registry,
               destination,
               "isolation_change"
             )

    assert {:ok, moving_registry, _movement} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               destination,
               "isolation_change"
             )

    assert {:error, :movement_in_progress} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               moving_registry,
               destination,
               "capacity_change"
             )
  end

  test "movement transitions stay bound to the preparing actor and correlation", fixture do
    destination = destination_for(fixture)

    assert {:ok, moving_registry, movement} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               destination,
               "isolation_change"
             )

    other_actor =
      fixture.auth_a
      |> Map.put(:actor_id, fixture.actor_b.id)

    other_correlation =
      fixture.auth_a
      |> Map.put(:correlation_id, UUID.generate())

    assert {:error, :movement_not_available} =
             TrustedRouting.quiesce_movement(other_actor, moving_registry, movement.id)

    assert {:error, :movement_not_available} =
             TrustedRouting.quiesce_movement(other_correlation, moving_registry, movement.id)

    assert {:error, :movement_not_available} =
             TrustedRouting.quiesce_movement(fixture.auth_a, moving_registry, UUID.generate())
  end

  test "movement quiesces, reconciles, cuts over, and invalidates every old route", fixture do
    destination = destination_for(fixture)
    expected_repository = fixture.movement_repository

    assert {:ok, copying_registry, movement} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               destination,
               "isolation_change"
             )

    assert {:ok, "Synthetic pooled tenant"} =
             TrustedRouting.with_route(fixture.auth_a, copying_registry, fn _placement ->
               tenant_name(fixture.tenant_a)
             end)

    copy_tenant_scope(
      fixture.pooled_repository,
      fixture.movement_repository,
      fixture.tenant_a
    )

    assert {:ok, quiesced_registry} =
             TrustedRouting.quiesce_movement(fixture.auth_a, copying_registry, movement.id)

    assert {:error, :tenant_moving} =
             TrustedRouting.with_route(fixture.auth_a, quiesced_registry, fn _placement ->
               flunk("ordinary work must be blocked while quiesced")
             end)

    assert {:error, :tenant_moving} =
             TrustedRouting.perform_interface(
               :event,
               TrustedRouting.job_args(fixture.auth_a),
               %{},
               quiesced_registry,
               fn _route -> flunk("non-HTTP work must be blocked while quiesced") end
             )

    assert {:ok, reconciled_registry} =
             TrustedRouting.reconcile_movement(
               fixture.auth_a,
               quiesced_registry,
               movement.id
             )

    assert {:ok, cutover_registry} =
             TrustedRouting.cutover_movement(
               fixture.auth_a,
               reconciled_registry,
               movement.id
             )

    moved_auth = %{fixture.auth_a | routing_version: 8}

    assert {:error, :stale_routing_version} =
             TrustedRouting.with_route(fixture.auth_a, cutover_registry, fn _placement ->
               flunk("the old route must not execute after cutover")
             end)

    for interface <- TrustedRouting.non_http_interfaces() do
      assert {:error, :stale_routing_version} =
               TrustedRouting.perform_interface(
                 interface,
                 TrustedRouting.job_args(fixture.auth_a),
                 %{},
                 cutover_registry,
                 fn _route -> flunk("a stale interface envelope must not execute") end
               )

      assert {:ok, {8, ["Synthetic pooled record"], ^expected_repository}} =
               TrustedRouting.perform_interface(
                 interface,
                 TrustedRouting.job_args(moved_auth),
                 %{"database" => fixture.pooled_database},
                 cutover_registry,
                 fn route ->
                   {
                     route.routing_version,
                     authorized_record_names!(fixture.actor_a, fixture.tenant_a),
                     Repo.get_dynamic_repo()
                   }
                 end
               )
    end

    assert {:ok, events} = TrustedRouting.movement_events(moved_auth, cutover_registry)

    assert {:error, :stale_routing_version} =
             TrustedRouting.movement_events(fixture.auth_a, cutover_registry)

    assert Enum.map(events, & &1.event_type) == [
             :movement_prepared,
             :movement_quiesced,
             :movement_reconciled,
             :movement_cut_over
           ]

    refute inspect(events) =~ fixture.pooled_database
    refute inspect(events) =~ fixture.dedicated_database
  end

  test "failed reconciliation cannot cut over and rollback restores source routing", fixture do
    destination = destination_for(fixture)

    assert {:ok, copying_registry, movement} =
             TrustedRouting.prepare_movement(
               fixture.auth_a,
               fixture.registry,
               destination,
               "rollback_rehearsal"
             )

    assert {:ok, quiesced_registry} =
             TrustedRouting.quiesce_movement(fixture.auth_a, copying_registry, movement.id)

    assert {:error, :reconciliation_failed} =
             TrustedRouting.reconcile_movement(
               fixture.auth_a,
               quiesced_registry,
               movement.id
             )

    assert {:error, :movement_not_ready} =
             TrustedRouting.cutover_movement(
               fixture.auth_a,
               quiesced_registry,
               movement.id
             )

    assert {:ok, rolled_back_registry} =
             TrustedRouting.rollback_movement(
               fixture.auth_a,
               quiesced_registry,
               movement.id,
               "reconciliation_failed"
             )

    assert {:ok, ["Synthetic pooled record"]} =
             TrustedRouting.with_route(fixture.auth_a, rolled_back_registry, fn _placement ->
               authorized_record_names!(fixture.actor_a, fixture.tenant_a)
             end)

    assert {:error, :stale_routing_version} =
             TrustedRouting.with_route(
               %{fixture.auth_a | routing_version: 8},
               rolled_back_registry,
               fn _placement -> flunk("rolled-back destination must not become authoritative") end
             )

    assert {:ok, events} = TrustedRouting.movement_events(fixture.auth_a, rolled_back_registry)

    assert Enum.map(events, & &1.event_type) == [
             :movement_prepared,
             :movement_quiesced,
             :movement_rolled_back
           ]
  end

  defp authenticated_tenant(tenant_id, actor_id, routing_version) do
    %AuthenticatedTenant{
      tenant_id: tenant_id,
      actor_id: actor_id,
      routing_version: routing_version,
      correlation_id: UUID.generate()
    }
  end

  defp destination_for(fixture) do
    placement(
      fixture.tenant_a,
      8,
      :dedicated,
      fixture.movement_repository,
      fixture.movement_database,
      "moved-a"
    )
  end

  defp placement(tenant_id, routing_version, profile, repository, database, namespace) do
    %Placement{
      tenant_id: tenant_id,
      routing_version: routing_version,
      profile: profile,
      repository: repository,
      database: database,
      cell: "cell:local",
      queue_namespace: "queue:#{namespace}",
      storage_namespace: "storage:#{namespace}",
      cache_namespace: "cache:#{namespace}",
      projection_namespace: "projection:#{namespace}"
    }
  end

  defp start_database!(database) do
    config =
      Repo.config()
      |> Keyword.put(:database, database)
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)

    :ok = Postgres.storage_up(config)
    {:ok, repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(repository)

    with_repository(repository, fn ->
      Ecto.Migrator.run(Repo, @migrations, :up, all: true, log: false)
    end)

    {repository, config}
  end

  defp stop_database!(repository, config) do
    if Process.alive?(repository) do
      GenServer.stop(repository)
    end

    :ok = Postgres.storage_down(config)
  end

  defp insert_tenant(repository, tenant_id, name) do
    with_repository(repository, fn ->
      Repo.query!(
        "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, now(), now())",
        [UUID.dump!(tenant_id), name]
      )
    end)
  end

  defp insert_actor(repository, tenant_id, name) do
    id = UUID.generate()

    with_repository(repository, fn ->
      Repo.query!(
        """
        INSERT INTO actors (id, tenant_id, name, kind, inserted_at, updated_at)
        VALUES ($1, $2, $3, 'human', NOW(), NOW())
        """,
        [UUID.dump!(id), UUID.dump!(tenant_id), name]
      )
    end)

    struct!(Actor, id: id, tenant_id: tenant_id, name: name, kind: :human)
  end

  defp grant_capability(repository, tenant_id, actor_id, capability_key) do
    role_id = UUID.generate()
    capability_id = UUID.generate()

    with_repository(repository, fn ->
      Repo.query!(
        """
        INSERT INTO roles (id, tenant_id, name, inserted_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        """,
        [UUID.dump!(role_id), UUID.dump!(tenant_id), "Routing #{capability_key}"]
      )

      Repo.query!(
        """
        INSERT INTO capabilities (id, tenant_id, key, inserted_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        """,
        [UUID.dump!(capability_id), UUID.dump!(tenant_id), capability_key]
      )

      Repo.query!(
        """
        INSERT INTO actor_roles (id, tenant_id, actor_id, role_id, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, NOW(), NOW())
        """,
        [
          UUID.dump!(UUID.generate()),
          UUID.dump!(tenant_id),
          UUID.dump!(actor_id),
          UUID.dump!(role_id)
        ]
      )

      Repo.query!(
        """
        INSERT INTO role_capabilities (
          id, tenant_id, role_id, capability_id, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, $4, NOW(), NOW())
        """,
        [
          UUID.dump!(UUID.generate()),
          UUID.dump!(tenant_id),
          UUID.dump!(role_id),
          UUID.dump!(capability_id)
        ]
      )
    end)
  end

  defp insert_record(repository, tenant_id, name) do
    id = UUID.generate()

    with_repository(repository, fn ->
      Repo.query!(
        """
        INSERT INTO foundation_records (
          id, tenant_id, name, status, lock_version, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, 'draft', 1, NOW(), NOW())
        """,
        [UUID.dump!(id), UUID.dump!(tenant_id), name]
      )
    end)

    id
  end

  defp read_record_names(actor, tenant_id) do
    query =
      FoundationRecord
      |> Ash.Query.for_read(:list_paginated)
      |> Ash.Query.set_tenant(tenant_id)

    case Ash.read(query, actor: actor, page: [limit: 3]) do
      {:ok, page} -> {:ok, Enum.map(page.results, & &1.name)}
      {:error, error} -> {:error, error}
    end
  end

  defp authorized_record_names!(actor, tenant_id) do
    {:ok, names} = read_record_names(actor, tenant_id)
    names
  end

  defp copy_tenant_scope(source_repository, destination_repository, tenant_id) do
    tenant_id = UUID.dump!(tenant_id)

    Enum.each(
      @movement_tables,
      &copy_table(&1, source_repository, destination_repository, tenant_id)
    )
  end

  defp copy_table(
         {table, columns, tenant_column},
         source_repository,
         destination_repository,
         tenant_id
       ) do
    column_list = Enum.join(columns, ", ")

    rows =
      with_repository(source_repository, fn ->
        Repo.query!(
          "SELECT #{column_list} FROM #{table} WHERE #{tenant_column} = $1 ORDER BY id",
          [tenant_id]
        ).rows
      end)

    placeholders =
      1..length(columns)
      |> Enum.map_join(", ", &"$#{&1}")

    copy_rows(destination_repository, table, column_list, placeholders, rows)
  end

  defp copy_rows(repository, table, column_list, placeholders, rows) do
    with_repository(repository, fn ->
      Enum.each(rows, fn row ->
        Repo.query!(
          "INSERT INTO #{table} (#{column_list}) VALUES (#{placeholders})",
          row
        )
      end)
    end)
  end

  defp tenant_name(tenant_id) do
    case Repo.query!("SELECT name FROM tenants WHERE id = $1", [UUID.dump!(tenant_id)]).rows do
      [[name]] -> name
      [] -> nil
    end
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
       "20260913040000_add_role_graph_integrity.exs"},
      {AshFoundationLab.Repo.Migrations.AddActionIdempotency,
       "20260914050000_add_action_idempotency.exs"}
    ]

    Enum.each(migration_files, fn {migration, filename} ->
      unless Code.ensure_loaded?(migration) do
        Code.require_file(Path.join(@migrations_path, filename))
      end
    end)
  end
end
