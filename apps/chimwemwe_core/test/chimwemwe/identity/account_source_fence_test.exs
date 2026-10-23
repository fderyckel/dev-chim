defmodule Chimwemwe.Identity.AccountSourceFenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias AshAuthentication.BcryptProvider
  alias Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Identity.{Account, AccountSourceFence, LocalCredentials}
  alias Chimwemwe.People.{Error, InternalWriter}
  alias Chimwemwe.Platform.{Persistence, PersistenceError, PersistenceRuntime, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  setup_all do
    persistence = start_supervised!({PersistenceRuntime, Fixture.runtime_options()})
    Fixture.seed!(persistence)
  end

  for operation <- [:provision, :activate, :reissue, :suspend, :bootstrap] do
    @operation operation
    test "source fence orders named #{@operation} and preserves exact account identity", f do
      actor = member!(f)
      before = prepare_account(f, actor, @operation)
      {holder, backend} = hold(f, [actor])
      writer = writer(f, fn -> transition(actor, before, @operation) end)
      assert_blocked(f, writer, backend)
      assert snapshot(f, actor) == before
      release(holder)
      assert {:ok, {:ok, after_account}} = Task.await(writer)
      assert after_account.actor_id == actor
      assert_identity(before, after_account)
      assert snapshot(f, actor) == after_account
    end
  end

  test "writer committed before source fence is visible and later provisioning remains pending",
       f do
    actor = member!(f)
    {:ok, {:ok, before}} = run(f, fn -> provision(actor) end)
    {holder, _backend} = hold(f, [actor])
    assert snapshot(f, actor) == before
    assert before.status == "pending_first_login"
    release(holder)
  end

  test "bootstrap actor change fences both old and new actor identities", f do
    for side <- [:old, :new] do
      old = member!(f)
      new = member!(f)
      {:ok, {:ok, account}} = run(f, fn -> provision(old) end)
      {holder, backend} = hold(f, [if(side == :old, do: old, else: new)])
      writer = writer(f, fn -> bootstrap_rebind(account.id, new) end)
      assert_blocked(f, writer, backend)
      assert snapshot(f, old).id == account.id
      assert snapshot(f, new) == nil
      release(holder)
      assert {:ok, {:ok, changed}} = Task.await(writer)
      assert changed.id == account.id
      assert changed.actor_id == new
      assert snapshot(f, old) == nil
    end
  end

  for operation <- [:insert, :update, :delete] do
    @operation operation
    test "direct SQL #{@operation} cannot bypass the database source fence", f do
      actor = member!(f)
      before = prepare_account(f, actor, @operation)
      {holder, backend} = hold(f, [actor])
      writer = writer(f, fn -> sql_transition(actor, before, @operation) end)
      assert_blocked(f, writer, backend)
      assert snapshot(f, actor) == before
      release(holder)
      assert {:ok, :written} = Task.await(writer)
    end
  end

  test "unrelated actor in another tenant progresses while the first actor is held", f do
    actor = member!(f)
    other = member!(f, Fixture.context_b())
    {holder, _backend} = hold(f, [actor])
    writer = writer(f, fn -> provision(other) end, Fixture.context_b())
    assert {:ok, {:ok, account}} = Task.await(writer, 1_000)
    assert account.actor_id == other
    release(holder)
  end

  test "the same global actor in two tenant memberships uses the same fence", f do
    actor = member!(f)
    add_member!(f, actor, Fixture.context_b())
    {holder, backend} = hold(f, [actor])

    writer =
      writer(
        f,
        fn -> AccountSourceFence.lock_current_transaction(Fixture.context_b(), [actor]) end,
        Fixture.context_b()
      )

    assert_blocked(f, writer, backend)
    release(holder)
    assert {:ok, :ok} = Task.await(writer)
  end

  test "missing context, missing membership and foreign actors are denied without account reads",
       f do
    actor = member!(f)
    foreign = member!(f, Fixture.context_b())

    assert {:ok, {:error, :invalid_context}} =
             run(f, fn -> AccountSourceFence.lock_current_transaction(nil, [actor]) end)

    for denied <- [foreign, UUID.generate()] do
      assert {:ok, {:error, :forbidden}} =
               run(f, fn ->
                 AccountSourceFence.lock_current_transaction(Fixture.context_a(), [denied])
               end)
    end

    absent_caller = Fixture.context(UUID.generate(), tenant(Fixture.context_a()), UUID.generate())

    assert {:ok, {:error, :forbidden}} =
             run(f, fn -> AccountSourceFence.lock_current_transaction(absent_caller, [actor]) end)

    assert {:ok, {:error, :invalid_context}} =
             Persistence.with_writer(f.persistence, Fixture.context_a(), fn ->
               AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])
             end)
  end

  test "closed input and 0, 1, 25, 26 boundaries do not truncate actors", f do
    actors = Enum.map(1..25, fn _ -> member!(f) end)

    for allowed <- [[], Enum.take(actors, 1), Enum.reverse(actors), [hd(actors), hd(actors)]] do
      assert {:ok, :ok} =
               run(f, fn ->
                 AccountSourceFence.lock_current_transaction(Fixture.context_a(), allowed)
               end)
    end

    for denied <- [nil, %{}, "all", [nil], ["invalid"], actors ++ [UUID.generate()]] do
      assert {:ok, {:error, :invalid_input}} =
               run(f, fn ->
                 AccountSourceFence.lock_current_transaction(Fixture.context_a(), denied)
               end)
    end
  end

  test "stale placement fails before the fence operation", f do
    stale = put_in(Fixture.context_a().placement.routing_version, 8)

    assert {:error, %PersistenceError{code: :route_not_available}} =
             Persistence.with_writer(f.persistence, stale, fn ->
               flunk("stale placement reached the account fence")
             end)
  end

  test "source reads refuse stale-snapshot isolation without changing credential writer isolation",
       f do
    actor = member!(f)

    for isolation <- ["REPEATABLE READ", "SERIALIZABLE"] do
      assert {:ok, {:error, :retryable_dependency}} =
               run(f, fn ->
                 Repo.query!("SET TRANSACTION ISOLATION LEVEL #{isolation}")
                 AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])
               end)
    end
  end

  test "database guard refuses truncate and rejects malformed lock sets", f do
    for sql <- [
          "TRUNCATE identity_accounts",
          "SELECT identity_account_source_lock(ARRAY[NULL]::uuid[])",
          "SELECT identity_account_source_lock(NULL::uuid[])"
        ] do
      assert {:ok, {:error, %Postgrex.Error{postgres: %{code: :check_violation}}}} =
               run(f, fn -> Repo.query(sql) end)
    end
  end

  test "account timeout aborts the whole owner transaction and releases the source lock", f do
    blocker = member!(f)
    actor = member!(f)
    {:ok, {:ok, account}} = run(f, fn -> provision(actor) end)
    {holder, _backend} = hold(f, [blocker], :raw)

    capture_log(fn ->
      assert {:error, %Error{code: :retryable_dependency}} =
               InternalWriter.run(f.persistence, Fixture.context_a(), fn _, _ ->
                 Repo.query!(
                   "UPDATE identity_accounts SET status = 'suspended', temporary_password_expires_at = NULL WHERE id = $1",
                   [UUID.dump!(account.id)]
                 )

                 dependency(
                   AccountSourceFence.lock_current_transaction(Fixture.context_a(), [blocker])
                 )
               end)
    end)

    assert snapshot(f, actor) == account
    release(holder)

    assert {:ok, :ok} =
             run(f, fn ->
               AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor, blocker])
             end)
  end

  test "idle time and repeated calls cannot restart the two-second transaction budget", f do
    actor = member!(f)
    {:ok, {:ok, account}} = run(f, fn -> provision(actor) end)

    capture_log(fn ->
      assert {:error, %Error{code: :retryable_dependency}} =
               InternalWriter.run(f.persistence, Fixture.context_a(), fn _, _ ->
                 Process.sleep(700)
                 :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])
                 Process.sleep(700)
                 :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])

                 Repo.query!(
                   "UPDATE identity_accounts SET status = 'suspended', temporary_password_expires_at = NULL WHERE id = $1",
                   [UUID.dump!(account.id)]
                 )

                 Process.sleep(750)
                 {:ok, :must_not_commit}
               end)
    end)

    assert snapshot(f, actor) == account
  end

  test "a shorter preexisting timeout is preserved", f do
    actor = member!(f)

    assert {:ok, "100ms"} =
             run(f, fn ->
               Repo.query!("SET LOCAL transaction_timeout = '100ms'")
               :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), [actor])
               %{rows: [[timeout]]} = Repo.query!("SHOW transaction_timeout")
               timeout
             end)
  end

  test "injected reverse acquisition deadlock rolls back one whole owner transaction", f do
    actors = Enum.map(1..2, fn _ -> member!(f) end)
    Enum.each(actors, fn actor -> run(f, fn -> provision(actor) end) end)
    parent = self()

    tasks =
      Enum.map([actors, Enum.reverse(actors)], fn [first, second] ->
        Task.async(fn ->
          result =
            InternalWriter.run(f.persistence, Fixture.context_a(), fn _, _ ->
              :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), [first])

              Repo.query!(
                "UPDATE identity_accounts SET status = 'suspended', temporary_password_expires_at = NULL WHERE actor_id = $1",
                [UUID.dump!(first)]
              )

              send(parent, {:first_locked, self()})
              receive do: (:continue -> :ok)

              dependency(
                AccountSourceFence.lock_current_transaction(Fixture.context_a(), [second])
              )
            end)

          {first, result}
        end)
      end)

    assert_receive {:first_locked, _}, 1_000
    assert_receive {:first_locked, _}, 1_000
    Enum.each(tasks, &send(&1.pid, :continue))
    results = Enum.map(tasks, &Task.await(&1))
    assert Enum.count(results, fn {_, result} -> result == {:ok, :locked} end) == 1

    assert [{loser, {:error, %Error{code: :retryable_dependency}}}] =
             Enum.reject(results, fn {_, result} -> result == {:ok, :locked} end)

    assert snapshot(f, loser).status == "pending_first_login"
  end

  defp dependency(:ok), do: {:ok, :locked}
  defp dependency({:error, reason}), do: {:error, %Error{code: reason}}

  defp assert_identity(nil, _after_account), do: :ok
  defp assert_identity(before, after_account), do: assert(after_account.id == before.id)

  defp prepare_account(_f, _actor, operation) when operation in [:provision, :bootstrap, :insert],
    do: nil

  defp prepare_account(f, actor, operation) when operation in [:reissue, :suspend] do
    {:ok, {:ok, pending}} = run(f, fn -> provision(actor) end)
    {:ok, {:ok, active}} = run(f, fn -> transition(actor, pending, :activate) end)
    active
  end

  defp prepare_account(f, actor, _operation) do
    {:ok, {:ok, account}} = run(f, fn -> provision(actor) end)
    account
  end

  defp provision(actor) do
    case LocalCredentials.provision("source-#{actor}@example.test", actor) do
      {:ok, %{account: account}} -> {:ok, summary(account)}
      {:error, _error} -> {:error, :credential_operation_failed}
    end
  end

  defp transition(actor, _before, :provision), do: provision(actor)
  defp transition(actor, _before, :bootstrap), do: bootstrap(actor)

  defp transition(_actor, before, :activate) do
    password = Base.url_encode64(:crypto.strong_rand_bytes(24))

    LocalCredentials.complete_first_login(before.id, before.lock_version, password, password)
    |> summarize()
  end

  defp transition(_actor, before, :reissue) do
    case LocalCredentials.reissue(before.id) do
      {:ok, %{account: account}} -> {:ok, summary(account)}
      {:error, _error} -> {:error, :credential_operation_failed}
    end
  end

  defp transition(_actor, before, :suspend),
    do: LocalCredentials.suspend(before.id) |> summarize()

  defp bootstrap(actor) do
    {:ok, hash} = BcryptProvider.hash(Base.url_encode64(:crypto.strong_rand_bytes(24)))

    Account
    |> Ash.Changeset.for_create(:bootstrap_local_account, %{
      actor_id: actor,
      email: "bootstrap-#{actor}@example.test",
      hashed_password: hash,
      status: :active
    })
    |> Ash.create(authorize?: false)
    |> summarize()
  end

  defp bootstrap_rebind(id, actor) do
    {:ok, account} =
      Account
      |> Ash.Query.for_read(:get_local_account, %{id: id})
      |> Ash.read_one(authorize?: false)

    account
    |> Ash.Changeset.for_update(:rotate_local_demo_password, %{actor_id: actor})
    |> Ash.update(authorize?: false)
    |> summarize()
  end

  defp summarize({:ok, account}), do: {:ok, summary(account)}
  defp summarize({:error, _error}), do: {:error, :credential_operation_failed}

  defp summary(account),
    do: %{
      id: account.id,
      actor_id: account.actor_id,
      status: to_string(account.status),
      lock_version: account.lock_version
    }

  defp sql_transition(actor, _before, :insert) do
    {:ok, hash} = BcryptProvider.hash(Base.url_encode64(:crypto.strong_rand_bytes(24)))

    Repo.query!(
      "INSERT INTO identity_accounts (id, actor_id, email, hashed_password, status, lock_version, inserted_at, updated_at) VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW())",
      [UUID.dump!(UUID.generate()), UUID.dump!(actor), "sql-#{actor}@example.test", hash]
    )

    :written
  end

  defp sql_transition(_actor, account, :update) do
    Repo.query!(
      "UPDATE identity_accounts SET status = 'suspended', temporary_password_expires_at = NULL WHERE id = $1",
      [UUID.dump!(account.id)]
    )

    :written
  end

  defp sql_transition(_actor, account, :delete) do
    Repo.query!("DELETE FROM identity_accounts WHERE id = $1", [UUID.dump!(account.id)])
    :written
  end

  defp member!(f, context \\ Fixture.context_a()) do
    actor = UUID.generate()
    add_member!(f, actor, context)
    actor
  end

  defp add_member!(f, actor, context) do
    {:ok, _} =
      run(
        f,
        fn -> Fixture.insert_membership(UUID.generate(), tenant(context), actor) end,
        context
      )
  end

  defp snapshot(f, actor) do
    {:ok, %{rows: rows}} =
      run(f, fn ->
        Repo.query!(
          "SELECT id::text, actor_id::text, status, lock_version FROM identity_accounts WHERE actor_id = $1",
          [UUID.dump!(actor)]
        )
      end)

    case rows do
      [] ->
        nil

      [[id, actor, status, version]] ->
        %{id: id, actor_id: actor, status: status, lock_version: version}
    end
  end

  defp hold(f, actors, mode \\ :private) do
    parent = self()
    holder = Task.async(fn -> run(f, fn -> hold_operation(actors, mode, parent) end) end)

    assert_receive {:held, pid, backend}, 1_000
    assert pid == holder.pid
    {holder, backend}
  end

  defp hold_operation(actors, mode, parent) do
    case mode do
      :private ->
        :ok = AccountSourceFence.lock_current_transaction(Fixture.context_a(), actors)

      :raw ->
        Repo.query!("SELECT identity_account_source_lock($1::uuid[])", [
          Enum.map(actors, &UUID.dump!/1)
        ])
    end

    %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
    send(parent, {:held, self(), backend})
    receive do: (:release -> :released)
  end

  defp release(holder) do
    send(holder.pid, :release)
    assert {:ok, :released} = Task.await(holder)
  end

  defp writer(f, operation, context \\ Fixture.context_a()) do
    parent = self()

    Task.async(fn ->
      run(
        f,
        fn ->
          %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
          send(parent, {:writing, self(), backend})
          operation.()
        end,
        context
      )
    end)
  end

  defp assert_blocked(f, writer, holder_backend) do
    assert_receive {:writing, pid, backend}, 1_000
    assert pid == writer.pid
    assert blocking?(f, backend, holder_backend, System.monotonic_time(:millisecond) + 1_000)
  end

  defp blocking?(f, writer, holder, deadline) do
    {:ok, %{rows: [[blockers]]}} =
      run(f, fn -> Repo.query!("SELECT pg_blocking_pids($1)", [writer]) end)

    cond do
      holder in blockers ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(5)
        blocking?(f, writer, holder, deadline)
    end
  end

  defp run(f, operation, context \\ Fixture.context_a()) do
    Persistence.with_writer(f.persistence, context, fn ->
      case Repo.transaction(fn -> abort_failed_operation(operation.()) end) do
        {:ok, result} -> result
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp abort_failed_operation({:error, reason}), do: Repo.rollback(reason)
  defp abort_failed_operation(result), do: result

  defp tenant(context), do: TrustedActor.tenant_id(context.actor)
end
