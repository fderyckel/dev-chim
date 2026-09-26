defmodule Chimwemwe.Platform.TemporalQualification do
  @moduledoc """
  Trusted boundary for the neutral ADR 0018 temporal qualification proof.

  The boundary exposes private resource-specific revision, append-only fact, and
  deliberate-reconciliation actions plus named reads. It derives authority and
  routing from validated execution context and exposes no generic Ash options,
  repository selector, public interface, or school vocabulary.
  """

  alias Chimwemwe.Platform.{
    Authority,
    ExecutionContext,
    Persistence,
    TemporalQualificationError,
    TrustedActor
  }

  alias Chimwemwe.Platform.TemporalQualification.{
    Aggregate,
    ConsumerBasisView,
    ConsumerBoundary,
    ConsumerHistoryView,
    ConsumerResult,
    FactBoundary,
    FactHistoryView,
    FactOperationResult,
    FactOperationView,
    FactView,
    HistoryView,
    RevisionRead,
    RevisionResult,
    RevisionView
  }

  @publish_keys [
    :aggregate_id,
    :causation_id,
    :idempotency_key,
    :reason_code,
    :scope_id,
    :segments
  ]
  @correct_keys [
    :aggregate_id,
    :causation_id,
    :expected_revision_id,
    :idempotency_key,
    :reason_code,
    :segments
  ]
  @segment_keys [:effective_from, :effective_until, :value]
  @maximum_segments 32
  @reason_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/
  @current_read_capability "platform.temporal_qualification.revisions.read_current"
  @history_read_capability "platform.temporal_qualification.revisions.read_history"

  @doc "Records one immutable neutral append-only entry."
  @spec record_fact_entry(Supervisor.supervisor(), term(), map()) ::
          {:ok, FactOperationResult.t()} | {:error, term()}
  def record_fact_entry(runtime, context, input) do
    FactBoundary.record_entry(runtime, context, input)
  end

  @doc "Reverses one exact entry and records its replacement in one operation."
  @spec reverse_and_replace_fact(Supervisor.supervisor(), term(), map()) ::
          {:ok, FactOperationResult.t()} | {:error, term()}
  def reverse_and_replace_fact(runtime, context, input) do
    FactBoundary.reverse_and_replace(runtime, context, input)
  end

  @doc "Returns one exact authorized append-only fact."
  @spec get_fact(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactView.t()} | {:error, term()}
  def get_fact(runtime, context, fact_id) do
    FactBoundary.get_fact(runtime, context, fact_id)
  end

  @doc "Returns one exact authorized fact operation and all of its facts."
  @spec get_fact_operation(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactOperationView.t()} | {:error, term()}
  def get_fact_operation(runtime, context, operation_id) do
    FactBoundary.get_operation(runtime, context, operation_id)
  end

  @doc "Returns bounded ordered append-only operations for one synthetic scope."
  @spec list_fact_history(Supervisor.supervisor(), term(), term()) ::
          {:ok, FactHistoryView.t()} | {:error, term()}
  def list_fact_history(runtime, context, scope_id) do
    FactBoundary.list_history(runtime, context, scope_id)
  end

  @doc "Pins a neutral durable consumer to one exact current source revision."
  @spec pin_consumer_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, ConsumerResult.t()} | {:error, term()}
  def pin_consumer_revision(runtime, context, input) do
    ConsumerBoundary.pin_revision(runtime, context, input)
  end

  @doc "Appends a deliberate consumer reconciliation to an exact current revision."
  @spec reconcile_consumer_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, ConsumerResult.t()} | {:error, term()}
  def reconcile_consumer_revision(runtime, context, input) do
    ConsumerBoundary.reconcile_revision(runtime, context, input)
  end

  @doc "Returns the latest immutable basis for one reconciliation consumer."
  @spec get_consumer_current(Supervisor.supervisor(), term(), term()) ::
          {:ok, ConsumerBasisView.t()} | {:error, term()}
  def get_consumer_current(runtime, context, consumer_id) do
    ConsumerBoundary.get_current(runtime, context, consumer_id)
  end

  @doc "Returns bounded immutable basis history for one reconciliation consumer."
  @spec list_consumer_history(Supervisor.supervisor(), term(), term()) ::
          {:ok, ConsumerHistoryView.t()} | {:error, term()}
  def list_consumer_history(runtime, context, consumer_id) do
    ConsumerBoundary.list_history(runtime, context, consumer_id)
  end

  @doc "Publishes revision one for a new neutral aggregate."
  @spec publish_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, RevisionResult.t()} | {:error, term()}
  def publish_revision(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_write_input(:publish, input),
           {:ok, action_input} <- action_input(:publish, validated_context, normalized_input) do
        run_action(runtime, validated_context, action_input)
      end
    end)
  end

  @doc "Corrects one exact current revision by publishing an immutable successor."
  @spec correct_revision(Supervisor.supervisor(), term(), map()) ::
          {:ok, RevisionResult.t()} | {:error, term()}
  def correct_revision(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with {:ok, normalized_input} <- normalize_write_input(:correct, input),
           {:ok, action_input} <- action_input(:correct, validated_context, normalized_input) do
        run_action(runtime, validated_context, action_input)
      end
    end)
  end

  @doc "Returns the authoritative current revision and its complete segment set."
  @spec get_current(Supervisor.supervisor(), term(), term()) ::
          {:ok, RevisionView.t()} | {:error, term()}
  def get_current(runtime, context, aggregate_id) do
    governed_id_read(runtime, context, aggregate_id, @current_read_capability, fn tenant_id, id ->
      RevisionRead.get_current(tenant_id, id)
    end)
  end

  @doc "Returns the current revision segment effective on one Date."
  @spec get_effective(Supervisor.supervisor(), term(), term(), term()) ::
          {:ok, RevisionView.t()} | {:error, term()}
  def get_effective(runtime, context, aggregate_id, as_of) do
    ExecutionContext.with_validated(
      context,
      &get_effective_for_context(runtime, &1, aggregate_id, as_of)
    )
  end

  @doc "Returns one exact immutable revision when history access is authorized."
  @spec get_revision(Supervisor.supervisor(), term(), term()) ::
          {:ok, RevisionView.t()} | {:error, term()}
  def get_revision(runtime, context, revision_id) do
    governed_id_read(runtime, context, revision_id, @history_read_capability, fn tenant_id, id ->
      RevisionRead.get_revision(tenant_id, id)
    end)
  end

  @doc "Returns at most 100 ordered revisions and reports whether the result was truncated."
  @spec list_history(Supervisor.supervisor(), term(), term()) ::
          {:ok, HistoryView.t()} | {:error, term()}
  def list_history(runtime, context, aggregate_id) do
    governed_id_read(runtime, context, aggregate_id, @history_read_capability, fn tenant_id, id ->
      RevisionRead.list_history(tenant_id, id)
    end)
  end

  @doc "Fails explicitly because the neutral proof does not implement recorded-time queries."
  @spec get_as_known(Supervisor.supervisor(), term(), term(), term(), term()) ::
          {:error, term()}
  def get_as_known(runtime, context, aggregate_id, effective_as_of, recorded_as_of) do
    ExecutionContext.with_validated(
      context,
      &get_as_known_for_context(runtime, &1, aggregate_id, effective_as_of, recorded_as_of)
    )
  end

  defp governed_id_read(runtime, context, raw_id, capability, operation) do
    ExecutionContext.with_validated(
      context,
      &governed_id_read_for_context(runtime, &1, raw_id, capability, operation)
    )
  end

  defp run_read(runtime, context, capability, operation) do
    case Persistence.with_writer(runtime, context, fn ->
           authorized_read(context.actor, capability, operation)
         end) do
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

  defp get_effective_for_context(runtime, context, aggregate_id, as_of) do
    with {:ok, aggregate_id} <- cast_uuid(aggregate_id),
         {:ok, as_of} <- cast_date(as_of) do
      run_read(runtime, context, @current_read_capability, fn tenant_id ->
        RevisionRead.get_effective(tenant_id, aggregate_id, as_of)
      end)
    end
  end

  defp get_as_known_for_context(runtime, context, aggregate_id, effective_as_of, recorded_as_of) do
    with {:ok, _aggregate_id} <- cast_uuid(aggregate_id),
         {:ok, _effective_as_of} <- cast_date(effective_as_of),
         {:ok, _recorded_as_of} <- cast_datetime(recorded_as_of) do
      run_read(runtime, context, @history_read_capability, fn _tenant_id ->
        temporal_error(:unsupported_query)
      end)
    end
  end

  defp governed_id_read_for_context(runtime, context, raw_id, capability, operation) do
    with {:ok, id} <- cast_uuid(raw_id) do
      run_read(runtime, context, capability, fn tenant_id -> operation.(tenant_id, id) end)
    end
  end

  defp authorized_read(actor, capability, operation) do
    if Authority.actor_has_capability?(actor, capability) do
      operation.(TrustedActor.tenant_id(actor))
    else
      temporal_error(:forbidden)
    end
  end

  defp action_input(mode, context, input) do
    action_name = if mode == :publish, do: :publish_revision, else: :correct_revision

    action_input =
      Ash.ActionInput.for_action(Aggregate, action_name, input,
        actor: context.actor,
        authorize?: true,
        context: action_context(context),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid? do
      {:ok, action_input}
    else
      temporal_error(:invalid_input)
    end
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
      {:ok, {:ok, %RevisionResult{} = result}} -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> temporal_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

  defp normalize_write_input(mode, input) when is_map(input) and not is_struct(input) do
    expected_keys = if mode == :publish, do: @publish_keys, else: @correct_keys

    with {:ok, normalized} <- normalize_input_keys(input, &write_input_key(mode, &1)),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(expected_keys),
         {:ok, aggregate_id} <- cast_uuid(normalized.aggregate_id),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id),
         {:ok, reason_code} <- normalize_reason(normalized.reason_code),
         {:ok, segments} <- normalize_segments(normalized.segments),
         {:ok, mode_fields} <- normalize_mode_fields(mode, normalized) do
      {:ok,
       mode_fields
       |> Map.merge(%{
         aggregate_id: aggregate_id,
         idempotency_key: idempotency_key,
         causation_id: causation_id,
         reason_code: reason_code,
         segments: segments
       })}
    else
      {:error, %TemporalQualificationError{}} = error -> error
      _invalid -> temporal_error(:invalid_input)
    end
  end

  defp normalize_write_input(_mode, _input), do: temporal_error(:invalid_input)

  defp normalize_mode_fields(:publish, input) do
    with {:ok, scope_id} <- cast_uuid(input.scope_id), do: {:ok, %{scope_id: scope_id}}
  end

  defp normalize_mode_fields(:correct, input) do
    with {:ok, expected_revision_id} <- cast_uuid(input.expected_revision_id) do
      {:ok, %{expected_revision_id: expected_revision_id}}
    end
  end

  defp normalize_segments(segments)
       when is_list(segments) and length(segments) in 1..@maximum_segments do
    with {:ok, normalized} <- map_all(segments, &normalize_segment/1),
         sorted <- Enum.sort_by(normalized, &{&1.effective_from, &1.effective_until, &1.value}),
         :ok <- reject_overlaps(sorted) do
      {:ok, sorted}
    end
  end

  defp normalize_segments(_segments), do: temporal_error(:invalid_input)

  defp normalize_segment(segment) when is_map(segment) and not is_struct(segment) do
    with {:ok, normalized} <- normalize_input_keys(segment, &segment_input_key/1),
         true <- Enum.sort(Map.keys(normalized)) == Enum.sort(@segment_keys),
         {:ok, effective_from} <- cast_date(normalized.effective_from),
         {:ok, effective_until} <- cast_date(normalized.effective_until),
         true <- Date.before?(effective_from, effective_until),
         {:ok, value} <- normalize_value(normalized.value) do
      {:ok,
       %{
         effective_from: effective_from,
         effective_until: effective_until,
         value: value
       }}
    else
      {:error, %TemporalQualificationError{}} = error -> error
      _invalid -> temporal_error(:invalid_input)
    end
  end

  defp normalize_segment(_segment), do: temporal_error(:invalid_input)

  defp reject_overlaps([left, right | rest]) do
    if Date.before?(right.effective_from, left.effective_until) do
      temporal_error(:effective_time_conflict)
    else
      reject_overlaps([right | rest])
    end
  end

  defp reject_overlaps(_segments), do: :ok

  defp normalize_reason(reason) when is_binary(reason) do
    reason = String.trim(reason)

    if byte_size(reason) in 1..80 and Regex.match?(@reason_pattern, reason) do
      {:ok, reason}
    else
      temporal_error(:invalid_input)
    end
  end

  defp normalize_reason(_reason), do: temporal_error(:invalid_input)

  defp normalize_value(value) when is_binary(value) do
    value = String.trim(value)
    if byte_size(value) in 1..80, do: {:ok, value}, else: temporal_error(:invalid_input)
  end

  defp normalize_value(_value), do: temporal_error(:invalid_input)

  defp normalize_input_keys(input, key_normalizer) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      with {:ok, normalized_key} <- key_normalizer.(key),
           false <- Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        _invalid_or_duplicate -> {:halt, temporal_error(:invalid_input)}
      end
    end)
  end

  defp write_input_key(:publish, key) when key in @publish_keys, do: {:ok, key}
  defp write_input_key(:correct, key) when key in @correct_keys, do: {:ok, key}
  defp write_input_key(:publish, "scope_id"), do: {:ok, :scope_id}
  defp write_input_key(:correct, "expected_revision_id"), do: {:ok, :expected_revision_id}

  defp write_input_key(mode, "aggregate_id") when mode in [:publish, :correct],
    do: {:ok, :aggregate_id}

  defp write_input_key(mode, "causation_id") when mode in [:publish, :correct],
    do: {:ok, :causation_id}

  defp write_input_key(mode, "idempotency_key") when mode in [:publish, :correct],
    do: {:ok, :idempotency_key}

  defp write_input_key(mode, "reason_code") when mode in [:publish, :correct],
    do: {:ok, :reason_code}

  defp write_input_key(mode, "segments") when mode in [:publish, :correct], do: {:ok, :segments}
  defp write_input_key(_mode, _key), do: temporal_error(:invalid_input)

  defp segment_input_key(key) when key in @segment_keys, do: {:ok, key}
  defp segment_input_key("effective_from"), do: {:ok, :effective_from}
  defp segment_input_key("effective_until"), do: {:ok, :effective_until}
  defp segment_input_key("value"), do: {:ok, :value}
  defp segment_input_key(_key), do: temporal_error(:invalid_input)

  defp map_all(values, mapper) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, mapped} ->
      case mapper.(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | mapped]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      error -> error
    end
  end

  defp cast_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> temporal_error(:invalid_input)
    end
  end

  defp cast_date(%Date{} = value), do: {:ok, value}

  defp cast_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> temporal_error(:invalid_input)
    end
  end

  defp cast_date(_value), do: temporal_error(:invalid_input)

  defp cast_datetime(%DateTime{} = value), do: {:ok, DateTime.shift_zone!(value, "Etc/UTC")}

  defp cast_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, DateTime.shift_zone!(datetime, "Etc/UTC")}
      {:error, _reason} -> temporal_error(:invalid_input)
    end
  end

  defp cast_datetime(_value), do: temporal_error(:invalid_input)

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
