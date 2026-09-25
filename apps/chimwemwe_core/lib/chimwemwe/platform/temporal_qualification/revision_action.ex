defmodule Chimwemwe.Platform.TemporalQualification.RevisionAction do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, TemporalQualificationError, TrustedActor}

  alias Chimwemwe.Platform.TemporalQualification.{RevisionResult, SegmentView}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @aggregate_type "platform.temporal_qualification.aggregate"
  @schema_version 1
  @modes [:publish, :correct]

  @spec run(:publish | :correct, Ash.ActionInput.t(), keyword(), map()) ::
          {:ok, RevisionResult.t()} | {:error, TemporalQualificationError.t()}
  def run(mode, input, _options, context) when mode in @modes do
    with {:ok, action_context} <- validate_context(context),
         :ok <- lock_writes(action_context.tenant_id, input.arguments.aggregate_id),
         :ok <- reauthorize(action_context.actor, capability(mode)),
         request_hash <- request_hash(mode, input.arguments),
         {:ok, claim} <- claim(mode, action_context, input.arguments, request_hash) do
      execute_or_replay(mode, action_context, input.arguments, request_hash, claim)
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp validate_context(%{
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
         true <- is_binary(purpose) and byte_size(String.trim(purpose)) > 0,
         true <- is_integer(routing_version) and routing_version > 0 do
      {:ok,
       %{
         actor: trusted_actor,
         actor_id: TrustedActor.actor_id(trusted_actor),
         tenant_id: tenant_id,
         correlation_id: correlation_id,
         purpose: purpose,
         routing_version: routing_version
       }}
    else
      _invalid -> temporal_error(:forbidden)
    end
  end

  defp validate_context(_context), do: temporal_error(:forbidden)

  defp lock_writes(tenant_id, aggregate_id) do
    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended(
               'platform-temporal-qualification-write:' || $1::text || ':' || $2::text,
               0
             )
           )
           """,
           [tenant_id, aggregate_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> temporal_error(:retryable_dependency)
    end
  end

  defp reauthorize(actor, capability) do
    if Authority.actor_has_capability?(actor, capability) do
      :ok
    else
      temporal_error(:forbidden)
    end
  end

  defp claim(mode, context, arguments, request_hash) do
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
             action_name(mode),
             dump_uuid(arguments.idempotency_key),
             @aggregate_type,
             dump_uuid(arguments.aggregate_id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} ->
        {:ok, {:new, claim_id}}

      {:ok, %{rows: []}} ->
        load_claim(mode, context.tenant_id, arguments.idempotency_key)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp load_claim(mode, tenant_id, idempotency_key) do
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
           [dump_uuid(tenant_id), action_name(mode), dump_uuid(idempotency_key)]
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

  defp execute_or_replay(mode, context, arguments, request_hash, {:new, claim_id}) do
    execute(mode, context, arguments, claim_id, request_hash)
  end

  defp execute_or_replay(_mode, context, arguments, request_hash, {:existing, claim}) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.aggregate_id == arguments.aggregate_id and claim.request_hash == request_hash do
      decode_result(claim.result_payload, claim.audit_reference, claim.event_id)
    else
      temporal_error(:idempotency_conflict)
    end
  end

  defp execute(:publish, context, arguments, claim_id, _request_hash) do
    with :ok <- insert_aggregate(context.tenant_id, arguments.aggregate_id, arguments.scope_id),
         {:ok, result} <-
           create_revision(
             context,
             arguments,
             arguments.scope_id,
             1,
             nil
           ),
         :ok <- select_current(context.tenant_id, arguments.aggregate_id, nil, result.revision_id),
         :ok <- insert_evidence(:publish, context, arguments, result),
         :ok <- complete_claim(claim_id, result) do
      {:ok, result}
    end
  end

  defp execute(:correct, context, arguments, claim_id, _request_hash) do
    with {:ok, aggregate} <- lock_aggregate(context.tenant_id, arguments.aggregate_id),
         :ok <-
           require_expected_revision(
             aggregate.current_revision_id,
             arguments.expected_revision_id
           ),
         {:ok, current_revision} <-
           load_current_revision(
             context.tenant_id,
             arguments.aggregate_id,
             arguments.expected_revision_id
           ),
         {:ok, result} <-
           create_revision(
             context,
             arguments,
             aggregate.scope_id,
             current_revision.aggregate_revision + 1,
             arguments.expected_revision_id
           ),
         :ok <-
           select_current(
             context.tenant_id,
             arguments.aggregate_id,
             arguments.expected_revision_id,
             result.revision_id
           ),
         :ok <- insert_evidence(:correct, context, arguments, result),
         :ok <- complete_claim(claim_id, result) do
      {:ok, result}
    end
  end

  defp insert_aggregate(tenant_id, aggregate_id, scope_id) do
    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_aggregates (
             id, tenant_id, scope_id, current_revision_id, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, NULL, NOW(), NOW())
           """,
           [dump_uuid(aggregate_id), dump_uuid(tenant_id), dump_uuid(scope_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp lock_aggregate(tenant_id, aggregate_id) do
    case Repo.query(
           """
           SELECT scope_id::text, current_revision_id::text
           FROM platform_temporal_qualification_aggregates
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), dump_uuid(aggregate_id)]
         ) do
      {:ok, %{rows: [[scope_id, current_revision_id]]}} ->
        {:ok, %{scope_id: scope_id, current_revision_id: current_revision_id}}

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp require_expected_revision(revision_id, revision_id), do: :ok
  defp require_expected_revision(_current, _expected), do: temporal_error(:conflict)

  defp load_current_revision(tenant_id, aggregate_id, revision_id) do
    case Repo.query(
           """
           SELECT aggregate_revision
           FROM platform_temporal_qualification_revisions
           WHERE tenant_id = $1 AND aggregate_id = $2 AND id = $3
           FOR SHARE
           """,
           [dump_uuid(tenant_id), dump_uuid(aggregate_id), dump_uuid(revision_id)]
         ) do
      {:ok, %{rows: [[aggregate_revision]]}} ->
        {:ok, %{aggregate_revision: aggregate_revision}}

      {:ok, %{rows: []}} ->
        temporal_error(:conflict)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp create_revision(context, arguments, _scope_id, aggregate_revision, predecessor_revision_id) do
    revision_id = UUID.generate()
    operation_id = UUID.generate()

    with {:ok, recorded_at} <-
           insert_revision(
             context.tenant_id,
             arguments.aggregate_id,
             revision_id,
             operation_id,
             aggregate_revision,
             predecessor_revision_id,
             arguments.reason_code
           ),
         {:ok, segments} <-
           insert_segments(
             context.tenant_id,
             arguments.aggregate_id,
             revision_id,
             arguments.segments
           ) do
      {:ok,
       %RevisionResult{
         aggregate_id: arguments.aggregate_id,
         revision_id: revision_id,
         operation_id: operation_id,
         aggregate_revision: aggregate_revision,
         predecessor_revision_id: predecessor_revision_id,
         reason_code: arguments.reason_code,
         recorded_at: recorded_at,
         segments: segments,
         audit_reference: UUID.generate(),
         event_id: UUID.generate()
       }}
    end
  end

  defp insert_revision(
         tenant_id,
         aggregate_id,
         revision_id,
         operation_id,
         aggregate_revision,
         predecessor_revision_id,
         reason_code
       ) do
    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_revisions (
             id,
             tenant_id,
             aggregate_id,
             operation_id,
             aggregate_revision,
             predecessor_revision_id,
             reason_code,
             recorded_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
           RETURNING recorded_at
           """,
           [
             dump_uuid(revision_id),
             dump_uuid(tenant_id),
             dump_uuid(aggregate_id),
             dump_uuid(operation_id),
             aggregate_revision,
             dump_uuid(predecessor_revision_id),
             reason_code
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_segments(tenant_id, aggregate_id, revision_id, segments) do
    segments
    |> Enum.reduce_while({:ok, []}, fn segment, {:ok, inserted} ->
      segment_id = UUID.generate()

      case Repo.query(
             """
             INSERT INTO platform_temporal_qualification_segments (
               id,
               tenant_id,
               aggregate_id,
               revision_id,
               effective_from,
               effective_until,
               value
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             """,
             [
               dump_uuid(segment_id),
               dump_uuid(tenant_id),
               dump_uuid(aggregate_id),
               dump_uuid(revision_id),
               segment.effective_from,
               segment.effective_until,
               segment.value
             ]
           ) do
        {:ok, %{num_rows: 1}} ->
          segment_view =
            struct!(SegmentView,
              id: segment_id,
              effective_from: segment.effective_from,
              effective_until: segment.effective_until,
              value: segment.value
            )

          {:cont, {:ok, [segment_view | inserted]}}

        {:error, error} ->
          {:halt, translate_query_error(error)}
      end
    end)
    |> case do
      {:ok, inserted} -> {:ok, Enum.reverse(inserted)}
      error -> error
    end
  end

  defp select_current(tenant_id, aggregate_id, nil, revision_id) do
    case Repo.query(
           """
           UPDATE platform_temporal_qualification_aggregates
           SET current_revision_id = $1, updated_at = NOW()
           WHERE tenant_id = $2 AND id = $3 AND current_revision_id IS NULL
           """,
           [dump_uuid(revision_id), dump_uuid(tenant_id), dump_uuid(aggregate_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> temporal_error(:conflict)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp select_current(tenant_id, aggregate_id, expected_revision_id, revision_id) do
    case Repo.query(
           """
           UPDATE platform_temporal_qualification_aggregates
           SET current_revision_id = $1, updated_at = NOW()
           WHERE tenant_id = $2 AND id = $3 AND current_revision_id = $4
           """,
           [
             dump_uuid(revision_id),
             dump_uuid(tenant_id),
             dump_uuid(aggregate_id),
             dump_uuid(expected_revision_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> temporal_error(:conflict)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_evidence(mode, context, arguments, result) do
    case insert_audit(mode, context, arguments, result) do
      :ok -> insert_outbox(mode, context, arguments, result)
      error -> error
    end
  end

  defp insert_audit(mode, context, arguments, result) do
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
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
             jsonb_build_object(
               'revision_id', $12::uuid,
               'operation_id', $13::uuid,
               'reason_code', $14::text,
               'purpose', $15::text,
               'segment_count', $16::bigint
             ),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(result.audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             action_name(mode),
             @aggregate_type,
             dump_uuid(result.aggregate_id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             result.aggregate_revision - 1,
             result.aggregate_revision,
             dump_uuid(result.revision_id),
             dump_uuid(result.operation_id),
             result.reason_code,
             context.purpose,
             length(result.segments)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(mode, context, arguments, result) do
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
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'internal',
             jsonb_strip_nulls(jsonb_build_object(
               'revision_id', $12::uuid,
               'operation_id', $13::uuid,
               'aggregate_revision', $14::bigint,
               'predecessor_revision_id', $15::uuid,
               'segment_count', $16::bigint
             )),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(result.event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @aggregate_type,
             dump_uuid(result.aggregate_id),
             event_type(mode),
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(result.audit_reference),
             dump_uuid(result.revision_id),
             dump_uuid(result.operation_id),
             result.aggregate_revision,
             dump_uuid(result.predecessor_revision_id),
             length(result.segments)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, result) do
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
             result_payload(result),
             dump_uuid(result.audit_reference),
             dump_uuid(result.event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> temporal_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp result_payload(result) do
    %{
      "aggregate_id" => result.aggregate_id,
      "revision_id" => result.revision_id,
      "operation_id" => result.operation_id,
      "aggregate_revision" => result.aggregate_revision,
      "predecessor_revision_id" => result.predecessor_revision_id,
      "reason_code" => result.reason_code,
      "recorded_at" => NaiveDateTime.to_iso8601(result.recorded_at),
      "segments" =>
        Enum.map(result.segments, fn segment ->
          %{
            "id" => segment.id,
            "effective_from" => Date.to_iso8601(segment.effective_from),
            "effective_until" => Date.to_iso8601(segment.effective_until),
            "value" => segment.value
          }
        end)
    }
  end

  defp decode_result(payload, audit_reference, event_id) when is_map(payload) do
    with {:ok, aggregate_id} <- cast_uuid(payload["aggregate_id"]),
         {:ok, revision_id} <- cast_uuid(payload["revision_id"]),
         {:ok, operation_id} <- cast_uuid(payload["operation_id"]),
         {:ok, predecessor_revision_id} <- cast_optional_uuid(payload["predecessor_revision_id"]),
         aggregate_revision when is_integer(aggregate_revision) and aggregate_revision > 0 <-
           payload["aggregate_revision"],
         reason_code when is_binary(reason_code) <- payload["reason_code"],
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]),
         {:ok, segments} <- decode_segments(payload["segments"]),
         {:ok, audit_reference} <- cast_uuid(audit_reference),
         {:ok, event_id} <- cast_uuid(event_id) do
      {:ok,
       %RevisionResult{
         aggregate_id: aggregate_id,
         revision_id: revision_id,
         operation_id: operation_id,
         aggregate_revision: aggregate_revision,
         predecessor_revision_id: predecessor_revision_id,
         reason_code: reason_code,
         recorded_at: recorded_at,
         segments: segments,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp decode_result(_payload, _audit_reference, _event_id),
    do: temporal_error(:retryable_dependency)

  defp decode_segments(segments) when is_list(segments) do
    segments
    |> Enum.reduce_while({:ok, []}, fn segment, {:ok, decoded} ->
      with true <- is_map(segment),
           {:ok, id} <- cast_uuid(segment["id"]),
           {:ok, effective_from} <- Date.from_iso8601(segment["effective_from"]),
           {:ok, effective_until} <- Date.from_iso8601(segment["effective_until"]),
           value when is_binary(value) <- segment["value"] do
        view =
          struct!(SegmentView,
            id: id,
            effective_from: effective_from,
            effective_until: effective_until,
            value: value
          )

        {:cont, {:ok, [view | decoded]}}
      else
        _invalid -> {:halt, temporal_error(:retryable_dependency)}
      end
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded)}
      error -> error
    end
  end

  defp decode_segments(_segments), do: temporal_error(:retryable_dependency)

  defp request_hash(mode, arguments) do
    mode_specific =
      case mode do
        :publish -> arguments.scope_id
        :correct -> arguments.expected_revision_id
      end

    {action_name(mode), arguments.aggregate_id, mode_specific, arguments.reason_code,
     arguments.segments, arguments.causation_id}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp action_name(:publish), do: "platform.temporal_qualification.revision.publish"
  defp action_name(:correct), do: "platform.temporal_qualification.revision.correct"

  defp event_type(:publish), do: "platform.temporal_qualification.revision.published"
  defp event_type(:correct), do: "platform.temporal_qualification.revision.corrected"

  defp capability(:publish), do: "platform.temporal_qualification.revisions.publish"
  defp capability(:correct), do: "platform.temporal_qualification.revisions.correct"

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "platform_temporal_qualification_segment_no_overlap",
              :platform_temporal_qualification_segment_no_overlap
            ],
       do: temporal_error(:effective_time_conflict)

  defp translate_query_error(%PostgrexError{postgres: %{code: code}})
       when code in [
              :unique_violation,
              :foreign_key_violation,
              :check_violation,
              :exclusion_violation
            ],
       do: temporal_error(:conflict)

  defp translate_query_error(_error), do: temporal_error(:retryable_dependency)

  defp cast_optional_uuid(nil), do: {:ok, nil}
  defp cast_optional_uuid(value), do: cast_uuid(value)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> temporal_error(:invalid_input)
    end
  end

  defp dump_uuid(nil), do: nil
  defp dump_uuid(value), do: UUID.dump!(value)
  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
