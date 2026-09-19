defmodule AshFoundationLab.TenantAdmission do
  @moduledoc """
  Disposable Phase 0 admission boundary for tenant-owned database work.

  A caller must acquire a tenant and placement permit before the supplied
  callback is invoked. Database checkout belongs inside that callback, so a
  rejected caller cannot consume an Ecto/Postgrex connection while waiting or
  being backpressured.

  This module is pressure-test evidence, not an accepted production API.
  """

  use GenServer

  @typedoc "Opaque permit returned only to an admitted caller."
  @type permit :: reference()

  @typedoc "Stable failure classification for an interface adapter."
  @type rejection :: %{
          required(:kind) => :invalid_tenant_context | :rate_limited | :retryable_dependency,
          required(:http_status) => 403 | 429 | 503,
          required(:retry_after_ms) => non_neg_integer()
        }

  @type option ::
          {:name, GenServer.name()}
          | {:per_tenant_limit, pos_integer()}
          | {:placement_limit, pos_integer()}
          | {:retry_after_ms, non_neg_integer()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(options) do
    {name, options} = Keyword.pop(options, :name)
    GenServer.start_link(__MODULE__, options, name: name)
  end

  @spec checkout(GenServer.server(), term()) :: {:ok, permit()} | {:error, rejection()}
  def checkout(server, tenant_id) do
    GenServer.call(server, {:checkout, tenant_id})
  end

  @spec checkin(GenServer.server(), permit()) :: :ok
  def checkin(server, permit) do
    GenServer.call(server, {:checkin, permit})
  end

  @spec with_permit(GenServer.server(), term(), (-> result)) ::
          {:ok, result} | {:error, rejection()}
        when result: term()
  def with_permit(server, tenant_id, callback) when is_function(callback, 0) do
    case checkout(server, tenant_id) do
      {:ok, permit} ->
        try do
          {:ok, callback.()}
        after
          checkin(server, permit)
        end

      {:error, rejection} ->
        {:error, rejection}
    end
  end

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(options) do
    per_tenant_limit = Keyword.fetch!(options, :per_tenant_limit)
    placement_limit = Keyword.fetch!(options, :placement_limit)
    retry_after_ms = Keyword.get(options, :retry_after_ms, 20)

    if per_tenant_limit < 1 or placement_limit < 1 do
      raise ArgumentError, "admission limits must be positive"
    end

    {:ok,
     %{
       per_tenant_limit: per_tenant_limit,
       placement_limit: placement_limit,
       retry_after_ms: retry_after_ms,
       active_total: 0,
       active_by_tenant: %{},
       permits: %{},
       monitors: %{},
       admitted: 0,
       rejected_by_tenant: 0,
       rejected_by_placement: 0,
       rejected_invalid_context: 0
     }}
  end

  @impl true
  def handle_call({:checkout, tenant_id}, {caller, _tag}, state) do
    cond do
      not valid_tenant_id?(tenant_id) ->
        rejection = rejection(:invalid_tenant_context, 403, 0)
        {:reply, {:error, rejection}, Map.update!(state, :rejected_invalid_context, &(&1 + 1))}

      Map.get(state.active_by_tenant, tenant_id, 0) >= state.per_tenant_limit ->
        rejection = rejection(:rate_limited, 429, state.retry_after_ms)
        {:reply, {:error, rejection}, Map.update!(state, :rejected_by_tenant, &(&1 + 1))}

      state.active_total >= state.placement_limit ->
        rejection = rejection(:retryable_dependency, 503, state.retry_after_ms)
        {:reply, {:error, rejection}, Map.update!(state, :rejected_by_placement, &(&1 + 1))}

      true ->
        permit = make_ref()
        monitor = Process.monitor(caller)

        admitted_state = %{
          state
          | active_total: state.active_total + 1,
            active_by_tenant:
              Map.update(state.active_by_tenant, tenant_id, 1, fn active -> active + 1 end),
            permits: Map.put(state.permits, permit, {tenant_id, monitor}),
            monitors: Map.put(state.monitors, monitor, permit),
            admitted: state.admitted + 1
        }

        {:reply, {:ok, permit}, admitted_state}
    end
  end

  def handle_call({:checkin, permit}, _from, state) do
    {next_state, monitor} = release_permit(state, permit)

    if monitor do
      Process.demonitor(monitor, [:flush])
    end

    {:reply, :ok, next_state}
  end

  def handle_call(:snapshot, _from, state) do
    snapshot = Map.drop(state, [:permits, :monitors])
    {:reply, snapshot, state}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Map.fetch(state.monitors, monitor) do
      {:ok, permit} ->
        {next_state, _monitor} = release_permit(state, permit)
        {:noreply, next_state}

      :error ->
        {:noreply, state}
    end
  end

  defp release_permit(state, permit) do
    case Map.pop(state.permits, permit) do
      {nil, _permits} ->
        {state, nil}

      {{tenant_id, monitor}, permits} ->
        tenant_active = Map.fetch!(state.active_by_tenant, tenant_id) - 1

        active_by_tenant =
          if tenant_active == 0 do
            Map.delete(state.active_by_tenant, tenant_id)
          else
            Map.put(state.active_by_tenant, tenant_id, tenant_active)
          end

        {%{
           state
           | active_total: state.active_total - 1,
             active_by_tenant: active_by_tenant,
             permits: permits,
             monitors: Map.delete(state.monitors, monitor)
         }, monitor}
    end
  end

  defp valid_tenant_id?(tenant_id) when is_binary(tenant_id), do: String.trim(tenant_id) != ""
  defp valid_tenant_id?(tenant_id) when is_integer(tenant_id), do: tenant_id > 0
  defp valid_tenant_id?(_tenant_id), do: false

  defp rejection(kind, http_status, retry_after_ms) do
    %{kind: kind, http_status: http_status, retry_after_ms: retry_after_ms}
  end
end
