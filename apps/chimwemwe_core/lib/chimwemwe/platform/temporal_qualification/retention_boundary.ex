defmodule Chimwemwe.Platform.TemporalQualification.RetentionBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.ExecutionContext

  alias Chimwemwe.Platform.TemporalQualification.{
    ActionBoundary,
    RetentionControl,
    RetentionResult
  }

  @declare_keys [
    :aggregate_id,
    :module_key,
    :policy_key,
    :classification,
    :retention_started_on,
    :retain_until,
    :reason_code,
    :idempotency_key,
    :causation_id
  ]
  @hold_keys [
    :control_id,
    :expected_version,
    :hold_reference_digest,
    :reason_code,
    :idempotency_key,
    :causation_id
  ]
  @erase_keys [:control_id, :expected_version, :reason_code, :idempotency_key, :causation_id]
  @qualified_key ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/

  def declare(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, @declare_keys),
           true <- exact_keys?(normalized, @declare_keys),
           {:ok, aggregate_id} <- ActionBoundary.uuid(normalized.aggregate_id),
           {:ok, module_key} <-
             ActionBoundary.token(normalized.module_key, @qualified_key, 3..120),
           {:ok, policy_key} <-
             ActionBoundary.token(normalized.policy_key, @qualified_key, 3..120),
           {:ok, classification} <- classification(normalized.classification),
           {:ok, started_on} <- ActionBoundary.date(normalized.retention_started_on),
           {:ok, retain_until} <- ActionBoundary.date(normalized.retain_until),
           true <- Date.compare(started_on, retain_until) in [:lt, :eq],
           {:ok, reason_code} <- reason(normalized.reason_code),
           {:ok, idempotency_key} <- ActionBoundary.uuid(normalized.idempotency_key),
           {:ok, causation_id} <- ActionBoundary.uuid(normalized.causation_id) do
        ActionBoundary.run(
          runtime,
          validated,
          RetentionControl,
          :declare_retention,
          %{
            aggregate_id: aggregate_id,
            module_key: module_key,
            policy_key: policy_key,
            classification: classification,
            retention_started_on: started_on,
            retain_until: retain_until,
            reason_code: reason_code,
            idempotency_key: idempotency_key,
            causation_id: causation_id
          },
          RetentionResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end

  def place_hold(runtime, context, input),
    do: hold_action(runtime, context, input, :place_legal_hold)

  def release_hold(runtime, context, input),
    do: hold_action(runtime, context, input, :release_legal_hold)

  def erase(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, @erase_keys),
           true <- exact_keys?(normalized, @erase_keys),
           {:ok, control_id} <- ActionBoundary.uuid(normalized.control_id),
           {:ok, version} <- ActionBoundary.positive_integer(normalized.expected_version),
           {:ok, reason_code} <- reason(normalized.reason_code),
           {:ok, idempotency_key} <- ActionBoundary.uuid(normalized.idempotency_key),
           {:ok, causation_id} <- ActionBoundary.uuid(normalized.causation_id) do
        ActionBoundary.run(
          runtime,
          validated,
          RetentionControl,
          :erase_retained_content,
          %{
            control_id: control_id,
            expected_version: version,
            reason_code: reason_code,
            idempotency_key: idempotency_key,
            causation_id: causation_id
          },
          RetentionResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end

  defp hold_action(runtime, context, input, action) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, @hold_keys),
           true <- exact_keys?(normalized, @hold_keys),
           {:ok, control_id} <- ActionBoundary.uuid(normalized.control_id),
           {:ok, version} <- ActionBoundary.positive_integer(normalized.expected_version),
           {:ok, digest} <- ActionBoundary.digest(normalized.hold_reference_digest),
           {:ok, reason_code} <- reason(normalized.reason_code),
           {:ok, idempotency_key} <- ActionBoundary.uuid(normalized.idempotency_key),
           {:ok, causation_id} <- ActionBoundary.uuid(normalized.causation_id) do
        ActionBoundary.run(
          runtime,
          validated,
          RetentionControl,
          action,
          %{
            control_id: control_id,
            expected_version: version,
            hold_reference_digest: digest,
            reason_code: reason_code,
            idempotency_key: idempotency_key,
            causation_id: causation_id
          },
          RetentionResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end

  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)
  defp classification(value) when value in [:internal, :restricted], do: {:ok, value}
  defp classification("internal"), do: {:ok, :internal}
  defp classification("restricted"), do: {:ok, :restricted}
  defp classification(_value), do: ActionBoundary.error(:invalid_input)

  defp reason(value),
    do: ActionBoundary.token(value, ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/, 1..80)
end
