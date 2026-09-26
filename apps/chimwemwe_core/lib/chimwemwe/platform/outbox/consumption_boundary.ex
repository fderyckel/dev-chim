defmodule Chimwemwe.Platform.Outbox.ConsumptionBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, OutboxError, Persistence, TrustedActor}

  alias Chimwemwe.Platform.Outbox.{
    ConsumerRegistry,
    ConsumptionResult,
    Envelope
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  @dispatch_capability "platform.outbox.dispatch"
  @failure_codes [:consumer_rejected, :invalid_contract, :retryable_dependency]
  @maximum_result_entries 32
  @maximum_result_bytes 4_096

  @leased_event_sql """
  SELECT delivery.status,
         delivery.lease_token,
         delivery.last_lease_token,
         delivery.lease_expires_at,
         delivery.lease_expires_at > transaction_timestamp() AS lease_active,
         delivery.attempt_count,
         event.tenant_id,
         event.actor_id,
         event.event_type,
         event.schema_version,
         event.routing_version,
         event.correlation_id,
         event.causation_id,
         event.occurred_at,
         event.classification,
         event.payload
    FROM platform_outbox_deliveries AS delivery
    JOIN platform_outbox_events AS event
      ON event.id = delivery.event_id
     AND event.tenant_id = delivery.tenant_id
   WHERE delivery.tenant_id = $1
     AND delivery.consumer_key = $2
     AND delivery.event_id = $3
  FOR UPDATE OF delivery
  """

  @receipt_sql """
  SELECT handler_revision,
         event_type,
         schema_version,
         routing_version,
         result_digest
    FROM platform_outbox_consumer_receipts
   WHERE tenant_id = $1
     AND consumer_key = $2
     AND event_id = $3
  """

  @insert_receipt_sql """
  INSERT INTO platform_outbox_consumer_receipts (
    id,
    tenant_id,
    event_id,
    consumer_key,
    handler_revision,
    event_type,
    schema_version,
    routing_version,
    result_digest,
    processed_at,
    inserted_at
  )
  VALUES (
    gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8,
    transaction_timestamp(), transaction_timestamp()
  )
  """

  @spec consume(
          Supervisor.supervisor(),
          term(),
          ConsumerRegistry.declaration(),
          String.t(),
          String.t()
        ) :: {:ok, ConsumptionResult.t()} | {:error, term()}
  def consume(runtime, context, declaration, event_id, lease_token) do
    run_writer(runtime, context, fn ->
      transaction(fn -> consume_or_rollback(context, declaration, event_id, lease_token) end)
    end)
  end

  defp consume_or_rollback(context, declaration, event_id, lease_token) do
    with :ok <- require_capability(context),
         {:ok, envelope} <- load_active_event(context, declaration, event_id, lease_token),
         {:ok, receipt} <- load_receipt(context, declaration, envelope),
         {:ok, result} <- consume_or_retain(context, declaration, envelope, receipt) do
      result
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp load_active_event(context, declaration, event_id, lease_token) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(@leased_event_sql, [
           dump_uuid(tenant_id),
           declaration.key,
           dump_uuid(event_id)
         ]) do
      {:ok, %{rows: [row]}} ->
        validate_active_event(row, context, declaration, event_id, lease_token)

      {:ok, %{rows: []}} ->
        outbox_error(:not_found)

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp validate_active_event(
         [
           "leased",
           lease_token,
           lease_token,
           lease_expires_at,
           true,
           attempt_count,
           tenant_id,
           actor_id,
           event_type,
           schema_version,
           routing_version,
           correlation_id,
           causation_id,
           occurred_at,
           "internal",
           payload
         ],
         context,
         declaration,
         event_id,
         requested_lease_token
       ) do
    lease_token = load_uuid(lease_token)

    if lease_token == requested_lease_token and
         routing_version == context.placement.routing_version and
         subscribed?(declaration, event_type, schema_version) do
      {:ok,
       %Envelope{
         event_id: event_id,
         tenant_id: load_uuid(tenant_id),
         actor_id: load_uuid(actor_id),
         event_type: event_type,
         schema_version: schema_version,
         routing_version: routing_version,
         correlation_id: load_uuid(correlation_id),
         causation_id: load_uuid(causation_id),
         occurred_at: utc_datetime(occurred_at),
         classification: :internal,
         payload: payload,
         attempt_count: attempt_count,
         lease_token: lease_token,
         lease_expires_at: utc_datetime(lease_expires_at)
       }}
    else
      outbox_error(:conflict)
    end
  end

  defp validate_active_event(_row, _context, _declaration, _event_id, _lease_token),
    do: outbox_error(:conflict)

  defp load_receipt(context, declaration, envelope) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(@receipt_sql, [
           dump_uuid(tenant_id),
           declaration.key,
           dump_uuid(envelope.event_id)
         ]) do
      {:ok, %{rows: []}} ->
        {:ok, nil}

      {:ok,
       %{
         rows: [
           [handler_revision, event_type, schema_version, routing_version, result_digest]
         ]
       }} ->
        if handler_revision == declaration.handler_revision and event_type == envelope.event_type and
             schema_version == envelope.schema_version and
             routing_version == envelope.routing_version do
          {:ok, result_digest}
        else
          outbox_error(:conflict)
        end

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp consume_or_retain(_context, declaration, envelope, result_digest)
       when is_binary(result_digest) do
    {:ok, consumption_result(declaration, envelope, result_digest, :already_processed)}
  end

  defp consume_or_retain(context, declaration, envelope, nil) do
    with {:ok, handler_result} <- invoke_handler(declaration.handler, envelope, context),
         {:ok, digest} <- validate_and_digest(handler_result),
         :ok <- insert_receipt(context, declaration, envelope, digest) do
      {:ok, consumption_result(declaration, envelope, digest, :processed)}
    end
  end

  defp invoke_handler(handler, envelope, context) do
    case handler.consume(envelope, context) do
      {:ok, result} -> {:ok, result}
      {:error, code} when code in @failure_codes -> outbox_error(code)
      _unexpected -> outbox_error(:invalid_contract)
    end
  rescue
    _error -> outbox_error(:consumer_rejected)
  catch
    _kind, _reason -> outbox_error(:consumer_rejected)
  end

  defp validate_and_digest(result)
       when is_map(result) and not is_struct(result) and
              map_size(result) <= @maximum_result_entries do
    if Enum.all?(result, &valid_result_entry?/1) do
      encoded = :erlang.term_to_binary(result, [:deterministic])

      if byte_size(encoded) <= @maximum_result_bytes do
        {:ok, :crypto.hash(:sha256, encoded)}
      else
        outbox_error(:invalid_contract)
      end
    else
      outbox_error(:invalid_contract)
    end
  end

  defp validate_and_digest(_result), do: outbox_error(:invalid_contract)

  defp valid_result_entry?({key, value}) when is_binary(key) and byte_size(key) in 1..120,
    do: is_nil(value) or is_boolean(value) or is_integer(value) or is_binary(value)

  defp valid_result_entry?(_entry), do: false

  defp insert_receipt(context, declaration, envelope, digest) do
    params = [
      dump_uuid(TrustedActor.tenant_id(context.actor)),
      dump_uuid(envelope.event_id),
      declaration.key,
      declaration.handler_revision,
      envelope.event_type,
      envelope.schema_version,
      envelope.routing_version,
      digest
    ]

    case Repo.query(@insert_receipt_sql, params) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, _reason} -> outbox_error(:retryable_dependency)
    end
  end

  defp consumption_result(declaration, envelope, digest, state) do
    %ConsumptionResult{
      consumer_key: declaration.key,
      event_id: envelope.event_id,
      handler_revision: declaration.handler_revision,
      result_digest: digest,
      state: state
    }
  end

  defp subscribed?(declaration, event_type, schema_version) do
    Enum.any?(declaration.events, fn event ->
      event.type == event_type and schema_version in event.schema_versions
    end)
  end

  defp require_capability(context) do
    if Authority.actor_has_capability?(context.actor, @dispatch_capability) do
      :ok
    else
      outbox_error(:forbidden)
    end
  end

  defp transaction(operation) do
    case Repo.transaction(operation) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  defp run_writer(runtime, context, operation) do
    case Persistence.with_writer(runtime, context, operation) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, error}} -> {:error, error}
      {:ok, _unexpected} -> outbox_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> outbox_error(:retryable_dependency)
  catch
    :exit, _reason -> outbox_error(:retryable_dependency)
  end

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
  defp load_uuid(uuid), do: UUID.load!(uuid)
  defp utc_datetime(%DateTime{} = value), do: value
  defp utc_datetime(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")
  defp outbox_error(code), do: {:error, %OutboxError{code: code}}
end
