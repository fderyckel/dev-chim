defmodule Chimwemwe.InstitutionalStructure.Evidence do
  @moduledoc false

  alias Chimwemwe.InstitutionalStructure.Error
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @schema_version 1

  @spec claim(map(), String.t(), String.t(), String.t(), binary(), String.t()) ::
          {:ok, {:new, String.t()} | {:existing, map()}} | {:error, Error.t()}
  def claim(context, action_name, aggregate_type, idempotency_key, request_hash, aggregate_id) do
    claim_id = UUID.generate()

    case Repo.query(
           """
           INSERT INTO platform_authority_action_idempotency (
             id, tenant_id, actor_id, action_name, idempotency_key,
             aggregate_type, aggregate_id, request_hash, status, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'started',
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           ON CONFLICT (tenant_id, action_name, idempotency_key) DO NOTHING
           RETURNING id::text
           """,
           [
             dump_uuid(claim_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             action_name,
             dump_uuid(idempotency_key),
             aggregate_type,
             dump_uuid(aggregate_id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id}}
      {:ok, %{rows: []}} -> load_claim(context.tenant_id, action_name, idempotency_key)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  @spec replay(map(), String.t(), binary()) :: {:ok, map()} | {:error, Error.t()}
  def replay(claim, actor_id, request_hash) do
    if claim.status == "completed" and claim.actor_id == actor_id and
         claim.request_hash == request_hash and is_map(claim.result_payload) do
      {:ok, claim}
    else
      error(:idempotency_conflict)
    end
  end

  @spec record(map(), map()) ::
          {:ok, %{audit_reference: String.t(), event_id: String.t()}} | {:error, Error.t()}
  def record(context, attributes) do
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    with :ok <- insert_audit(context, attributes, audit_reference),
         :ok <- insert_outbox(context, attributes, audit_reference, event_id),
         :ok <- complete_claim(attributes, audit_reference, event_id) do
      {:ok, %{audit_reference: audit_reference, event_id: event_id}}
    end
  end

  defp load_claim(tenant_id, action_name, idempotency_key) do
    case Repo.query(
           """
           SELECT id::text, actor_id::text, aggregate_id::text, request_hash, status,
                  result_payload, audit_reference::text, event_id::text
           FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name = $2 AND idempotency_key = $3
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), action_name, dump_uuid(idempotency_key)]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
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
            id: id,
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            request_hash: request_hash,
            status: status,
            result_payload: result_payload,
            audit_reference: audit_reference,
            event_id: event_id
          }}}

      _missing_or_failed ->
        error(:retryable_dependency)
    end
  end

  defp insert_audit(context, attributes, audit_reference) do
    case Repo.query(
           """
           INSERT INTO platform_authority_audit_events (
             id, tenant_id, actor_id, action_name, aggregate_type, aggregate_id,
             idempotency_key, correlation_id, causation_id, before_version,
             after_version, change_summary, occurred_at, inserted_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [
             dump_uuid(audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             attributes.action_name,
             attributes.aggregate_type,
             dump_uuid(attributes.aggregate_id),
             dump_uuid(attributes.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(attributes.causation_id),
             attributes.before_version,
             attributes.after_version,
             attributes.change_summary
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp insert_outbox(context, attributes, audit_reference, event_id) do
    case Repo.query(
           """
           INSERT INTO platform_outbox_events (
             id, tenant_id, actor_id, aggregate_type, aggregate_id, event_type,
             schema_version, routing_version, correlation_id, causation_id,
             audit_reference, classification, payload, occurred_at, inserted_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'internal',
                   $12::jsonb, (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [
             dump_uuid(event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             attributes.aggregate_type,
             dump_uuid(attributes.aggregate_id),
             attributes.event_type,
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(attributes.causation_id),
             dump_uuid(audit_reference),
             attributes.event_payload
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp complete_claim(attributes, audit_reference, event_id) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed', result_payload = $2::jsonb,
               audit_reference = $3, event_id = $4,
               completed_at = (NOW() AT TIME ZONE 'utc'),
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE id = $1 AND status = 'started'
           """,
           [
             dump_uuid(attributes.claim_id),
             attributes.result_payload,
             dump_uuid(audit_reference),
             dump_uuid(event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
