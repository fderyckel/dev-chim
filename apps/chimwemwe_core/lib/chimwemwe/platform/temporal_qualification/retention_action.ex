defmodule Chimwemwe.Platform.TemporalQualification.RetentionAction do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{OperationEvidence, RetentionResult}
  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate_type "platform.temporal_qualification.retention"
  @lock_namespace "platform-temporal-qualification-retention"
  @modes [:declare, :place_hold, :release_hold, :erase]

  @spec run(atom(), Ash.ActionInput.t(), keyword(), map()) ::
          {:ok, RetentionResult.t()} | {:error, TemporalQualificationError.t()}
  def run(mode, input, _options, ash_context) when mode in @modes do
    arguments = input.arguments
    claim_aggregate_id = Map.get(arguments, :control_id, arguments[:aggregate_id])
    request_hash = OperationEvidence.request_hash({action_name(mode), arguments})

    with {:ok, context} <- OperationEvidence.context(ash_context),
         :ok <- OperationEvidence.lock(@lock_namespace, context.tenant_id, claim_aggregate_id),
         :ok <- OperationEvidence.authorize(context, capability(mode)),
         {:ok, claim} <-
           OperationEvidence.claim(context, %{
             action_name: action_name(mode),
             aggregate_type: @aggregate_type,
             aggregate_id: claim_aggregate_id,
             idempotency_key: arguments.idempotency_key,
             request_hash: request_hash
           }) do
      execute_or_replay(mode, context, arguments, claim_aggregate_id, request_hash, claim)
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp execute_or_replay(mode, context, arguments, _claim_aggregate_id, _hash, {:new, claim_id}) do
    execute(mode, context, arguments, claim_id)
  end

  defp execute_or_replay(
         _mode,
         context,
         _arguments,
         claim_aggregate_id,
         request_hash,
         {:existing, claim}
       ) do
    if OperationEvidence.exact_replay?(claim, context, claim_aggregate_id, request_hash) do
      decode_result(claim.result_payload, claim.audit_reference, claim.event_id)
    else
      temporal_error(:idempotency_conflict)
    end
  end

  defp execute(:declare, context, arguments, claim_id) do
    control_id = UUID.generate()
    receipt_id = UUID.generate()

    with :ok <- require_module_access(context.tenant_id, arguments.module_key, :ordinary),
         {:ok, scope_id} <- load_scope(context.tenant_id, arguments.aggregate_id),
         {:ok, recorded_at} <-
           insert_declaration(context, arguments, control_id, receipt_id, scope_id),
         result <-
           retention_result(
             arguments,
             %{
               control_id: control_id,
               scope_id: scope_id,
               receipt_id: receipt_id,
               operation: :declared,
               state: :retained,
               version: 1,
               recorded_at: recorded_at,
               hold_reference_digest: nil,
               counts: %{segments: 0, facts: 0, projections: 0}
             }
           ),
         :ok <- record_completion(:declare, context, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp execute(mode, context, arguments, claim_id)
       when mode in [:place_hold, :release_hold, :erase] do
    with {:ok, control} <- load_control(context.tenant_id, arguments.control_id),
         :ok <- require_module_access(context.tenant_id, control.module_key, :mandatory),
         :ok <- require_version(control.version, arguments.expected_version),
         {:ok, transition} <- transition(mode, context, arguments, control),
         result <- result_from_transition(arguments, control, transition),
         :ok <- record_completion(mode, context, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp insert_declaration(context, arguments, control_id, receipt_id, scope_id) do
    case Repo.query(
           """
           WITH inserted_control AS (
             INSERT INTO platform_temporal_qualification_retention_controls (
               id, tenant_id, aggregate_id, scope_id, module_key, policy_key,
               classification, retention_started_on, retain_until, state, version,
               current_receipt_id, inserted_at, updated_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'retained', 1, $10, NOW(), NOW())
             RETURNING id
           )
           INSERT INTO platform_temporal_qualification_retention_receipts (
             id, tenant_id, control_id, aggregate_id, scope_id, operation, version,
             reason_code, redacted_segment_count, redacted_fact_count,
             purged_projection_count, recorded_at
           )
           SELECT $10, $2, id, $3, $4, 'declared', 1, $11, 0, 0, 0, NOW()
           FROM inserted_control
           RETURNING recorded_at
           """,
           [
             dump(control_id),
             dump(context.tenant_id),
             dump(arguments.aggregate_id),
             dump(scope_id),
             arguments.module_key,
             arguments.policy_key,
             Atom.to_string(arguments.classification),
             arguments.retention_started_on,
             arguments.retain_until,
             dump(receipt_id),
             arguments.reason_code
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp transition(:place_hold, context, arguments, control) do
    cond do
      control.state == "erased" -> temporal_error(:retention_conflict)
      control.state == "held" -> temporal_error(:legal_hold_conflict)
      true -> update_control(context, arguments, control, :hold_placed)
    end
  end

  defp transition(:release_hold, context, arguments, control) do
    if control.state == "held" and
         control.active_hold_digest == arguments.hold_reference_digest do
      update_control(context, arguments, control, :hold_released)
    else
      temporal_error(:legal_hold_conflict)
    end
  end

  defp transition(:erase, context, arguments, control) do
    cond do
      control.state == "held" ->
        temporal_error(:legal_hold_conflict)

      control.state == "erased" ->
        temporal_error(:retention_conflict)

      Date.before?(control.database_today, control.retain_until) ->
        temporal_error(:retention_conflict)

      true ->
        erase_content(context, arguments, control)
    end
  end

  defp update_control(context, arguments, control, operation) do
    receipt_id = UUID.generate()
    next_version = control.version + 1
    hold_digest = arguments.hold_reference_digest
    next_state = if operation == :hold_placed, do: "held", else: "retained"
    next_active_digest = if operation == :hold_placed, do: hold_digest, else: nil

    case Repo.query(
           """
           WITH inserted_receipt AS (
             INSERT INTO platform_temporal_qualification_retention_receipts (
               id, tenant_id, control_id, aggregate_id, scope_id, operation, version,
               reason_code, hold_reference_digest, redacted_segment_count,
               redacted_fact_count, purged_projection_count, recorded_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, 0, 0, NOW())
             RETURNING recorded_at
           )
           UPDATE platform_temporal_qualification_retention_controls
           SET state = $10, version = $7, active_hold_digest = $11,
               current_receipt_id = $1, updated_at = NOW()
           FROM inserted_receipt
           WHERE id = $3 AND tenant_id = $2 AND version = $12
           RETURNING inserted_receipt.recorded_at
           """,
           [
             dump(receipt_id),
             dump(context.tenant_id),
             dump(control.id),
             dump(control.aggregate_id),
             dump(control.scope_id),
             Atom.to_string(operation),
             next_version,
             arguments.reason_code,
             hold_digest,
             next_state,
             next_active_digest,
             control.version
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} ->
        {:ok,
         %{
           receipt_id: receipt_id,
           operation: operation,
           state: next_state,
           version: next_version,
           recorded_at: recorded_at,
           hold_reference_digest: hold_digest,
           counts: %{segments: 0, facts: 0, projections: 0}
         }}

      {:ok, %{rows: []}} ->
        temporal_error(:conflict)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp erase_content(context, arguments, control) do
    receipt_id = UUID.generate()
    next_version = control.version + 1

    with {:ok, segment_count} <-
           redact_segments(context.tenant_id, control.aggregate_id, receipt_id),
         {:ok, fact_count} <- redact_facts(context.tenant_id, control.scope_id, receipt_id),
         {:ok, projection_count} <- purge_projection(context.tenant_id, control.aggregate_id),
         {:ok, recorded_at} <-
           complete_erasure(
             context,
             arguments,
             control,
             receipt_id,
             next_version,
             segment_count,
             fact_count,
             projection_count
           ) do
      {:ok,
       %{
         receipt_id: receipt_id,
         operation: :erased,
         state: "erased",
         version: next_version,
         recorded_at: recorded_at,
         hold_reference_digest: nil,
         counts: %{segments: segment_count, facts: fact_count, projections: projection_count}
       }}
    end
  end

  defp redact_segments(tenant_id, aggregate_id, receipt_id) do
    count_query(
      """
      UPDATE platform_temporal_qualification_segments
      SET value = '[redacted]', redacted_at = NOW(), redaction_receipt_id = $3
      WHERE tenant_id = $1 AND aggregate_id = $2 AND redacted_at IS NULL
      """,
      [dump(tenant_id), dump(aggregate_id), dump(receipt_id)]
    )
  end

  defp redact_facts(tenant_id, scope_id, receipt_id) do
    count_query(
      """
      UPDATE platform_temporal_qualification_facts
      SET quantity = 0, redacted_at = NOW(), redaction_receipt_id = $3
      WHERE tenant_id = $1 AND scope_id = $2 AND redacted_at IS NULL
      """,
      [dump(tenant_id), dump(scope_id), dump(receipt_id)]
    )
  end

  defp purge_projection(tenant_id, aggregate_id) do
    count_query(
      """
      DELETE FROM platform_temporal_qualification_current_projections
      WHERE tenant_id = $1 AND aggregate_id = $2
      """,
      [dump(tenant_id), dump(aggregate_id)]
    )
  end

  defp complete_erasure(
         context,
         arguments,
         control,
         receipt_id,
         next_version,
         segment_count,
         fact_count,
         projection_count
       ) do
    case Repo.query(
           """
           WITH inserted_receipt AS (
             INSERT INTO platform_temporal_qualification_retention_receipts (
               id, tenant_id, control_id, aggregate_id, scope_id, operation, version,
               reason_code, redacted_segment_count, redacted_fact_count,
               purged_projection_count, recorded_at
             )
             VALUES ($1, $2, $3, $4, $5, 'erased', $6, $7, $8, $9, $10, NOW())
             RETURNING recorded_at
           )
           UPDATE platform_temporal_qualification_retention_controls
           SET state = 'erased', version = $6, active_hold_digest = NULL,
               current_receipt_id = $1, erased_at = NOW(), updated_at = NOW()
           FROM inserted_receipt
           WHERE id = $3 AND tenant_id = $2 AND version = $11
           RETURNING inserted_receipt.recorded_at
           """,
           [
             dump(receipt_id),
             dump(context.tenant_id),
             dump(control.id),
             dump(control.aggregate_id),
             dump(control.scope_id),
             next_version,
             arguments.reason_code,
             segment_count,
             fact_count,
             projection_count,
             control.version
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:ok, %{rows: []}} -> temporal_error(:conflict)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp count_query(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp load_scope(tenant_id, aggregate_id) do
    case Repo.query(
           "SELECT scope_id::text FROM platform_temporal_qualification_aggregates WHERE tenant_id = $1 AND id = $2 FOR SHARE",
           [dump(tenant_id), dump(aggregate_id)]
         ) do
      {:ok, %{rows: [[scope_id]]}} -> {:ok, scope_id}
      {:ok, %{rows: []}} -> temporal_error(:not_found)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp load_control(tenant_id, control_id) do
    case Repo.query(
           """
           SELECT id::text, aggregate_id::text, scope_id::text, module_key, policy_key,
                  classification, retention_started_on, retain_until, state, version,
                  active_hold_digest, CURRENT_DATE
           FROM platform_temporal_qualification_retention_controls
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump(tenant_id), dump(control_id)]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             aggregate_id,
             scope_id,
             module_key,
             policy_key,
             classification,
             retention_started_on,
             retain_until,
             state,
             version,
             active_hold_digest,
             database_today
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           aggregate_id: aggregate_id,
           scope_id: scope_id,
           module_key: module_key,
           policy_key: policy_key,
           classification: classification,
           retention_started_on: retention_started_on,
           retain_until: retain_until,
           state: state,
           version: version,
           active_hold_digest: active_hold_digest,
           database_today: database_today
         }}

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp require_module_access(tenant_id, module_key, mode) do
    case Repo.query(
           """
           SELECT activation.state, activation.retained_data_state
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1 AND entitlement.module_key = $2
           FOR KEY SHARE
           """,
           [dump(tenant_id), module_key]
         ) do
      {:ok, %{rows: [["active", "retained"]]}} -> :ok
      {:ok, %{rows: [["inactive", "retained"]]}} when mode == :mandatory -> :ok
      {:ok, %{rows: [_]}} -> temporal_error(:forbidden)
      {:ok, %{rows: []}} -> temporal_error(:forbidden)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp require_version(version, version), do: :ok
  defp require_version(_actual, _expected), do: temporal_error(:conflict)

  defp result_from_transition(_arguments, control, transition) do
    retention_result(
      %{
        aggregate_id: control.aggregate_id,
        module_key: control.module_key,
        policy_key: control.policy_key,
        classification: String.to_existing_atom(control.classification),
        retention_started_on: control.retention_started_on,
        retain_until: control.retain_until
      },
      %{
        control_id: control.id,
        scope_id: control.scope_id,
        receipt_id: transition.receipt_id,
        operation: transition.operation,
        state: String.to_existing_atom(transition.state),
        version: transition.version,
        recorded_at: transition.recorded_at,
        hold_reference_digest: transition.hold_reference_digest,
        counts: transition.counts
      }
    )
  end

  defp retention_result(arguments, details) do
    %RetentionResult{
      control_id: details.control_id,
      aggregate_id: arguments.aggregate_id,
      scope_id: details.scope_id,
      module_key: arguments.module_key,
      policy_key: arguments.policy_key,
      classification: arguments.classification,
      retention_started_on: arguments.retention_started_on,
      retain_until: arguments.retain_until,
      state: details.state,
      version: details.version,
      receipt_id: details.receipt_id,
      operation: details.operation,
      hold_reference_digest: details.hold_reference_digest,
      redacted_segment_count: details.counts.segments,
      redacted_fact_count: details.counts.facts,
      purged_projection_count: details.counts.projections,
      recorded_at: details.recorded_at,
      audit_reference: UUID.generate(),
      event_id: UUID.generate()
    }
  end

  defp record_completion(mode, context, arguments, claim_id, result) do
    with :ok <-
           OperationEvidence.insert_evidence(context, %{
             audit_reference: result.audit_reference,
             event_id: result.event_id,
             action_name: action_name(mode),
             aggregate_type: @aggregate_type,
             aggregate_id: result.control_id,
             idempotency_key: arguments.idempotency_key,
             causation_id: arguments.causation_id,
             before_version: result.version - 1,
             after_version: result.version,
             summary: %{
               "control_id" => result.control_id,
               "operation" => Atom.to_string(result.operation),
               "reason_code" => arguments.reason_code,
               "state" => Atom.to_string(result.state),
               "purpose" => context.purpose
             },
             event_type: event_type(mode),
             payload: %{
               "control_id" => result.control_id,
               "aggregate_id" => result.aggregate_id,
               "scope_id" => result.scope_id,
               "receipt_id" => result.receipt_id,
               "operation" => Atom.to_string(result.operation),
               "state" => Atom.to_string(result.state),
               "version" => result.version
             }
           }) do
      OperationEvidence.complete_claim(
        claim_id,
        result_payload(result),
        result.audit_reference,
        result.event_id
      )
    end
  end

  defp result_payload(result) do
    result
    |> Map.from_struct()
    |> Map.new(fn
      {:recorded_at, value} -> {"recorded_at", NaiveDateTime.to_iso8601(value)}
      {:retention_started_on, value} -> {"retention_started_on", Date.to_iso8601(value)}
      {:retain_until, value} -> {"retain_until", Date.to_iso8601(value)}
      {:hold_reference_digest, nil} -> {"hold_reference_digest", nil}
      {:hold_reference_digest, value} -> {"hold_reference_digest", Base.encode64(value)}
      {key, value} when is_atom(value) -> {Atom.to_string(key), Atom.to_string(value)}
      {key, value} -> {Atom.to_string(key), value}
    end)
  end

  defp decode_result(payload, audit_reference, event_id) when is_map(payload) do
    with {:ok, control_id} <- cast_payload_uuid(payload, "control_id"),
         {:ok, aggregate_id} <- cast_payload_uuid(payload, "aggregate_id"),
         {:ok, scope_id} <- cast_payload_uuid(payload, "scope_id"),
         {:ok, receipt_id} <- cast_payload_uuid(payload, "receipt_id"),
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]),
         {:ok, retention_started_on} <- Date.from_iso8601(payload["retention_started_on"]),
         {:ok, retain_until} <- Date.from_iso8601(payload["retain_until"]),
         {:ok, hold_digest} <- decode_optional_digest(payload["hold_reference_digest"]),
         {:ok, audit_reference} <- OperationEvidence.cast_uuid(audit_reference),
         {:ok, event_id} <- OperationEvidence.cast_uuid(event_id),
         {:ok, state} <- cast_state(payload["state"]),
         {:ok, operation} <- cast_operation(payload["operation"]) do
      {:ok,
       struct!(RetentionResult, %{
         control_id: control_id,
         aggregate_id: aggregate_id,
         scope_id: scope_id,
         module_key: payload["module_key"],
         policy_key: payload["policy_key"],
         classification: String.to_existing_atom(payload["classification"]),
         retention_started_on: retention_started_on,
         retain_until: retain_until,
         state: state,
         version: payload["version"],
         receipt_id: receipt_id,
         operation: operation,
         hold_reference_digest: hold_digest,
         redacted_segment_count: payload["redacted_segment_count"],
         redacted_fact_count: payload["redacted_fact_count"],
         purged_projection_count: payload["purged_projection_count"],
         recorded_at: recorded_at,
         audit_reference: audit_reference,
         event_id: event_id
       })}
    else
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp decode_result(_payload, _audit_reference, _event_id),
    do: temporal_error(:retryable_dependency)

  defp cast_payload_uuid(payload, key), do: OperationEvidence.cast_uuid(payload[key])
  defp decode_optional_digest(nil), do: {:ok, nil}

  defp decode_optional_digest(value) do
    case Base.decode64(value) do
      {:ok, digest} when byte_size(digest) == 32 -> {:ok, digest}
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp cast_state("retained"), do: {:ok, :retained}
  defp cast_state("held"), do: {:ok, :held}
  defp cast_state("erased"), do: {:ok, :erased}
  defp cast_state(_state), do: temporal_error(:retryable_dependency)
  defp cast_operation("declared"), do: {:ok, :declared}
  defp cast_operation("hold_placed"), do: {:ok, :hold_placed}
  defp cast_operation("hold_released"), do: {:ok, :hold_released}
  defp cast_operation("erased"), do: {:ok, :erased}
  defp cast_operation(_operation), do: temporal_error(:retryable_dependency)

  defp action_name(:declare), do: "platform.temporal_qualification.retention.declare"
  defp action_name(:place_hold), do: "platform.temporal_qualification.legal_hold.place"
  defp action_name(:release_hold), do: "platform.temporal_qualification.legal_hold.release"
  defp action_name(:erase), do: "platform.temporal_qualification.retention.erase"
  defp event_type(:declare), do: "platform.temporal_qualification.retention.declared"
  defp event_type(:place_hold), do: "platform.temporal_qualification.legal_hold.placed"
  defp event_type(:release_hold), do: "platform.temporal_qualification.legal_hold.released"
  defp event_type(:erase), do: "platform.temporal_qualification.retention.erased"
  defp capability(:declare), do: "platform.temporal_qualification.retention.declare"
  defp capability(:place_hold), do: "platform.temporal_qualification.legal_hold.place"
  defp capability(:release_hold), do: "platform.temporal_qualification.legal_hold.release"
  defp capability(:erase), do: "platform.temporal_qualification.retention.erase"
  defp dump(value), do: OperationEvidence.dump_uuid(value)
  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
