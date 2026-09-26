defmodule Chimwemwe.Platform.TemporalQualification.OperationEvidence do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, TemporalQualificationError, TrustedActor}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @spec context(map()) :: {:ok, map()} | {:error, TemporalQualificationError.t()}
  def context(%{
        actor: actor,
        tenant: tenant_id,
        source_context: %{
          chimwemwe: %{
            correlation_id: correlation_id,
            purpose: purpose,
            routing_version: routing_version
          }
        }
      }) do
    with {:ok, trusted_actor} <- TrustedActor.revalidate(actor),
         true <- tenant_id == TrustedActor.tenant_id(trusted_actor),
         {:ok, correlation_id} <- cast_uuid(correlation_id),
         true <- is_binary(purpose) and byte_size(String.trim(purpose)) in 1..160,
         true <- is_integer(routing_version) and routing_version > 0 do
      {:ok,
       %{
         actor: trusted_actor,
         actor_id: TrustedActor.actor_id(trusted_actor),
         tenant_id: tenant_id,
         correlation_id: correlation_id,
         purpose: String.trim(purpose),
         routing_version: routing_version
       }}
    else
      _invalid -> temporal_error(:forbidden)
    end
  end

  def context(_context), do: temporal_error(:forbidden)

  @spec authorize(map(), String.t()) :: :ok | {:error, TemporalQualificationError.t()}
  def authorize(context, capability) do
    if Authority.actor_has_capability?(context.actor, capability) do
      :ok
    else
      temporal_error(:forbidden)
    end
  end

  @spec lock(String.t(), String.t(), String.t()) ::
          :ok | {:error, TemporalQualificationError.t()}
  def lock(namespace, tenant_id, aggregate_id) do
    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended($1::text || ':' || $2::text || ':' || $3::text, 0)
           )
           """,
           [namespace, tenant_id, aggregate_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  @spec request_hash(term()) :: binary()
  def request_hash(canonical_request) do
    canonical_request
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  @spec claim(map(), map()) :: {:ok, {:new, String.t()} | {:existing, map()}} | {:error, term()}
  def claim(context, spec) do
    claim_id = UUID.generate()

    case Repo.query(
           """
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
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'started', NOW(), NOW())
           ON CONFLICT (tenant_id, action_name, idempotency_key) DO NOTHING
           RETURNING id::text
           """,
           [
             dump_uuid(claim_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             spec.action_name,
             dump_uuid(spec.idempotency_key),
             spec.aggregate_type,
             dump_uuid(spec.aggregate_id),
             spec.request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id}}
      {:ok, %{rows: []}} -> load_claim(context.tenant_id, spec)
      {:error, error} -> translate_query_error(error)
    end
  end

  @spec exact_replay?(map(), map(), String.t(), binary()) :: boolean()
  def exact_replay?(claim, context, aggregate_id, request_hash) do
    claim.status == "completed" and claim.actor_id == context.actor_id and
      claim.aggregate_id == aggregate_id and claim.request_hash == request_hash
  end

  @spec insert_evidence(map(), map()) :: :ok | {:error, TemporalQualificationError.t()}
  def insert_evidence(context, spec) do
    case insert_audit(context, spec) do
      :ok -> insert_outbox(context, spec)
      {:error, _reason} = error -> error
    end
  end

  @spec complete_claim(String.t(), map(), String.t(), String.t()) ::
          :ok | {:error, TemporalQualificationError.t()}
  def complete_claim(claim_id, payload, audit_reference, event_id) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed',
               result_payload = $2::jsonb,
               audit_reference = $3,
               event_id = $4,
               completed_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND status = 'started'
           """,
           [
             dump_uuid(claim_id),
             payload,
             dump_uuid(audit_reference),
             dump_uuid(event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> temporal_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  @spec translate_query_error(term()) :: {:error, TemporalQualificationError.t()}
  def translate_query_error(%PostgrexError{postgres: %{code: code}})
      when code in [
             :unique_violation,
             :foreign_key_violation,
             :check_violation,
             :exclusion_violation
           ],
      do: temporal_error(:conflict)

  def translate_query_error(_error), do: temporal_error(:retryable_dependency)

  @spec cast_uuid(term()) :: {:ok, String.t()} | {:error, TemporalQualificationError.t()}
  def cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> temporal_error(:invalid_input)
    end
  end

  @spec dump_uuid(String.t() | nil) :: binary() | nil
  def dump_uuid(nil), do: nil
  def dump_uuid(value), do: UUID.dump!(value)

  defp load_claim(tenant_id, spec) do
    case Repo.query(
           """
           SELECT
             actor_id::text,
             aggregate_id::text,
             request_hash,
             status,
             result_payload,
             audit_reference::text,
             event_id::text
           FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name = $2 AND idempotency_key = $3
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), spec.action_name, dump_uuid(spec.idempotency_key)]
         ) do
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
        temporal_error(:retryable_dependency)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp insert_audit(context, spec) do
    case Repo.query(
           """
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
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, NOW(), NOW())
           """,
           [
             dump_uuid(spec.audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             spec.action_name,
             spec.aggregate_type,
             dump_uuid(spec.aggregate_id),
             dump_uuid(spec.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(spec.causation_id),
             spec.before_version,
             spec.after_version,
             spec.summary
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(context, spec) do
    case Repo.query(
           """
           INSERT INTO platform_outbox_events (
             id,
             tenant_id,
             actor_id,
             aggregate_type,
             aggregate_id,
             event_type,
             schema_version,
             routing_version,
             correlation_id,
             causation_id,
             audit_reference,
             classification,
             payload,
             occurred_at,
             inserted_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, 1, $7, $8, $9, $10, 'internal', $11::jsonb, NOW(), NOW()
           )
           """,
           [
             dump_uuid(spec.event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             spec.aggregate_type,
             dump_uuid(spec.aggregate_id),
             spec.event_type,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(spec.causation_id),
             dump_uuid(spec.audit_reference),
             spec.payload
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
