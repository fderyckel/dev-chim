defmodule Chimwemwe.Platform.GovernedExtension.Registry do
  @moduledoc """
  Immutable, code-owned registry of governed extension contracts.

  A registry declaration binds one released module and typed presentation schema
  to an exact descriptor derived from a contract-valid Ash resource. Tenant input
  cannot add a resource, field, action, policy, repository, or executable rule.
  """

  alias Chimwemwe.Platform.ResourceDescriptor

  @contract_keys [
    :descriptor_contract,
    :kind,
    :module_key,
    :resource,
    :schema_key,
    :schema_version
  ]
  @content_keys ~w(fields labels read_action title)
  @key_pattern ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/
  @revision_pattern ~r/^sha256:[0-9a-f]{64}$/
  @maximum_key_length 120
  @maximum_title_length 120
  @maximum_label_length 120
  @maximum_fields 32
  @classification_rank %{"public" => 0, "internal" => 1, "confidential" => 2, "restricted" => 3}

  @enforce_keys [:declarations]
  defstruct [:declarations]

  @type declaration :: %{
          descriptor: ResourceDescriptor.descriptor(),
          descriptor_contract: ResourceDescriptor.contract(),
          kind: :presentation,
          module_key: String.t(),
          resource: module(),
          schema_key: String.t(),
          schema_version: pos_integer()
        }
  @opaque t :: %__MODULE__{declarations: %{String.t() => declaration()}}

  @spec new([map()]) :: {:ok, t()} | {:error, :invalid_registry}
  def new(declarations) when is_list(declarations) and declarations != [] do
    declarations
    |> Enum.reduce_while({:ok, %{}}, fn declaration, {:ok, acc} ->
      with {:ok, normalized} <- normalize_declaration(declaration),
           false <- Map.has_key?(acc, normalized.schema_key) do
        {:cont, {:ok, Map.put(acc, normalized.schema_key, normalized)}}
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
    sources = Enum.map(Map.values(declarations), &Map.drop(&1, [:descriptor]))

    with {:ok, rebuilt} <- new(sources),
         true <- rebuilt.declarations == declarations do
      {:ok, registry}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  def revalidate(_registry), do: {:error, :invalid_registry}

  @spec fetch(t(), term()) :: {:ok, declaration()} | {:error, :schema_not_available}
  def fetch(%__MODULE__{declarations: declarations}, schema_key) when is_binary(schema_key) do
    case Map.fetch(declarations, schema_key) do
      {:ok, declaration} -> {:ok, declaration}
      :error -> {:error, :schema_not_available}
    end
  end

  def fetch(_registry, _schema_key), do: {:error, :schema_not_available}

  @doc false
  @spec valid_revision?(term()) :: boolean()
  def valid_revision?(revision),
    do: is_binary(revision) and Regex.match?(@revision_pattern, revision)

  @doc "Validates and normalizes the only Slice 1I-A presentation schema."
  @spec validate_content(declaration(), term()) ::
          {:ok, map(), :public | :internal | :confidential | :restricted}
          | {:error, :invalid_definition | :reference_not_allowed}
  def validate_content(%{kind: :presentation, descriptor: descriptor}, content)
      when is_map(content) and not is_struct(content) do
    with true <- MapSet.new(Map.keys(content)) == MapSet.new(@content_keys),
         {:ok, title} <- normalize_bounded_text(content["title"], @maximum_title_length),
         {:ok, fields} <- validate_fields(content["fields"], descriptor),
         {:ok, labels} <- validate_labels(content["labels"], fields),
         {:ok, read_action} <- validate_read_action(content["read_action"], descriptor),
         {:ok, classification} <- derive_classification(fields, descriptor) do
      {:ok,
       %{
         "fields" => fields,
         "labels" => labels,
         "read_action" => read_action,
         "title" => title
       }, classification}
    else
      false -> {:error, :invalid_definition}
      {:error, _reason} = error -> error
    end
  end

  def validate_content(_declaration, _content), do: {:error, :invalid_definition}

  defp normalize_declaration(declaration)
       when is_map(declaration) and not is_struct(declaration) do
    with true <- MapSet.new(Map.keys(declaration)) == MapSet.new(@contract_keys),
         {:ok, module_key} <- normalize_key(Map.fetch!(declaration, :module_key)),
         {:ok, schema_key} <- normalize_key(Map.fetch!(declaration, :schema_key)),
         :presentation <- Map.fetch!(declaration, :kind),
         resource when is_atom(resource) <- Map.fetch!(declaration, :resource),
         schema_version when is_integer(schema_version) and schema_version > 0 <-
           Map.fetch!(declaration, :schema_version),
         descriptor_contract when is_map(descriptor_contract) <-
           Map.fetch!(declaration, :descriptor_contract),
         {:ok, descriptor} <- ResourceDescriptor.derive(resource, descriptor_contract),
         %{"kind" => "tenant_owned", "required" => true} <- descriptor["tenant_scope"] do
      {:ok,
       %{
         descriptor: descriptor,
         descriptor_contract: descriptor_contract,
         kind: :presentation,
         module_key: module_key,
         resource: resource,
         schema_key: schema_key,
         schema_version: schema_version
       }}
    else
      _invalid -> {:error, :invalid_registry}
    end
  end

  defp normalize_declaration(_declaration), do: {:error, :invalid_registry}

  defp normalize_key(key) when is_binary(key) do
    normalized = String.trim(key)

    if byte_size(normalized) <= @maximum_key_length and Regex.match?(@key_pattern, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_registry}
    end
  end

  defp normalize_key(_key), do: {:error, :invalid_registry}

  defp validate_fields(fields, descriptor)
       when is_list(fields) and fields != [] and length(fields) <= @maximum_fields do
    allowed = MapSet.new(Enum.map(descriptor["fields"], & &1["ref"]))

    if Enum.uniq(fields) == fields and
         Enum.all?(fields, &(is_binary(&1) and MapSet.member?(allowed, &1))) do
      {:ok, fields}
    else
      {:error, :reference_not_allowed}
    end
  end

  defp validate_fields(_fields, _descriptor), do: {:error, :reference_not_allowed}

  defp validate_labels(labels, fields) when is_map(labels) and not is_struct(labels) do
    field_set = MapSet.new(fields)

    labels
    |> Enum.reduce_while({:ok, %{}}, fn {field, label}, {:ok, normalized} ->
      with true <- is_binary(field) and MapSet.member?(field_set, field),
           {:ok, label} <- normalize_bounded_text(label, @maximum_label_length) do
        {:cont, {:ok, Map.put(normalized, field, label)}}
      else
        _invalid -> {:halt, {:error, :reference_not_allowed}}
      end
    end)
  end

  defp validate_labels(_labels, _fields), do: {:error, :reference_not_allowed}

  defp validate_read_action(action_ref, descriptor) when is_binary(action_ref) do
    case Enum.find(descriptor["actions"], &(&1["ref"] == action_ref)) do
      %{"kind" => "read"} -> {:ok, action_ref}
      _missing_or_mutation -> {:error, :reference_not_allowed}
    end
  end

  defp validate_read_action(_action_ref, _descriptor), do: {:error, :reference_not_allowed}

  defp derive_classification(fields, descriptor) do
    by_ref = Map.new(descriptor["fields"], &{&1["ref"], &1["classification"]})

    classification =
      fields
      |> Enum.map(&Map.fetch!(by_ref, &1))
      |> Enum.max_by(&Map.fetch!(@classification_rank, &1))

    {:ok, classification_atom(classification)}
  end

  defp classification_atom("public"), do: :public
  defp classification_atom("internal"), do: :internal
  defp classification_atom("confidential"), do: :confidential
  defp classification_atom("restricted"), do: :restricted

  defp normalize_bounded_text(value, maximum) when is_binary(value) do
    normalized = String.trim(value)

    if normalized != "" and byte_size(normalized) <= maximum do
      {:ok, normalized}
    else
      {:error, :invalid_definition}
    end
  end

  defp normalize_bounded_text(_value, _maximum), do: {:error, :invalid_definition}
end
