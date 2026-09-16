defmodule AshFoundationLab.RetainedDataMigrationTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.Repo
  alias AshFoundationLab.RetainedDataMigration
  alias Ecto.Adapters.Postgres
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @lock_timeout "250ms"
  @base_migrations_path Path.expand("../../priv/repo/migrations", __DIR__)

  @rehearsal_migrations_path Path.expand(
                               "../../priv/retained_data_migration_rehearsal/migrations",
                               __DIR__
                             )

  @base_migrations [
    {20_260_913_000_000, AshFoundationLab.Repo.Migrations.CreateFoundationRecords},
    {20_260_913_010_000, AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow},
    {20_260_913_020_000, AshFoundationLab.Repo.Migrations.AddTransactionalOutbox},
    {20_260_913_030_000, AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle},
    {20_260_913_040_000, AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity},
    {20_260_914_050_000, AshFoundationLab.Repo.Migrations.AddActionIdempotency}
  ]

  @expand_migration {
    20_260_915_010_000,
    AshFoundationLab.RetainedDataMigration.ExpandFoundationRecordName
  }

  @enforce_migration {
    20_260_915_020_000,
    AshFoundationLab.RetainedDataMigration.EnforceFoundationRecordDualWrite
  }

  @validate_migration {
    20_260_915_030_000,
    AshFoundationLab.RetainedDataMigration.ValidateFoundationRecordName
  }

  @contract_migration {
    20_260_915_040_000,
    AshFoundationLab.RetainedDataMigration.ContractFoundationRecordName
  }

  setup_all do
    ensure_migrations_loaded!()
    :ok
  end

  test "the migration artifacts separate additive expand, validation, and destructive contract" do
    expand = rehearsal_source("*_expand_foundation_record_name.exs")
    enforce = rehearsal_source("*_enforce_foundation_record_dual_write.exs")
    validate = rehearsal_source("*_validate_foundation_record_name.exs")
    contract = rehearsal_source("*_contract_foundation_record_name.exs")

    backfill =
      File.read!(Path.expand("../../lib/ash_foundation_lab/retained_data_migration.ex", __DIR__))

    assert expand =~ "add(:canonical_name, :text)"
    assert expand =~ "NOT VALID"
    assert expand =~ ~s(@lock_timeout "#{@lock_timeout}")
    assert expand =~ "SET LOCAL lock_timeout"
    refute expand =~ "add(:canonical_name, :text, null: false)"
    refute expand =~ "default:"
    refute expand =~ "remove :name"

    assert enforce =~ "LOCK TABLE foundation_records IN SHARE ROW EXCLUSIVE MODE"
    assert enforce =~ "canonical name backfill is incomplete"
    assert enforce =~ "CHECK (canonical_name IS NOT NULL)"
    assert enforce =~ "DROP CONSTRAINT foundation_records_canonical_name_must_be_present"

    assert validate =~ "VALIDATE CONSTRAINT foundation_records_canonical_name_must_not_be_empty"
    assert validate =~ "VALIDATE CONSTRAINT foundation_records_canonical_name_must_be_present"

    assert backfill =~ "WHERE tenant_id = $1 AND canonical_name IS NULL"
    assert backfill =~ "FOR UPDATE SKIP LOCKED"
    assert backfill =~ "LIMIT $2"
    assert backfill =~ "record.tenant_id = $1"

    assert contract =~ "ALTER COLUMN canonical_name SET NOT NULL"
    assert contract =~ "DROP COLUMN name RESTRICT"
    assert contract =~ "the destructive contract drops the legacy name column"
  end

  test "expand obeys its lock budget and rolls back without losing legacy data" do
    with_disposable_database(fn fixture ->
      parent = self()

      lock_holder =
        Task.async(fn ->
          with_repository(fixture.primary_repository, fn ->
            Repo.transaction(fn ->
              Repo.query!("LOCK TABLE foundation_records IN ACCESS SHARE MODE")
              send(parent, {:legacy_reader_locked, self()})

              receive do
                :release_legacy_reader -> :ok
              after
                5_000 -> raise "test did not release the synthetic legacy reader"
              end
            end)
          end)
        end)

      assert_receive {:legacy_reader_locked, lock_holder_pid}
      started_at = System.monotonic_time(:millisecond)

      error =
        assert_raise PostgrexError, fn ->
          run_migration(fixture.secondary_repository, @expand_migration, :up)
        end

      elapsed_ms = System.monotonic_time(:millisecond) - started_at
      assert error.postgres.code == :lock_not_available
      assert elapsed_ms < 2_000
      refute column_exists?(fixture.secondary_repository, "canonical_name")

      send(lock_holder_pid, :release_legacy_reader)
      assert {:ok, :ok} = Task.await(lock_holder)

      legacy_before = legacy_snapshot(fixture.primary_repository)

      assert [20_260_915_010_000] =
               run_migration(fixture.primary_repository, @expand_migration, :up)

      assert column_nullable(fixture.primary_repository, "canonical_name") == "YES"

      refute constraint_validated?(
               fixture.primary_repository,
               "foundation_records_canonical_name_must_not_be_empty"
             )

      dual_write_existing(
        fixture.primary_repository,
        hd(fixture.tenant_a_record_ids),
        "Dual-written value"
      )

      assert [20_260_915_010_000] =
               run_migration(fixture.primary_repository, @expand_migration, :down)

      refute column_exists?(fixture.primary_repository, "canonical_name")

      assert Enum.map(legacy_snapshot(fixture.primary_repository), &elem(&1, 0)) ==
               Enum.map(legacy_before, &elem(&1, 0))

      assert legacy_name(fixture.primary_repository, hd(fixture.tenant_a_record_ids)) ==
               "Dual-written value"
    end)
  end

  test "bounded tenant backfill preserves mixed-version data and gates irreversible contract" do
    with_disposable_database(fn fixture ->
      assert [20_260_915_010_000] =
               run_migration(fixture.primary_repository, @expand_migration, :up)

      legacy_insert_id =
        insert_legacy_record(
          fixture.primary_repository,
          fixture.tenant_a,
          "Legacy writer after expand"
        )

      assert compatible_name(fixture.primary_repository, legacy_insert_id) ==
               "Legacy writer after expand"

      dual_write_id = hd(fixture.tenant_a_record_ids)
      dual_write_existing(fixture.primary_repository, dual_write_id, "Compatible dual write")
      assert legacy_name(fixture.primary_repository, dual_write_id) == "Compatible dual write"
      assert compatible_name(fixture.primary_repository, dual_write_id) == "Compatible dual write"

      assert {:error, :missing_context} = RetainedDataMigration.backfill_batch(nil, 2)

      assert {:error, :invalid_context} =
               RetainedDataMigration.new_context("not-a-uuid", fixture.tenant_a, UUID.generate())

      {:ok, tenant_a_context} =
        RetainedDataMigration.new_context(
          UUID.generate(),
          fixture.tenant_a,
          UUID.generate()
        )

      {:ok, tenant_b_context} =
        RetainedDataMigration.new_context(
          UUID.generate(),
          fixture.tenant_b,
          UUID.generate()
        )

      assert {:error, :invalid_batch_size} =
               RetainedDataMigration.backfill_batch(tenant_a_context, 101)

      assert {:ok, 3} = RetainedDataMigration.remaining_count(tenant_a_context)
      assert {:ok, 2} = RetainedDataMigration.remaining_count(tenant_b_context)

      assert {:ok, first_batch} = RetainedDataMigration.backfill_batch(tenant_a_context, 2)
      assert length(first_batch) == 2
      assert {:ok, 1} = RetainedDataMigration.remaining_count(tenant_a_context)
      assert {:ok, 2} = RetainedDataMigration.remaining_count(tenant_b_context)

      assert {:ok, second_batch} = RetainedDataMigration.backfill_batch(tenant_a_context, 2)
      assert length(second_batch) == 1
      assert MapSet.disjoint?(MapSet.new(first_batch), MapSet.new(second_batch))
      assert {:ok, []} = RetainedDataMigration.backfill_batch(tenant_a_context, 2)
      assert {:ok, 0} = RetainedDataMigration.remaining_count(tenant_a_context)

      assert {:ok, tenant_b_batch} = RetainedDataMigration.backfill_batch(tenant_b_context, 2)
      assert length(tenant_b_batch) == 2
      assert {:ok, 0} = RetainedDataMigration.remaining_count(tenant_b_context)

      late_legacy_id =
        insert_legacy_record(
          fixture.primary_repository,
          fixture.tenant_a,
          "Late legacy writer"
        )

      enforcement_error =
        assert_raise PostgrexError, fn ->
          run_migration(fixture.primary_repository, @enforce_migration, :up)
        end

      assert enforcement_error.postgres.code == :check_violation

      refute constraint_exists?(
               fixture.primary_repository,
               "foundation_records_canonical_name_must_be_present"
             )

      assert legacy_name(fixture.primary_repository, late_legacy_id) == "Late legacy writer"
      assert {:ok, [^late_legacy_id]} = RetainedDataMigration.backfill_batch(tenant_a_context, 2)

      assert [20_260_915_020_000] =
               run_migration(fixture.primary_repository, @enforce_migration, :up)

      assert_raise PostgrexError, fn ->
        insert_legacy_record(fixture.primary_repository, fixture.tenant_a, "Rejected old writer")
      end

      final_dual_id =
        insert_dual_record(
          fixture.primary_repository,
          fixture.tenant_b,
          "Final dual writer"
        )

      assert [20_260_915_030_000] =
               run_migration(fixture.primary_repository, @validate_migration, :up)

      assert constraint_validated?(
               fixture.primary_repository,
               "foundation_records_canonical_name_must_not_be_empty"
             )

      assert constraint_validated?(
               fixture.primary_repository,
               "foundation_records_canonical_name_must_be_present"
             )

      retained_before_contract = canonical_snapshot(fixture.primary_repository)

      assert [20_260_915_040_000] =
               run_migration(fixture.primary_repository, @contract_migration, :up)

      assert canonical_snapshot(fixture.primary_repository) == retained_before_contract

      assert Enum.any?(retained_before_contract, fn {id, _tenant_id, _name} ->
               id == final_dual_id
             end)

      refute column_exists?(fixture.primary_repository, "name")
      assert column_nullable(fixture.primary_repository, "canonical_name") == "NO"

      undefined_column =
        assert_raise PostgrexError, fn ->
          legacy_name(fixture.primary_repository, dual_write_id)
        end

      assert undefined_column.postgres.code == :undefined_column

      assert_raise Ecto.MigrationError,
                   ~r/the destructive contract drops the legacy name column/,
                   fn ->
                     run_migration(fixture.primary_repository, @contract_migration, :down)
                   end
    end)
  end

  defp with_disposable_database(operation) do
    database =
      "ash_foundation_lab_retained_migration_#{System.unique_integer([:positive, :monotonic])}"

    config =
      Repo.config()
      |> Keyword.put(:database, database)
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)

    :ok = Postgres.storage_up(config)
    {:ok, primary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    {:ok, secondary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(primary_repository)
    Process.unlink(secondary_repository)

    try do
      with_repository(primary_repository, fn ->
        Ecto.Migrator.run(Repo, @base_migrations, :up, all: true, log: false)
      end)

      fixture = seed_fixture(primary_repository)

      with_repository(primary_repository, fn ->
        operation.(
          Map.merge(fixture, %{
            primary_repository: primary_repository,
            secondary_repository: secondary_repository
          })
        )
      end)
    after
      stop_repository(secondary_repository)
      stop_repository(primary_repository)
      :ok = Postgres.storage_down(config)
    end
  end

  defp seed_fixture(repository) do
    tenant_a = UUID.generate()
    tenant_b = UUID.generate()

    with_repository(repository, fn ->
      insert_tenant(tenant_a, "Synthetic migration tenant A")
      insert_tenant(tenant_b, "Synthetic migration tenant B")
    end)

    tenant_a_record_ids =
      Enum.map(1..3, fn sequence ->
        insert_legacy_record(repository, tenant_a, "Retained A #{sequence}")
      end)

    Enum.each(1..2, fn sequence ->
      insert_legacy_record(repository, tenant_b, "Retained B #{sequence}")
    end)

    %{
      tenant_a: tenant_a,
      tenant_b: tenant_b,
      tenant_a_record_ids: tenant_a_record_ids
    }
  end

  defp insert_tenant(tenant_id, name) do
    Repo.query!(
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, now(), now())",
      [UUID.dump!(tenant_id), name]
    )
  end

  defp insert_legacy_record(repository, tenant_id, name) do
    record_id = UUID.generate()

    with_repository(repository, fn ->
      Repo.query!(
        """
        INSERT INTO foundation_records (id, tenant_id, name, inserted_at, updated_at)
        VALUES ($1, $2, $3, now(), now())
        """,
        [UUID.dump!(record_id), UUID.dump!(tenant_id), name]
      )
    end)

    record_id
  end

  defp insert_dual_record(repository, tenant_id, name) do
    record_id = UUID.generate()

    with_repository(repository, fn ->
      Repo.query!(
        """
        INSERT INTO foundation_records (
          id, tenant_id, name, canonical_name, inserted_at, updated_at
        )
        VALUES ($1, $2, $3, $3, now(), now())
        """,
        [UUID.dump!(record_id), UUID.dump!(tenant_id), name]
      )
    end)

    record_id
  end

  defp dual_write_existing(repository, record_id, name) do
    with_repository(repository, fn ->
      Repo.query!(
        "UPDATE foundation_records SET name = $2, canonical_name = $2 WHERE id = $1",
        [UUID.dump!(record_id), name]
      )
    end)
  end

  defp legacy_name(repository, record_id) do
    with_repository(repository, fn ->
      case Repo.query!("SELECT name FROM foundation_records WHERE id = $1", [
             UUID.dump!(record_id)
           ]).rows do
        [[name]] -> name
      end
    end)
  end

  defp compatible_name(repository, record_id) do
    with_repository(repository, fn ->
      case Repo.query!(
             "SELECT coalesce(canonical_name, name) FROM foundation_records WHERE id = $1",
             [UUID.dump!(record_id)]
           ).rows do
        [[name]] -> name
      end
    end)
  end

  defp legacy_snapshot(repository) do
    with_repository(repository, fn ->
      Repo.query!("SELECT id, tenant_id, name FROM foundation_records ORDER BY tenant_id, id").rows
      |> Enum.map(fn [id, tenant_id, name] -> {UUID.load!(id), UUID.load!(tenant_id), name} end)
    end)
  end

  defp canonical_snapshot(repository) do
    with_repository(repository, fn ->
      Repo.query!(
        "SELECT id, tenant_id, canonical_name FROM foundation_records ORDER BY tenant_id, id"
      ).rows
      |> Enum.map(fn [id, tenant_id, name] -> {UUID.load!(id), UUID.load!(tenant_id), name} end)
    end)
  end

  defp column_exists?(repository, column_name) do
    column_nullable(repository, column_name) != nil
  end

  defp column_nullable(repository, column_name) do
    with_repository(repository, fn ->
      case Repo.query!(
             """
             SELECT is_nullable
             FROM information_schema.columns
             WHERE table_schema = 'public'
               AND table_name = 'foundation_records'
               AND column_name = $1
             """,
             [column_name]
           ).rows do
        [[is_nullable]] -> is_nullable
        [] -> nil
      end
    end)
  end

  defp constraint_exists?(repository, constraint_name) do
    with_repository(repository, fn ->
      Repo.query!("SELECT 1 FROM pg_constraint WHERE conname = $1", [constraint_name]).num_rows ==
        1
    end)
  end

  defp constraint_validated?(repository, constraint_name) do
    with_repository(repository, fn ->
      case Repo.query!("SELECT convalidated FROM pg_constraint WHERE conname = $1", [
             constraint_name
           ]).rows do
        [[validated?]] -> validated?
        [] -> false
      end
    end)
  end

  defp run_migration(repository, migration, direction) do
    with_repository(repository, fn ->
      Ecto.Migrator.run(Repo, [migration], direction, all: true, log: false)
    end)
  end

  defp with_repository(repository, operation) do
    previous_repository = Repo.put_dynamic_repo(repository)

    try do
      operation.()
    after
      Repo.put_dynamic_repo(previous_repository)
    end
  end

  defp stop_repository(repository) do
    if Process.alive?(repository), do: GenServer.stop(repository)
  end

  defp rehearsal_source(glob) do
    assert [migration_path] = Path.wildcard(Path.join(@rehearsal_migrations_path, glob))
    File.read!(migration_path)
  end

  defp ensure_migrations_loaded! do
    base_migration_files = [
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

    rehearsal_migration_files = [
      {AshFoundationLab.RetainedDataMigration.ExpandFoundationRecordName,
       "20260915010000_expand_foundation_record_name.exs"},
      {AshFoundationLab.RetainedDataMigration.EnforceFoundationRecordDualWrite,
       "20260915020000_enforce_foundation_record_dual_write.exs"},
      {AshFoundationLab.RetainedDataMigration.ValidateFoundationRecordName,
       "20260915030000_validate_foundation_record_name.exs"},
      {AshFoundationLab.RetainedDataMigration.ContractFoundationRecordName,
       "20260915040000_contract_foundation_record_name.exs"}
    ]

    Enum.each(base_migration_files, fn {migration, filename} ->
      unless Code.ensure_loaded?(migration) do
        Code.require_file(Path.join(@base_migrations_path, filename))
      end
    end)

    Enum.each(rehearsal_migration_files, fn {migration, filename} ->
      unless Code.ensure_loaded?(migration) do
        Code.require_file(Path.join(@rehearsal_migrations_path, filename))
      end
    end)
  end
end
