defmodule Chimwemwe.Platform.TemporalQualification.ImportAction do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{ImportResult, OperationEvidence}
  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate_type "platform.temporal_qualification.import"
  @lock_namespace "platform-temporal-qualification-import"
  @modes [:baseline, :conflict, :reconcile]

  @spec run(atom(), Ash.ActionInput.t(), keyword(), map()) ::
          {:ok, ImportResult.t()} | {:error, TemporalQualificationError.t()}
  def run(mode, input, _options, ash_context) when mode in @modes do
    arguments = input.arguments
    request_hash = OperationEvidence.request_hash({action_name(mode), arguments})

    with {:ok, context} <- OperationEvidence.context(ash_context),
         :ok <- OperationEvidence.lock(@lock_namespace, context.tenant_id, arguments.import_id),
         :ok <- OperationEvidence.authorize(context, capability(mode)),
         :ok <- require_active_module(context.tenant_id, arguments.module_key),
         {:ok, claim} <-
           OperationEvidence.claim(context, %{
             action_name: action_name(mode),
             aggregate_type: @aggregate_type,
             aggregate_id: arguments.import_id,
             idempotency_key: arguments.idempotency_key,
             request_hash: request_hash
           }) do
      execute_or_replay(mode, context, arguments, request_hash, claim)
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp execute_or_replay(mode, context, arguments, _hash, {:new, claim_id}) do
    execute(mode, context, arguments, claim_id)
  end

  defp execute_or_replay(_mode, context, arguments, request_hash, {:existing, claim}) do
    if OperationEvidence.exact_replay?(claim, context, arguments.import_id, request_hash) do
      decode_result(claim.result_payload, claim.audit_reference, claim.event_id)
    else
      temporal_error(:idempotency_conflict)
    end
  end

  defp execute(mode, context, arguments, claim_id) when mode in [:baseline, :conflict] do
    record_id = UUID.generate()
    audit_reference = UUID.generate()
    event_id = UUID.generate()
    state = if mode == :baseline, do: :baseline, else: :reconciliation_required

    with :ok <- validate_digests(arguments),
         {:ok, recorded_at} <- insert_initial(mode, context, arguments, record_id),
         result <-
           import_result(
             arguments,
             record_id,
             1,
             nil,
             state,
             recorded_at,
             audit_reference,
             event_id
           ),
         :ok <- record_completion(mode, context, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp execute(:reconcile, context, arguments, claim_id) do
    record_id = UUID.generate()
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    with {:ok, predecessor} <-
           load_conflict(context.tenant_id, arguments.import_id, arguments.expected_record_id),
         {:ok, recorded_at} <-
           insert_reconciliation(context, arguments, predecessor, record_id),
         result <-
           %ImportResult{
             import_id: arguments.import_id,
             record_id: record_id,
             version: 2,
             predecessor_record_id: predecessor.id,
             state: :reconciled,
             conflict_code: nil,
             source_snapshot_digest: predecessor.source_snapshot_digest,
             source_identifier_digest: predecessor.source_identifier_digest,
             mapping_revision: predecessor.mapping_revision,
             aggregate_id: arguments.aggregate_id,
             revision_id: arguments.revision_id,
             recorded_at: recorded_at,
             audit_reference: audit_reference,
             event_id: event_id
           },
         :ok <- record_completion(:reconcile, context, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp validate_digests(arguments) do
    if byte_size(arguments.source_snapshot_digest) == 32 and
         byte_size(arguments.source_identifier_digest) == 32 do
      :ok
    else
      temporal_error(:invalid_input)
    end
  end

  defp insert_initial(mode, context, arguments, record_id) do
    state = if mode == :baseline, do: "baseline", else: "reconciliation_required"
    conflict_code = if mode == :conflict, do: arguments.conflict_code, else: nil
    aggregate_id = if mode == :baseline, do: dump(arguments.aggregate_id), else: nil
    revision_id = if mode == :baseline, do: dump(arguments.revision_id), else: nil

    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_import_records (
             id, tenant_id, import_id, version, module_key, state, conflict_code,
             source_snapshot_digest, source_identifier_digest, mapping_revision,
             aggregate_id, revision_id, recorded_at
           )
           VALUES ($1, $2, $3, 1, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
           RETURNING recorded_at
           """,
           [
             dump(record_id),
             dump(context.tenant_id),
             dump(arguments.import_id),
             arguments.module_key,
             state,
             conflict_code,
             arguments.source_snapshot_digest,
             arguments.source_identifier_digest,
             arguments.mapping_revision,
             aggregate_id,
             revision_id
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp insert_reconciliation(context, arguments, predecessor, record_id) do
    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_import_records (
             id, tenant_id, import_id, version, predecessor_record_id, module_key,
             state, source_snapshot_digest, source_identifier_digest, mapping_revision,
             aggregate_id, revision_id, recorded_at
           )
           VALUES ($1, $2, $3, 2, $4, $5, 'reconciled', $6, $7, $8, $9, $10, NOW())
           RETURNING recorded_at
           """,
           [
             dump(record_id),
             dump(context.tenant_id),
             dump(arguments.import_id),
             dump(predecessor.id),
             arguments.module_key,
             predecessor.source_snapshot_digest,
             predecessor.source_identifier_digest,
             predecessor.mapping_revision,
             dump(arguments.aggregate_id),
             dump(arguments.revision_id)
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp load_conflict(tenant_id, import_id, record_id) do
    case Repo.query(
           """
           SELECT id::text, source_snapshot_digest, source_identifier_digest, mapping_revision
           FROM platform_temporal_qualification_import_records
           WHERE tenant_id = $1 AND import_id = $2 AND id = $3
             AND version = 1 AND state = 'reconciliation_required'
           FOR SHARE
           """,
           [dump(tenant_id), dump(import_id), dump(record_id)]
         ) do
      {:ok, %{rows: [[id, snapshot_digest, identifier_digest, mapping_revision]]}} ->
        {:ok,
         %{
           id: id,
           source_snapshot_digest: snapshot_digest,
           source_identifier_digest: identifier_digest,
           mapping_revision: mapping_revision
         }}

      {:ok, %{rows: []}} ->
        temporal_error(:conflict)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp require_active_module(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT 1
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1 AND entitlement.module_key = $2
             AND activation.state = 'active'
             AND activation.retained_data_state = 'retained'
           FOR KEY SHARE
           """,
           [dump(tenant_id), module_key]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> temporal_error(:forbidden)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp import_result(
         arguments,
         record_id,
         version,
         predecessor_id,
         state,
         recorded_at,
         audit,
         event
       ) do
    %ImportResult{
      import_id: arguments.import_id,
      record_id: record_id,
      version: version,
      predecessor_record_id: predecessor_id,
      state: state,
      conflict_code: Map.get(arguments, :conflict_code),
      source_snapshot_digest: arguments.source_snapshot_digest,
      source_identifier_digest: arguments.source_identifier_digest,
      mapping_revision: arguments.mapping_revision,
      aggregate_id: Map.get(arguments, :aggregate_id),
      revision_id: Map.get(arguments, :revision_id),
      recorded_at: recorded_at,
      audit_reference: audit,
      event_id: event
    }
  end

  defp record_completion(mode, context, arguments, claim_id, result) do
    with :ok <-
           OperationEvidence.insert_evidence(context, %{
             audit_reference: result.audit_reference,
             event_id: result.event_id,
             action_name: action_name(mode),
             aggregate_type: @aggregate_type,
             aggregate_id: result.import_id,
             idempotency_key: arguments.idempotency_key,
             causation_id: arguments.causation_id,
             before_version: result.version - 1,
             after_version: result.version,
             summary: %{
               "import_id" => result.import_id,
               "record_id" => result.record_id,
               "state" => Atom.to_string(result.state),
               "reason_code" => arguments.reason_code,
               "purpose" => context.purpose
             },
             event_type: event_type(mode),
             payload: %{
               "import_id" => result.import_id,
               "record_id" => result.record_id,
               "version" => result.version,
               "state" => Atom.to_string(result.state),
               "aggregate_id" => result.aggregate_id,
               "revision_id" => result.revision_id
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
    %{
      "import_id" => result.import_id,
      "record_id" => result.record_id,
      "version" => result.version,
      "predecessor_record_id" => result.predecessor_record_id,
      "state" => Atom.to_string(result.state),
      "conflict_code" => result.conflict_code,
      "source_snapshot_digest" => Base.encode64(result.source_snapshot_digest),
      "source_identifier_digest" => Base.encode64(result.source_identifier_digest),
      "mapping_revision" => result.mapping_revision,
      "aggregate_id" => result.aggregate_id,
      "revision_id" => result.revision_id,
      "recorded_at" => NaiveDateTime.to_iso8601(result.recorded_at)
    }
  end

  defp decode_result(payload, audit_reference, event_id) when is_map(payload) do
    with {:ok, import_id} <- cast_uuid(payload["import_id"]),
         {:ok, record_id} <- cast_uuid(payload["record_id"]),
         {:ok, predecessor_id} <- cast_optional_uuid(payload["predecessor_record_id"]),
         {:ok, aggregate_id} <- cast_optional_uuid(payload["aggregate_id"]),
         {:ok, revision_id} <- cast_optional_uuid(payload["revision_id"]),
         {:ok, snapshot_digest} <- decode_digest(payload["source_snapshot_digest"]),
         {:ok, identifier_digest} <- decode_digest(payload["source_identifier_digest"]),
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]),
         {:ok, state} <- cast_state(payload["state"]),
         {:ok, audit_reference} <- cast_uuid(audit_reference),
         {:ok, event_id} <- cast_uuid(event_id) do
      {:ok,
       %ImportResult{
         import_id: import_id,
         record_id: record_id,
         version: payload["version"],
         predecessor_record_id: predecessor_id,
         state: state,
         conflict_code: payload["conflict_code"],
         source_snapshot_digest: snapshot_digest,
         source_identifier_digest: identifier_digest,
         mapping_revision: payload["mapping_revision"],
         aggregate_id: aggregate_id,
         revision_id: revision_id,
         recorded_at: recorded_at,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp decode_result(_payload, _audit_reference, _event_id),
    do: temporal_error(:retryable_dependency)

  defp cast_uuid(value), do: OperationEvidence.cast_uuid(value)
  defp cast_optional_uuid(nil), do: {:ok, nil}
  defp cast_optional_uuid(value), do: cast_uuid(value)

  defp decode_digest(value) do
    case Base.decode64(value) do
      {:ok, digest} when byte_size(digest) == 32 -> {:ok, digest}
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp cast_state("baseline"), do: {:ok, :baseline}
  defp cast_state("reconciliation_required"), do: {:ok, :reconciliation_required}
  defp cast_state("reconciled"), do: {:ok, :reconciled}
  defp cast_state(_state), do: temporal_error(:retryable_dependency)

  defp action_name(:baseline), do: "platform.temporal_qualification.import.register_baseline"
  defp action_name(:conflict), do: "platform.temporal_qualification.import.register_conflict"
  defp action_name(:reconcile), do: "platform.temporal_qualification.import.reconcile_conflict"
  defp event_type(:baseline), do: "platform.temporal_qualification.import.baseline_registered"
  defp event_type(:conflict), do: "platform.temporal_qualification.import.conflict_registered"
  defp event_type(:reconcile), do: "platform.temporal_qualification.import.conflict_reconciled"

  defp capability(mode) when mode in [:baseline, :conflict],
    do: "platform.temporal_qualification.import.register"

  defp capability(:reconcile), do: "platform.temporal_qualification.import.reconcile"
  defp dump(value), do: OperationEvidence.dump_uuid(value)
  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
