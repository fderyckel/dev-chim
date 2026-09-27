defmodule Chimwemwe.Platform.Outbox do
  @moduledoc """
  Tenant-safe internal delivery boundary for durable outbox facts.

  This boundary leases events, runs database-local code-owned consumers with
  durable receipts, acknowledges or records failed attempts, and governs exact
  dead-letter replay. It does not publish outside the core.
  """

  alias Ash.Type.UUID

  alias Chimwemwe.Platform.ExecutionContext

  alias Chimwemwe.Platform.Outbox.{
    ConsumerRegistry,
    ConsumptionBoundary,
    DeliveryBoundary,
    ReplayBoundary,
    ReplayCursor,
    ReplayCursorBoundary,
    ReplayInput,
    ReplayRangeInput,
    ReplayRangeResult
  }

  alias Chimwemwe.Platform.OutboxError

  @failure_codes [:consumer_rejected, :invalid_contract, :retryable_dependency]

  @doc "Claims one bounded batch for a trusted code-owned consumer declaration."
  @spec claim(Supervisor.supervisor(), term(), term(), term()) ::
          {:ok, [Chimwemwe.Platform.Outbox.Envelope.t()]} | {:error, term()}
  def claim(runtime, registry, context, consumer_key) do
    claim_with_mode(runtime, registry, context, consumer_key, :normal)
  end

  @doc "Claims one bounded module backlog batch while ordinary authority remains inactive."
  @spec claim_reconciliation(Supervisor.supervisor(), term(), term(), term()) ::
          {:ok, [Chimwemwe.Platform.Outbox.Envelope.t()]} | {:error, term()}
  def claim_reconciliation(runtime, registry, context, consumer_key) do
    claim_with_mode(runtime, registry, context, consumer_key, :reconciliation)
  end

  defp claim_with_mode(runtime, registry, context, consumer_key, mode) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key) do
        DeliveryBoundary.claim(runtime, validated_context, declaration, mode)
      end
    end)
  end

  @doc "Acknowledges one exact active delivery lease."
  @spec acknowledge(Supervisor.supervisor(), term(), term(), term(), term(), term()) ::
          {:ok, Chimwemwe.Platform.Outbox.DeliveryResult.t()} | {:error, term()}
  def acknowledge(runtime, registry, context, consumer_key, event_id, lease_token) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key),
           {:ok, event_id} <- cast_uuid(event_id),
           {:ok, lease_token} <- cast_uuid(lease_token) do
        DeliveryBoundary.acknowledge(
          runtime,
          validated_context,
          declaration,
          event_id,
          lease_token
        )
      end
    end)
  end

  @doc "Records one exact active lease failure using a bounded stable code."
  @spec fail(Supervisor.supervisor(), term(), term(), term(), term(), term(), term()) ::
          {:ok, Chimwemwe.Platform.Outbox.DeliveryResult.t()} | {:error, term()}
  def fail(runtime, registry, context, consumer_key, event_id, lease_token, failure_code) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key),
           {:ok, event_id} <- cast_uuid(event_id),
           {:ok, lease_token} <- cast_uuid(lease_token),
           {:ok, failure_code} <- validate_failure_code(failure_code) do
        DeliveryBoundary.fail(
          runtime,
          validated_context,
          declaration,
          event_id,
          lease_token,
          failure_code
        )
      end
    end)
  end

  @doc "Runs one exact active lease through its code-owned database-local consumer."
  @spec consume(Supervisor.supervisor(), term(), term(), term(), term()) ::
          {:ok, Chimwemwe.Platform.Outbox.ConsumptionResult.t()} | {:error, term()}
  def consume(runtime, registry, context, consumer_key, envelope) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key),
           {:ok, event_id, lease_token} <- validate_envelope(envelope) do
        ConsumptionBoundary.consume(
          runtime,
          validated_context,
          declaration,
          event_id,
          lease_token
        )
      end
    end)
  end

  @doc "Releases one exact dead-letter delivery through governed audited replay."
  @spec replay(Supervisor.supervisor(), term(), term(), term(), term()) ::
          {:ok, Chimwemwe.Platform.Outbox.ReplayResult.t()} | {:error, term()}
  def replay(runtime, registry, context, consumer_key, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key),
           {:ok, normalized} <- validate_replay_input(input) do
        ReplayBoundary.replay(runtime, validated_context, declaration, normalized)
      end
    end)
  end

  @doc "Returns a bounded cursor page of exact dead-letter references."
  def replay_page(runtime, registry, context, consumer_key, cursor) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key),
           {:ok, cursor} <- validate_replay_cursor(cursor) do
        ReplayCursorBoundary.page(runtime, validated_context, declaration, cursor)
      end
    end)
  end

  @doc "Replays a bounded ordered list of exact dead letters."
  def replay_range(runtime, registry, context, consumer_key, %ReplayRangeInput{items: items})
      when is_list(items) and items != [] and length(items) <= 100 do
    if Enum.uniq_by(items, & &1.event_id) == items do
      items
      |> replay_items(runtime, registry, context, consumer_key)
      |> case do
        {:ok, results} -> {:ok, %ReplayRangeResult{results: Enum.reverse(results)}}
        error -> error
      end
    else
      outbox_error(:invalid_input)
    end
  end

  def replay_range(_runtime, _registry, _context, _consumer_key, _input),
    do: outbox_error(:invalid_input)

  defp replay_items(items, runtime, registry, context, consumer_key) do
    Enum.reduce_while(items, {:ok, []}, fn input, {:ok, results} ->
      case replay(runtime, registry, context, consumer_key, input) do
        {:ok, result} -> {:cont, {:ok, [result | results]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  @doc "Returns sanitized count-only status for one code-owned consumer."
  @spec status(Supervisor.supervisor(), term(), term(), term()) ::
          {:ok, Chimwemwe.Platform.Outbox.Status.t()} | {:error, term()}
  def status(runtime, registry, context, consumer_key) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, registry} <- revalidate_registry(registry),
           {:ok, declaration} <- fetch_consumer(registry, consumer_key) do
        DeliveryBoundary.status(runtime, validated_context, declaration)
      end
    end)
  end

  defp revalidate_registry(registry) do
    case ConsumerRegistry.revalidate(registry) do
      {:ok, revalidated} -> {:ok, revalidated}
      {:error, :invalid_registry} -> outbox_error(:invalid_registry)
    end
  end

  defp fetch_consumer(registry, key) do
    case ConsumerRegistry.fetch(registry, key) do
      {:ok, declaration} -> {:ok, declaration}
      {:error, :consumer_not_available} -> outbox_error(:consumer_not_available)
    end
  end

  defp cast_uuid(value) do
    case UUID.cast_input(value, []) do
      {:ok, uuid} -> {:ok, uuid}
      _invalid -> outbox_error(:invalid_input)
    end
  end

  defp validate_failure_code(code) when code in @failure_codes, do: {:ok, code}
  defp validate_failure_code(_code), do: outbox_error(:invalid_input)

  defp validate_envelope(%Chimwemwe.Platform.Outbox.Envelope{} = envelope) do
    with {:ok, event_id} <- cast_uuid(envelope.event_id),
         {:ok, lease_token} <- cast_uuid(envelope.lease_token) do
      {:ok, event_id, lease_token}
    end
  end

  defp validate_envelope(_envelope), do: outbox_error(:invalid_input)

  defp validate_replay_input(%ReplayInput{} = input) do
    with {:ok, event_id} <- cast_uuid(input.event_id),
         {:ok, idempotency_key} <- cast_uuid(input.idempotency_key),
         {:ok, causation_id} <- cast_uuid(input.causation_id),
         true <- is_integer(input.expected_lock_version) and input.expected_lock_version > 0,
         {:ok, reason_code} <- validate_reason_code(input.reason_code) do
      {:ok,
       %ReplayInput{
         event_id: event_id,
         expected_lock_version: input.expected_lock_version,
         idempotency_key: idempotency_key,
         causation_id: causation_id,
         reason_code: reason_code
       }}
    else
      _invalid -> outbox_error(:invalid_input)
    end
  end

  defp validate_replay_input(_input), do: outbox_error(:invalid_input)

  defp validate_replay_cursor(%ReplayCursor{} = cursor)
       when is_integer(cursor.after_cursor) and cursor.after_cursor >= 0 and
              is_integer(cursor.through_cursor) and
              cursor.through_cursor > cursor.after_cursor and is_integer(cursor.limit) and
              cursor.limit in 1..100,
       do: {:ok, cursor}

  defp validate_replay_cursor(_cursor), do: outbox_error(:invalid_input)

  defp validate_reason_code(value) when is_binary(value) do
    normalized = String.trim(value)

    if byte_size(normalized) in 1..120 and
         Regex.match?(~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/, normalized) do
      {:ok, normalized}
    else
      outbox_error(:invalid_input)
    end
  end

  defp validate_reason_code(_value), do: outbox_error(:invalid_input)

  defp outbox_error(code), do: {:error, %OutboxError{code: code}}
end
