defmodule Chimwemwe.Platform.TemporalQualification.FactBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{
    Authority,
    ExecutionContext,
    Persistence,
    TemporalQualificationError,
    TrustedActor
  }

  alias Chimwemwe.Platform.TemporalQualification.{
    Fact,
    FactHistoryView,
    FactOperationResult,
    FactOperationView,
    FactRead,
    FactView,
    OperationEvidence
  }

  @record_keys [
    :causation_id,
    :effective_on,
    :idempotency_key,
    :quantity,
    :reason_code,
    :scope_id
  ]
  @reverse_keys [
    :causation_id,
    :idempotency_key,
    :reason_code,
    :replacement_effective_on,
    :replacement_quantity,
    :target_fact_id
  ]
  @maximum_quantity 9_000_000_000_000
  @reason_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/
  @read_capability "platform.temporal_qualification.facts.read_history"

  @spec record_entry(Supervisor.supervisor(), term(), map()) ::
          {:ok, FactOperationResult.t()} | {:error, term()}
  def record_entry(runtime, context, input) do
    governed_action(runtime, context, :record, input)
  end

  @spec reverse_and_replace(Supervisor.supervisor(), term(), map()) ::
          {:ok, FactOperationResult.t()} | {:error, term()}
  def reverse_and_replace(runtime, context, input) do
    governed_action(runtime, context, :reverse_and_replace, input)
  end

  @spec get_fact(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactView.t()} | {:error, term()}
  def get_fact(runtime, context, fact_id) do
    governed_read(runtime, context, fact_id, &FactRead.get_fact/2)
  end

  @spec get_operation(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactOperationView.t()} | {:error, term()}
  def get_operation(runtime, context, operation_id) do
    governed_read(runtime, context, operation_id, &FactRead.get_operation/2)
  end

  @spec list_history(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactHistoryView.t()} | {:error, term()}
  def list_history(runtime, context, scope_id) do
    governed_read(runtime, context, scope_id, &FactRead.list_history/2)
  end

  defp governed_action(runtime, context, mode, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_input(mode, input),
           {:ok, action_input} <- action_input(mode, validated_context, normalized_input) do
        run_action(runtime, validated_context, action_input)
      end
    end)
  end

  defp governed_read(runtime, context, raw_id, operation) do
    ExecutionContext.with_validated(context, fn validated_context ->
      case OperationEvidence.cast_uuid(raw_id) do
        {:ok, id} -> run_read(runtime, validated_context, operation, id)
        {:error, _reason} = error -> error
      end
    end)
  end

  defp run_read(runtime, context, operation, id) do
    result =
      Persistence.with_writer(runtime, context, fn ->
        authorized_read(context, operation, id)
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

  defp authorized_read(context, operation, id) do
    if Authority.actor_has_capability?(context.actor, @read_capability) do
      operation.(TrustedActor.tenant_id(context.actor), id)
    else
      temporal_error(:forbidden)
    end
  end

  defp action_input(mode, context, input) do
    action_name = if mode == :record, do: :record_entry, else: :reverse_and_replace

    action_input =
      Ash.ActionInput.for_action(Fact, action_name, input,
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
      {:ok, {:ok, %FactOperationResult{} = result}} -> {:ok, result}
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
    expected_keys = if mode == :record, do: @record_keys, else: @reverse_keys

    with {:ok, normalized} <- normalize_keys(input, mode),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(expected_keys),
         {:ok, idempotency_key} <- OperationEvidence.cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- OperationEvidence.cast_uuid(normalized.causation_id),
         {:ok, reason_code} <- normalize_reason(normalized.reason_code),
         {:ok, mode_fields} <- normalize_mode_fields(mode, normalized) do
      {:ok,
       Map.merge(mode_fields, %{
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

  defp normalize_mode_fields(:record, input) do
    with {:ok, scope_id} <- OperationEvidence.cast_uuid(input.scope_id),
         {:ok, effective_on} <- cast_date(input.effective_on),
         {:ok, quantity} <- cast_quantity(input.quantity) do
      {:ok, %{scope_id: scope_id, effective_on: effective_on, quantity: quantity}}
    end
  end

  defp normalize_mode_fields(:reverse_and_replace, input) do
    with {:ok, target_fact_id} <- OperationEvidence.cast_uuid(input.target_fact_id),
         {:ok, replacement_effective_on} <- cast_date(input.replacement_effective_on),
         {:ok, replacement_quantity} <- cast_quantity(input.replacement_quantity) do
      {:ok,
       %{
         target_fact_id: target_fact_id,
         replacement_effective_on: replacement_effective_on,
         replacement_quantity: replacement_quantity
       }}
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

  defp input_key(:record, key) when key in @record_keys, do: {:ok, key}
  defp input_key(:reverse_and_replace, key) when key in @reverse_keys, do: {:ok, key}
  defp input_key(:record, "scope_id"), do: {:ok, :scope_id}
  defp input_key(:record, "effective_on"), do: {:ok, :effective_on}
  defp input_key(:record, "quantity"), do: {:ok, :quantity}
  defp input_key(:reverse_and_replace, "target_fact_id"), do: {:ok, :target_fact_id}

  defp input_key(:reverse_and_replace, "replacement_effective_on"),
    do: {:ok, :replacement_effective_on}

  defp input_key(:reverse_and_replace, "replacement_quantity"),
    do: {:ok, :replacement_quantity}

  defp input_key(mode, "reason_code") when mode in [:record, :reverse_and_replace],
    do: {:ok, :reason_code}

  defp input_key(mode, "idempotency_key") when mode in [:record, :reverse_and_replace],
    do: {:ok, :idempotency_key}

  defp input_key(mode, "causation_id") when mode in [:record, :reverse_and_replace],
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

  defp cast_quantity(quantity)
       when is_integer(quantity) and quantity != 0 and
              quantity >= -@maximum_quantity and quantity <= @maximum_quantity,
       do: {:ok, quantity}

  defp cast_quantity(_quantity), do: temporal_error(:invalid_input)

  defp cast_date(%Date{} = date), do: {:ok, date}

  defp cast_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> temporal_error(:invalid_input)
    end
  end

  defp cast_date(_value), do: temporal_error(:invalid_input)

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
