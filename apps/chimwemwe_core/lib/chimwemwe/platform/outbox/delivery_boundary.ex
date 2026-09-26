defmodule Chimwemwe.Platform.Outbox.DeliveryBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, OutboxError, Persistence, TrustedActor}

  alias Chimwemwe.Platform.Outbox.{
    ConsumerRegistry,
    DeliveryResult,
    Envelope,
    Status
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  @dispatch_capability "platform.outbox.dispatch"
  @observe_capability "platform.outbox.observe"

  @claim_sql """
  WITH candidates AS (
    SELECT event.id AS event_id,
           event.tenant_id,
           event.actor_id,
           event.event_type,
           event.schema_version,
           event.routing_version,
           event.correlation_id,
           event.causation_id,
           event.occurred_at,
           event.classification,
           event.payload,
           gen_random_uuid() AS next_lease_token
      FROM platform_outbox_events AS event
      JOIN unnest($3::text[], $4::bigint[]) AS allowed(event_type, schema_version)
        ON allowed.event_type = event.event_type
       AND allowed.schema_version = event.schema_version
  LEFT JOIN platform_outbox_deliveries AS delivery
        ON delivery.tenant_id = event.tenant_id
       AND delivery.event_id = event.id
       AND delivery.consumer_key = $6
     WHERE event.tenant_id = $1
       AND event.routing_version = $2
       AND event.classification = 'internal'
       AND (
         delivery.id IS NULL OR
         (delivery.status = 'available' AND delivery.available_at <= transaction_timestamp()) OR
         (delivery.status = 'leased' AND delivery.lease_expires_at <= transaction_timestamp())
       )
  ORDER BY event.occurred_at, event.id
  FOR UPDATE OF event SKIP LOCKED
     LIMIT $5
  ), claimed AS (
    INSERT INTO platform_outbox_deliveries (
      id,
      tenant_id,
      event_id,
      consumer_key,
      status,
      attempt_count,
      lock_version,
      lease_token,
      last_lease_token,
      lease_expires_at,
      available_at,
      failure_code,
      first_claimed_at,
      last_claimed_at,
      completed_at,
      inserted_at,
      updated_at
    )
    SELECT gen_random_uuid(),
           $1,
           candidate.event_id,
           $6,
           'leased',
           1,
           1,
           candidate.next_lease_token,
           candidate.next_lease_token,
           transaction_timestamp() + ($7::bigint * interval '1 millisecond'),
           transaction_timestamp(),
           NULL,
           transaction_timestamp(),
           transaction_timestamp(),
           NULL,
           transaction_timestamp(),
           transaction_timestamp()
      FROM candidates AS candidate
    ON CONFLICT (event_id, tenant_id, consumer_key) DO UPDATE
       SET status = 'leased',
           attempt_count = platform_outbox_deliveries.attempt_count + 1,
           lock_version = platform_outbox_deliveries.lock_version + 1,
           lease_token = EXCLUDED.lease_token,
           last_lease_token = EXCLUDED.last_lease_token,
           lease_expires_at = EXCLUDED.lease_expires_at,
           available_at = transaction_timestamp(),
           failure_code = NULL,
           last_claimed_at = transaction_timestamp(),
           completed_at = NULL,
           updated_at = transaction_timestamp()
     WHERE (platform_outbox_deliveries.status = 'available' AND
              platform_outbox_deliveries.available_at <= transaction_timestamp())
        OR (platform_outbox_deliveries.status = 'leased' AND
              platform_outbox_deliveries.lease_expires_at <= transaction_timestamp())
    RETURNING event_id, attempt_count, lease_token, lease_expires_at
  )
  SELECT candidate.event_id,
         candidate.tenant_id,
         candidate.actor_id,
         candidate.event_type,
         candidate.schema_version,
         candidate.routing_version,
         candidate.correlation_id,
         candidate.causation_id,
         candidate.occurred_at,
         candidate.classification,
         candidate.payload,
         claimed.attempt_count,
         claimed.lease_token,
         claimed.lease_expires_at
    FROM claimed
    JOIN candidates AS candidate ON candidate.event_id = claimed.event_id
  ORDER BY candidate.occurred_at, candidate.event_id
  """

  @delivery_sql """
  SELECT delivery.status,
         delivery.attempt_count,
         delivery.lock_version,
         delivery.lease_token,
         delivery.last_lease_token,
         delivery.lease_expires_at,
         delivery.available_at,
         delivery.failure_code,
         delivery.completed_at,
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

  @complete_sql """
  UPDATE platform_outbox_deliveries
     SET status = 'completed',
         lock_version = lock_version + 1,
         lease_token = NULL,
         lease_expires_at = NULL,
         failure_code = NULL,
         completed_at = transaction_timestamp(),
         updated_at = transaction_timestamp()
   WHERE tenant_id = $1
     AND consumer_key = $2
     AND event_id = $3
     AND status = 'leased'
     AND lease_token = $4
     AND lease_expires_at > transaction_timestamp()
  RETURNING attempt_count, available_at, completed_at, lock_version, status
  """

  @fail_sql """
  UPDATE platform_outbox_deliveries
     SET status = $5,
         lock_version = lock_version + 1,
         lease_token = NULL,
         lease_expires_at = NULL,
         available_at = CASE
           WHEN $5 = 'available'
             THEN transaction_timestamp() + ($6::bigint * interval '1 millisecond')
           ELSE transaction_timestamp()
         END,
         failure_code = $7,
         completed_at = NULL,
         updated_at = transaction_timestamp()
   WHERE tenant_id = $1
     AND consumer_key = $2
     AND event_id = $3
     AND status = 'leased'
     AND lease_token = $4
     AND lease_expires_at > transaction_timestamp()
  RETURNING attempt_count, available_at, completed_at, lock_version, status
  """

  @status_sql """
  SELECT count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.id IS NULL
         ) AS unclaimed,
         count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.status = 'available'
         ) AS available,
         count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.status = 'leased'
             AND delivery.lease_expires_at > transaction_timestamp()
         ) AS leased,
         count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.status = 'leased'
             AND delivery.lease_expires_at <= transaction_timestamp()
         ) AS expired_lease,
         count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.status = 'completed'
         ) AS completed,
         count(*) FILTER (
           WHERE event.routing_version = $2 AND delivery.status = 'dead_letter'
         ) AS dead_letter,
         count(*) FILTER (
           WHERE event.routing_version <> $2
         ) AS stale_route,
         min(event.occurred_at) FILTER (
           WHERE event.routing_version = $2 AND (
             delivery.id IS NULL OR
             delivery.status = 'available' OR
             (delivery.status = 'leased' AND
               delivery.lease_expires_at <= transaction_timestamp())
           )
         ) AS oldest_pending_at
    FROM platform_outbox_events AS event
    JOIN unnest($3::text[], $4::bigint[]) AS allowed(event_type, schema_version)
      ON allowed.event_type = event.event_type
     AND allowed.schema_version = event.schema_version
    LEFT JOIN platform_outbox_deliveries AS delivery
      ON delivery.tenant_id = event.tenant_id
     AND delivery.event_id = event.id
     AND delivery.consumer_key = $5
   WHERE event.tenant_id = $1
     AND event.classification = 'internal'
  """

  @spec claim(Supervisor.supervisor(), term(), ConsumerRegistry.declaration()) ::
          {:ok, [Envelope.t()]} | {:error, term()}
  def claim(runtime, context, declaration) do
    run_writer(runtime, context, fn -> claim_transaction(context, declaration) end)
  end

  @spec acknowledge(
          Supervisor.supervisor(),
          term(),
          ConsumerRegistry.declaration(),
          String.t(),
          String.t()
        ) :: {:ok, DeliveryResult.t()} | {:error, term()}
  def acknowledge(runtime, context, declaration, event_id, lease_token) do
    transition(runtime, context, declaration, event_id, fn row ->
      acknowledge_row(context, declaration, event_id, lease_token, row)
    end)
  end

  @spec fail(
          Supervisor.supervisor(),
          term(),
          ConsumerRegistry.declaration(),
          String.t(),
          String.t(),
          atom()
        ) :: {:ok, DeliveryResult.t()} | {:error, term()}
  def fail(runtime, context, declaration, event_id, lease_token, failure_code) do
    transition(runtime, context, declaration, event_id, fn row ->
      fail_row(context, declaration, event_id, lease_token, failure_code, row)
    end)
  end

  @spec status(Supervisor.supervisor(), term(), ConsumerRegistry.declaration()) ::
          {:ok, Status.t()} | {:error, term()}
  def status(runtime, context, declaration) do
    run_writer(runtime, context, fn ->
      case require_capability(context, @observe_capability) do
        :ok -> read_status(context, declaration)
        {:error, _error} = error -> error
      end
    end)
  end

  defp transition(runtime, context, declaration, event_id, operation) do
    run_writer(runtime, context, fn ->
      transition_transaction(context, declaration, event_id, operation)
    end)
  end

  defp claim_transaction(context, declaration) do
    transaction(fn -> claim_or_rollback(context, declaration) end)
  end

  defp claim_or_rollback(context, declaration) do
    with :ok <- require_capability(context, @dispatch_capability),
         {:ok, envelopes} <- claim_batch(context, declaration) do
      envelopes
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp transition_transaction(context, declaration, event_id, operation) do
    transaction(fn -> transition_or_rollback(context, declaration, event_id, operation) end)
  end

  defp transition_or_rollback(context, declaration, event_id, operation) do
    with :ok <- require_capability(context, @dispatch_capability),
         {:ok, row} <- load_delivery(context, declaration, event_id),
         {:ok, result} <- operation.(row) do
      result
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp transaction(operation) do
    case Repo.transaction(operation) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  defp claim_batch(context, declaration) do
    tenant_id = TrustedActor.tenant_id(context.actor)
    {event_types, schema_versions} = ConsumerRegistry.event_pairs(declaration)

    params = [
      dump_uuid(tenant_id),
      context.placement.routing_version,
      event_types,
      schema_versions,
      declaration.batch_size,
      declaration.key,
      declaration.lease_ms
    ]

    case Repo.query(@claim_sql, params) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &envelope/1)}
      {:error, _reason} -> outbox_error(:retryable_dependency)
    end
  end

  defp envelope([
         event_id,
         tenant_id,
         actor_id,
         event_type,
         schema_version,
         routing_version,
         correlation_id,
         causation_id,
         occurred_at,
         "internal",
         payload,
         attempt_count,
         lease_token,
         lease_expires_at
       ]) do
    %Envelope{
      event_id: load_uuid(event_id),
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
      lease_token: load_uuid(lease_token),
      lease_expires_at: utc_datetime(lease_expires_at)
    }
  end

  defp load_delivery(context, declaration, event_id) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(@delivery_sql, [
           dump_uuid(tenant_id),
           declaration.key,
           dump_uuid(event_id)
         ]) do
      {:ok, %{rows: [row]}} ->
        row |> normalize_delivery_row() |> validate_delivery_contract(context, declaration)

      {:ok, %{rows: []}} ->
        outbox_error(:not_found)

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp validate_delivery_contract(row, context, declaration) do
    [
      _status,
      _attempt_count,
      _lock_version,
      _lease_token,
      _last_lease_token,
      _lease_expires_at,
      _available_at,
      _failure_code,
      _completed_at,
      event_type,
      schema_version,
      routing_version,
      classification
    ] = row

    if subscribed?(declaration, event_type, schema_version) and
         routing_version == context.placement.routing_version and classification == "internal" do
      {:ok, row}
    else
      outbox_error(:conflict)
    end
  end

  defp acknowledge_row(context, declaration, event_id, lease_token, row) do
    case row do
      [
        "completed",
        attempts,
        version,
        _token,
        ^lease_token,
        _expires,
        available_at,
        nil,
        completed_at | _contract
      ] ->
        {:ok,
         delivery_result(
           declaration,
           event_id,
           "completed",
           attempts,
           version,
           available_at,
           completed_at
         )}

      ["leased", _attempts, _version, ^lease_token, ^lease_token, expires | _rest]
      when not is_nil(expires) ->
        complete(context, declaration, event_id, lease_token)

      _other ->
        outbox_error(:conflict)
    end
  end

  defp complete(context, declaration, event_id, lease_token) do
    tenant_id = TrustedActor.tenant_id(context.actor)

    case Repo.query(@complete_sql, [
           dump_uuid(tenant_id),
           declaration.key,
           dump_uuid(event_id),
           dump_uuid(lease_token)
         ]) do
      {:ok, %{rows: [[attempts, available_at, completed_at, version, status]]}} ->
        {:ok,
         delivery_result(
           declaration,
           event_id,
           status,
           attempts,
           version,
           available_at,
           completed_at
         )}

      {:ok, %{rows: []}} ->
        outbox_error(:conflict)

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp fail_row(context, declaration, event_id, lease_token, failure_code, row) do
    case row do
      [
        status,
        attempts,
        version,
        _token,
        ^lease_token,
        _expires,
        available_at,
        stored_failure,
        completed_at | _contract
      ]
      when status in ["available", "dead_letter"] ->
        if stored_failure == Atom.to_string(failure_code) do
          {:ok,
           delivery_result(
             declaration,
             event_id,
             status,
             attempts,
             version,
             available_at,
             completed_at
           )}
        else
          outbox_error(:conflict)
        end

      ["leased", attempts, _version, ^lease_token, ^lease_token, expires | _rest]
      when not is_nil(expires) ->
        record_failure(
          context,
          declaration,
          event_id,
          lease_token,
          failure_code,
          attempts
        )

      _other ->
        outbox_error(:conflict)
    end
  end

  defp record_failure(context, declaration, event_id, lease_token, failure_code, attempts) do
    tenant_id = TrustedActor.tenant_id(context.actor)
    status = if attempts >= declaration.max_attempts, do: "dead_letter", else: "available"

    params = [
      dump_uuid(tenant_id),
      declaration.key,
      dump_uuid(event_id),
      dump_uuid(lease_token),
      status,
      declaration.retry_ms,
      Atom.to_string(failure_code)
    ]

    case Repo.query(@fail_sql, params) do
      {:ok, %{rows: [[attempts, available_at, completed_at, version, returned_status]]}} ->
        {:ok,
         delivery_result(
           declaration,
           event_id,
           returned_status,
           attempts,
           version,
           available_at,
           completed_at
         )}

      {:ok, %{rows: []}} ->
        outbox_error(:conflict)

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp read_status(context, declaration) do
    tenant_id = TrustedActor.tenant_id(context.actor)
    {event_types, schema_versions} = ConsumerRegistry.event_pairs(declaration)

    params = [
      dump_uuid(tenant_id),
      context.placement.routing_version,
      event_types,
      schema_versions,
      declaration.key
    ]

    case Repo.query(@status_sql, params) do
      {:ok,
       %{
         rows: [
           [
             unclaimed,
             available,
             leased,
             expired_lease,
             completed,
             dead_letter,
             stale_route,
             oldest_pending_at
           ]
         ]
       }} ->
        {:ok,
         %Status{
           unclaimed: unclaimed,
           available: available,
           leased: leased,
           expired_lease: expired_lease,
           completed: completed,
           dead_letter: dead_letter,
           stale_route: stale_route,
           oldest_pending_at: utc_datetime(oldest_pending_at)
         }}

      {:error, _reason} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp subscribed?(declaration, event_type, schema_version) do
    Enum.any?(declaration.events, fn event ->
      event.type == event_type and schema_version in event.schema_versions
    end)
  end

  defp normalize_delivery_row(row) do
    row
    |> List.update_at(3, &load_optional_uuid/1)
    |> List.update_at(4, &load_uuid/1)
  end

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
  defp load_uuid(uuid), do: UUID.load!(uuid)
  defp load_optional_uuid(nil), do: nil
  defp load_optional_uuid(uuid), do: load_uuid(uuid)

  defp require_capability(context, capability) do
    if Authority.actor_has_capability?(context.actor, capability) do
      :ok
    else
      outbox_error(:forbidden)
    end
  end

  defp delivery_result(
         declaration,
         event_id,
         status,
         attempts,
         version,
         available_at,
         completed_at
       ) do
    %DeliveryResult{
      consumer_key: declaration.key,
      event_id: event_id,
      status: String.to_existing_atom(status),
      attempt_count: attempts,
      lock_version: version,
      available_at: utc_datetime(available_at),
      completed_at: utc_datetime(completed_at)
    }
  end

  defp utc_datetime(nil), do: nil
  defp utc_datetime(%DateTime{} = value), do: value
  defp utc_datetime(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")

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

  defp outbox_error(code), do: {:error, %OutboxError{code: code}}
end
