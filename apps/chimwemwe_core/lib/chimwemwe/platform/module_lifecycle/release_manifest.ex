defmodule Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest do
  @moduledoc """
  Immutable, code-owned description of modules present in one product release.

  The manifest is established by trusted platform code, never action or request
  input. It contains no tenant entitlement or activation state.
  """

  @module_key_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @version_pattern ~r/^[0-9]+\.[0-9]+\.[0-9]+(?:[+-][0-9A-Za-z.-]+)?$/
  @maximum_key_length 120
  @maximum_owner_length 120
  @declaration_keys [:dependencies, :key, :owner, :version]

  @enforce_keys [:declarations]
  defstruct [:declarations]

  @type declaration :: %{
          key: String.t(),
          version: String.t(),
          owner: String.t(),
          dependencies: [String.t()]
        }
  @opaque t :: %__MODULE__{declarations: %{String.t() => declaration()}}

  @spec new([map()]) :: {:ok, t()} | {:error, :invalid_manifest}
  def new(declarations) when is_list(declarations) and declarations != [] do
    with {:ok, normalized} <- normalize_declarations(declarations),
         :ok <- validate_dependencies(normalized),
         :ok <- validate_acyclic(normalized) do
      {:ok, %__MODULE__{declarations: normalized}}
    end
  end

  def new(_declarations), do: {:error, :invalid_manifest}

  @doc false
  @spec revalidate(term()) :: {:ok, t()} | {:error, :invalid_manifest}
  def revalidate(%__MODULE__{declarations: declarations} = manifest)
      when is_map(declarations) do
    with {:ok, rebuilt} <- new(Map.values(declarations)),
         true <- rebuilt.declarations == declarations do
      {:ok, manifest}
    else
      _invalid -> {:error, :invalid_manifest}
    end
  end

  def revalidate(_manifest), do: {:error, :invalid_manifest}

  @spec fetch(t(), term()) :: {:ok, declaration()} | {:error, :module_not_released}
  def fetch(%__MODULE__{declarations: declarations}, key) when is_binary(key) do
    case Map.fetch(declarations, key) do
      {:ok, declaration} -> {:ok, declaration}
      :error -> {:error, :module_not_released}
    end
  end

  def fetch(_manifest, _key), do: {:error, :module_not_released}

  defp normalize_declarations(declarations) do
    Enum.reduce_while(declarations, {:ok, %{}}, fn declaration, {:ok, acc} ->
      with {:ok, normalized} <- normalize_declaration(declaration),
           false <- Map.has_key?(acc, normalized.key) do
        {:cont, {:ok, Map.put(acc, normalized.key, normalized)}}
      else
        _invalid_or_duplicate -> {:halt, {:error, :invalid_manifest}}
      end
    end)
  end

  defp normalize_declaration(declaration)
       when is_map(declaration) and not is_struct(declaration) do
    with true <- Enum.sort(Map.keys(declaration)) == @declaration_keys,
         {:ok, key} <- normalize_key(Map.fetch!(declaration, :key)),
         {:ok, version} <- normalize_version(Map.fetch!(declaration, :version)),
         {:ok, owner} <- normalize_owner(Map.fetch!(declaration, :owner)),
         {:ok, dependencies} <- normalize_dependency_keys(Map.fetch!(declaration, :dependencies)),
         false <- key in dependencies do
      {:ok,
       %{
         key: key,
         version: version,
         owner: owner,
         dependencies: dependencies
       }}
    else
      _invalid -> {:error, :invalid_manifest}
    end
  end

  defp normalize_declaration(_declaration), do: {:error, :invalid_manifest}

  defp normalize_dependency_keys(dependencies) when is_list(dependencies) do
    with {:ok, normalized} <- normalize_keys(dependencies),
         true <- length(normalized) == MapSet.size(MapSet.new(normalized)) do
      {:ok, Enum.sort(normalized)}
    else
      _invalid -> {:error, :invalid_manifest}
    end
  end

  defp normalize_dependency_keys(_dependencies), do: {:error, :invalid_manifest}

  defp normalize_keys(keys) do
    Enum.reduce_while(keys, {:ok, []}, fn key, {:ok, acc} ->
      case normalize_key(key) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, :invalid_manifest} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_key(key) when is_binary(key) do
    normalized = String.trim(key)

    if byte_size(normalized) <= @maximum_key_length and
         Regex.match?(@module_key_pattern, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_manifest}
    end
  end

  defp normalize_key(_key), do: {:error, :invalid_manifest}

  defp normalize_version(version) when is_binary(version) do
    normalized = String.trim(version)

    case Version.parse(normalized) do
      {:ok, parsed} ->
        if Regex.match?(@version_pattern, normalized) do
          {:ok, to_string(parsed)}
        else
          {:error, :invalid_manifest}
        end

      :error ->
        {:error, :invalid_manifest}
    end
  end

  defp normalize_version(_version), do: {:error, :invalid_manifest}

  defp normalize_owner(owner) when is_binary(owner) do
    normalized = String.trim(owner)

    if normalized != "" and byte_size(normalized) <= @maximum_owner_length do
      {:ok, normalized}
    else
      {:error, :invalid_manifest}
    end
  end

  defp normalize_owner(_owner), do: {:error, :invalid_manifest}

  defp validate_dependencies(declarations) do
    if Enum.all?(declarations, fn {_key, declaration} ->
         Enum.all?(declaration.dependencies, &Map.has_key?(declarations, &1))
       end) do
      :ok
    else
      {:error, :invalid_manifest}
    end
  end

  defp validate_acyclic(declarations) do
    declarations
    |> Map.keys()
    |> Enum.reduce_while({:ok, %{}}, fn key, {:ok, visited} ->
      case visit(key, declarations, %{}, visited) do
        {:ok, next_visited} -> {:cont, {:ok, next_visited}}
        {:error, :invalid_manifest} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, _visited} -> :ok
      error -> error
    end
  end

  defp visit(key, declarations, visiting, visited) do
    cond do
      Map.has_key?(visited, key) ->
        {:ok, visited}

      Map.has_key?(visiting, key) ->
        {:error, :invalid_manifest}

      true ->
        visiting = Map.put(visiting, key, true)

        case visit_dependencies(key, declarations, visiting, visited) do
          {:ok, next_visited} -> {:ok, Map.put(next_visited, key, true)}
          error -> error
        end
    end
  end

  defp visit_dependencies(key, declarations, visiting, visited) do
    declarations
    |> Map.fetch!(key)
    |> Map.fetch!(:dependencies)
    |> Enum.reduce_while({:ok, visited}, fn dependency, {:ok, current_visited} ->
      case visit(dependency, declarations, visiting, current_visited) do
        {:ok, next_visited} -> {:cont, {:ok, next_visited}}
        {:error, :invalid_manifest} = error -> {:halt, error}
      end
    end)
  end
end
