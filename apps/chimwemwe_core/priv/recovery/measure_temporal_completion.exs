defmodule Chimwemwe.TemporalCompletionMeasurement do
  alias Chimwemwe.Platform.{
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    TemporalQualification,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Repo

  @tenant_id "11111111-1111-4111-8111-111111111111"
  @actor_id "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @module_key "synthetic.temporal"
  @sample_size 100

  def run do
    context = context()
    runtime = runtime()

    measurements =
      Enum.reduce(1..@sample_size, empty_measurements(), fn sample, measurements ->
        aggregate_id = Ecto.UUID.generate()
        scope_id = Ecto.UUID.generate()

        {publish_us, {:ok, published}} =
          :timer.tc(fn ->
            TemporalQualification.publish_revision(runtime, context, %{
              aggregate_id: aggregate_id,
              scope_id: scope_id,
              reason_code: "synthetic_baseline",
              segments: [
                %{
                  effective_from: ~D[2024-01-01],
                  effective_until: ~D[2025-01-01],
                  value: "alpha"
                },
                %{
                  effective_from: ~D[2025-01-01],
                  effective_until: ~D[2026-01-01],
                  value: "beta"
                }
              ],
              idempotency_key: Ecto.UUID.generate(),
              causation_id: Ecto.UUID.generate()
            })
          end)

        {correct_us, {:ok, corrected}} =
          :timer.tc(fn ->
            TemporalQualification.correct_revision(runtime, context, %{
              aggregate_id: aggregate_id,
              expected_revision_id: published.revision_id,
              reason_code: "synthetic_correction",
              segments: [
                %{
                  effective_from: ~D[2024-01-01],
                  effective_until: ~D[2026-01-01],
                  value: "corrected"
                }
              ],
              idempotency_key: Ecto.UUID.generate(),
              causation_id: Ecto.UUID.generate()
            })
          end)

        {retention_us, {:ok, _retention}} =
          :timer.tc(fn ->
            TemporalQualification.declare_retention(runtime, context, %{
              aggregate_id: aggregate_id,
              module_key: @module_key,
              policy_key: "synthetic.temporal_policy",
              classification: :restricted,
              retention_started_on: ~D[2024-01-01],
              retain_until: Date.add(Date.utc_today(), 365),
              reason_code: "synthetic_retention",
              idempotency_key: Ecto.UUID.generate(),
              causation_id: Ecto.UUID.generate()
            })
          end)

        {import_us, {:ok, _imported}} =
          :timer.tc(fn ->
            TemporalQualification.register_baseline_import(runtime, context, %{
              import_id: Ecto.UUID.generate(),
              module_key: @module_key,
              source_snapshot_digest: :crypto.hash(:sha256, "snapshot-#{sample}"),
              source_identifier_digest: :crypto.hash(:sha256, "source-#{sample}"),
              mapping_revision: "mapping-v1",
              aggregate_id: aggregate_id,
              revision_id: corrected.revision_id,
              reason_code: "synthetic_import",
              idempotency_key: Ecto.UUID.generate(),
              causation_id: Ecto.UUID.generate()
            })
          end)

        {projection_us, {:ok, _projection}} =
          :timer.tc(fn ->
            TemporalQualification.rebuild_current_projection(runtime, context, %{
              aggregate_id: aggregate_id,
              module_key: @module_key
            })
          end)

        measurements
        |> add(:publish, publish_us)
        |> add(:correct, correct_us)
        |> add(:retention, retention_us)
        |> add(:import, import_us)
        |> add(:projection, projection_us)
      end)

    {:ok, [[row_count, total_bytes]]} =
      Persistence.with_writer(runtime, context, fn ->
        Repo.query!("ANALYZE")

        Repo.query!("""
        SELECT sum(reltuples)::bigint, sum(pg_total_relation_size(oid))::bigint
        FROM pg_class
        WHERE relname LIKE 'platform_temporal_qualification_%'
          AND relkind IN ('r', 'i')
        """).rows
      end)

    IO.puts("temporal_measurement sample_size=#{@sample_size}")

    Enum.each([:publish, :correct, :retention, :import, :projection], fn action ->
      values = Map.fetch!(measurements, action)

      IO.puts(
        "#{action}_ms p50=#{percentile(values, 50)} p95=#{percentile(values, 95)} " <>
          "max=#{milliseconds(Enum.max(values))}"
      )
    end)

    IO.puts("temporal_storage estimated_rows=#{row_count} total_bytes=#{total_bytes}")
  end

  defp empty_measurements do
    %{publish: [], correct: [], retention: [], import: [], projection: []}
  end

  defp add(measurements, action, microseconds) do
    Map.update!(measurements, action, &[microseconds | &1])
  end

  defp percentile(values, percentage) do
    ordered = Enum.sort(values)
    index = max(div(length(ordered) * percentage + 99, 100) - 1, 0)
    ordered |> Enum.at(index) |> milliseconds()
  end

  defp milliseconds(microseconds), do: Float.round(microseconds / 1_000, 3)

  defp context do
    {:ok, actor} =
      TrustedActor.establish(actor_id: @actor_id, tenant_id: @tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: @tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-temporal-completion"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: Ecto.UUID.generate(),
        purpose: "platform.temporal_qualification.local_measurement",
        locale: "en"
      )

    context
  end

  defp runtime do
    {:ok, runtime} =
      PersistenceRuntime.start_link(
        repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 4]],
        placements: [
          [
            tenant_id: @tenant_id,
            routing_version: 7,
            profile: :pooled,
            placement_ref: "pooled-temporal-completion",
            repository: :pooled
          ]
        ],
        per_tenant_limit: 4,
        per_placement_limit: 4
      )

    runtime
  end
end

Chimwemwe.TemporalCompletionMeasurement.run()
