defmodule Chimwemwe.Platform.TemporalQualification.ImportBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.ExecutionContext

  alias Chimwemwe.Platform.TemporalQualification.{
    ActionBoundary,
    ImportRecord,
    ImportResult
  }

  @baseline_keys [
    :import_id,
    :module_key,
    :source_snapshot_digest,
    :source_identifier_digest,
    :mapping_revision,
    :aggregate_id,
    :revision_id,
    :reason_code,
    :idempotency_key,
    :causation_id
  ]
  @conflict_keys [
    :import_id,
    :module_key,
    :source_snapshot_digest,
    :source_identifier_digest,
    :mapping_revision,
    :conflict_code,
    :reason_code,
    :idempotency_key,
    :causation_id
  ]
  @reconcile_keys [
    :import_id,
    :expected_record_id,
    :module_key,
    :aggregate_id,
    :revision_id,
    :reason_code,
    :idempotency_key,
    :causation_id
  ]
  @qualified_key ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @simple_token ~r/^[A-Za-z0-9][A-Za-z0-9._-]*$/
  @reason_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/

  def register_baseline(runtime, context, input) do
    initial_action(runtime, context, input, :register_baseline, @baseline_keys)
  end

  def register_conflict(runtime, context, input) do
    initial_action(runtime, context, input, :register_conflict, @conflict_keys)
  end

  def reconcile_conflict(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, @reconcile_keys),
           true <- exact_keys?(normalized, @reconcile_keys),
           {:ok, import_id} <- ActionBoundary.uuid(normalized.import_id),
           {:ok, expected_record_id} <- ActionBoundary.uuid(normalized.expected_record_id),
           {:ok, module_key} <- module_key(normalized.module_key),
           {:ok, aggregate_id} <- ActionBoundary.uuid(normalized.aggregate_id),
           {:ok, revision_id} <- ActionBoundary.uuid(normalized.revision_id),
           {:ok, reason_code} <- reason(normalized.reason_code),
           {:ok, idempotency_key} <- ActionBoundary.uuid(normalized.idempotency_key),
           {:ok, causation_id} <- ActionBoundary.uuid(normalized.causation_id) do
        ActionBoundary.run(
          runtime,
          validated,
          ImportRecord,
          :reconcile_conflict,
          %{
            import_id: import_id,
            expected_record_id: expected_record_id,
            module_key: module_key,
            aggregate_id: aggregate_id,
            revision_id: revision_id,
            reason_code: reason_code,
            idempotency_key: idempotency_key,
            causation_id: causation_id
          },
          ImportResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end

  defp initial_action(runtime, context, input, action, keys) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, keys),
           true <- exact_keys?(normalized, keys),
           {:ok, import_id} <- ActionBoundary.uuid(normalized.import_id),
           {:ok, module_key} <- module_key(normalized.module_key),
           {:ok, snapshot_digest} <- ActionBoundary.digest(normalized.source_snapshot_digest),
           {:ok, identifier_digest} <- ActionBoundary.digest(normalized.source_identifier_digest),
           {:ok, mapping_revision} <-
             ActionBoundary.token(normalized.mapping_revision, @simple_token, 1..80),
           {:ok, action_fields} <- initial_action_fields(action, normalized),
           {:ok, reason_code} <- reason(normalized.reason_code),
           {:ok, idempotency_key} <- ActionBoundary.uuid(normalized.idempotency_key),
           {:ok, causation_id} <- ActionBoundary.uuid(normalized.causation_id) do
        arguments =
          Map.merge(action_fields, %{
            import_id: import_id,
            module_key: module_key,
            source_snapshot_digest: snapshot_digest,
            source_identifier_digest: identifier_digest,
            mapping_revision: mapping_revision,
            reason_code: reason_code,
            idempotency_key: idempotency_key,
            causation_id: causation_id
          })

        ActionBoundary.run(
          runtime,
          validated,
          ImportRecord,
          action,
          arguments,
          ImportResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end

  defp initial_action_fields(:register_baseline, input) do
    with {:ok, aggregate_id} <- ActionBoundary.uuid(input.aggregate_id),
         {:ok, revision_id} <- ActionBoundary.uuid(input.revision_id) do
      {:ok, %{aggregate_id: aggregate_id, revision_id: revision_id}}
    end
  end

  defp initial_action_fields(:register_conflict, input) do
    with {:ok, conflict_code} <- ActionBoundary.token(input.conflict_code, @reason_pattern, 1..80) do
      {:ok, %{conflict_code: conflict_code}}
    end
  end

  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)
  defp module_key(value), do: ActionBoundary.token(value, @qualified_key, 3..120)
  defp reason(value), do: ActionBoundary.token(value, @reason_pattern, 1..80)
end
