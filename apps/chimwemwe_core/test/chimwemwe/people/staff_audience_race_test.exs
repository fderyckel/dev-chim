defmodule Chimwemwe.People.StaffAudienceRaceTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Chimwemwe.People.StaffAudienceFixture
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{Foundation, LocalCredentials, SessionFoundation}
  alias Chimwemwe.People.{Error, InternalWriter, StaffAudience}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.StaffAudience.Clock
  alias Chimwemwe.Platform.{ModuleLifecycle, Persistence, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    {:ok, f} = Fixture.seed!(persistence)
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

      for agent <- [f.source, f.account_source],
          do: if(Process.alive?(agent), do: Agent.stop(agent))

      cleanup!()
    end)

    {:ok, connect!(f)}
  end

  for operation <- [
        :staff_insert,
        :staff_end,
        :association_revoke,
        :account_provision,
        :account_suspend,
        :account_rebind,
        :assignment_insert,
        :grant_delete,
        :role_inclusion,
        :role_rename,
        :session_logout,
        :connection_suspend,
        :module_deactivate
      ] do
    @operation operation
    test "complete source fence orders #{@operation} through callback and commit", f do
      recipient =
        staff!(f,
          account: if(@operation == :account_provision, do: :absent, else: :active),
          dates: %{effective_from: Date.add(Date.utc_today(), -1)}
        )

      candidate = prepare_operation(f, recipient, @operation)
      parent = self()

      holder =
        Task.async(fn ->
          StaffAudience.capture(f.audience, f.request, draft(), fn _proof ->
            [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
            send(parent, {:held, self(), backend})
            receive do: (:release -> {:ok, :captured})
          end)
        end)

      assert_receive {:held, holder_pid, holder_backend}, 1_000
      assert holder_pid == holder.pid

      writer =
        Task.async(fn ->
          Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
            Repo.transaction(fn ->
              [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
              send(parent, {:writing, self(), backend})

              abort_failure(candidate.())
            end)
          end)
        end)

      assert_receive {:writing, writer_pid, writer_backend}, 1_000
      assert writer_pid == writer.pid

      observed =
        blocked?(
          f,
          writer_backend,
          holder_backend,
          System.monotonic_time(:millisecond) + 1_000
        )

      assert observed

      send(holder.pid, :release)
      assert {:ok, :captured} = Task.await(holder)
      assert {:ok, result} = Task.await(writer)
      assert successful?(result)
    end
  end

  test "writer before preparation changes the source; later writer invalidates recheck", f do
    old = capture!(f)
    staff!(f, linked: false)
    new = capture!(f)
    refute old.basis_digest == new.basis_digest

    assert {:error, %Error{code: :stale}} =
             StaffAudience.recheck(f.audience, f.request, draft(), old)
  end

  test "callback failure rolls back earlier source-owner writes and releases locks", f do
    before = sql!(f, "SELECT count(*) FROM platform_capabilities").rows

    assert {:error, %Error{code: :stale}} =
             StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
               Fixture.insert_capability(
                 UUID.generate(),
                 tenant(f),
                 "synthetic.rollback.case_#{System.unique_integer([:positive])}"
               )

               {:error, %Error{code: :stale}}
             end)

    assert sql!(f, "SELECT count(*) FROM platform_capabilities").rows == before
    assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
  end

  test "two-second callback deadline aborts the entire owner transaction", f do
    before = sql!(f, "SELECT count(*) FROM platform_capabilities").rows

    capture_log(fn ->
      assert {:error, %Error{code: :retryable_dependency}} =
               StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
                 Fixture.insert_capability(
                   UUID.generate(),
                   tenant(f),
                   "synthetic.timeout.case_#{System.unique_integer([:positive])}"
                 )

                 Repo.query!("SELECT pg_sleep(2.1)")
                 {:ok, :must_not_commit}
               end)
    end)

    assert sql!(f, "SELECT count(*) FROM platform_capabilities").rows == before
  end

  test "callback deadline rolls back even when the server timer does not interrupt", f do
    before = sql!(f, "SELECT count(*) FROM platform_capabilities").rows

    assert {:error, %Error{code: :retryable_dependency}} =
             StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
               # Fault injection exercises the independent pre-commit guard.
               Repo.query!("SET LOCAL transaction_timeout = '0'")
               write_timeout_marker!(f)
               Repo.query!("SELECT pg_sleep(2.1)")
               {:ok, :must_not_commit}
             end)

    assert sql!(f, "SELECT count(*) FROM platform_capabilities").rows == before
    assert {:ok, _} = StaffAudience.capture(f.audience, f.request, draft())
  end

  test "independent deadline preserves a shorter existing transaction budget", f do
    before = sql!(f, "SELECT count(*) FROM platform_capabilities").rows

    assert {:error, %Error{code: :retryable_dependency}} =
             InternalWriter.run(f.persistence, f.request.context, fn _, _ ->
               Repo.query!("SET LOCAL transaction_timeout = '100ms'")
               budget = Clock.start()
               Repo.query!("SET LOCAL transaction_timeout = '0'")
               write_timeout_marker!(f)
               Repo.query!("SELECT pg_sleep(0.15)")
               Clock.within_budget(budget)
               {:ok, :must_not_commit}
             end)

    assert sql!(f, "SELECT count(*) FROM platform_capabilities").rows == before
  end

  test "independent deadline includes transaction time before source preparation", f do
    before = sql!(f, "SELECT count(*) FROM platform_capabilities").rows

    assert {:error, %Error{code: :retryable_dependency}} =
             InternalWriter.run(f.persistence, f.request.context, fn _, _ ->
               Repo.query!("SELECT pg_sleep(1.2)")
               budget = Clock.start()
               Repo.query!("SET LOCAL transaction_timeout = '0'")
               write_timeout_marker!(f)
               Repo.query!("SELECT pg_sleep(0.9)")
               Clock.within_budget(budget)
               {:ok, :must_not_commit}
             end)

    assert sql!(f, "SELECT count(*) FROM platform_capabilities").rows == before
  end

  test "acting-session short deadline rolls back instead of accepting stale authority", f do
    sql!(
      f,
      "UPDATE identity_application_sessions SET idle_expires_at = (clock_timestamp() AT TIME ZONE 'UTC') + interval '180 milliseconds' WHERE id = $1",
      [UUID.dump!(f.request.session.id)]
    )

    capture_log(fn ->
      assert {:error, %Error{code: code}} =
               StaffAudience.capture(f.audience, f.request, draft(), fn _ ->
                 Repo.query!("SELECT pg_sleep(0.3)")
                 {:ok, :must_not_commit}
               end)

      assert code in [:retryable_dependency, :stale]
    end)
  end

  test "writer-time dates, DST and local-midnight preparation boundary", f do
    {:ok, :checked} =
      Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
        spring = Clock.basis_at("Europe/Brussels", ~N[2026-03-28 23:00:00])
        autumn = Clock.basis_at("Europe/Brussels", ~N[2026-10-24 22:00:00])
        midnight = Clock.basis_at("Europe/Brussels", ~N[2026-10-24 21:59:59])
        assert spring.date == ~D[2026-03-29]
        assert NaiveDateTime.diff(spring.midnight, spring.now) == 23 * 3600
        assert autumn.date == ~D[2026-10-25]
        assert NaiveDateTime.diff(autumn.midnight, autumn.now) == 25 * 3600
        assert midnight.expires_at == ~N[2026-10-24 22:00:00.000000]
        assert spring.expires_at == ~N[2026-03-28 23:05:00.000000]
        :checked
      end)
  end

  defp write_timeout_marker!(f) do
    Fixture.insert_capability(
      UUID.generate(),
      tenant(f),
      "synthetic.timeout.guard_#{System.unique_integer([:positive])}"
    )
  end

  defp prepare_operation(f, _recipient, :staff_insert) do
    person = Fixture.person!(f)

    fn ->
      People.record_staff_affiliation(
        f.runtime,
        Fixture.context_a(),
        Fixture.participation_input(f, person)
      )
    end
  end

  defp prepare_operation(f, r, :staff_end),
    do: fn ->
      People.end_participation(
        f.runtime,
        Fixture.context_a(),
        Map.merge(Fixture.keys(), %{
          participation_id: r.part.id,
          expected_version: 1,
          effective_until: Date.utc_today()
        })
      )
    end

  defp prepare_operation(f, r, :association_revoke),
    do: fn ->
      People.revoke_staff_account_association(
        f.runtime,
        Fixture.context_a(),
        Map.merge(Fixture.keys(), %{association_id: r.association.id, expected_version: 1})
      )
    end

  defp prepare_operation(_f, r, :account_provision),
    do: fn ->
      {:ok, %{account: account}} =
        LocalCredentials.provision("racing-#{r.actor}@example.test", r.actor)

      {:ok, account.id}
    end

  defp prepare_operation(_f, r, :account_suspend),
    do: fn ->
      case LocalCredentials.suspend(r.account) do
        {:ok, _} -> {:ok, :suspended}
        error -> error
      end
    end

  defp prepare_operation(_f, r, :account_rebind),
    do: fn ->
      Repo.query!("UPDATE identity_accounts SET actor_id = $2 WHERE id = $1", [
        UUID.dump!(r.account),
        UUID.dump!(UUID.generate())
      ])
    end

  defp prepare_operation(f, r, :assignment_insert) do
    role = UUID.generate()

    sql!(
      f,
      "INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at) VALUES ($1, $2, 'Synthetic nested role', 1, NOW(), NOW())",
      [UUID.dump!(role), UUID.dump!(tenant(f))]
    )

    fn -> Fixture.insert_assignment(tenant(f), r.member, role) end
  end

  defp prepare_operation(f, _r, :grant_delete),
    do: fn ->
      Repo.query!(
        "DELETE FROM platform_role_capability_grants WHERE tenant_id = $1 AND role_id = $2",
        [UUID.dump!(tenant(f)), UUID.dump!(f.role_a)]
      )
    end

  defp prepare_operation(f, _r, :role_inclusion) do
    child = UUID.generate()

    sql!(
      f,
      "INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at) VALUES ($1, $2, 'Synthetic nested role', 1, NOW(), NOW())",
      [UUID.dump!(child), UUID.dump!(tenant(f))]
    )

    fn ->
      Repo.query!(
        "INSERT INTO platform_role_inclusions (id, tenant_id, role_id, included_role_id, inserted_at) VALUES ($1,$2,$3,$4,NOW())",
        Enum.map([UUID.generate(), tenant(f), f.role_a, child], &UUID.dump!/1)
      )
    end
  end

  defp prepare_operation(f, _r, :role_rename),
    do: fn ->
      Repo.query!(
        "UPDATE platform_roles SET name = 'Renamed synthetic role', lock_version = lock_version + 1 WHERE id = $1",
        [UUID.dump!(f.role_a)]
      )
    end

  defp prepare_operation(f, _r, :session_logout),
    do: fn ->
      SessionFoundation.logout(
        f.persistence,
        f.request.context,
        Map.merge(Fixture.keys(), %{token: f.request.session_token})
      )
    end

  defp prepare_operation(f, _r, :connection_suspend),
    do: fn ->
      Foundation.suspend_connection(
        f.persistence,
        Fixture.context_a(),
        Map.merge(Fixture.keys(), %{connection_id: f.connection_id, expected_version: 3})
      )
    end

  defp prepare_operation(f, _r, :module_deactivate) do
    cap = UUID.generate()

    sql!(
      f,
      "INSERT INTO platform_capabilities (id,tenant_id,key,inserted_at,updated_at) VALUES ($1,$2,'platform.modules.deactivate',NOW(),NOW())",
      [UUID.dump!(cap), UUID.dump!(tenant(f))]
    )

    sql!(
      f,
      "INSERT INTO platform_role_capability_grants (id,tenant_id,role_id,capability_id,inserted_at) VALUES ($1,$2,$3,$4,NOW())",
      Enum.map([UUID.generate(), tenant(f), f.role_a, cap], &UUID.dump!/1)
    )

    fn ->
      ModuleLifecycle.deactivate(
        f.persistence,
        People.release_manifest(),
        Fixture.context_a(),
        Map.merge(Fixture.keys(), %{module_key: "people.core", expected_version: 1})
      )
    end
  end

  defp blocked?(f, writer, holder, deadline) do
    [[blockers]] = sql!(f, "SELECT pg_blocking_pids($1)", [writer]).rows

    cond do
      holder in blockers ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(5)
        blocked?(f, writer, holder, deadline)
    end
  end

  defp successful?({:ok, _}), do: true
  defp successful?(%Postgrex.Result{}), do: true
  defp successful?(_), do: false
  defp abort_failure({:error, reason}), do: Repo.rollback(reason)
  defp abort_failure(result), do: result
  defp tenant(f), do: TrustedActor.tenant_id(f.request.context.actor)
end
