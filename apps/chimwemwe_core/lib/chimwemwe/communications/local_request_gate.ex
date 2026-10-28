defmodule Chimwemwe.Communications.LocalRequestGate do
  @moduledoc "Bounded synchronous admission for the disabled local proof; no production child or jobs."
  use GenServer
  alias Chimwemwe.Communications.Error
  alias Chimwemwe.Platform.DatabaseAdmission
  @maximum_waiters 32
  @wait_ms 2_000
  @scope_key {__MODULE__, :held}

  def start_link({tenant, institution}), do: start_link({tenant, institution, nil})

  def start_link({tenant, institution, admission}),
    do: GenServer.start_link(__MODULE__, {tenant, institution, admission})

  def statistics(gate), do: GenServer.call(gate, :statistics)

  def held?(gate, tenant, institution),
    do:
      Process.get(@scope_key) == {self(), gate, tenant, institution} and is_pid(gate) and
        Process.alive?(gate)

  def with_slot(nil, _tenant, _institution, operation) when is_function(operation, 0),
    do: operation.()

  def with_slot(gate, tenant, institution, operation)
      when is_pid(gate) and is_function(operation, 0) do
    case Process.get(@scope_key) do
      nil ->
        acquire(gate, tenant, institution, operation)

      scope when scope == {self(), gate, tenant, institution} ->
        if Process.alive?(gate), do: operation.(), else: error(:retryable_dependency)

      _ ->
        error(:forbidden)
    end
  end

  def with_slot(_gate, _tenant, _institution, _operation), do: error(:retryable_dependency)

  defp acquire(gate, tenant, institution, operation) do
    reference = make_ref()

    try do
      case GenServer.call(
             gate,
             {:acquire, self(), reference, tenant, institution},
             @wait_ms + 100
           ) do
        :granted -> execute(gate, tenant, institution, reference, operation)
        {:error, code} -> error(code)
      end
    catch
      :exit, _reason ->
        GenServer.cast(gate, {:cancel, self(), reference})
        error(:retryable_dependency)
    end
  end

  defp execute(gate, tenant, institution, reference, operation) do
    Process.put(@scope_key, {self(), gate, tenant, institution})

    try do
      operation.()
    after
      Process.delete(@scope_key)
      GenServer.cast(gate, {:release, self(), reference})
    end
  end

  @impl true
  def init({tenant, institution, admission}),
    do:
      {:ok,
       %{
         tenant: tenant,
         admission: admission,
         capacity_timer: nil,
         capacity_deferrals: 0,
         institution: institution,
         active: nil,
         waiting: [],
         admitted: 0,
         overflow: 0,
         expired: 0,
         cancelled: 0,
         maximum_observed_waiters: 0
       }}

  @impl true
  def handle_call(:statistics, _from, state),
    do:
      {:reply,
       Map.merge(
         Map.take(state, [
           :admitted,
           :overflow,
           :expired,
           :cancelled,
           :maximum_observed_waiters,
           :capacity_deferrals
         ]),
         %{
           active: if(state.active, do: 1, else: 0),
           waiting: length(state.waiting),
           maximum_waiters: @maximum_waiters
         }
       ), state}

  def handle_call({:acquire, pid, reference, tenant, institution}, from, state) do
    cond do
      tenant != state.tenant or institution != state.institution ->
        {:reply, {:error, :forbidden}, state}

      state.active == nil and state.waiting == [] and capacity_available?(state) ->
        monitor = Process.monitor(pid)

        {:reply, :granted,
         %{state | active: {pid, reference, monitor}, admitted: state.admitted + 1}}

      length(state.waiting) >= @maximum_waiters ->
        {:reply, {:error, :rate_limited}, %{state | overflow: state.overflow + 1}}

      true ->
        monitor = Process.monitor(pid)
        timer = Process.send_after(self(), {:expire, reference}, @wait_ms)

        entry = %{
          pid: pid,
          reference: reference,
          monitor: monitor,
          timer: timer,
          from: from,
          expires_at: System.monotonic_time(:millisecond) + @wait_ms
        }

        {:noreply,
         advance(%{
           state
           | waiting: state.waiting ++ [entry],
             maximum_observed_waiters:
               max(state.maximum_observed_waiters, length(state.waiting) + 1)
         })}
    end
  end

  @impl true
  def handle_cast({:release, pid, reference}, %{active: {pid, reference, monitor}} = state) do
    Process.demonitor(monitor, [:flush])
    {:noreply, advance(%{state | active: nil})}
  end

  def handle_cast({:cancel, pid, reference}, state) do
    state =
      cancel_waiter(
        state,
        fn entry -> entry.pid == pid and entry.reference == reference end,
        :cancelled
      )

    case state.active do
      {^pid, ^reference, monitor} ->
        Process.demonitor(monitor, [:flush])
        {:noreply, advance(%{state | active: nil, cancelled: state.cancelled + 1})}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(_message, state), do: {:noreply, state}

  @impl true
  def handle_info(:capacity_check, state), do: {:noreply, advance(%{state | capacity_timer: nil})}

  def handle_info({:expire, reference}, state) do
    {expired, waiting} = Enum.split_with(state.waiting, &(&1.reference == reference))

    Enum.each(expired, fn entry ->
      Process.demonitor(entry.monitor, [:flush])
      GenServer.reply(entry.from, {:error, :rate_limited})
    end)

    {:noreply, %{state | waiting: waiting, expired: state.expired + length(expired)}}
  end

  def handle_info(
        {:DOWN, monitor, :process, _pid, _reason},
        %{active: {_owner, _reference, monitor}} = state
      ),
      do: {:noreply, advance(%{state | active: nil, cancelled: state.cancelled + 1})}

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state),
    do: {:noreply, cancel_waiter(state, &(&1.monitor == monitor), :cancelled)}

  def handle_info(_message, state), do: {:noreply, state}

  defp cancel_waiter(state, predicate, counter) do
    {removed, waiting} = Enum.split_with(state.waiting, predicate)

    Enum.each(removed, fn entry ->
      Process.cancel_timer(entry.timer)
      Process.demonitor(entry.monitor, [:flush])
    end)

    state |> Map.put(:waiting, waiting) |> Map.update!(counter, &(&1 + length(removed)))
  end

  defp advance(%{active: active} = state) when not is_nil(active), do: state
  defp advance(%{waiting: []} = state), do: clear_capacity_timer(state)

  defp advance(%{waiting: [entry | waiting]} = state) do
    cond do
      not Process.alive?(entry.pid) ->
        Process.cancel_timer(entry.timer)
        Process.demonitor(entry.monitor, [:flush])
        advance(%{state | waiting: waiting, cancelled: state.cancelled + 1})

      System.monotonic_time(:millisecond) >= entry.expires_at ->
        Process.cancel_timer(entry.timer)
        Process.demonitor(entry.monitor, [:flush])
        GenServer.reply(entry.from, {:error, :rate_limited})
        advance(%{state | waiting: waiting, expired: state.expired + 1})

      not capacity_available?(state) ->
        defer_for_capacity(state)

      true ->
        state = clear_capacity_timer(state)
        Process.cancel_timer(entry.timer)
        GenServer.reply(entry.from, :granted)

        %{
          state
          | active: {entry.pid, entry.reference, entry.monitor},
            waiting: waiting,
            admitted: state.admitted + 1
        }
    end
  end

  defp capacity_available?(%{admission: nil}), do: true

  defp capacity_available?(state),
    do: DatabaseAdmission.statistics(state.admission).active_permits == 0

  defp defer_for_capacity(%{capacity_timer: nil} = state),
    do: %{
      state
      | capacity_timer: Process.send_after(self(), :capacity_check, 5),
        capacity_deferrals: state.capacity_deferrals + 1
    }

  defp defer_for_capacity(state), do: state
  defp clear_capacity_timer(%{capacity_timer: nil} = state), do: state

  defp clear_capacity_timer(state) do
    Process.cancel_timer(state.capacity_timer)
    %{state | capacity_timer: nil}
  end

  defp error(code), do: {:error, %Error{code: code}}
end
