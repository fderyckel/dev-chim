defmodule Chimwemwe.Platform.Outbox.Dispatcher do
  @moduledoc """
  Explicitly supervised, database-local outbox dispatcher.

  Every instance receives its persistence runtime, immutable consumer registry,
  trusted execution context, consumer key, and bounded poll interval. No instance
  is installed in the application supervisor and no production placement is
  selected by this process.
  """

  use GenServer

  alias Chimwemwe.Platform.{
    ExecutionContext,
    Outbox,
    OutboxError,
    PersistenceRuntime,
    PlacementRegistry,
    TrustedActor
  }

  alias Chimwemwe.Platform.Outbox.{ConsumerRegistry, ConsumptionResult, DispatcherStatus}

  @minimum_poll_interval_ms 10
  @maximum_poll_interval_ms 300_000
  @failure_codes [:consumer_rejected, :invalid_contract, :retryable_dependency]
  @required_options [:consumer_key, :context, :poll_interval_ms, :registry, :runtime]

  @type option ::
          {:consumer_key, String.t()}
          | {:context, ExecutionContext.t()}
          | {:poll_interval_ms, pos_integer()}
          | {:registry, ConsumerRegistry.t()}
          | {:runtime, Supervisor.supervisor()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(options) when is_list(options), do: GenServer.start_link(__MODULE__, options)

  @spec dispatch_now(GenServer.server()) :: {:ok, DispatcherStatus.t()} | {:error, term()}
  def dispatch_now(dispatcher), do: GenServer.call(dispatcher, {:dispatch_now, :normal}, 30_000)

  @spec reconcile_now(GenServer.server()) :: {:ok, DispatcherStatus.t()} | {:error, term()}
  def reconcile_now(dispatcher),
    do: GenServer.call(dispatcher, {:dispatch_now, :reconciliation}, 30_000)

  @spec status(GenServer.server()) :: DispatcherStatus.t()
  def status(dispatcher), do: GenServer.call(dispatcher, :status)

  @impl true
  def init(options) do
    with :ok <- validate_option_keys(options),
         {:ok, registry} <- ConsumerRegistry.revalidate(Keyword.fetch!(options, :registry)),
         {:ok, declaration} <-
           ConsumerRegistry.fetch(registry, Keyword.fetch!(options, :consumer_key)),
         :ok <- ExecutionContext.validate(Keyword.fetch!(options, :context)),
         {:ok, _placement_registry} <-
           PersistenceRuntime.child_pid(
             Keyword.fetch!(options, :runtime),
             PlacementRegistry
           ),
         {:ok, poll_interval_ms} <-
           validate_poll_interval(Keyword.fetch!(options, :poll_interval_ms)) do
      state = %{
        runtime: Keyword.fetch!(options, :runtime),
        registry: registry,
        context: Keyword.fetch!(options, :context),
        consumer_key: declaration.key,
        poll_interval_ms: poll_interval_ms,
        status: empty_status()
      }

      schedule_poll(poll_interval_ms)
      {:ok, state}
    else
      _invalid -> {:stop, :invalid_dispatcher_configuration}
    end
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  def handle_call({:dispatch_now, mode}, _from, state) do
    {reply, next_state} = dispatch(state, mode)
    {:reply, reply, next_state}
  end

  @impl true
  def handle_info(:poll, state) do
    {_reply, next_state} = dispatch(state, :normal)
    schedule_poll(state.poll_interval_ms)
    {:noreply, next_state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp dispatch(state, mode) do
    polled_at = DateTime.utc_now()
    started_at = System.monotonic_time()

    result =
      case claim(state, mode) do
        {:ok, envelopes} ->
          next_status =
            Enum.reduce(envelopes, %{state.status | last_polled_at: polled_at}, fn envelope,
                                                                                   status ->
              dispatch_envelope(state, envelope, status)
            end)

          {{:ok, next_status}, %{state | status: next_status}}

        {:error, error} ->
          next_status = %{
            state.status
            | failed_count: state.status.failed_count + 1,
              last_polled_at: polled_at
          }

          {{:error, error}, %{state | status: next_status}}
      end

    emit_telemetry(state, mode, result, started_at)
    result
  end

  defp claim(state, :normal),
    do: Outbox.claim(state.runtime, state.registry, state.context, state.consumer_key)

  defp claim(state, :reconciliation),
    do:
      Outbox.claim_reconciliation(
        state.runtime,
        state.registry,
        state.context,
        state.consumer_key
      )

  defp emit_telemetry(state, mode, {{outcome, _value}, %{status: status}}, started_at) do
    {operational_measurements, status_available} = operational_measurements(state)

    :telemetry.execute(
      [:chimwemwe, :outbox, :dispatch],
      Map.merge(
        %{
          duration: System.monotonic_time() - started_at,
          acknowledged_count: status.acknowledged_count,
          failed_count: status.failed_count,
          processed_count: status.processed_count,
          skipped_count: status.skipped_count
        },
        operational_measurements
      ),
      %{
        tenant_id: TrustedActor.tenant_id(state.context.actor),
        routing_version: state.context.placement.routing_version,
        consumer_key: state.consumer_key,
        mode: mode,
        outcome: outcome,
        status_available: status_available
      }
    )
  end

  defp operational_measurements(state) do
    case Outbox.status(state.runtime, state.registry, state.context, state.consumer_key) do
      {:ok, status} ->
        pending_count = status.unclaimed + status.available + status.expired_lease

        {%{
           dead_letter_count: status.dead_letter,
           expired_lease_count: status.expired_lease,
           oldest_pending_age_ms: oldest_pending_age_ms(status.oldest_pending_at),
           pending_count: pending_count,
           retry_ready_count: status.available,
           stale_route_count: status.stale_route
         }, true}

      {:error, _error} ->
        {%{}, false}
    end
  end

  defp oldest_pending_age_ms(nil), do: 0

  defp oldest_pending_age_ms(oldest_pending_at) do
    max(DateTime.diff(DateTime.utc_now(), oldest_pending_at, :millisecond), 0)
  end

  defp dispatch_envelope(state, envelope, status) do
    case Outbox.consume(
           state.runtime,
           state.registry,
           state.context,
           state.consumer_key,
           envelope
         ) do
      {:ok, %ConsumptionResult{} = result} ->
        acknowledge(state, envelope, result, status)

      {:error, error} ->
        fail(state, envelope, failure_code(error), status)
    end
  end

  defp acknowledge(state, envelope, result, status) do
    case Outbox.acknowledge(
           state.runtime,
           state.registry,
           state.context,
           state.consumer_key,
           envelope.event_id,
           envelope.lease_token
         ) do
      {:ok, _delivery} ->
        status
        |> increment_result(result.state)
        |> Map.update!(:acknowledged_count, &(&1 + 1))

      {:error, _error} ->
        Map.update!(status, :failed_count, &(&1 + 1))
    end
  end

  defp fail(state, envelope, failure_code, status) do
    case Outbox.fail(
           state.runtime,
           state.registry,
           state.context,
           state.consumer_key,
           envelope.event_id,
           envelope.lease_token,
           failure_code
         ) do
      {:ok, _delivery} -> Map.update!(status, :failed_count, &(&1 + 1))
      {:error, _error} -> Map.update!(status, :failed_count, &(&1 + 1))
    end
  end

  defp increment_result(status, :processed),
    do: Map.update!(status, :processed_count, &(&1 + 1))

  defp increment_result(status, :already_processed),
    do: Map.update!(status, :skipped_count, &(&1 + 1))

  defp failure_code(%OutboxError{code: code}) when code in @failure_codes, do: code
  defp failure_code(_error), do: :retryable_dependency

  defp validate_option_keys(options) do
    keys = Keyword.keys(options)

    if Enum.sort(keys) == Enum.sort(@required_options) and Enum.uniq(keys) == keys do
      :ok
    else
      {:error, :invalid_options}
    end
  end

  defp validate_poll_interval(value)
       when is_integer(value) and value >= @minimum_poll_interval_ms and
              value <= @maximum_poll_interval_ms,
       do: {:ok, value}

  defp validate_poll_interval(_value), do: {:error, :invalid_poll_interval}

  defp schedule_poll(interval), do: Process.send_after(self(), :poll, interval)

  defp empty_status do
    %DispatcherStatus{
      acknowledged_count: 0,
      failed_count: 0,
      last_polled_at: nil,
      processed_count: 0,
      skipped_count: 0
    }
  end
end
