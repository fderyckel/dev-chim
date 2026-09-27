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
  @required_declaration_keys [
    :batch_size,
    :events,
    :handler,
    :handler_revision,
    :key,
    :lease_ms,
    :max_attempts,
    :retry_ms
  ]
  @optional_declaration_keys [:module_key, :work_kind]
  @event_keys [:schema_versions, :type]

  @enforce_keys [:declarations]
  defstruct [:declarations]

  @type event_contract :: %{type: String.t(), schema_versions: [pos_integer()]}
  @type declaration :: %{
          key: String.t(),
          events: [event_contract()],
          handler: module(),
          handler_revision: pos_integer(),
          batch_size: pos_integer(),
          lease_ms: pos_integer(),
          max_attempts: pos_integer(),
          retry_ms: pos_integer(),
          module_key: String.t() | nil,
          work_kind: :platform | :ordinary | :mandatory
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
      {:ok, normalized} ->
        if unique_ordinary_module_consumers?(normalized) do
          {:ok, %__MODULE__{declarations: normalized}}
        else
          {:error, :invalid_registry}
        end

      error ->
        error
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
  @spec ordinary_for_module(t(), String.t()) ::
          {:ok, declaration()} | {:error, :consumer_not_available}
  def ordinary_for_module(%__MODULE__{declarations: declarations}, module_key)
      when is_binary(module_key) do
    matches =
      declarations
      |> Map.values()
      |> Enum.filter(&(&1.module_key == module_key and &1.work_kind == :ordinary))

    case matches do
      [declaration] -> {:ok, declaration}
      _none_or_ambiguous -> {:error, :consumer_not_available}
    end
  end

  def ordinary_for_module(_registry, _module_key), do: {:error, :consumer_not_available}

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
    with true <- valid_declaration_keys?(Map.keys(declaration)),
         {:ok, key} <- normalize_key(Map.fetch!(declaration, :key)),
         {:ok, events} <- normalize_events(Map.fetch!(declaration, :events)),
         {:ok, handler} <- normalize_handler(Map.fetch!(declaration, :handler)),
         {:ok, handler_revision} <-
           positive_integer(Map.fetch!(declaration, :handler_revision)),
         {:ok, batch_size} <-
           bounded_integer(Map.fetch!(declaration, :batch_size), 1, @maximum_batch_size),
         {:ok, lease_ms} <-
           bounded_integer(Map.fetch!(declaration, :lease_ms), 1, @maximum_lease_ms),
         {:ok, max_attempts} <-
           bounded_integer(Map.fetch!(declaration, :max_attempts), 1, @maximum_attempts),
         {:ok, retry_ms} <-
           bounded_integer(Map.fetch!(declaration, :retry_ms), 1, @maximum_retry_ms),
         {:ok, module_key, work_kind} <-
           normalize_module_binding(
             Map.get(declaration, :module_key),
             Map.get(declaration, :work_kind, :platform),
             batch_size
           ) do
      {:ok,
       %{
         key: key,
         events: events,
         handler: handler,
         handler_revision: handler_revision,
         batch_size: batch_size,
         lease_ms: lease_ms,
         max_attempts: max_attempts,
         retry_ms: retry_ms,
         module_key: module_key,
         work_kind: work_kind
       }}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  defp normalize_declaration(_declaration), do: {:error, :invalid_registry}

  defp valid_declaration_keys?(keys) do
    allowed = @required_declaration_keys ++ @optional_declaration_keys

    Enum.all?(@required_declaration_keys, &(&1 in keys)) and
      Enum.all?(keys, &(&1 in allowed))
  end

  defp unique_ordinary_module_consumers?(declarations) do
    ordinary_modules =
      declarations
      |> Map.values()
      |> Enum.filter(&(&1.work_kind == :ordinary))
      |> Enum.map(& &1.module_key)

    Enum.uniq(ordinary_modules) == ordinary_modules
  end

  defp normalize_module_binding(nil, :platform, _batch_size), do: {:ok, nil, :platform}

  defp normalize_module_binding(module_key, work_kind, batch_size)
       when work_kind in [:ordinary, :mandatory] do
    with {:ok, module_key} <- normalize_key(module_key),
         true <- work_kind == :mandatory or batch_size == 1 do
      {:ok, module_key, work_kind}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  defp normalize_module_binding(_module_key, _work_kind, _batch_size),
    do: {:error, :invalid_registry}

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

  defp normalize_handler(handler) when is_atom(handler) do
    behaviours =
      if Code.ensure_loaded?(handler) do
        handler.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()
      else
        []
      end

    if Chimwemwe.Platform.Outbox.Consumer in behaviours and
         function_exported?(handler, :consume, 2) do
      {:ok, handler}
    else
      {:error, :invalid_registry}
    end
  end

  defp normalize_handler(_handler), do: {:error, :invalid_registry}

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive_integer(_value), do: {:error, :invalid_registry}

  defp bounded_integer(value, minimum, maximum)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: {:ok, value}

  defp bounded_integer(_value, _minimum, _maximum), do: {:error, :invalid_registry}
end
