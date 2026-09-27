defmodule Chimwemwe.Platform.TemporalQualification.ActionBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{Persistence, TemporalQualificationError, TrustedActor}

  @spec run(Supervisor.supervisor(), map(), module(), atom(), map(), module()) ::
          {:ok, struct()} | {:error, term()}
  def run(runtime, context, resource, action, arguments, result_module) do
    action_input =
      Ash.ActionInput.for_action(resource, action, arguments,
        actor: context.actor,
        authorize?: true,
        context: action_context(context),
        domain: Chimwemwe.Platform,
        tenant: TrustedActor.tenant_id(context.actor)
      )

    if action_input.valid? do
      run_action(runtime, context, action_input, result_module)
    else
      temporal_error(:invalid_input)
    end
  rescue
    _error -> temporal_error(:internal)
  end

  @spec normalize_keys(map(), [atom()]) :: {:ok, map()} | {:error, TemporalQualificationError.t()}
  def normalize_keys(input, allowed) when is_map(input) and not is_struct(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      normalized_key = normalize_key(key, allowed)

      if normalized_key && not Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        {:halt, temporal_error(:invalid_input)}
      end
    end)
  end

  def normalize_keys(_input, _allowed), do: temporal_error(:invalid_input)

  @spec uuid(term()) :: {:ok, String.t()} | {:error, TemporalQualificationError.t()}
  def uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> temporal_error(:invalid_input)
    end
  end

  @spec date(term()) :: {:ok, Date.t()} | {:error, TemporalQualificationError.t()}
  def date(%Date{} = value), do: {:ok, value}

  def date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> temporal_error(:invalid_input)
    end
  end

  def date(_value), do: temporal_error(:invalid_input)

  @spec digest(term()) :: {:ok, binary()} | {:error, TemporalQualificationError.t()}
  def digest(value) when is_binary(value) and byte_size(value) == 32, do: {:ok, value}

  def digest(value) when is_binary(value) and byte_size(value) == 64 do
    case Base.decode16(value, case: :mixed) do
      {:ok, digest} when byte_size(digest) == 32 -> {:ok, digest}
      _invalid -> temporal_error(:invalid_input)
    end
  end

  def digest(_value), do: temporal_error(:invalid_input)

  @spec token(term(), Regex.t(), Range.t()) ::
          {:ok, String.t()} | {:error, TemporalQualificationError.t()}
  def token(value, pattern, range) when is_binary(value) do
    normalized = String.trim(value)

    if byte_size(normalized) in range and Regex.match?(pattern, normalized) do
      {:ok, normalized}
    else
      temporal_error(:invalid_input)
    end
  end

  def token(_value, _pattern, _range), do: temporal_error(:invalid_input)

  @spec positive_integer(term()) ::
          {:ok, pos_integer()} | {:error, TemporalQualificationError.t()}
  def positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  def positive_integer(_value), do: temporal_error(:invalid_input)

  def error(code), do: temporal_error(code)

  defp normalize_key(key, allowed) when is_atom(key), do: if(key in allowed, do: key)

  defp normalize_key(key, allowed) when is_binary(key) do
    Enum.find(allowed, &(Atom.to_string(&1) == key))
  end

  defp normalize_key(_key, _allowed), do: nil

  defp run_action(runtime, context, action_input, result_module) do
    case Persistence.with_writer(runtime, context, fn ->
           Ash.run_action(action_input,
             actor: context.actor,
             authorize?: true,
             domain: Chimwemwe.Platform,
             tenant: TrustedActor.tenant_id(context.actor)
           )
         end) do
      {:ok, {:ok, result}} when is_struct(result, result_module) -> {:ok, result}
      {:ok, {:error, error}} -> map_action_error(error)
      {:ok, _unexpected} -> temporal_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> temporal_error(:retryable_dependency)
  catch
    :exit, _reason -> temporal_error(:retryable_dependency)
  end

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
