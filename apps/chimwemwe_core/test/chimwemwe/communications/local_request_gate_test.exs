defmodule Chimwemwe.Communications.LocalRequestGateTest do
  use ExUnit.Case, async: true
  alias Chimwemwe.Classroom.Fixture, as: Classroom
  alias Chimwemwe.Communications.{Error, LocalRequestGate}
  alias Chimwemwe.Platform.DatabaseAdmission
  @tenant "fictional-tenant"
  @institution "fictional-institution"
  setup do
    gate = start_supervised!({LocalRequestGate, {@tenant, @institution}})
    %{gate: gate}
  end

  test "exact synchronous nesting reuses one slot, mismatches refuse, and exceptions release", %{
    gate: gate
  } do
    assert {:ok, :nested} =
             LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
               assert LocalRequestGate.held?(gate, @tenant, @institution)
               assert %{active: 1, waiting: 0, admitted: 1} = LocalRequestGate.statistics(gate)

               assert {:error, %Error{code: :forbidden}} =
                        LocalRequestGate.with_slot(gate, @tenant, "other", fn ->
                          flunk("mismatched scope ran")
                        end)

               LocalRequestGate.with_slot(gate, @tenant, @institution, fn -> {:ok, :nested} end)
             end)

    assert_raise RuntimeError, fn ->
      LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
        raise "fictional callback failure"
      end)
    end

    assert {:ok, :next} =
             LocalRequestGate.with_slot(gate, @tenant, @institution, fn -> {:ok, :next} end)

    assert %{active: 0, waiting: 0, admitted: 3} = LocalRequestGate.statistics(gate)
    refute LocalRequestGate.held?(gate, @tenant, @institution)
  end

  test "overflow refuses without running; waiting and active owner termination release capacity",
       %{gate: gate} do
    parent = self()

    owner =
      spawn(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :held)

          receive do
            :finish -> {:ok, :done}
          end
        end)
      end)

    assert_receive :held

    waiting =
      for _ <- 1..32,
          do:
            spawn(fn ->
              LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
                send(parent, {:ran, self()})
                {:ok, :done}
              end)
            end)

    await_count(gate, 32)

    assert {:error, %Error{code: :rate_limited}} =
             LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
               flunk("overflow ran")
             end)

    first = hd(waiting)
    Process.exit(first, :kill)
    await_count(gate, 31)
    Process.exit(owner, :kill)
    for _ <- 1..31, do: assert_receive({:ran, _}, 2_000)
    assert %{active: 0, waiting: 0, overflow: 1} = LocalRequestGate.statistics(gate)
  end

  test "waiting timeout is explicit and a later request can proceed", %{gate: gate} do
    parent = self()

    owner =
      spawn(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :held)

          receive do
            :finish -> {:ok, :done}
          end
        end)
      end)

    assert_receive :held

    assert {:error, %Error{code: :rate_limited}} =
             LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
               flunk("expired waiter ran")
             end)

    assert %{waiting: 0, expired: 1} = LocalRequestGate.statistics(gate)
    send(owner, :finish)

    assert {:ok, :after_timeout} =
             LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
               {:ok, :after_timeout}
             end)
  end

  test "a queued request observes changes after waiting", %{gate: gate} do
    parent = self()
    {:ok, state} = Agent.start_link(fn -> :allowed end)
    on_exit(fn -> if Process.alive?(state), do: Agent.stop(state) end)

    owner =
      spawn(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :held)

          receive do
            :finish -> {:ok, :done}
          end
        end)
      end)

    assert_receive :held

    caller =
      Task.async(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          {:ok, Agent.get(state, & &1)}
        end)
      end)

    await_count(gate, 1)
    Agent.update(state, fn _ -> :revoked end)
    send(owner, :finish)
    assert {:ok, :revoked} = Task.await(caller)
  end

  test "release ahead of a delayed expiry message cannot grant an expired waiter", %{gate: gate} do
    parent = self()

    {owner, monitor} =
      spawn_monitor(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :held)

          receive do
            :finish -> :ok
          end
        end)
      end)

    assert_receive :held

    waiter =
      Task.async(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :expired_callback_ran)
          :ok
        end)
      end)

    await_count(gate, 1)
    :ok = :sys.suspend(gate)

    state =
      :sys.replace_state(gate, fn state ->
        %{
          state
          | waiting:
              Enum.map(
                state.waiting,
                &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
              )
        }
      end)

    send(owner, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}
    send(gate, {:expire, hd(state.waiting).reference})
    :ok = :sys.resume(gate)
    assert {:error, %Error{code: :rate_limited}} = Task.await(waiter)
    refute_receive :expired_callback_ran
    assert %{active: 0, waiting: 0, expired: 1} = LocalRequestGate.statistics(gate)
  end

  for disposition <- [:release, :expiry] do
    test "already-admitted work proceeds while communications waits: #{disposition}" do
      admission =
        start_supervised!({DatabaseAdmission, per_tenant_limit: 1, per_placement_limit: 1})

      gate =
        start_supervised!(
          Supervisor.child_spec({LocalRequestGate, {@tenant, @institution, admission}},
            id: :capacity_gate
          )
        )

      parent = self()

      other =
        Task.async(fn ->
          DatabaseAdmission.with_permit(admission, Classroom.context_a(), fn ->
            send(parent, :ordinary_work_admitted)

            receive do
              :release -> :done
            end
          end)
        end)

      assert_receive :ordinary_work_admitted, 2_000

      caller =
        Task.async(fn ->
          LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
            send(parent, :communications_executed)
            {:ok, :done}
          end)
        end)

      await_count(gate, 1)
      assert %{active: 0, waiting: 1} = LocalRequestGate.statistics(gate)
      assert %{active_permits: 1, admitted: 1} = DatabaseAdmission.statistics(admission)

      if unquote(disposition) == :expiry do
        assert {:error, %Error{code: :rate_limited}} = Task.await(caller)
        refute_received :communications_executed
        assert %{active_permits: 1, admitted: 1} = DatabaseAdmission.statistics(admission)
        assert %{expired: 1, active: 0, waiting: 0} = LocalRequestGate.statistics(gate)
        send(other.pid, :release)
        assert {:ok, :done} = Task.await(other)
      else
        send(other.pid, :release)
        assert {:ok, :done} = Task.await(other)
        assert {:ok, :done} = Task.await(caller)
        assert_receive :communications_executed
      end

      assert {:ok, :later} =
               LocalRequestGate.with_slot(gate, @tenant, @institution, fn -> {:ok, :later} end)

      assert %{active_permits: 0, admitted: 1} = DatabaseAdmission.statistics(admission)
    end
  end

  test "a dispatch observation reserves no database permit and ordinary arrivals retain accounting" do
    admission =
      start_supervised!({DatabaseAdmission, per_tenant_limit: 1, per_placement_limit: 1})

    gate =
      start_supervised!(
        Supervisor.child_spec({LocalRequestGate, {@tenant, @institution, admission}},
          id: :capacity_gate
        )
      )

    parent = self()

    dispatched =
      Task.async(fn ->
        LocalRequestGate.with_slot(gate, @tenant, @institution, fn ->
          send(parent, :dispatched)

          receive do
            :finish -> {:ok, :done}
          end
        end)
      end)

    assert_receive :dispatched

    ordinary =
      Task.async(fn ->
        DatabaseAdmission.with_permit(admission, Classroom.context_a(), fn ->
          send(parent, :ordinary_admitted_after_dispatch)

          receive do
            :finish -> :done
          end
        end)
      end)

    assert_receive :ordinary_admitted_after_dispatch, 2_000

    assert {:error, _} =
             DatabaseAdmission.with_permit(admission, nil, fn -> flunk("missing context ran") end)

    assert {:error, _} =
             DatabaseAdmission.with_permit(admission, Classroom.context_a(), fn ->
               flunk("tenant overflow ran")
             end)

    assert {:error, _} =
             DatabaseAdmission.with_permit(admission, Classroom.context_b(), fn ->
               flunk("placement overflow ran")
             end)

    send(ordinary.pid, :finish)
    assert {:ok, :done} = Task.await(ordinary)
    send(dispatched.pid, :finish)
    assert {:ok, :done} = Task.await(dispatched)

    assert %{active_permits: 0, admitted: 1, tenant_rejections: 1, placement_rejections: 1} =
             DatabaseAdmission.statistics(admission)
  end

  defp await_count(gate, expected, attempts \\ 100)

  defp await_count(_gate, _expected, 0),
    do: flunk("gate did not reach the expected bounded queue")

  defp await_count(gate, expected, attempts) do
    if LocalRequestGate.statistics(gate).waiting == expected,
      do: :ok,
      else:
        (
          Process.sleep(5)
          await_count(gate, expected, attempts - 1)
        )
  end
end
