defmodule Chimwemwe.Platform.Outbox.ReplayBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, OutboxError, Persistence, TrustedActor}
  alias Chimwemwe.Platform.Outbox.{ConsumerRegistry, ReplayInput, ReplayResult}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @action_name "platform.outbox.delivery.replay"
  @aggregate_type "platform.outbox.delivery"
  @replay_capability "platform.outbox.replay"
  @lock_namespace "platform-outbox-delivery-replay"

  @claim_sql """
  INSERT INTO platform_authority_action_idempotency (
    id,
    tenant_id,
    actor_id,
    action_name,
    idempotency_key,
    aggregate_type,
    aggregate_id,
    request_hash,
    status,
    inserted_at,
    updated_at
  )
  VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'started',
          transaction_timestamp(), transaction_timestamp())
  ON CONFLICT (tenant_id, action_name, idempotency_key) DO NOTHING
  RETURNING id::text
  """

  @load_claim_sql """
  SELECT actor_id::text,
         aggregate_id::text,
         request_hash,
         status,
         result_payload,
         audit_reference::text,
         event_id::text
    FROM platform_authority_action_idempotency
   WHERE tenant_id = $1
     AND action_name = $2
     AND idempotency_key = $3
  FOR UPDATE
  """

  @delivery_sql """
  SELECT delivery.status,
         delivery.attempt_count,
         delivery.replay_count,
         delivery.lock_version,
         delivery.failure_code,
         event.event_type,
         event.schema_version,
         event.routing_version,
         event.classification
    FROM platform_outbox_deliveries AS delivery
    JOIN platform_outbox_events AS event
      ON event.id = delivery.event_id
     AND event.tenant_id = delivery.tenant_id
   WHERE delivery.tenant_id = $1
     AND delivery.consumer_key = $2
     AND delivery.event_id = $3
  FOR UPDATE OF delivery
  """

  @replay_sql """
  UPDATE platform_outbox_deliveries
     SET status = 'available',
         attempt_count = 0,
         replay_count = replay_count + 1,
         lock_version = lock_version + 1,
         lease_token = NULL,
         lease_expires_at = NULL,
         available_at = transaction_timestamp(),
         completed_at = NULL,
         updated_at = transaction_timestamp()
   WHERE tenant_id = $1
     AND consumer_key = $2
     AND event_id = $3
     AND status = 'dead_letter'
     AND lock_version = $4
  RETURNING lock_version, replay_count
  """

  @insert_audit_sql """
  INSERT INTO platform_authority_audit_events (
    id,
    tenant_id,
    actor_id,
    action_name,
    aggregate_type,
    aggregate_id,
    idempotency_key,
    correlation_id,
    causation_id,
    before_version,
    after_version,
    change_summary,
    occurred_at,
    inserted_at
  )
  VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb,
          transaction_timestamp(), transaction_timestamp())
  """

  @complete_claim_sql """
  UPDATE platform_authority_action_idempotency
     SET status = 'completed',
         result_payload = $2::jsonb,
         audit_reference = $3,
         event_id = $4,
         completed_at = transaction_timestamp(),
         updated_at = transaction_timestamp()
   WHERE id = $1
     AND status = 'started'
  """

  @spec replay(
          Supervisor.supervisor(),
          term(),
          ConsumerRegistry.declaration(),
          ReplayInput.t()
        ) :: {:ok, ReplayResult.t()} | {:error, term()}
  def replay(runtime, context, declaration, input) do
    run_writer(runtime, context, fn ->
      transaction(fn -> replay_or_rollback(context, declaration, input) end)
    end)
  end

  defp replay_or_rollback(context, declaration, input) do
    request_hash =
      request_hash({
        @action_name,
        declaration.key,
        declaration.handler_revision,
        input.event_id,
        input.expected_lock_version,
        input.reason_code,
        input.causation_id
      })

    with :ok <- require_capability(context),
         :ok <- lock(context, declaration, input),
         {:ok, claim} <- claim(context, input, request_hash),
         {:ok, result} <-
           execute_or_replay(context, declaration, input, request_hash, claim) do
      result
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp execute_or_replay(context, declaration, input, _request_hash, {:new, claim_id}) do
    execute(context, declaration, input, claim_id)
  end

  defp execute_or_replay(context, declaration, input, request_hash, {:existing, claim}) do
    if claim.status == "completed" and
         claim.actor_id == TrustedActor.actor_id(context.actor) and
         claim.aggregate_id == input.event_id and claim.event_id == input.event_id and
         claim.request_hash == request_hash do
      decode_result(claim.result_payload, claim.audit_reference, declaration, input)
    else
      outbox_error(:conflict)
    end
  end

  defp execute(context, declaration, input, claim_id) do
    with {:ok, delivery} <- load_delivery(context, declaration, input),
         :ok <- validate_delivery(delivery, context, declaration, input),
         {:ok, lock_version, replay_count} <- update_delivery(context, declaration, input),
         audit_reference <- UUID.generate(),
         result <- replay_result(declaration, input, audit_reference, lock_version, replay_count),
         :ok <- insert_audit(context, declaration, input, delivery, result),
         :ok <- complete_claim(claim_id, input, result) do
      {:ok, result}
    end
  end

  defp lock(context, declaration, input) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended($1::text || ':' || $2::text || ':' || $3::text || ':' || $4::text, 0)
           )
           """,
           [@lock_namespace, tenant_id, declaration.key, input.event_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _reason} -> outbox_error(:retryable_dependency)
    end
  end

  defp claim(context, input, request_hash) do
    claim_id = UUID.generate()
    tenant_id = TrustedActor.tenant_id(context.actor)
    actor_id = TrustedActor.actor_id(context.actor)

    params = [
      dump_uuid(claim_id),
      dump_uuid(tenant_id),
      dump_uuid(actor_id),
      @action_name,
      dump_uuid(input.idempotency_key),
      @aggregate_type,
      dump_uuid(input.event_id),
      request_hash
    ]

    case Repo.query(@claim_sql, params) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id}}
      {:ok, %{rows: []}} -> load_claim(tenant_id, input.idempotency_key)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp load_claim(tenant_id, idempotency_key) do
    case Repo.query(@load_claim_sql, [
           dump_uuid(tenant_id),
           @action_name,
           dump_uuid(idempotency_key)
         ]) do
      {:ok,
       %{
         rows: [
           [
             actor_id,
             aggregate_id,
             request_hash,
             status,
             result_payload,
             audit_reference,
             event_id
           ]
         ]
       }} ->
        {:ok,
         {:existing,
          %{
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            request_hash: request_hash,
            status: status,
            result_payload: result_payload,
            audit_reference: audit_reference,
            event_id: event_id
          }}}

      {:ok, %{rows: []}} ->
        outbox_error(:retryable_dependency)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp load_delivery(context, declaration, input) do
    case Repo.query(@delivery_sql, [
           dump_uuid(TrustedActor.tenant_id(context.actor)),
           declaration.key,
           dump_uuid(input.event_id)
         ]) do
      {:ok,
       %{
         rows: [
           [
             status,
             attempt_count,
             replay_count,
             lock_version,
             failure_code,
             event_type,
             schema_version,
             routing_version,
             classification
           ]
         ]
       }} ->
        {:ok,
         %{
           status: status,
           attempt_count: attempt_count,
           replay_count: replay_count,
           lock_version: lock_version,
           failure_code: failure_code,
           event_type: event_type,
           schema_version: schema_version,
           routing_version: routing_version,
           classification: classification
         }}

      {:ok, %{rows: []}} ->
        outbox_error(:not_found)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp validate_delivery(delivery, context, declaration, input) do
    if delivery.status == "dead_letter" and
         delivery.lock_version == input.expected_lock_version and
         not is_nil(delivery.failure_code) and
         delivery.routing_version == context.placement.routing_version and
         delivery.classification == "internal" and
         subscribed?(declaration, delivery.event_type, delivery.schema_version) do
      :ok
    else
      outbox_error(:conflict)
    end
  end

  defp update_delivery(context, declaration, input) do
    case Repo.query(@replay_sql, [
           dump_uuid(TrustedActor.tenant_id(context.actor)),
           declaration.key,
           dump_uuid(input.event_id),
           input.expected_lock_version
         ]) do
      {:ok, %{rows: [[lock_version, replay_count]]}} ->
        {:ok, lock_version, replay_count}

      {:ok, %{rows: []}} ->
        outbox_error(:conflict)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp insert_audit(context, declaration, input, delivery, result) do
    summary = %{
      "consumer_key" => declaration.key,
      "handler_revision" => declaration.handler_revision,
      "prior_attempt_count" => delivery.attempt_count,
      "prior_failure_code" => delivery.failure_code,
      "reason_code" => input.reason_code,
      "replay_count" => result.replay_count
    }

    params = [
      dump_uuid(result.audit_reference),
      dump_uuid(TrustedActor.tenant_id(context.actor)),
      dump_uuid(TrustedActor.actor_id(context.actor)),
      @action_name,
      @aggregate_type,
      dump_uuid(input.event_id),
      dump_uuid(input.idempotency_key),
      dump_uuid(context.correlation_id),
      dump_uuid(input.causation_id),
      input.expected_lock_version,
      result.lock_version,
      summary
    ]

    case Repo.query(@insert_audit_sql, params) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, input, result) do
    payload = %{
      "consumer_key" => result.consumer_key,
      "event_id" => result.event_id,
      "lock_version" => result.lock_version,
      "replay_count" => result.replay_count,
      "status" => Atom.to_string(result.status)
    }

    case Repo.query(@complete_claim_sql, [
           dump_uuid(claim_id),
           payload,
           dump_uuid(result.audit_reference),
           dump_uuid(input.event_id)
         ]) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> outbox_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp decode_result(payload, audit_reference, declaration, input)
       when is_map(payload) and is_binary(audit_reference) do
    expected_event_id = input.event_id
    expected_consumer_key = declaration.key

    with ^expected_event_id <- payload["event_id"],
         ^expected_consumer_key <- payload["consumer_key"],
         "available" <- payload["status"],
         lock_version when is_integer(lock_version) and lock_version > 0 <-
           payload["lock_version"],
         replay_count when is_integer(replay_count) and replay_count > 0 <-
           payload["replay_count"] do
      {:ok,
       replay_result(
         declaration,
         input,
         audit_reference,
         lock_version,
         replay_count
       )}
    else
      _invalid -> outbox_error(:conflict)
    end
  end

  defp decode_result(_payload, _audit_reference, _declaration, _input),
    do: outbox_error(:conflict)

  defp replay_result(declaration, input, audit_reference, lock_version, replay_count) do
    %ReplayResult{
      audit_reference: audit_reference,
      consumer_key: declaration.key,
      event_id: input.event_id,
      lock_version: lock_version,
      replay_count: replay_count,
      status: :available
    }
  end

  defp require_capability(context) do
    if Authority.actor_has_capability?(context.actor, @replay_capability) do
      :ok
    else
      outbox_error(:forbidden)
    end
  end

  defp subscribed?(declaration, event_type, schema_version) do
    Enum.any?(declaration.events, fn event ->
      event.type == event_type and schema_version in event.schema_versions
    end)
  end

  defp request_hash(request) do
    request
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
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

  defp translate_query_error(%PostgrexError{postgres: %{code: code}})
       when code in [
              :unique_violation,
              :foreign_key_violation,
              :check_violation,
              :exclusion_violation
            ],
       do: outbox_error(:conflict)

  defp translate_query_error(_error), do: outbox_error(:retryable_dependency)

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
  defp outbox_error(code), do: {:error, %OutboxError{code: code}}
end
