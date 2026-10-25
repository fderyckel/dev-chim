# Explicit qualification probe, outside the ordinary functional test suite.
# It measures every repeat and fails when the retained acceptance target fails.
ExUnit.start()

defmodule Chimwemwe.People.StaffAudienceWorkloadTest do
  use ExUnit.Case, async: false
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.{Fixture, Foundation}
  alias Chimwemwe.People.StaffAudience
  alias Chimwemwe.Platform.PersistenceRuntime

  @tag timeout: 120_000
  test "three disclosed source-stage runs beside real classroom reads and writes" do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, seeded} = Fixture.seed!(persistence)
    old = Application.get_env(:chimwemwe_core, :identity_session_hmac_secret)

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    on_exit(fn ->
      if old,
        do: Application.put_env(:chimwemwe_core, :identity_session_hmac_secret, old),
        else: Application.delete_env(:chimwemwe_core, :identity_session_hmac_secret)

      for agent <- [seeded.source, seeded.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))
    end)

    f = connect!(seeded)
    for _ <- 1..24, do: staff!(f)
    class = Fixture.class!(f)

    for _ <- 1..10 do
      assert {:ok, _} = Foundation.current_class(f.persistence, Fixture.context_a(), class.id)
      assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
    end

    results =
      for run <- 1..3 do
        baseline = workload(f, class, false)
        mixed = workload(f, class, true)
        read_change = percent(mixed.read.p95, baseline.read.p95)
        write_change = percent(mixed.write.p95, baseline.write.p95)

        result = %{
          run: run,
          baseline: baseline,
          mixed: mixed,
          classroom_read_p95_change_percent: read_change,
          classroom_write_p95_change_percent: write_change,
          accepted:
            read_change <= 20 and write_change <= 20 and mixed.read.p95 <= 300 and
              mixed.read.p99 <= 750 and mixed.write.p95 <= 750 and mixed.write.p99 <= 2000
        }

        # Aggregate timings only: no subject references, source proofs or credentials.
        IO.puts("STAFF_SOURCE_WORKLOAD " <> Jason.encode!(result))
        assert mixed.read.count == 120
        assert mixed.write.count == 30
        assert mixed.source.count == 5
        assert mixed.source.p99 < 2000
        result
      end

    assert Enum.all?(results, & &1.accepted),
           "Staff-source classroom impact exceeds the retained 20% target; qualification is blocked"
  end

  defp workload(f, class, source?) do
    parent = self()

    readers =
      for _ <- 1..4,
          do:
            worker(parent, :read, fn ->
              samples(30, fn ->
                Foundation.current_class(f.persistence, Fixture.context_a(), class.id)
              end)
            end)

    writer =
      worker(parent, :write, fn ->
        samples(30, fn ->
          created = Fixture.class!(f)

          Foundation.assign_teacher(
            f.persistence,
            Fixture.context_a(),
            Fixture.teacher_input(f, created)
          )
        end)
      end)

    sources = if source?, do: [source_reader(parent, f)], else: []

    tasks = readers ++ [writer] ++ sources
    for _ <- tasks, do: assert_receive({:ready, _}, 2_000)
    Enum.each(tasks, &send(&1.pid, :start))

    tasks
    |> Enum.map(&Task.await(&1, 60_000))
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {kind, groups} -> {kind, summarize(List.flatten(groups))} end)
    |> Map.put_new(:source, summarize([]))
  end

  defp source_reader(parent, f) do
    worker(parent, :source, fn -> samples(5, fn -> source_capture(f) end) end)
  end

  defp source_capture(f) do
    StaffAudience.capture(f.audience, f.request, draft(), fn proof ->
      assert map_size(proof.subjects) == 25
      {:ok, :captured}
    end)
  end

  defp worker(parent, kind, operation) do
    Task.async(fn ->
      send(parent, {:ready, self()})
      receive do: (:start -> {kind, operation.()})
    end)
  end

  defp samples(count, operation) do
    for _ <- 1..count do
      {microseconds, result} = :timer.tc(operation)
      assert match?({:ok, _}, result)
      microseconds / 1000
    end
  end

  defp summarize([]), do: %{count: 0, p95: 0.0, p99: 0.0}

  defp summarize(samples) do
    sorted = Enum.sort(samples)

    %{
      count: length(samples),
      p95: Enum.at(sorted, ceil(length(sorted) * 0.95) - 1),
      p99: Enum.at(sorted, ceil(length(sorted) * 0.99) - 1)
    }
  end

  defp percent(mixed, baseline), do: Float.round(100 * (mixed / baseline - 1), 2)
end
