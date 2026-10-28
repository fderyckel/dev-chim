# Aggregate-only diagnosis, deliberately outside ordinary functional tests.
ExUnit.start()

defmodule Chimwemwe.People.SourceLockDiagnosis do
  use ExUnit.Case, async: false
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.{Attendance, Fixture, Foundation}
  alias Chimwemwe.Identity.{SessionFoundation, VerifiedExternalIdentity}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.StaffAudience
  alias Chimwemwe.Platform.{Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo

  test "attribute source-stage queries and controlled classroom blockers" do
    phase = System.fetch_env!("PEOPLE_FENCE_PHASE")
    assert phase in ["before", "after"]
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, seeded} = Fixture.seed!(persistence)

    Application.put_env(
      :chimwemwe_core,
      :identity_session_hmac_secret,
      :crypto.strong_rand_bytes(48)
    )

    f = connect!(seeded)

    on_exit(fn ->
      for agent <- [seeded.source, seeded.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      cleanup!()
    end)

    # Restore only this fixture's explicitly verified author association, so the
    # real attendance journey is authorized. Never infer authority from an account.
    {:ok, part} = People.current_participation(f.runtime, Fixture.context_a(), f.staff.id)

    {:ok, _} =
      associate!(
        f,
        %{person: %{id: part.person_id}, part: f.staff},
        f.membership_a,
        TrustedActor.actor_id(Fixture.context_a().actor)
      )

    request = separate_request!(f)
    {class, _, _, _} = Fixture.classroom!(f)
    for _ <- 1..24, do: staff!(f)

    candidate = Fixture.class!(f)
    assignment_context = Fixture.context_a()

    assignment = fn ->
      Foundation.assign_teacher(
        f.persistence,
        assignment_context,
        Fixture.teacher_input(f, candidate)
      )
    end

    attendance = fn -> Attendance.prepare(f.persistence, request, class.id) end
    assert {:ok, _} = attendance.()

    IO.puts(
      "PEOPLE_SOURCE_BLOCKING " <>
        Jason.encode!(%{
          phase: phase,
          foundation: held_probe(f, assignment_context, assignment, phase == "before"),
          attendance: held_probe(f, request.context, attendance, phase == "before")
        })
    )

    key = {__MODULE__, make_ref()}
    :ok = :telemetry.attach(key, [:chimwemwe, :repo, :query], &__MODULE__.query_event/4, nil)
    Process.put(:people_source_diagnostic_owner, self())

    try do
      samples =
        for _ <- 1..10 do
          {elapsed, {:ok, :captured}} =
            :timer.tc(fn ->
              StaffAudience.capture(f.audience, f.request, draft(), fn proof ->
                assert map_size(proof.subjects) == 25
                {:ok, :captured}
              end)
            end)

          elapsed / 1000
        end

      Process.delete(:people_source_diagnostic_owner)

      IO.puts(
        "PEOPLE_SOURCE_STAGES " <>
          Jason.encode!(%{
            phase: phase,
            captures: length(samples),
            mean_ms: Enum.sum(samples) / length(samples),
            query_stages: drain(%{})
          })
      )
    after
      Process.delete(:people_source_diagnostic_owner)
      :telemetry.detach(key)
    end
  end

  def query_event(_event, measurements, metadata, _config) do
    if owner = Process.get(:people_source_diagnostic_owner) do
      stage =
        cond do
          String.contains?(metadata.query, "people_") -> :people
          String.contains?(metadata.query, "platform_") -> :authority_and_modules
          String.contains?(metadata.query, "institutional_units") -> :institution
          String.contains?(metadata.query, "identity_accounts") -> :accounts
          String.contains?(metadata.query, "identity_") -> :session_and_origin
          true -> :clock_and_other
        end

      time = System.convert_time_unit(measurements.total_time, :native, :microsecond) / 1000
      send(owner, {:stage, stage, time})
    end
  end

  defp drain(acc) do
    receive do
      {:stage, stage, time} ->
        drain(
          Map.update(acc, stage, %{queries: 1, total_ms: time}, fn old ->
            %{queries: old.queries + 1, total_ms: old.total_ms + time}
          end)
        )
    after
      0 -> acc
    end
  end

  defp held_probe(f, context, operation, must_block) do
    parent = self()

    source =
      Task.async(fn ->
        StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(parent, {:source_held, backend})
          receive do: (:release -> {:ok, :captured})
        end)
      end)

    assert_receive {:source_held, source_backend}, 1_000

    writer =
      Task.async(fn ->
        Persistence.with_writer(f.persistence, context, fn ->
          Repo.transaction(fn ->
            [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
            send(parent, {:writer_started, backend})
            operation.()
          end)
        end)
      end)

    assert_receive {:writer_started, writer_backend}, 1_000

    category =
      if must_block do
        blocked_category(
          f,
          writer_backend,
          source_backend,
          System.monotonic_time(:millisecond) + 700
        )
      else
        assert {:ok, {:ok, {:ok, _}}} = Task.await(writer, 1_000)
        :completed_while_source_held
      end

    send(source.pid, :release)
    assert {:ok, :captured} = Task.await(source)
    if must_block, do: assert(match?({:ok, {:ok, {:ok, _}}}, Task.await(writer)))
    category
  end

  defp blocked_category(f, writer, source, deadline) do
    %{rows: [[blocked, category]]} =
      sql!(
        f,
        """
        SELECT $2 = ANY(pg_blocking_pids($1)), CASE
          WHEN query LIKE '%people_participations%' THEN 'people_participation'
          WHEN query LIKE '%platform_tenant_memberships%' THEN 'independent_membership'
          WHEN query LIKE '%institutional_units%' THEN 'institution'
          ELSE 'other' END
        FROM pg_stat_activity WHERE pid = $1
        """,
        [writer, source]
      )

    cond do
      blocked ->
        category

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("expected source blocker not observed")

      true ->
        Process.sleep(2)
        blocked_category(f, writer, source, deadline)
    end
  end

  defp separate_request!(f) do
    {:ok, proof} =
      VerifiedExternalIdentity.establish(
        connection_id: f.connection_id,
        protocol: :oidc,
        issuer: "https://identity.example.test/issuer",
        subject: "synthetic-attendance-educator",
        assurance: "mfa",
        authenticated_at: DateTime.utc_now()
      )

    context = Fixture.context_a()

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
    %{f.request | context: context, session: view, session_token: session.token}
  end
end
