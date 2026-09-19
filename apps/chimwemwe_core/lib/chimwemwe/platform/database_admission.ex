defmodule Chimwemwe.Platform.DatabaseAdmission do
  @moduledoc """
  Enforces node-local tenant and placement capacity before database checkout.

  The supplied operation is invoked only after a validated execution context
  acquires both limits. Admission protects capacity; it does not authorize the
  operation, select a repository, or establish that a routing version is current.
  """

  use GenServer

  alias Chimwemwe.Platform.{AdmissionError, ExecutionContext, TrustedActor}

  @type option ::
          {:name, GenServer.name()}
          | {:per_tenant_limit, pos_integer()}
          | {:per_placement_limit, pos_integer()}
          | {:retry_after_ms, pos_integer() | nil}

  @type statistics :: %{
          active_permits: non_neg_integer(),
          admitted: non_neg_integer(),
          placement_rejections: non_neg_integer(),
          tenant_rejections: non_neg_integer()
        }

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    {name, init_options} = Keyword.pop(options, :name)
    GenServer.start_link(__MODULE__, init_options, name: name)
  end

  @doc "Runs an operation only after trusted tenant and placement admission succeeds."
  @spec with_permit(GenServer.server(), term(), (-> result)) ::
          {:ok, result} | {:error, AdmissionError.t() | term()}
        when result: term()
  def with_permit(server, context, operation) when is_function(operation, 0) do
    ExecutionContext.with_validated(context, fn validated_context ->
      case acquire(server, validated_context) do
        {:ok, permit} -> run_and_release(server, permit, operation)
        {:error, %AdmissionError{} = error} -> {:error, error}
      end
    end)
  end

  @doc "Returns identifier-free local admission counters for operations and monitoring."
  @spec statistics(GenServer.server()) :: statistics()
  def statistics(server), do: GenServer.call(server, :statistics)

  @impl true
  def init(options) do
    with :ok <- validate_option_keys(options),
         {:ok, per_tenant_limit} <- positive_option(options, :per_tenant_limit),
         {:ok, per_placement_limit} <- positive_option(options, :per_placement_limit),
         {:ok, retry_after_ms} <- optional_positive_option(options, :retry_after_ms) do
      {:ok,
       %{
         per_tenant_limit: per_tenant_limit,
         per_placement_limit: per_placement_limit,
         retry_after_ms: retry_after_ms,
         active_by_tenant: %{},
         active_by_placement: %{},
         permits: %{},
         monitors: %{},
         admitted: 0,
         tenant_rejections: 0,
         placement_rejections: 0
       }}
    else
      {:error, field} -> {:stop, {:invalid_admission_option, field}}
    end
  end

  @impl true
  def handle_call({:acquire, tenant_key, placement_key}, {owner, _tag}, state) do
    tenant_active = Map.get(state.active_by_tenant, tenant_key, 0)
    placement_active = Map.get(state.active_by_placement, placement_key, 0)

    cond do
      tenant_active >= state.per_tenant_limit ->
        error = admission_error(:rate_limited, state.retry_after_ms)
        {:reply, {:error, error}, Map.update!(state, :tenant_rejections, &(&1 + 1))}

      placement_active >= state.per_placement_limit ->
        error = admission_error(:retryable_dependency, state.retry_after_ms)
        {:reply, {:error, error}, Map.update!(state, :placement_rejections, &(&1 + 1))}

      true ->
        {permit, next_state} = admit(state, owner, tenant_key, placement_key)
        {:reply, {:ok, permit}, next_state}
    end
  end

  def handle_call({:release, permit}, {owner, _tag}, state) do
    {:reply, :ok, release_owned_permit(state, permit, owner)}
  end

  def handle_call(:statistics, _from, state) do
    statistics = %{
      active_permits: map_size(state.permits),
      admitted: state.admitted,
      placement_rejections: state.placement_rejections,
      tenant_rejections: state.tenant_rejections
    }

    {:reply, statistics, state}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, owner, _reason}, state) do
    case Map.fetch(state.monitors, monitor) do
      {:ok, permit} -> {:noreply, release_owned_permit(state, permit, owner)}
      :error -> {:noreply, state}
    end
  end

  defp acquire(server, context) do
    tenant_id = TrustedActor.tenant_id(context.actor)
    placement_key = {context.placement.profile, context.placement.placement_ref}
    tenant_key = {placement_key, tenant_id}

    GenServer.call(server, {:acquire, tenant_key, placement_key})
  catch
    :exit, _reason -> {:error, admission_error(:retryable_dependency, nil)}
  end

  defp run_and_release(server, permit, operation) do
    {:ok, operation.()}
  after
    GenServer.call(server, {:release, permit})
  end

  defp admit(state, owner, tenant_key, placement_key) do
    permit = make_ref()
    monitor = Process.monitor(owner)

    next_state = %{
      state
      | active_by_tenant: Map.update(state.active_by_tenant, tenant_key, 1, &(&1 + 1)),
        active_by_placement: Map.update(state.active_by_placement, placement_key, 1, &(&1 + 1)),
        permits:
          Map.put(state.permits, permit, %{
            monitor: monitor,
            owner: owner,
            placement_key: placement_key,
            tenant_key: tenant_key
          }),
        monitors: Map.put(state.monitors, monitor, permit),
        admitted: state.admitted + 1
    }

    {permit, next_state}
  end

  defp release_owned_permit(state, permit, owner) do
    case Map.fetch(state.permits, permit) do
      {:ok, %{owner: ^owner} = held_permit} -> release_permit(state, permit, held_permit)
      _missing_or_different_owner -> state
    end
  end

  defp release_permit(state, permit, held_permit) do
    Process.demonitor(held_permit.monitor, [:flush])

    %{
      state
      | active_by_tenant: decrement(state.active_by_tenant, held_permit.tenant_key),
        active_by_placement: decrement(state.active_by_placement, held_permit.placement_key),
        permits: Map.delete(state.permits, permit),
        monitors: Map.delete(state.monitors, held_permit.monitor)
    }
  end

  defp decrement(counts, key) do
    case Map.fetch!(counts, key) - 1 do
      0 -> Map.delete(counts, key)
      remaining -> Map.put(counts, key, remaining)
    end
  end

  defp admission_error(code, retry_after_ms) do
    %AdmissionError{code: code, retry_after_ms: retry_after_ms}
  end

  defp validate_option_keys(options) do
    allowed = [:per_tenant_limit, :per_placement_limit, :retry_after_ms]

    case Keyword.keys(options) -- allowed do
      [] -> :ok
      _unknown -> {:error, :unknown}
    end
  end

  defp positive_option(options, field) do
    case Keyword.fetch(options, field) do
      {:ok, value} when is_integer(value) and value > 0 -> {:ok, value}
      _missing_or_invalid -> {:error, field}
    end
  end

  defp optional_positive_option(options, field) do
    case Keyword.get(options, field) do
      nil -> {:ok, nil}
      value when is_integer(value) and value > 0 -> {:ok, value}
      _invalid -> {:error, field}
    end
  end
end
