defmodule AshFoundationLab.RetainedDataMigrationMeasurement do
  @moduledoc """
  Reproducible synthetic scale measurement for the retained-data rehearsal.

  This module is Phase 0 evidence tooling. It creates and destroys uniquely
  named local databases and is not a production migration runner.
  """

  alias AshFoundationLab.Repo
  alias AshFoundationLab.RetainedDataMigration
  alias Ecto.Adapters.Postgres
  alias Ecto.UUID

  @default_primary_rows 1_280_000
  @default_control_rows 32_000
  @default_repetitions 3
  @batch_size 100
  @support_index "foundation_records_canonical_name_backfill_index"
  @lock_timeout "250ms"
  @migration_lock_attempts 120
  @lock_retry_delay_ms 250

  @base_migrations [
    {20_260_913_000_000, AshFoundationLab.Repo.Migrations.CreateFoundationRecords,
     "20260913000000_create_foundation_records.exs"},
    {20_260_913_010_000, AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow,
     "20260913010000_add_access_model_and_record_workflow.exs"},
    {20_260_913_020_000, AshFoundationLab.Repo.Migrations.AddTransactionalOutbox,
     "20260913020000_add_transactional_outbox.exs"},
    {20_260_913_030_000, AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle,
     "20260913030000_add_synthetic_module_lifecycle.exs"},
    {20_260_913_040_000, AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity,
     "20260913040000_add_role_graph_integrity.exs"},
    {20_260_914_050_000, AshFoundationLab.Repo.Migrations.AddActionIdempotency,
     "20260914050000_add_action_idempotency.exs"}
  ]

  @rehearsal_migrations [
    {20_260_915_010_000, AshFoundationLab.RetainedDataMigration.ExpandFoundationRecordName,
     "20260915010000_expand_foundation_record_name.exs"},
    {20_260_915_020_000, AshFoundationLab.RetainedDataMigration.EnforceFoundationRecordDualWrite,
     "20260915020000_enforce_foundation_record_dual_write.exs"},
    {20_260_915_030_000, AshFoundationLab.RetainedDataMigration.ValidateFoundationRecordName,
     "20260915030000_validate_foundation_record_name.exs"},
    {20_260_915_040_000, AshFoundationLab.RetainedDataMigration.ContractFoundationRecordName,
     "20260915040000_contract_foundation_record_name.exs"}
  ]

  @measured_sources [
    "lib/ash_foundation_lab/retained_data_migration.ex",
    "lib/ash_foundation_lab/retained_data_migration_measurement.ex",
    "lib/mix/tasks/phase0.retained_data.measure.ex",
    "priv/retained_data_migration_rehearsal/migrations/20260915010000_expand_foundation_record_name.exs",
    "priv/retained_data_migration_rehearsal/migrations/20260915020000_enforce_foundation_record_dual_write.exs",
    "priv/retained_data_migration_rehearsal/migrations/20260915030000_validate_foundation_record_name.exs",
    "priv/retained_data_migration_rehearsal/migrations/20260915040000_contract_foundation_record_name.exs"
  ]

  @type option ::
          {:primary_rows, pos_integer()}
          | {:control_rows, pos_integer()}
          | {:repetitions, pos_integer()}
          | {:output_path, Path.t() | nil}
          | {:progress, boolean()}

  @doc "Runs the disposable measurement and optionally writes its JSON artifact."
  @spec run!([option()]) :: map()
  def run!(options \\ []) do
    primary_rows = positive_option!(options, :primary_rows, @default_primary_rows)
    control_rows = positive_option!(options, :control_rows, @default_control_rows)
    repetitions = positive_option!(options, :repetitions, @default_repetitions)
    output_path = Keyword.get(options, :output_path)
    progress? = Keyword.get(options, :progress, false)

    ensure_migrations_loaded!()

    runs =
      Enum.map(1..repetitions, fn repetition ->
        report(progress?, "starting repetition #{repetition}/#{repetitions}")
        run = run_repetition!(repetition, primary_rows, control_rows, progress?)
        report(progress?, "completed repetition #{repetition}/#{repetitions}")
        run
      end)

    result = build_result(primary_rows, control_rows, repetitions, runs)
    maybe_write!(output_path, result)
    result
  end

  defp run_repetition!(repetition, primary_rows, control_rows, progress?) do
    database =
      "ash_foundation_lab_retained_measurement_#{System.unique_integer([:positive, :monotonic])}"

    config =
      Repo.config()
      |> Keyword.put(:database, database)
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)

    :ok = Postgres.storage_up(config)
    {:ok, repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(repository)

    try do
      with_repository(repository, fn ->
        Ecto.Migrator.run(Repo, migration_pairs(@base_migrations), :up,
          all: true,
          log: false
        )

        environment = database_environment()
        start_lsn = current_lsn()
        {fixture, seed_ms} = timed(fn -> seed!(primary_rows, control_rows) end)
        report(progress?, "repetition #{repetition}: seeded #{primary_rows + control_rows} rows")
        after_seed_lsn = current_lsn()
        after_seed_size = relation_sizes()

        {expand_attempts, expand_ms} =
          timed(fn -> run_lock_bounded_migration!(Enum.at(@rehearsal_migrations, 0), :up) end)

        report(progress?, "repetition #{repetition}: expand completed")

        after_expand_lsn = current_lsn()

        {_, support_index_ms} = timed(&create_support_index!/0)
        report(progress?, "repetition #{repetition}: support index completed")
        after_index_lsn = current_lsn()
        after_index_size = relation_sizes()

        primary_context = context!(fixture.primary_tenant_id)
        control_context = context!(fixture.control_tenant_id)

        {primary_backfill, primary_backfill_ms} =
          timed(fn -> backfill_tenant!(primary_context, primary_rows) end)

        report(progress?, "repetition #{repetition}: primary backfill completed")

        primary_remaining = remaining!(primary_context)
        control_remaining_after_primary = remaining!(control_context)
        control_populated_after_primary = populated_count!(fixture.control_tenant_id)

        unless primary_remaining == 0 and control_remaining_after_primary == control_rows and
                 control_populated_after_primary == 0 do
          raise "tenant-scoped backfill changed rows outside its synthetic tenant"
        end

        {control_backfill, control_backfill_ms} =
          timed(fn -> backfill_tenant!(control_context, control_rows) end)

        report(progress?, "repetition #{repetition}: control backfill completed")

        after_backfill_lsn = current_lsn()
        after_backfill_size = relation_sizes()

        mismatch_count = value_mismatch_count!()
        retained_before_contract = retained_fingerprint!()

        {enforce_attempts, enforce_ms} =
          timed(fn -> run_lock_bounded_migration!(Enum.at(@rehearsal_migrations, 1), :up) end)

        after_enforce_lsn = current_lsn()

        {validate_attempts, validate_ms} =
          timed(fn -> run_lock_bounded_migration!(Enum.at(@rehearsal_migrations, 2), :up) end)

        after_validate_lsn = current_lsn()

        {_, support_index_drop_ms} = timed(&drop_support_index!/0)
        after_index_drop_lsn = current_lsn()

        {contract_attempts, contract_ms} =
          timed(fn -> run_lock_bounded_migration!(Enum.at(@rehearsal_migrations, 3), :up) end)

        report(
          progress?,
          "repetition #{repetition}: enforcement, validation, and contract completed"
        )

        final_lsn = current_lsn()
        final_size = relation_sizes()
        retained_after_contract = retained_fingerprint!()

        assertions = %{
          "canonical_column_not_null" => column_nullable!("canonical_name") == "NO",
          "control_tenant_untouched_during_primary_backfill" =>
            control_remaining_after_primary == control_rows and
              control_populated_after_primary == 0,
          "legacy_column_removed" => not column_exists?("name"),
          "non_empty_constraint_validated" =>
            constraint_validated?("foundation_records_canonical_name_must_not_be_empty"),
          "presence_constraint_validated" =>
            constraint_validated?("foundation_records_canonical_name_must_be_present"),
          "retained_fingerprint_unchanged" => retained_before_contract == retained_after_contract,
          "support_index_removed" => not index_exists?(@support_index),
          "tenant_counts_preserved" =>
            retained_after_contract["rows"] == primary_rows + control_rows,
          "values_match" => mismatch_count == 0
        }

        unless Enum.all?(assertions, fn {_name, passed?} -> passed? end) do
          raise "retained-data measurement assertion failed: #{inspect(assertions)}"
        end

        %{
          "repetition" => repetition,
          "environment" => environment,
          "rows" => %{
            "control_tenant" => control_rows,
            "primary_tenant" => primary_rows,
            "total" => primary_rows + control_rows
          },
          "timings_ms" => %{
            "contract" => contract_ms,
            "control_backfill" => control_backfill_ms,
            "enforce" => enforce_ms,
            "expand" => expand_ms,
            "primary_backfill" => primary_backfill_ms,
            "seed" => seed_ms,
            "support_index_build" => support_index_ms,
            "support_index_drop" => support_index_drop_ms,
            "validate" => validate_ms
          },
          "migration_lock_attempts" => %{
            "contract" => contract_attempts,
            "enforce" => enforce_attempts,
            "expand" => expand_attempts,
            "validate" => validate_attempts
          },
          "backfill" => %{
            "batch_size" => @batch_size,
            "control" => summarize_backfill(control_backfill, control_backfill_ms),
            "primary" => summarize_backfill(primary_backfill, primary_backfill_ms),
            "support_index" => %{
              "columns" => ["tenant_id", "inserted_at", "id"],
              "creation" => "concurrent",
              "name" => @support_index,
              "predicate" => "canonical_name IS NULL"
            }
          },
          "relation_bytes" => %{
            "after_backfill" => after_backfill_size,
            "after_contract" => final_size,
            "after_seed" => after_seed_size,
            "with_support_index" => after_index_size
          },
          "wal_bytes" => %{
            "backfill" => lsn_difference(after_backfill_lsn, after_index_lsn),
            "contract" => lsn_difference(final_lsn, after_index_drop_lsn),
            "enforce" => lsn_difference(after_enforce_lsn, after_backfill_lsn),
            "expand" => lsn_difference(after_expand_lsn, after_seed_lsn),
            "seed" => lsn_difference(after_seed_lsn, start_lsn),
            "support_index_build" => lsn_difference(after_index_lsn, after_expand_lsn),
            "support_index_drop" => lsn_difference(after_index_drop_lsn, after_validate_lsn),
            "total" => lsn_difference(final_lsn, start_lsn),
            "validate" => lsn_difference(after_validate_lsn, after_enforce_lsn)
          },
          "retained_fingerprint" => retained_after_contract,
          "assertions" => assertions
        }
      end)
    after
      if Process.alive?(repository), do: GenServer.stop(repository)
      :ok = Postgres.storage_down(config)
    end
  end

  defp seed!(primary_rows, control_rows) do
    primary_tenant_id = UUID.generate()
    control_tenant_id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO tenants (id, name, inserted_at, updated_at)
      VALUES ($1, 'Synthetic annual-volume tenant', now(), now()),
             ($2, 'Synthetic control tenant', now(), now())
      """,
      [UUID.dump!(primary_tenant_id), UUID.dump!(control_tenant_id)]
    )

    insert_synthetic_rows!(primary_tenant_id, "primary", primary_rows)
    insert_synthetic_rows!(control_tenant_id, "control", control_rows)

    %{primary_tenant_id: primary_tenant_id, control_tenant_id: control_tenant_id}
  end

  defp insert_synthetic_rows!(tenant_id, label, row_count) do
    Repo.query!(
      """
      INSERT INTO foundation_records (id, tenant_id, name, inserted_at, updated_at)
      SELECT (
               substr(digest, 1, 8) || '-' || substr(digest, 9, 4) || '-' ||
               substr(digest, 13, 4) || '-' || substr(digest, 17, 4) || '-' ||
               substr(digest, 21, 12)
             )::uuid,
             $1,
             $2 || ' retained row ' || sequence,
             timestamp '2025-01-01 00:00:00' +
               ((sequence - 1) % 200) * interval '1 day' +
               ((sequence - 1) % 8) * interval '1 minute',
             timestamp '2025-01-01 00:00:00' +
               ((sequence - 1) % 200) * interval '1 day' +
               ((sequence - 1) % 8) * interval '1 minute'
      FROM (
        SELECT sequence, md5($3 || ':' || sequence::text) AS digest
        FROM generate_series(1, $4) AS sequence
      ) AS synthetic_rows
      """,
      [UUID.dump!(tenant_id), label, tenant_id, row_count],
      timeout: :infinity
    )
  end

  defp create_support_index! do
    with_session_lock_timeout(fn ->
      Repo.query!(
        """
        CREATE INDEX CONCURRENTLY #{@support_index}
        ON foundation_records (tenant_id, inserted_at, id)
        WHERE canonical_name IS NULL
        """,
        [],
        timeout: :infinity
      )
    end)

    unless index_valid?(@support_index), do: raise("concurrent support index is not valid")
  end

  defp drop_support_index! do
    with_session_lock_timeout(fn ->
      Repo.query!("DROP INDEX CONCURRENTLY #{@support_index}", [], timeout: :infinity)
    end)
  end

  defp with_session_lock_timeout(operation) do
    Repo.checkout(fn ->
      Repo.query!("SET lock_timeout = '#{@lock_timeout}'")

      try do
        operation.()
      after
        Repo.query!("RESET lock_timeout")
      end
    end)
  end

  defp backfill_tenant!(context, expected_rows) do
    do_backfill_tenant(context, expected_rows, 0, [])
  end

  defp do_backfill_tenant(context, expected_rows, processed, durations) do
    {{:ok, identifiers}, elapsed_ms} =
      timed(fn -> RetainedDataMigration.backfill_batch(context, @batch_size) end)

    case identifiers do
      [] ->
        unless processed == expected_rows do
          raise "backfill processed #{processed} rows; expected #{expected_rows}"
        end

        %{"batch_durations_ms" => Enum.reverse(durations), "rows" => processed}

      identifiers ->
        do_backfill_tenant(
          context,
          expected_rows,
          processed + length(identifiers),
          [elapsed_ms | durations]
        )
    end
  end

  defp summarize_backfill(backfill, elapsed_ms) do
    durations = backfill["batch_durations_ms"]

    %{
      "batches" => length(durations),
      "batch_latency_ms" => %{
        "max" => round_metric(Enum.max(durations)),
        "p50" => percentile(durations, 0.50),
        "p95" => percentile(durations, 0.95),
        "p99" => percentile(durations, 0.99)
      },
      "elapsed_ms" => elapsed_ms,
      "rows" => backfill["rows"],
      "rows_per_second" => round_metric(backfill["rows"] * 1_000 / elapsed_ms)
    }
  end

  defp percentile(values, fraction) do
    sorted = Enum.sort(values)
    index = max(ceil(length(sorted) * fraction) - 1, 0)
    sorted |> Enum.at(index) |> round_metric()
  end

  defp context!(tenant_id) do
    {:ok, context} =
      RetainedDataMigration.new_context(UUID.generate(), tenant_id, UUID.generate())

    context
  end

  defp remaining!(context) do
    {:ok, remaining} = RetainedDataMigration.remaining_count(context)
    remaining
  end

  defp populated_count!(tenant_id) do
    [[count]] =
      Repo.query!(
        """
        SELECT count(*)
        FROM foundation_records
        WHERE tenant_id = $1 AND canonical_name IS NOT NULL
        """,
        [UUID.dump!(tenant_id)]
      ).rows

    count
  end

  defp value_mismatch_count! do
    [[count]] =
      Repo.query!(
        "SELECT count(*) FROM foundation_records WHERE canonical_name IS DISTINCT FROM name"
      ).rows

    count
  end

  defp retained_fingerprint! do
    [[rows, fingerprint]] =
      Repo.query!("""
      SELECT count(*),
             bit_xor(hashtextextended(
               id::text || ':' || tenant_id::text || ':' || canonical_name,
               0
             ))::text
      FROM foundation_records
      """).rows

    %{"fingerprint" => fingerprint, "rows" => rows}
  end

  defp relation_sizes do
    [[table_bytes, index_bytes, total_bytes]] =
      Repo.query!("""
      SELECT pg_relation_size('foundation_records'),
             pg_indexes_size('foundation_records'),
             pg_total_relation_size('foundation_records')
      """).rows

    %{"indexes" => index_bytes, "table" => table_bytes, "total" => total_bytes}
  end

  defp current_lsn do
    [[lsn]] = Repo.query!("SELECT pg_current_wal_lsn()::text").rows
    lsn
  end

  defp lsn_difference(later, earlier) do
    [[bytes]] =
      Repo.query!("SELECT pg_wal_lsn_diff($1::text::pg_lsn, $2::text::pg_lsn)::bigint", [
        later,
        earlier
      ]).rows

    bytes
  end

  defp column_exists?(column_name) do
    [[exists?]] =
      Repo.query!(
        """
        SELECT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'foundation_records'
            AND column_name = $1
        )
        """,
        [column_name]
      ).rows

    exists?
  end

  defp column_nullable!(column_name) do
    [[nullable]] =
      Repo.query!(
        """
        SELECT is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'foundation_records'
          AND column_name = $1
        """,
        [column_name]
      ).rows

    nullable
  end

  defp constraint_validated?(constraint_name) do
    [[validated?]] =
      Repo.query!("SELECT convalidated FROM pg_constraint WHERE conname = $1", [constraint_name]).rows

    validated?
  end

  defp index_exists?(index_name) do
    [[exists?]] =
      Repo.query!(
        "SELECT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = $1)",
        [index_name]
      ).rows

    exists?
  end

  defp index_valid?(index_name) do
    [[valid?]] =
      Repo.query!(
        """
        SELECT index_definition.indisvalid
        FROM pg_index AS index_definition
        JOIN pg_class AS index_relation ON index_relation.oid = index_definition.indexrelid
        WHERE index_relation.relname = $1
        """,
        [index_name]
      ).rows

    valid?
  end

  defp database_environment do
    settings =
      for setting <- ~w(
            fsync
            full_page_writes
            max_connections
            shared_buffers
            synchronous_commit
            wal_level
          ),
          into: %{} do
        [[value]] = Repo.query!("SELECT current_setting($1)", [setting]).rows
        {setting, value}
      end

    [[version]] = Repo.query!("SHOW server_version").rows

    %{
      "postgresql_server_version" => version,
      "settings" => settings
    }
  end

  defp run_migration!({version, module, _filename}, direction) do
    Ecto.Migrator.run(Repo, [{version, module}], direction, all: true, log: false)
  end

  defp run_lock_bounded_migration!(specification, direction) do
    do_run_lock_bounded_migration!(specification, direction, 1)
  end

  defp do_run_lock_bounded_migration!(specification, direction, attempt) do
    run_migration!(specification, direction)
    attempt
  rescue
    error in Postgrex.Error ->
      if error.postgres.code == :lock_not_available and attempt < @migration_lock_attempts do
        Process.sleep(@lock_retry_delay_ms)
        do_run_lock_bounded_migration!(specification, direction, attempt + 1)
      else
        {_version, _module, filename} = specification

        reraise RuntimeError,
                [
                  message: "#{filename} failed on attempt #{attempt}: #{Exception.message(error)}"
                ],
                __STACKTRACE__
      end
  end

  defp migration_pairs(specifications) do
    Enum.map(specifications, fn {version, module, _filename} -> {version, module} end)
  end

  defp ensure_migrations_loaded! do
    spike_root = spike_root()

    for {_version, module, filename} <- @base_migrations do
      unless Code.ensure_loaded?(module) do
        Code.require_file(Path.join([spike_root, "priv/repo/migrations", filename]))
      end
    end

    for {_version, module, filename} <- @rehearsal_migrations do
      unless Code.ensure_loaded?(module) do
        Code.require_file(
          Path.join([spike_root, "priv/retained_data_migration_rehearsal/migrations", filename])
        )
      end
    end
  end

  defp build_result(primary_rows, control_rows, repetitions, runs) do
    %{
      "schema_version" => 1,
      "status" => "phase0_evidence",
      "owner" => "Platform engineering",
      "measured_on" => Date.utc_today() |> Date.to_iso8601(),
      "source" => source_record(),
      "command" =>
        "MIX_ENV=test mix phase0.retained_data.measure --primary-rows #{primary_rows} " <>
          "--control-rows #{control_rows} --repetitions #{repetitions}",
      "envelope" => %{
        "approved_production_target" => false,
        "basis" =>
          "one synthetic 800-learner school-year at 200 days and eight attendance opportunities, plus a separate control tenant",
        "control_tenant_rows" => control_rows,
        "primary_tenant_rows" => primary_rows,
        "repetitions" => repetitions,
        "total_rows_per_run" => primary_rows + control_rows
      },
      "environment" => local_environment(),
      "methodology" => %{
        "backfill_batch_size" => @batch_size,
        "batch_latency_percentile_method" => "nearest-rank over successful data batches",
        "database_lifecycle" => "new local disposable PostgreSQL database per repetition",
        "lock_timeout" => @lock_timeout,
        "migration_lock_retry" => %{
          "delay_ms" => @lock_retry_delay_ms,
          "maximum_attempts" => @migration_lock_attempts,
          "rule" =>
            "retry only PostgreSQL lock_not_available after the failed transaction rolls back"
        },
        "support_index" =>
          "temporary concurrent partial index on tenant_id, inserted_at, and id where canonical_name is null",
        "tenant_safety" =>
          "backfill primary tenant first; assert every control row remains null before separately backfilling control tenant"
      },
      "runs" => runs,
      "summary" => summarize_runs(runs),
      "result" => "measured_with_bounded_remediation",
      "limits" => [
        "Local single-node PostgreSQL is not the proposed managed production writer, HA standby, or replica topology.",
        "The planning envelope is synthetic and not an owner-approved production scale or service-level target.",
        "The measurement does not exercise mixed application releases, concurrent user writes, replica lag, failover, backup, or restore.",
        "The temporary support index is benchmark choreography; its production creation, cleanup, lock budget, and operator ownership require a reviewed migration plan.",
        "WAL and relation bytes describe this schema, generated text shape, PostgreSQL settings, and local hardware only."
      ]
    }
  end

  defp summarize_runs(runs) do
    %{
      "primary_backfill_rows_per_second" =>
        distribution(runs, &get_in(&1, ["backfill", "primary", "rows_per_second"])),
      "primary_backfill_elapsed_ms" =>
        distribution(runs, &get_in(&1, ["timings_ms", "primary_backfill"])),
      "support_index_build_ms" =>
        distribution(runs, &get_in(&1, ["timings_ms", "support_index_build"])),
      "total_wal_bytes" => distribution(runs, &get_in(&1, ["wal_bytes", "total"])),
      "final_relation_bytes" =>
        distribution(runs, &get_in(&1, ["relation_bytes", "after_contract", "total"]))
    }
  end

  defp distribution(runs, extractor) do
    values = Enum.map(runs, extractor)

    %{
      "max" => values |> Enum.max() |> round_metric(),
      "median" => percentile(values, 0.50),
      "min" => values |> Enum.min() |> round_metric()
    }
  end

  defp source_record do
    spike_root = spike_root()
    {revision, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: spike_root)
    {status, 0} = System.cmd("git", ["status", "--porcelain"], cd: spike_root)

    artifacts =
      Map.new(@measured_sources, fn relative_path ->
        digest =
          relative_path
          |> then(&Path.join(spike_root, &1))
          |> File.read!()
          |> then(&:crypto.hash(:sha256, &1))
          |> Base.encode16(case: :lower)

        {relative_path, digest}
      end)

    %{
      "artifacts_sha256" => artifacts,
      "git_revision" => String.trim(revision),
      "working_tree" => if(String.trim(status) == "", do: "clean", else: "dirty")
    }
  end

  defp local_environment do
    %{
      "architecture" => :erlang.system_info(:system_architecture) |> to_string(),
      "cpu" => command_value("sysctl", ["-n", "machdep.cpu.brand_string"]),
      "elixir" => System.version(),
      "erlang_otp" => System.otp_release(),
      "memory_bytes" => command_value("sysctl", ["-n", "hw.memsize"]),
      "operating_system" => command_value("sw_vers", ["-productVersion"]),
      "scheduler_count" => System.schedulers_online() |> Integer.to_string()
    }
  end

  defp command_value(command, arguments) do
    case System.cmd(command, arguments, stderr_to_stdout: true) do
      {value, 0} -> String.trim(value)
      {_error, _status} -> "unavailable"
    end
  end

  defp maybe_write!(nil, _result), do: :ok

  defp maybe_write!(output_path, result) do
    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, Jason.encode!(result, pretty: true) <> "\n")
  end

  defp report(true, message), do: IO.puts("Retained-data measurement: #{message}")
  defp report(false, _message), do: :ok

  defp positive_option!(options, name, default) do
    case Keyword.get(options, name, default) do
      value when is_integer(value) and value > 0 -> value
      value -> raise ArgumentError, "#{name} must be a positive integer, got: #{inspect(value)}"
    end
  end

  defp timed(operation) do
    started_at = System.monotonic_time()
    result = operation.()
    elapsed = System.monotonic_time() - started_at

    {result,
     elapsed
     |> System.convert_time_unit(:native, :microsecond)
     |> Kernel./(1_000)
     |> round_metric()}
  end

  defp round_metric(value) when is_integer(value), do: value
  defp round_metric(value), do: Float.round(value, 3)

  defp with_repository(repository, operation) do
    previous_repository = Repo.put_dynamic_repo(repository)

    try do
      operation.()
    after
      Repo.put_dynamic_repo(previous_repository)
    end
  end

  defp spike_root do
    Mix.Project.project_file()
    |> Path.dirname()
    |> Path.expand()
  end
end
