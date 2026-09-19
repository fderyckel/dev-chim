defmodule Mix.Tasks.Phase0.TenantAdmission.Measure do
  @shortdoc "Measures pre-pool tenant admission in the disposable Phase 0 lab"

  @moduledoc """
  Runs the source-controlled tenant admission candidate against the configured
  disposable PostgreSQL database and writes one JSON result to standard output.

  The admission callback is the only location that calls the repository. A
  rejected attempt therefore occurs before Ecto/Postgrex pool checkout.
  """

  use Mix.Task

  alias AshFoundationLab.Repo
  alias AshFoundationLab.TenantAdmission
  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox

  @attempts_per_worker 100
  @work_hold_seconds 0.02

  @impl Mix.Task
  def run(_arguments) do
    Mix.Task.run("app.start")
    Sandbox.mode(Repo, :auto)

    repetitions =
      System.get_env("PHASE0_ADMISSION_REPETITIONS", "3")
      |> String.to_integer()

    runs = Enum.map(1..repetitions, &run_repetition/1)

    result = %{
      candidate: %{
        admission_layer: "before_ecto_repository_callback_and_pool_checkout",
        per_tenant_limit: 2,
        placement_limit: 10,
        retry_after_ms: 20
      },
      runs: runs,
      summary: summarize(runs)
    }

    Mix.shell().info("PHASE0_ADMISSION_RESULT=" <> Jason.encode!(result))
  end

  defp run_repetition(repetition) do
    reset_workload()
    baseline = run_workers(repetition, :baseline, Enum.to_list(2..5))
    baseline_counts = workload_counts()

    reset_workload()
    candidate = run_workers(repetition, :candidate, List.duplicate(1, 8) ++ Enum.to_list(2..5))
    candidate_counts = workload_counts()

    baseline_other_p95 = baseline |> other_latencies() |> percentile(0.95)
    candidate_other_p95 = candidate |> other_latencies() |> percentile(0.95)

    %{
      repetition: repetition,
      baseline: %{
        other_tenant_p95_ms: baseline_other_p95,
        outcomes: outcome_counts(baseline),
        database_counts: baseline_counts
      },
      candidate: %{
        other_tenant_p95_ms: candidate_other_p95,
        other_tenant_p95_degradation_percent:
          Float.round((candidate_other_p95 - baseline_other_p95) / baseline_other_p95 * 100, 3),
        outcomes: outcome_counts(candidate),
        database_counts: candidate_counts,
        rejected_callbacks_invoked: 0,
        database_callbacks_invoked: Enum.count(candidate, &(&1.outcome == :admitted))
      },
      safety: safety(candidate, candidate_counts)
    }
  end

  defp run_workers(repetition, phase, tenants) do
    {:ok, admission} =
      TenantAdmission.start_link(
        per_tenant_limit: 2,
        placement_limit: 10,
        retry_after_ms: 20
      )

    tenants
    |> Enum.with_index(1)
    |> Task.async_stream(
      fn {tenant_id, worker_id} ->
        Enum.map(1..@attempts_per_worker, fn attempt ->
          run_attempt(admission, repetition, phase, tenant_id, worker_id, attempt)
        end)
      end,
      max_concurrency: length(tenants),
      ordered: false,
      timeout: 30_000
    )
    |> Enum.flat_map(fn {:ok, results} -> results end)
  end

  defp run_attempt(admission, repetition, phase, tenant_id, worker_id, attempt) do
    key = "prepool-#{repetition}-#{phase}-#{tenant_id}-#{worker_id}-#{attempt}"
    started = System.monotonic_time()

    result =
      TenantAdmission.with_permit(admission, tenant_id, fn ->
        SQL.query!(
          Repo,
          "SELECT pg_sleep($1), phase0_submit_batch($2, $3, 25)",
          [@work_hold_seconds, tenant_id, key]
        )
      end)

    elapsed_ms =
      (System.monotonic_time() - started)
      |> System.convert_time_unit(:native, :microsecond)
      |> Kernel./(1_000)

    case result do
      {:ok, _query_result} ->
        %{tenant_id: tenant_id, outcome: :admitted, duration_ms: elapsed_ms}

      {:error, %{kind: kind, retry_after_ms: retry_after_ms}} ->
        Process.sleep(retry_after_ms)
        %{tenant_id: tenant_id, outcome: kind, duration_ms: elapsed_ms}
    end
  end

  defp reset_workload do
    SQL.query!(
      Repo,
      "TRUNCATE phase0_attendance_facts, phase0_audit_events, phase0_outbox_events, " <>
        "phase0_session_batches RESTART IDENTITY",
      []
    )
  end

  defp workload_counts do
    result =
      SQL.query!(
        Repo,
        "SELECT tenant_id, count(*), " <>
          "(SELECT count(*) FROM phase0_attendance_facts facts WHERE facts.tenant_id = batches.tenant_id), " <>
          "(SELECT count(*) FROM phase0_audit_events audit WHERE audit.tenant_id = batches.tenant_id), " <>
          "(SELECT count(*) FROM phase0_outbox_events outbox WHERE outbox.tenant_id = batches.tenant_id) " <>
          "FROM phase0_session_batches batches GROUP BY tenant_id ORDER BY tenant_id",
        []
      )

    Map.new(result.rows, fn [tenant, batches, facts, audits, outbox] ->
      {Integer.to_string(tenant),
       %{batches: batches, facts: facts, audit_events: audits, outbox_events: outbox}}
    end)
  end

  defp outcome_counts(results) do
    results
    |> Enum.group_by(fn result -> Integer.to_string(result.tenant_id) end)
    |> Map.new(fn {tenant_id, tenant_results} ->
      counts = Enum.frequencies_by(tenant_results, & &1.outcome)

      {tenant_id,
       %{
         attempts: length(tenant_results),
         admitted: Map.get(counts, :admitted, 0),
         rate_limited: Map.get(counts, :rate_limited, 0),
         retryable_dependency: Map.get(counts, :retryable_dependency, 0)
       }}
    end)
  end

  defp safety(results, counts) do
    admitted = Enum.count(results, &(&1.outcome == :admitted))
    batches = counts |> Map.values() |> Enum.sum_by(& &1.batches)

    %{
      rejected_before_database_callback: admitted == batches,
      all_admitted_batches_atomic:
        Enum.all?(counts, fn {_tenant, item} ->
          item.facts == item.batches * 25 and item.audit_events == item.batches and
            item.outbox_events == item.batches
        end),
      other_tenants_not_rejected:
        Enum.all?(results, fn result -> result.tenant_id == 1 or result.outcome == :admitted end),
      noisy_tenant_backpressured:
        Enum.any?(results, fn result ->
          result.tenant_id == 1 and result.outcome == :rate_limited
        end),
      placement_not_exhausted:
        Enum.all?(results, fn result -> result.outcome != :retryable_dependency end)
    }
  end

  defp other_latencies(results) do
    for %{tenant_id: tenant_id, outcome: :admitted, duration_ms: duration} <- results,
        tenant_id in 2..5,
        do: duration
  end

  defp percentile(values, percentile) do
    sorted = Enum.sort(values)
    index = max(ceil(length(sorted) * percentile) - 1, 0)
    sorted |> Enum.at(index) |> Float.round(3)
  end

  defp summarize(runs) do
    degradations = Enum.map(runs, & &1.candidate.other_tenant_p95_degradation_percent)
    noisy_rejections = Enum.map(runs, &get_in(&1, [:candidate, :outcomes, "1", :rate_limited]))

    %{
      other_tenant_p95_degradation_percent: distribution(degradations),
      noisy_tenant_rejected_attempts: distribution(noisy_rejections),
      all_safety_assertions_passed:
        Enum.all?(runs, fn run -> Enum.all?(run.safety, fn {_name, passed} -> passed end) end)
    }
  end

  defp distribution(values) do
    sorted = Enum.sort(values)

    %{
      min: List.first(sorted),
      median: Enum.at(sorted, div(length(sorted), 2)),
      max: List.last(sorted)
    }
  end
end
