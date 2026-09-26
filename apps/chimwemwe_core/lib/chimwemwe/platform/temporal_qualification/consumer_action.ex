defmodule Chimwemwe.Platform.TemporalQualification.ConsumerAction do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{
    ConsumerBasisView,
    ConsumerResult,
    OperationEvidence
  }

  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate_type "platform.temporal_qualification.reconciliation_consumer"
  @lock_namespace "platform-temporal-qualification-consumer"
  @modes [:pin, :reconcile]

  @spec run(:pin | :reconcile, Ash.ActionInput.t(), keyword(), map()) ::
          {:ok, ConsumerResult.t()} | {:error, TemporalQualificationError.t()}
  def run(mode, input, _options, ash_context) when mode in @modes do
    arguments = input.arguments
    request_hash = OperationEvidence.request_hash({action_name(mode), arguments})

    with {:ok, context} <- OperationEvidence.context(ash_context),
         :ok <- OperationEvidence.lock(@lock_namespace, context.tenant_id, arguments.consumer_id),
         :ok <- OperationEvidence.authorize(context, capability(mode)),
         {:ok, claim} <-
           OperationEvidence.claim(context, %{
             action_name: action_name(mode),
             aggregate_type: @aggregate_type,
             aggregate_id: arguments.consumer_id,
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

  defp execute_or_replay(mode, context, arguments, _request_hash, {:new, claim_id}) do
    execute(mode, context, arguments, claim_id)
  end

  defp execute_or_replay(_mode, context, arguments, request_hash, {:existing, claim}) do
    if OperationEvidence.exact_replay?(
         claim,
         context,
         arguments.consumer_id,
         request_hash
       ) do
      decode_result(claim.result_payload, claim.audit_reference, claim.event_id)
    else
      temporal_error(:idempotency_conflict)
    end
  end

  defp execute(:pin, context, arguments, claim_id) do
    with :ok <- require_absent_consumer(context.tenant_id, arguments.consumer_id),
         :ok <-
           require_current_revision(
             context.tenant_id,
             arguments.aggregate_id,
             arguments.revision_id
           ) do
      create_basis(
        :pin,
        context,
        arguments,
        claim_id,
        arguments.aggregate_id,
        arguments.revision_id,
        1,
        nil
      )
    end
  end

  defp execute(:reconcile, context, arguments, claim_id) do
    with {:ok, current} <- load_current_basis(context.tenant_id, arguments.consumer_id),
         :ok <- require_expected_basis(current.id, arguments.expected_basis_id),
         :ok <- require_new_revision(current.revision_id, arguments.target_revision_id),
         :ok <-
           require_current_revision(
             context.tenant_id,
             current.aggregate_id,
             arguments.target_revision_id
           ) do
      create_basis(
        :reconcile,
        context,
        arguments,
        claim_id,
        current.aggregate_id,
        arguments.target_revision_id,
        current.basis_version + 1,
        current.id
      )
    end
  end

  defp create_basis(
         mode,
         context,
         arguments,
         claim_id,
         aggregate_id,
         revision_id,
         basis_version,
         predecessor_basis_id
       ) do
    basis_id = UUID.generate()
    operation_id = UUID.generate()
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    basis = %{
      basis_id: basis_id,
      consumer_id: arguments.consumer_id,
      aggregate_id: aggregate_id,
      revision_id: revision_id,
      operation_id: operation_id,
      basis_version: basis_version,
      predecessor_basis_id: predecessor_basis_id,
      reason_code: arguments.reason_code
    }

    with {:ok, recorded_at} <-
           insert_basis(context.tenant_id, basis),
         result <-
           result(
             Map.put(basis, :recorded_at, recorded_at),
             audit_reference,
             event_id
           ),
         :ok <- insert_evidence(mode, context, arguments, result),
         :ok <-
           OperationEvidence.complete_claim(
             claim_id,
             result_payload(result),
             audit_reference,
             event_id
           ) do
      {:ok, result}
    end
  end

  defp require_absent_consumer(tenant_id, consumer_id) do
    case Repo.query(
           """
           SELECT 1
           FROM platform_temporal_qualification_consumer_bases
           WHERE tenant_id = $1 AND consumer_id = $2
           LIMIT 1
           """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(consumer_id)]
         ) do
      {:ok, %{rows: []}} -> :ok
      {:ok, %{rows: [[1]]}} -> temporal_error(:conflict)
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp load_current_basis(tenant_id, consumer_id) do
    case Repo.query(
           """
           SELECT id::text, aggregate_id::text, revision_id::text, basis_version
           FROM platform_temporal_qualification_consumer_bases
           WHERE tenant_id = $1 AND consumer_id = $2
           ORDER BY basis_version DESC
           LIMIT 1
           FOR UPDATE
           """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(consumer_id)]
         ) do
      {:ok, %{rows: [[id, aggregate_id, revision_id, basis_version]]}} ->
        {:ok,
         %{
           id: id,
           aggregate_id: aggregate_id,
           revision_id: revision_id,
           basis_version: basis_version
         }}

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp require_current_revision(tenant_id, aggregate_id, revision_id) do
    case Repo.query(
           """
           SELECT current_revision_id::text
           FROM platform_temporal_qualification_aggregates
           WHERE tenant_id = $1 AND id = $2
           FOR SHARE
           """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(aggregate_id)]
         ) do
      {:ok, %{rows: [[^revision_id]]}} ->
        :ok

      {:ok, %{rows: [[_other_revision_id]]}} ->
        if revision_belongs_to_aggregate?(tenant_id, aggregate_id, revision_id) do
          temporal_error(:conflict)
        else
          temporal_error(:not_found)
        end

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp revision_belongs_to_aggregate?(tenant_id, aggregate_id, revision_id) do
    case Repo.query(
           """
           SELECT 1
           FROM platform_temporal_qualification_revisions
           WHERE tenant_id = $1 AND aggregate_id = $2 AND id = $3
           """,
           [
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(aggregate_id),
             OperationEvidence.dump_uuid(revision_id)
           ]
         ) do
      {:ok, %{rows: [[1]]}} -> true
      _other -> false
    end
  end

  defp require_expected_basis(basis_id, basis_id), do: :ok
  defp require_expected_basis(_current, _expected), do: temporal_error(:conflict)

  defp require_new_revision(revision_id, revision_id), do: temporal_error(:conflict)
  defp require_new_revision(_current, _target), do: :ok

  defp insert_basis(tenant_id, basis) do
    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_consumer_bases (
             id,
             tenant_id,
             consumer_id,
             aggregate_id,
             revision_id,
             operation_id,
             basis_version,
             predecessor_basis_id,
             reason_code,
             recorded_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
           RETURNING recorded_at
           """,
           [
             OperationEvidence.dump_uuid(basis.basis_id),
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(basis.consumer_id),
             OperationEvidence.dump_uuid(basis.aggregate_id),
             OperationEvidence.dump_uuid(basis.revision_id),
             OperationEvidence.dump_uuid(basis.operation_id),
             basis.basis_version,
             OperationEvidence.dump_uuid(basis.predecessor_basis_id),
             basis.reason_code
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp result(basis, audit_reference, event_id) do
    %ConsumerResult{
      basis: %ConsumerBasisView{
        basis_id: basis.basis_id,
        consumer_id: basis.consumer_id,
        aggregate_id: basis.aggregate_id,
        revision_id: basis.revision_id,
        operation_id: basis.operation_id,
        basis_version: basis.basis_version,
        predecessor_basis_id: basis.predecessor_basis_id,
        reason_code: basis.reason_code,
        recorded_at: basis.recorded_at
      },
      audit_reference: audit_reference,
      event_id: event_id
    }
  end

  defp insert_evidence(mode, context, arguments, result) do
    basis = result.basis

    OperationEvidence.insert_evidence(context, %{
      audit_reference: result.audit_reference,
      event_id: result.event_id,
      action_name: action_name(mode),
      aggregate_type: @aggregate_type,
      aggregate_id: basis.consumer_id,
      idempotency_key: arguments.idempotency_key,
      causation_id: arguments.causation_id,
      before_version: basis.basis_version - 1,
      after_version: basis.basis_version,
      summary: %{
        "basis_id" => basis.basis_id,
        "basis_version" => basis.basis_version,
        "operation_id" => basis.operation_id,
        "revision_id" => basis.revision_id,
        "reason_code" => basis.reason_code,
        "purpose" => context.purpose
      },
      event_type: event_type(mode),
      payload: %{
        "consumer_id" => basis.consumer_id,
        "basis_id" => basis.basis_id,
        "basis_version" => basis.basis_version,
        "revision_id" => basis.revision_id,
        "predecessor_basis_id" => basis.predecessor_basis_id,
        "operation_id" => basis.operation_id
      }
    })
  end

  defp result_payload(result) do
    basis = result.basis

    %{
      "basis_id" => basis.basis_id,
      "consumer_id" => basis.consumer_id,
      "aggregate_id" => basis.aggregate_id,
      "revision_id" => basis.revision_id,
      "operation_id" => basis.operation_id,
      "basis_version" => basis.basis_version,
      "predecessor_basis_id" => basis.predecessor_basis_id,
      "reason_code" => basis.reason_code,
      "recorded_at" => NaiveDateTime.to_iso8601(basis.recorded_at)
    }
  end

  defp decode_result(payload, audit_reference, event_id) when is_map(payload) do
    with {:ok, basis_id} <- OperationEvidence.cast_uuid(payload["basis_id"]),
         {:ok, consumer_id} <- OperationEvidence.cast_uuid(payload["consumer_id"]),
         {:ok, aggregate_id} <- OperationEvidence.cast_uuid(payload["aggregate_id"]),
         {:ok, revision_id} <- OperationEvidence.cast_uuid(payload["revision_id"]),
         {:ok, operation_id} <- OperationEvidence.cast_uuid(payload["operation_id"]),
         basis_version when is_integer(basis_version) and basis_version > 0 <-
           payload["basis_version"],
         {:ok, predecessor_basis_id} <- cast_optional_uuid(payload["predecessor_basis_id"]),
         reason_code when is_binary(reason_code) <- payload["reason_code"],
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]),
         {:ok, audit_reference} <- OperationEvidence.cast_uuid(audit_reference),
         {:ok, event_id} <- OperationEvidence.cast_uuid(event_id) do
      {:ok,
       result(
         %{
           basis_id: basis_id,
           consumer_id: consumer_id,
           aggregate_id: aggregate_id,
           revision_id: revision_id,
           operation_id: operation_id,
           basis_version: basis_version,
           predecessor_basis_id: predecessor_basis_id,
           reason_code: reason_code,
           recorded_at: recorded_at
         },
         audit_reference,
         event_id
       )}
    else
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp decode_result(_payload, _audit_reference, _event_id),
    do: temporal_error(:retryable_dependency)

  defp cast_optional_uuid(nil), do: {:ok, nil}
  defp cast_optional_uuid(value), do: OperationEvidence.cast_uuid(value)

  defp action_name(:pin), do: "platform.temporal_qualification.consumer.pin_revision"

  defp action_name(:reconcile),
    do: "platform.temporal_qualification.consumer.reconcile_revision"

  defp event_type(:pin), do: "platform.temporal_qualification.consumer.revision_pinned"

  defp event_type(:reconcile),
    do: "platform.temporal_qualification.consumer.revision_reconciled"

  defp capability(:pin), do: "platform.temporal_qualification.consumers.pin"

  defp capability(:reconcile),
    do: "platform.temporal_qualification.consumers.reconcile"

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
