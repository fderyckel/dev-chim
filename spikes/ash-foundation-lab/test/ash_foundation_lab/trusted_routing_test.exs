defmodule AshFoundationLab.TrustedRoutingTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.Repo
  alias AshFoundationLab.TrustedRouting
  alias AshFoundationLab.TrustedRouting.AuthenticatedTenant
  alias AshFoundationLab.TrustedRouting.Placement
  alias Ecto.Adapters.Postgres
  alias Ecto.UUID

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

    suffix = System.unique_integer([:positive, :monotonic])
    pooled_database = "ash_foundation_lab_routing_pooled_#{suffix}"
    dedicated_database = "ash_foundation_lab_routing_dedicated_#{suffix}"

    {pooled_repository, pooled_config} = start_database!(pooled_database)
    {dedicated_repository, dedicated_config} = start_database!(dedicated_database)

    on_exit(fn ->
      stop_database!(dedicated_repository, dedicated_config)
      stop_database!(pooled_repository, pooled_config)
    end)

    {:ok,
     pooled_database: pooled_database,
     pooled_repository: pooled_repository,
     dedicated_database: dedicated_database,
     dedicated_repository: dedicated_repository}
  end

  setup fixture do
    tenant_a = UUID.generate()
    tenant_b = UUID.generate()

    insert_tenant(fixture.pooled_repository, tenant_a, "Synthetic pooled tenant")
    insert_tenant(fixture.dedicated_repository, tenant_b, "Synthetic dedicated tenant")

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
     pooled_placement: pooled_placement,
     dedicated_placement: dedicated_placement,
     registry: registry,
     auth_a: authenticated_tenant(tenant_a, 7),
     auth_b: authenticated_tenant(tenant_b, 11)}
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

  defp authenticated_tenant(tenant_id, routing_version) do
    %AuthenticatedTenant{
      tenant_id: tenant_id,
      actor_id: UUID.generate(),
      routing_version: routing_version,
      correlation_id: UUID.generate()
    }
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
       "20260913040000_add_role_graph_integrity.exs"}
    ]

    Enum.each(migration_files, fn {migration, filename} ->
      unless Code.ensure_loaded?(migration) do
        Code.require_file(Path.join(@migrations_path, filename))
      end
    end)
  end
end
