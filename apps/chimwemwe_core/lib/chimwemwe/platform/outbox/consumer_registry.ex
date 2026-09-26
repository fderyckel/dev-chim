defmodule Chimwemwe.Platform.Outbox.ConsumerRegistry do
  @moduledoc """
  Immutable, code-owned declarations for internal outbox consumers.

  The registry fixes each consumer's exact event/schema subscription and delivery
  limits. It is supplied by trusted release code, never request or event data.
  """

  @key_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @maximum_key_length 160
  @maximum_batch_size 100
  @maximum_lease_ms 300_000
  @maximum_attempts 25
  @maximum_retry_ms 86_400_000
  @declaration_keys [:batch_size, :events, :key, :lease_ms, :max_attempts, :retry_ms]
  @event_keys [:schema_versions, :type]

  @enforce_keys [:declarations]
  defstruct [:declarations]

  @type event_contract :: %{type: String.t(), schema_versions: [pos_integer()]}
  @type declaration :: %{
          key: String.t(),
          events: [event_contract()],
          batch_size: pos_integer(),
          lease_ms: pos_integer(),
          max_attempts: pos_integer(),
          retry_ms: pos_integer()
        }
  @opaque t :: %__MODULE__{declarations: %{String.t() => declaration()}}

  @spec new([map()]) :: {:ok, t()} | {:error, :invalid_registry}
  def new(declarations) when is_list(declarations) and declarations != [] do
    declarations
    |> Enum.reduce_while({:ok, %{}}, fn declaration, {:ok, acc} ->
      with {:ok, normalized} <- normalize_declaration(declaration),
           false <- Map.has_key?(acc, normalized.key) do
        {:cont, {:ok, Map.put(acc, normalized.key, normalized)}}
      else
        _invalid_or_duplicate -> {:halt, {:error, :invalid_registry}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, %__MODULE__{declarations: normalized}}
      error -> error
    end
  end

  def new(_declarations), do: {:error, :invalid_registry}

  @doc false
  @spec revalidate(term()) :: {:ok, t()} | {:error, :invalid_registry}
  def revalidate(%__MODULE__{declarations: declarations} = registry)
      when is_map(declarations) do
    with {:ok, rebuilt} <- new(Map.values(declarations)),
         true <- rebuilt.declarations == declarations do
      {:ok, registry}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  def revalidate(_registry), do: {:error, :invalid_registry}

  @spec fetch(t(), term()) :: {:ok, declaration()} | {:error, :consumer_not_available}
  def fetch(%__MODULE__{declarations: declarations}, key) when is_binary(key) do
    case Map.fetch(declarations, key) do
      {:ok, declaration} -> {:ok, declaration}
      :error -> {:error, :consumer_not_available}
    end
  end

  def fetch(_registry, _key), do: {:error, :consumer_not_available}

  @doc false
  @spec event_pairs(declaration()) :: {[String.t()], [pos_integer()]}
  def event_pairs(%{events: events}) do
    events
    |> Enum.flat_map(fn event ->
      Enum.map(event.schema_versions, &{event.type, &1})
    end)
    |> Enum.sort()
    |> Enum.unzip()
  end

  defp normalize_declaration(declaration)
       when is_map(declaration) and not is_struct(declaration) do
    with true <- Enum.sort(Map.keys(declaration)) == @declaration_keys,
         {:ok, key} <- normalize_key(Map.fetch!(declaration, :key)),
         {:ok, events} <- normalize_events(Map.fetch!(declaration, :events)),
         {:ok, batch_size} <-
           bounded_integer(Map.fetch!(declaration, :batch_size), 1, @maximum_batch_size),
         {:ok, lease_ms} <-
           bounded_integer(Map.fetch!(declaration, :lease_ms), 1, @maximum_lease_ms),
         {:ok, max_attempts} <-
           bounded_integer(Map.fetch!(declaration, :max_attempts), 1, @maximum_attempts),
         {:ok, retry_ms} <-
           bounded_integer(Map.fetch!(declaration, :retry_ms), 1, @maximum_retry_ms) do
      {:ok,
       %{
         key: key,
         events: events,
         batch_size: batch_size,
         lease_ms: lease_ms,
         max_attempts: max_attempts,
         retry_ms: retry_ms
       }}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  defp normalize_declaration(_declaration), do: {:error, :invalid_registry}

  defp normalize_events(events) when is_list(events) and events != [] do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case normalize_event(event) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} ->
        normalized = Enum.sort_by(normalized, & &1.type)

        if Enum.uniq_by(normalized, & &1.type) == normalized do
          {:ok, normalized}
        else
          {:error, :invalid_registry}
        end

      error ->
        error
    end
  end

  defp normalize_events(_events), do: {:error, :invalid_registry}

  defp normalize_event(event) when is_map(event) and not is_struct(event) do
    with true <- Enum.sort(Map.keys(event)) == @event_keys,
         {:ok, type} <- normalize_key(Map.fetch!(event, :type)),
         versions when is_list(versions) and versions != [] <-
           Map.fetch!(event, :schema_versions),
         true <- Enum.all?(versions, &(is_integer(&1) and &1 > 0)),
         versions <- Enum.sort(versions),
         true <- Enum.uniq(versions) == versions do
      {:ok, %{type: type, schema_versions: versions}}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  defp normalize_event(_event), do: {:error, :invalid_registry}

  defp normalize_key(value) when is_binary(value) do
    normalized = String.trim(value)

    if byte_size(normalized) <= @maximum_key_length and Regex.match?(@key_pattern, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_registry}
    end
  end

  defp normalize_key(_value), do: {:error, :invalid_registry}

  defp bounded_integer(value, minimum, maximum)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: {:ok, value}

  defp bounded_integer(_value, _minimum, _maximum), do: {:error, :invalid_registry}
end
