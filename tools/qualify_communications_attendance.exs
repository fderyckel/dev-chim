# One complete fresh database pair per invocation. All attempts retained in JSON output.
ExUnit.start()

defmodule Chimwemwe.Communications.AttendanceQualificationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.Classroom.{Attendance, Fixture, Foundation}
  alias Chimwemwe.Communications.{LocalRequestGate, Publication}
  alias Chimwemwe.Communications.Fixture, as: Comm
  alias Chimwemwe.Identity.{SessionFoundation, VerifiedExternalIdentity}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.StaffAudienceFixture, as: Audience
  alias Chimwemwe.Platform.{DatabaseAdmission, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo

  @tag timeout: 180_000
  test "complete communications plus actual attendance retain every limit" do
    assert String.starts_with?(
             System.fetch_env!("CHIMWEMWE_TEST_DATABASE"),
             "chimwemwe_comm1_mixed_"
           )

    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    assert Mix.env() == :test
    assert String.starts_with?(System.fetch_env!("PGHOST"), "/")

    assert {:ok, %{rows: [[0]]}} =
             Fixture.query(%{persistence: persistence}, """
             SELECT (SELECT count(*) FROM platform_tenant_memberships) +
               (SELECT count(*) FROM platform_authority_audit_events) +
               (SELECT count(*) FROM people_persons) + (SELECT count(*) FROM identity_accounts)
             """)

    {:ok, seeded} = Fixture.seed!(persistence)
    f = attendance_fixture!(Comm.connect!(seeded))
    Audience.account!(f, TrustedActor.actor_id(f.request.context.actor), :active)

    others =
      for _ <- 1..23 do
        staff = Audience.staff!(f)
        Comm.request!(f, staff.actor, staff.member)
      end

    recipients = [f.request, f.recipient_request | others]
    assert length(recipients) == 25
    {published, _} = Comm.publish!(f)
    to_publish = Comm.create!(f)
    {publication, _} = Comm.prepare!(f, to_publish)
    {pending_publication, _} = Comm.submit!(f, to_publish, publication)
    {to_correct, _} = Comm.publish!(f)
    {correction, _} = Comm.prepare!(f, to_correct, "correct")
    {pending_correction, _} = Comm.submit!(f, to_correct, correction)

    approvals =
      for {notice, prepared} <- [
            {pending_publication, publication},
            {pending_correction, correction}
          ],
          do:
            Map.merge(Fixture.keys(), %{
              notice_id: notice.notice_id,
              expected_version: notice.version,
              preparation_id: prepared.preparation_id
            })

    f = Map.merge(f, %{recipients: recipients, published: published, approvals: approvals})

    for _ <- 1..10 do
      assert {:ok, _} = Attendance.prepare(f.persistence, f.attendance_request, f.reader_class.id)

      assert {:ok, _} =
               Publication.recipient_status(
                 f.communications,
                 f.recipient_request,
                 published.notice_id
               )
    end

    assert {:ok, _} = correction(f, f.reader_class)
    # Declared settling is outside measurement; no retries or discarded pairs.
    {:ok, repository} = PersistenceRuntime.child_pid(persistence, {:repository, :pooled})
    Repo.put_dynamic_repo(repository)
    Repo.query!("CHECKPOINT")
    Process.sleep(500)
    checkpoint_before = checkpoint()
    baseline = workload(f, false)
    mixed = workload(f, true)
    checkpoint_after = checkpoint()
    # Preserve every measured attempt even if a later convergence assertion fails.
    IO.puts(
      "COMM1_ATTENDANCE_RAW " <>
        Jason.encode!(%{run: System.fetch_env!("COMM1_RUN"), baseline: baseline, mixed: mixed})
    )

    read_change = percent(mixed.groups.read.p95, baseline.groups.read.p95)
    write_change = percent(mixed.groups.write.p95, baseline.groups.write.p95)

    operations_succeeded =
      Enum.all?(Map.values(baseline.groups) ++ Map.values(mixed.groups), &(&1.failures == 0))

    assert {:ok, metrics} =
             Publication.metrics(
               f.communications,
               f.approver,
               published.notice_id,
               published.revision_id
             )

    assert metrics.receipt_confirmed == 25

    assert {:ok, %{number: 1}} =
             Publication.review_operation(f.communications, f.approver, to_publish.notice_id)

    assert {:ok, %{number: 2}} =
             Publication.review_operation(f.communications, f.approver, to_correct.notice_id)

    accepted =
      operations_succeeded && read_change <= 20 && write_change <= 20 &&
        mixed.groups.read.p95 <= 300 && mixed.groups.read.p99 <= 750 &&
        mixed.groups.write.p95 <= 750 && mixed.groups.write.p99 <= 2000 &&
        mixed.groups.comm_read.p95 <= 300 && mixed.groups.comm_read.p99 <= 750 &&
        mixed.groups.receipt.p95 <= 750 && mixed.groups.receipt.p99 <= 2000 &&
        mixed.groups.approval.p95 <= 750 && mixed.groups.approval.p99 <= 2000 &&
        mixed.admission.tenant_rejections == 0 && mixed.admission.placement_rejections == 0 &&
        mixed.admission.admitted == 357 && baseline.admission.admitted == 180 &&
        mixed.gate.overflow == 0 && mixed.gate.expired == 0 &&
        checkpoint_before == checkpoint_after

    result = %{
      run: System.fetch_env!("COMM1_RUN"),
      database: System.fetch_env!("CHIMWEMWE_TEST_DATABASE"),
      baseline: baseline,
      mixed: mixed,
      classroom_read_p95_change_percent: read_change,
      classroom_write_p95_change_percent: write_change,
      checkpoint_before: checkpoint_before,
      checkpoint_after: checkpoint_after,
      receipts: metrics.receipt_confirmed,
      accepted: accepted,
      limits: %{
        pool: 6,
        tenant: 6,
        placement: 12,
        active_communications: 1,
        waiting_communications: 32,
        queue_wait_ms: 2000
      }
    }

    IO.puts("COMM1_ATTENDANCE " <> Jason.encode!(result))

    assert accepted,
           "COMM-1 mixed attendance qualification failed; retain this attempt and do not waive limits"
  end

  defp workload(f, mixed?) do
    parent = self()
    {:ok, admission} = PersistenceRuntime.child_pid(f.persistence, DatabaseAdmission)
    before_stats = DatabaseAdmission.statistics(admission)
    before_gate = LocalRequestGate.statistics(f.communications.request_gate)

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
        for i <- 0..29, do: sample(fn -> correction(f, Enum.at(f.writer_classes, rem(i, 6))) end)
      end)

    communications =
      if mixed? do
        readers =
          for _ <- 1..5,
              do:
                worker(parent, :comm_read, fn ->
                  for _ <- 1..30,
                      do:
                        sample(fn ->
                          Publication.recipient_status(
                            f.communications,
                            f.recipient_request,
                            f.published.notice_id
                          )
                        end)
                end)

        receipts =
          for request <- f.recipients,
              do:
                worker(parent, :receipt, fn ->
                  [
                    sample(fn ->
                      Publication.confirm_receipt(
                        f.communications,
                        request,
                        Map.merge(Fixture.keys(), %{
                          notice_id: f.published.notice_id,
                          revision_id: f.published.revision_id
                        })
                      )
                    end)
                  ]
                end)

        approvals =
          for input <- f.approvals,
              do:
                worker(parent, :approval, fn ->
                  [
                    sample(fn ->
                      Publication.approve_operation(f.communications, f.approver, input)
                    end)
                  ]
                end)

        readers ++ receipts ++ approvals
      else
        []
      end

    tasks = readers ++ [writer] ++ communications
    for _ <- tasks, do: assert_receive({:ready, _}, 2_000)
    Enum.each(tasks, &send(&1.pid, :start))

    samples =
      tasks
      |> Enum.map(&Task.await(&1, 60_000))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {kind, groups} -> {kind, List.flatten(groups)} end)

    after_stats = DatabaseAdmission.statistics(admission)
    after_gate = LocalRequestGate.statistics(f.communications.request_gate)

    deltas =
      Map.new(
        [:admitted, :tenant_rejections, :placement_rejections],
        &{&1, Map.fetch!(after_stats, &1) - Map.fetch!(before_stats, &1)}
      )

    gate =
      Map.merge(
        after_gate,
        Map.new(
          [:admitted, :overflow, :expired, :cancelled],
          &{&1, Map.fetch!(after_gate, &1) - Map.fetch!(before_gate, &1)}
        )
      )

    %{
      groups: Map.new(samples, fn {kind, values} -> {kind, summarize(values)} end),
      samples: samples,
      admission: deltas,
      gate: gate
    }
  end

  defp checkpoint do
    Repo.query!("SELECT num_timed,num_requested FROM pg_stat_checkpointer").rows
  end

  defp attendance_fixture!(f) do
    context = Fixture.context_a()
    {:ok, part} = People.current_participation(f.runtime, context, f.staff.id)

    {:ok, _} =
      Audience.associate!(
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
