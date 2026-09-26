defmodule Chimwemwe.Platform.TemporalQualification.ConsumerBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{
    Authority,
    ExecutionContext,
    Persistence,
    TemporalQualificationError,
    TrustedActor
  }

  alias Chimwemwe.Platform.TemporalQualification.{
    ConsumerBasis,
    ConsumerBasisView,
    ConsumerHistoryView,
    ConsumerRead,
    ConsumerResult,
    OperationEvidence
  }

  @pin_keys [
    :aggregate_id,
    :causation_id,
    :consumer_id,
    :idempotency_key,
    :reason_code,
    :revision_id
  ]
  @reconcile_keys [
    :causation_id,
    :consumer_id,
    :expected_basis_id,
    :idempotency_key,
    :reason_code,
    :target_revision_id
  ]
  @reason_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/
  @read_capability "platform.temporal_qualification.consumers.read_history"

  @spec pin_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, ConsumerResult.t()} | {:error, term()}
  def pin_revision(runtime, context, input) do
    governed_action(runtime, context, :pin, input)
  end

  @spec reconcile_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, ConsumerResult.t()} | {:error, term()}
  def reconcile_revision(runtime, context, input) do
    governed_action(runtime, context, :reconcile, input)
  end

  @spec get_current(Supervisor.supervisor(), term(), term()) ::
          {:ok, ConsumerBasisView.t()} | {:error, term()}
  def get_current(runtime, context, consumer_id) do
    governed_read(runtime, context, consumer_id, &ConsumerRead.get_current/2)
  end

  @spec list_history(Supervisor.supervisor(), term(), term()) ::
          {:ok, ConsumerHistoryView.t()} | {:error, term()}
  def list_history(runtime, context, consumer_id) do
    governed_read(runtime, context, consumer_id, &ConsumerRead.list_history/2)
  end

  defp governed_action(runtime, context, mode, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_input(mode, input),
           {:ok, action_input} <- action_input(mode, validated_context, normalized_input) do
        run_action(runtime, validated_context, action_input)
      end
    end)
  end

  defp governed_read(runtime, context, raw_consumer_id, operation) do
    ExecutionContext.with_validated(context, fn validated_context ->
      case OperationEvidence.cast_uuid(raw_consumer_id) do
        {:ok, consumer_id} -> run_read(runtime, validated_context, operation, consumer_id)
        {:error, _reason} = error -> error
      end
    end)
  end

  defp run_read(runtime, context, operation, consumer_id) do
    result =
      Persistence.with_writer(runtime, context, fn ->
        authorized_read(context, operation, consumer_id)
      end)

    case result do
      {:ok, {:ok, _value} = result} -> result
      {:ok, {:error, %TemporalQualificationError{}} = error} -> error
      {:ok, _unexpected} -> temporal_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp authorized_read(context, operation, consumer_id) do
    if Authority.actor_has_capability?(context.actor, @read_capability) do
      operation.(TrustedActor.tenant_id(context.actor), consumer_id)
    else
      temporal_error(:forbidden)
    end
  end

  defp action_input(mode, context, input) do
    action_name = if mode == :pin, do: :pin_revision, else: :reconcile_revision

    action_input =
      Ash.ActionInput.for_action(ConsumerBasis, action_name, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid?, do: {:ok, action_input}, else: temporal_error(:invalid_input)
  rescue
    _error -> temporal_error(:internal)
  end

  defp run_action(runtime, context, action_input) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, %ConsumerResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> temporal_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp normalize_input(mode, input) when is_map(input) and not is_struct(input) do
    expected_keys = if mode == :pin, do: @pin_keys, else: @reconcile_keys

    with {:ok, normalized} <- normalize_keys(input, mode),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(expected_keys),
         {:ok, consumer_id} <- OperationEvidence.cast_uuid(normalized.consumer_id),
         {:ok, idempotency_key} <- OperationEvidence.cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- OperationEvidence.cast_uuid(normalized.causation_id),
         {:ok, reason_code} <- normalize_reason(normalized.reason_code),
         {:ok, mode_fields} <- normalize_mode_fields(mode, normalized) do
      {:ok,
       Map.merge(mode_fields, %{
         consumer_id: consumer_id,
         idempotency_key: idempotency_key,
         causation_id: causation_id,
         reason_code: reason_code
       })}
    else
      {:error, %TemporalQualificationError{}} = error -> error
      _invalid -> temporal_error(:invalid_input)
    end
  end

  defp normalize_input(_mode, _input), do: temporal_error(:invalid_input)

  defp normalize_mode_fields(:pin, input) do
    with {:ok, aggregate_id} <- OperationEvidence.cast_uuid(input.aggregate_id),
         {:ok, revision_id} <- OperationEvidence.cast_uuid(input.revision_id) do
      {:ok, %{aggregate_id: aggregate_id, revision_id: revision_id}}
    end
  end

  defp normalize_mode_fields(:reconcile, input) do
    with {:ok, expected_basis_id} <- OperationEvidence.cast_uuid(input.expected_basis_id),
         {:ok, target_revision_id} <- OperationEvidence.cast_uuid(input.target_revision_id) do
      {:ok, %{expected_basis_id: expected_basis_id, target_revision_id: target_revision_id}}
    end
  end

  defp normalize_keys(input, mode) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- input_key(mode, key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid -> {:halt, temporal_error(:invalid_input)}
      end
    end)
  end

  defp input_key(:pin, key) when key in @pin_keys, do: {:ok, key}
  defp input_key(:reconcile, key) when key in @reconcile_keys, do: {:ok, key}
  defp input_key(:pin, "aggregate_id"), do: {:ok, :aggregate_id}
  defp input_key(:pin, "revision_id"), do: {:ok, :revision_id}
  defp input_key(:reconcile, "expected_basis_id"), do: {:ok, :expected_basis_id}
  defp input_key(:reconcile, "target_revision_id"), do: {:ok, :target_revision_id}

  defp input_key(mode, "consumer_id") when mode in [:pin, :reconcile],
    do: {:ok, :consumer_id}

  defp input_key(mode, "reason_code") when mode in [:pin, :reconcile],
    do: {:ok, :reason_code}

  defp input_key(mode, "idempotency_key") when mode in [:pin, :reconcile],
    do: {:ok, :idempotency_key}

  defp input_key(mode, "causation_id") when mode in [:pin, :reconcile],
    do: {:ok, :causation_id}

  defp input_key(_mode, _key), do: temporal_error(:invalid_input)

  defp normalize_reason(reason) when is_binary(reason) do
    reason = String.trim(reason)

    if byte_size(reason) in 1..80 and Regex.match?(@reason_pattern, reason) do
      {:ok, reason}
    else
      temporal_error(:invalid_input)
    end
  end

  defp normalize_reason(_reason), do: temporal_error(:invalid_input)

  defp action_context(context) do
    %{
      chimwemwe: %{
        correlation_id: context.correlation_id,
        locale: context.locale,
        purpose: context.purpose,
        routing_version: context.placement.routing_version
      }
    }
  end

  defp map_action_error(error) do
    case find_temporal_error(error) do
      %TemporalQualificationError{} = temporal_error -> {:error, temporal_error}
      nil when is_struct(error, Ash.Error.Forbidden) -> temporal_error(:forbidden)
      nil when is_struct(error, Ash.Error.Invalid) -> temporal_error(:invalid_input)
      nil -> temporal_error(:internal)
    end
  end

  defp find_temporal_error(%TemporalQualificationError{} = error), do: error

  defp find_temporal_error(%{errors: errors}) when is_list(errors) do
    Enum.find_value(errors, &find_temporal_error/1)
  end

  defp find_temporal_error(%{error: error}), do: find_temporal_error(error)
  defp find_temporal_error(_error), do: nil

  defp temporal_error(code), do: {:error, %TemporalQualificationError{code: code}}
end
