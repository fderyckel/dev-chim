defmodule Chimwemwe.Platform.TemporalQualification.FactAction do
  @moduledoc false

  alias Chimwemwe.Platform.TemporalQualification.{
    FactOperationResult,
    FactOperationView,
    FactView,
    OperationEvidence
  }

  alias Chimwemwe.Platform.TemporalQualificationError
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate_type "platform.temporal_qualification.fact_operation"
  @lock_namespace "platform-temporal-qualification-fact"
  @maximum_quantity 9_000_000_000_000
  @modes [:record, :reverse_and_replace]

  @spec run(:record | :reverse_and_replace, Ash.ActionInput.t(), keyword(), map()) ::
          {:ok, FactOperationResult.t()} | {:error, TemporalQualificationError.t()}
  def run(mode, input, _options, ash_context) when mode in @modes do
    arguments = input.arguments
    aggregate_id = claim_aggregate_id(mode, arguments)
    request_hash = OperationEvidence.request_hash({action_name(mode), arguments})

    with {:ok, context} <- OperationEvidence.context(ash_context),
         :ok <- OperationEvidence.lock(@lock_namespace, context.tenant_id, aggregate_id),
         :ok <- OperationEvidence.authorize(context, capability(mode)),
         {:ok, claim} <-
           OperationEvidence.claim(context, %{
             action_name: action_name(mode),
             aggregate_type: claim_aggregate_type(mode),
             aggregate_id: aggregate_id,
             idempotency_key: arguments.idempotency_key,
             request_hash: request_hash
           }) do
      execute_or_replay(mode, context, arguments, aggregate_id, request_hash, claim)
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp execute_or_replay(
         mode,
         context,
         arguments,
         _aggregate_id,
         _request_hash,
         {:new, claim_id}
       ) do
    execute(mode, context, arguments, claim_id)
  end

  defp execute_or_replay(
         _mode,
         context,
         _arguments,
         aggregate_id,
         request_hash,
         {:existing, claim}
       ) do
    if OperationEvidence.exact_replay?(claim, context, aggregate_id, request_hash) do
      decode_result(claim.result_payload, claim.audit_reference, claim.event_id)
    else
      temporal_error(:idempotency_conflict)
    end
  end

  defp execute(:record, context, arguments, claim_id) do
    operation_id = UUID.generate()
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    with {:ok, recorded_at} <-
           insert_operation(
             context.tenant_id,
             operation_id,
             arguments.scope_id,
             :record,
             nil,
             arguments.reason_code
           ),
         {:ok, fact} <-
           insert_fact(
             context.tenant_id,
             arguments.scope_id,
             operation_id,
             :entry,
             nil,
             arguments.effective_on,
             arguments.quantity
           ),
         result <-
           result(
             %{
               operation_id: operation_id,
               scope_id: arguments.scope_id,
               kind: :record,
               target_fact_id: nil,
               reason_code: arguments.reason_code,
               recorded_at: recorded_at,
               facts: [fact]
             },
             audit_reference,
             event_id
           ),
         :ok <- insert_evidence(:record, context, arguments, result),
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

  defp execute(:reverse_and_replace, context, arguments, claim_id) do
    operation_id = UUID.generate()
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    with {:ok, target} <- load_target(context.tenant_id, arguments.target_fact_id),
         :ok <- validate_target_quantity(target.quantity),
         {:ok, recorded_at} <-
           insert_operation(
             context.tenant_id,
             operation_id,
             target.scope_id,
             :reverse_and_replace,
             arguments.target_fact_id,
             arguments.reason_code
           ),
         {:ok, reversal} <-
           insert_fact(
             context.tenant_id,
             target.scope_id,
             operation_id,
             :reversal,
             arguments.target_fact_id,
             target.effective_on,
             -target.quantity
           ),
         {:ok, replacement} <-
           insert_fact(
             context.tenant_id,
             target.scope_id,
             operation_id,
             :entry,
             nil,
             arguments.replacement_effective_on,
             arguments.replacement_quantity
           ),
         result <-
           result(
             %{
               operation_id: operation_id,
               scope_id: target.scope_id,
               kind: :reverse_and_replace,
               target_fact_id: arguments.target_fact_id,
               reason_code: arguments.reason_code,
               recorded_at: recorded_at,
               facts: [reversal, replacement]
             },
             audit_reference,
             event_id
           ),
         :ok <- insert_evidence(:reverse_and_replace, context, arguments, result),
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

  defp load_target(tenant_id, fact_id) do
    case Repo.query(
           """
           SELECT scope_id::text, effective_on, quantity
           FROM platform_temporal_qualification_facts
           WHERE tenant_id = $1 AND id = $2 AND kind = 'entry'
           FOR UPDATE
           """,
           [OperationEvidence.dump_uuid(tenant_id), OperationEvidence.dump_uuid(fact_id)]
         ) do
      {:ok, %{rows: [[scope_id, effective_on, quantity]]}} ->
        {:ok, %{scope_id: scope_id, effective_on: effective_on, quantity: quantity}}

      {:ok, %{rows: []}} ->
        temporal_error(:not_found)

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp validate_target_quantity(quantity)
       when is_integer(quantity) and quantity != 0 and
              quantity >= -@maximum_quantity and quantity <= @maximum_quantity,
       do: :ok

  defp validate_target_quantity(_quantity), do: temporal_error(:conflict)

  defp insert_operation(tenant_id, operation_id, scope_id, kind, target_fact_id, reason_code) do
    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_fact_operations (
             id, tenant_id, scope_id, kind, target_fact_id, reason_code, recorded_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, NOW())
           RETURNING recorded_at
           """,
           [
             OperationEvidence.dump_uuid(operation_id),
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(scope_id),
             Atom.to_string(kind),
             OperationEvidence.dump_uuid(target_fact_id),
             reason_code
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} -> {:ok, recorded_at}
      {:error, error} -> OperationEvidence.translate_query_error(error)
    end
  end

  defp insert_fact(
         tenant_id,
         scope_id,
         operation_id,
         kind,
         reverses_fact_id,
         effective_on,
         quantity
       ) do
    fact_id = UUID.generate()

    case Repo.query(
           """
           INSERT INTO platform_temporal_qualification_facts (
             id,
             tenant_id,
             scope_id,
             operation_id,
             kind,
             reverses_fact_id,
             effective_on,
             quantity,
             recorded_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
           RETURNING recorded_at
           """,
           [
             OperationEvidence.dump_uuid(fact_id),
             OperationEvidence.dump_uuid(tenant_id),
             OperationEvidence.dump_uuid(scope_id),
             OperationEvidence.dump_uuid(operation_id),
             Atom.to_string(kind),
             OperationEvidence.dump_uuid(reverses_fact_id),
             effective_on,
             quantity
           ]
         ) do
      {:ok, %{rows: [[recorded_at]]}} ->
        {:ok,
         %FactView{
           id: fact_id,
           operation_id: operation_id,
           kind: kind,
           reverses_fact_id: reverses_fact_id,
           effective_on: effective_on,
           quantity: quantity,
           recorded_at: recorded_at
         }}

      {:error, error} ->
        OperationEvidence.translate_query_error(error)
    end
  end

  defp result(operation, audit_reference, event_id) do
    %FactOperationResult{
      operation: %FactOperationView{
        operation_id: operation.operation_id,
        scope_id: operation.scope_id,
        kind: operation.kind,
        target_fact_id: operation.target_fact_id,
        reason_code: operation.reason_code,
        recorded_at: operation.recorded_at,
        facts: operation.facts
      },
      audit_reference: audit_reference,
      event_id: event_id
    }
  end

  defp insert_evidence(mode, context, arguments, result) do
    operation = result.operation

    OperationEvidence.insert_evidence(context, %{
      audit_reference: result.audit_reference,
      event_id: result.event_id,
      action_name: action_name(mode),
      aggregate_type: @aggregate_type,
      aggregate_id: operation.operation_id,
      idempotency_key: arguments.idempotency_key,
      causation_id: arguments.causation_id,
      before_version: 0,
      after_version: 1,
      summary: %{
        "operation_id" => operation.operation_id,
        "operation_kind" => Atom.to_string(operation.kind),
        "target_fact_id" => operation.target_fact_id,
        "reason_code" => operation.reason_code,
        "purpose" => context.purpose,
        "fact_count" => length(operation.facts)
      },
      event_type: event_type(mode),
      payload: %{
        "operation_id" => operation.operation_id,
        "operation_kind" => Atom.to_string(operation.kind),
        "target_fact_id" => operation.target_fact_id,
        "fact_ids" => Enum.map(operation.facts, & &1.id),
        "fact_count" => length(operation.facts)
      }
    })
  end

  defp result_payload(result) do
    operation = result.operation

    %{
      "operation_id" => operation.operation_id,
      "scope_id" => operation.scope_id,
      "kind" => Atom.to_string(operation.kind),
      "target_fact_id" => operation.target_fact_id,
      "reason_code" => operation.reason_code,
      "recorded_at" => NaiveDateTime.to_iso8601(operation.recorded_at),
      "facts" => Enum.map(operation.facts, &fact_payload/1)
    }
  end

  defp fact_payload(fact) do
    %{
      "id" => fact.id,
      "operation_id" => fact.operation_id,
      "kind" => Atom.to_string(fact.kind),
      "reverses_fact_id" => fact.reverses_fact_id,
      "effective_on" => Date.to_iso8601(fact.effective_on),
      "quantity" => fact.quantity,
      "recorded_at" => NaiveDateTime.to_iso8601(fact.recorded_at)
    }
  end

  defp decode_result(payload, audit_reference, event_id) when is_map(payload) do
    with {:ok, operation_id} <- OperationEvidence.cast_uuid(payload["operation_id"]),
         {:ok, scope_id} <- OperationEvidence.cast_uuid(payload["scope_id"]),
         {:ok, kind} <- cast_operation_kind(payload["kind"]),
         {:ok, target_fact_id} <- cast_optional_uuid(payload["target_fact_id"]),
         reason_code when is_binary(reason_code) <- payload["reason_code"],
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]),
         {:ok, facts} <- decode_facts(payload["facts"]),
         {:ok, audit_reference} <- OperationEvidence.cast_uuid(audit_reference),
         {:ok, event_id} <- OperationEvidence.cast_uuid(event_id) do
      {:ok,
       result(
         %{
           operation_id: operation_id,
           scope_id: scope_id,
           kind: kind,
           target_fact_id: target_fact_id,
           reason_code: reason_code,
           recorded_at: recorded_at,
           facts: facts
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

  defp decode_facts(facts) when is_list(facts) do
    facts
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, decoded} ->
      case decode_fact(payload) do
        {:ok, fact} -> {:cont, {:ok, [fact | decoded]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded)}
      error -> error
    end
  end

  defp decode_facts(_facts), do: temporal_error(:retryable_dependency)

  defp decode_fact(payload) when is_map(payload) do
    with {:ok, id} <- OperationEvidence.cast_uuid(payload["id"]),
         {:ok, operation_id} <- OperationEvidence.cast_uuid(payload["operation_id"]),
         {:ok, kind} <- cast_fact_kind(payload["kind"]),
         {:ok, reverses_fact_id} <- cast_optional_uuid(payload["reverses_fact_id"]),
         {:ok, effective_on} <- Date.from_iso8601(payload["effective_on"]),
         quantity when is_integer(quantity) and quantity != 0 <- payload["quantity"],
         {:ok, recorded_at} <- NaiveDateTime.from_iso8601(payload["recorded_at"]) do
      {:ok,
       %FactView{
         id: id,
         operation_id: operation_id,
         kind: kind,
         reverses_fact_id: reverses_fact_id,
         effective_on: effective_on,
         quantity: quantity,
         recorded_at: recorded_at
       }}
    else
      _invalid -> temporal_error(:retryable_dependency)
    end
  end

  defp decode_fact(_payload), do: temporal_error(:retryable_dependency)

  defp cast_operation_kind("record"), do: {:ok, :record}
  defp cast_operation_kind("reverse_and_replace"), do: {:ok, :reverse_and_replace}
  defp cast_operation_kind(_kind), do: temporal_error(:retryable_dependency)

  defp cast_fact_kind("entry"), do: {:ok, :entry}
  defp cast_fact_kind("reversal"), do: {:ok, :reversal}
  defp cast_fact_kind(_kind), do: temporal_error(:retryable_dependency)

  defp cast_optional_uuid(nil), do: {:ok, nil}
  defp cast_optional_uuid(value), do: OperationEvidence.cast_uuid(value)

  defp claim_aggregate_id(:record, arguments), do: arguments.scope_id
  defp claim_aggregate_id(:reverse_and_replace, arguments), do: arguments.target_fact_id

  defp claim_aggregate_type(:record), do: "platform.temporal_qualification.fact_scope"
  defp claim_aggregate_type(:reverse_and_replace), do: "platform.temporal_qualification.fact"

  defp action_name(:record), do: "platform.temporal_qualification.fact.record"

  defp action_name(:reverse_and_replace),
    do: "platform.temporal_qualification.fact.reverse_and_replace"

  defp event_type(:record), do: "platform.temporal_qualification.fact.recorded"

  defp event_type(:reverse_and_replace),
    do: "platform.temporal_qualification.fact.reversed_and_replaced"

  defp capability(:record), do: "platform.temporal_qualification.facts.record"

  defp capability(:reverse_and_replace),
    do: "platform.temporal_qualification.facts.reverse_and_replace"

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
