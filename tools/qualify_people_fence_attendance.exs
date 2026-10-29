# Actual attendance workload, separate from the unchanged foundation qualifier.
ExUnit.start()

defmodule Chimwemwe.People.FenceAttendanceWorkloadTest do
  use ExUnit.Case, async: false
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.{Attendance, Fixture, Foundation}
  alias Chimwemwe.Identity.{SessionFoundation, VerifiedExternalIdentity}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.StaffAudience
  alias Chimwemwe.Platform.{DatabaseAdmission, PersistenceRuntime, TrustedActor}

  @tag timeout: 180_000
  test "three actual attendance comparisons retain all limits" do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
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
    end)

    results =
      for run <- 1..3 do
        {:ok, seeded} = Fixture.seed!(persistence)

        try do
          f = attendance_fixture!(connect!(seeded))
          for _ <- 1..24, do: staff!(f)

          for _ <- 1..10 do
            assert {:ok, _} =
                     Attendance.prepare(f.persistence, f.attendance_request, f.reader_class.id)

            assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
          end

          # Warm the correction path on the reader's class. The six writer classes
          # each receive exactly five baseline + five mixed corrections (cap ten).
          assert {:ok, _} = correction(f, f.reader_class)
          baseline = workload(f, false)
          mixed = workload(f, true)
          read_change = percent(mixed.read.p95, baseline.read.p95)
          write_change = percent(mixed.write.p95, baseline.write.p95)

          operations_succeeded =
            Enum.all?(Map.values(baseline) ++ Map.values(mixed), &(&1.failures == 0))

          result = %{
            run: run,
            workload: "actual_attendance",
            baseline: baseline,
            mixed: mixed,
            classroom_read_p95_change_percent: read_change,
            classroom_write_p95_change_percent: write_change,
            impact_comparison_valid: operations_succeeded,
            accepted:
              operations_succeeded and read_change <= 20 and write_change <= 20 and
                mixed.read.p95 <= 300 and
                mixed.read.p99 <= 750 and mixed.write.p95 <= 750 and mixed.write.p99 <= 2000
          }

          IO.puts("PEOPLE_FENCE_ATTENDANCE " <> Jason.encode!(result))
          assert mixed.read.count == 120 and mixed.write.count == 30 and mixed.source.count == 5
          assert mixed.source.p99 < 2000
          result
        after
          for agent <- [seeded.source, seeded.account_source],
              do: if(Process.alive?(agent), do: Agent.stop(agent))

          cleanup!()
        end
      end

    assert Enum.all?(results, & &1.accepted),
           "Actual attendance impact exceeds retained 20% target; qualification remains blocked"
  end

  defp attendance_fixture!(f) do
    context = Fixture.context_a()
    {:ok, part} = People.current_participation(f.runtime, context, f.staff.id)

    {:ok, _} =
      associate!(
        f,
        %{person: %{id: part.person_id}, part: f.staff},
        f.membership_a,
        TrustedActor.actor_id(context.actor)
      )

    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: f.connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: "synthetic-attendance-educator",
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    {:ok, session} =
      SessionFoundation.create(
        f.persistence,
        context,
        Map.merge(Fixture.keys(), %{
          external_identity_link_id: f.link_id,
          membership_id: f.membership_a,
          proof: proof
        })
      )

    {:ok, view} = SessionFoundation.validate(f.persistence, context, %{token: session.token})

    f =
      Map.put(f, :attendance_request, %{
        f.request
        | context: context,
          session: view,
          session_token: session.token
      })

    classes =
      for index <- 1..7 do
        student =
          if index == 1,
            do: f.student,
            else: Fixture.participation!(f, Fixture.person!(f), :student)

        enrolment = Fixture.enrolment!(%{f | student: student})
        class = Fixture.class!(f)

        assert {:ok, _} =
                 Foundation.assign_teacher(
                   f.persistence,
                   context,
                   Fixture.teacher_input(f, class)
                 )

        assert {:ok, _} =
                 Foundation.place_student(
                   f.persistence,
                   context,
                   Fixture.placement_input(enrolment, class)
                 )

        assert {:ok, view} = Attendance.prepare(f.persistence, f.attendance_request, class.id)

        input =
          Map.merge(Fixture.keys(), %{
            class_id: view.class_id,
            local_date: view.local_date,
            calendar_revision: view.calendar_revision,
            roster_basis: view.roster_basis,
            marks: Enum.map(view.students, &%{person_id: &1.id, mark: "present"})
          })

        assert {:ok, _} = Attendance.submit(f.persistence, f.attendance_request, input)
        class
      end

    [reader | writers] = classes
    Map.merge(f, %{reader_class: reader, writer_classes: writers})
  end

  defp correction(f, class) do
    with {:ok, view} <- Attendance.prepare(f.persistence, f.attendance_request, class.id) do
      input =
        Map.merge(Fixture.keys(), %{
          class_id: class.id,
          submission_id: view.submission_id,
          expected_revision_id: view.revision_id,
          reason_code: "marking_error",
          marks:
            Enum.map(view.students, fn student ->
              %{
                person_id: student.id,
                mark: if(student.mark == "present", do: "late", else: "present")
              }
            end)
        })

      Attendance.correct(f.persistence, f.attendance_request, input)
    end
  end

  defp workload(f, source?) do
    parent = self()
    {:ok, admission} = PersistenceRuntime.child_pid(f.persistence, DatabaseAdmission)
    before = DatabaseAdmission.statistics(admission)

    readers =
      for _ <- 1..4,
          do:
            worker(parent, :read, fn ->
              for _ <- 1..30,
                  do:
                    sample(fn ->
                      Attendance.prepare(f.persistence, f.attendance_request, f.reader_class.id)
                    end)
            end)

    writer =
      worker(parent, :write, fn ->
        for index <- 0..29,
            do: sample(fn -> correction(f, Enum.at(f.writer_classes, rem(index, 6))) end)
      end)

    sources =
      if source?,
        do: [
          worker(parent, :source, fn ->
            for _ <- 1..5,
                do:
                  sample(fn ->
                    StaffAudience.capture(f.audience, f.request, draft(), fn proof ->
                      assert map_size(proof.subjects) == 25
                      {:ok, :captured}
                    end)
                  end)
          end)
        ],
        else: []

    tasks = readers ++ [writer] ++ sources
    for _ <- tasks, do: assert_receive({:ready, _}, 2_000)
    Enum.each(tasks, &send(&1.pid, :start))

    result =
      tasks
      |> Enum.map(&Task.await(&1, 60_000))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {kind, groups} -> {kind, summarize(List.flatten(groups))} end)
      |> Map.put_new(:source, summarize([]))

    after_stats = DatabaseAdmission.statistics(admission)

    IO.puts(
      "PEOPLE_FENCE_ATTENDANCE_ADMISSION " <>
        Jason.encode!(%{
          mixed: source?,
          admitted: after_stats.admitted - before.admitted,
          tenant_rejections: after_stats.tenant_rejections - before.tenant_rejections,
          placement_rejections: after_stats.placement_rejections - before.placement_rejections
        })
    )

    result
  end

  defp worker(parent, kind, operation) do
    Task.async(fn ->
      send(parent, {:ready, self()})
      receive do: (:start -> {kind, operation.()})
    end)
  end

  defp sample(operation) do
    {elapsed, result} = :timer.tc(operation)

    code =
      case result do
        {:ok, _} -> :ok
        {:error, %{code: code}} -> code
        _ -> :unexpected_result
      end

    %{milliseconds: elapsed / 1000, code: code}
  end

  defp summarize([]), do: %{count: 0, failures: 0, error_counts: %{}, p95: 0.0, p99: 0.0}

  defp summarize(samples) do
    sorted = samples |> Enum.map(& &1.milliseconds) |> Enum.sort()
    failures = Enum.reject(samples, &(&1.code == :ok))

    %{
      count: length(samples),
      failures: length(failures),
      error_counts: Enum.frequencies_by(failures, & &1.code),
      p95: Enum.at(sorted, ceil(length(sorted) * 0.95) - 1),
      p99: Enum.at(sorted, ceil(length(sorted) * 0.99) - 1)
    }
  end

  defp percent(mixed, baseline), do: Float.round(100 * (mixed / baseline - 1), 2)
end
