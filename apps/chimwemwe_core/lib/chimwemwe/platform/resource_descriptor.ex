defmodule Chimwemwe.Platform.ResourceDescriptor do
  @moduledoc """
  Derives a versioned Chimwemwe descriptor from an explicit Ash allowlist.

  The descriptor is a build and release tooling contract. It contains only a
  small portable projection of the public model surface and never becomes an
  alternate source of model, tenancy, or authorization authority.
  """

  alias Ash.Resource.Info
  alias Chimwemwe.Platform.ResourceContract

  @schema_version 1
  @classifications [:public, :internal, :confidential, :restricted]
  @contract_keys [:actions, :fields, :model_version, :resource_ref, :schema_version]
  @field_keys [:classification, :ref, :source]
  @action_keys [:ref, :source]
  @mutation_types [:create, :update, :destroy]
  @action_types [:read | @mutation_types]
  @generic_mutation_refs ~w(create update destroy)
  @resource_ref_pattern ~r/\A[a-z][a-z0-9_]*\z/
  @member_ref_pattern ~r/\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/

  @type descriptor :: %{required(String.t()) => term()}
  @type contract :: %{
          required(:schema_version) => pos_integer(),
          required(:model_version) => pos_integer(),
          required(:resource_ref) => String.t(),
          required(:fields) => [field_contract()],
          required(:actions) => [action_contract()]
        }
  @type field_contract :: %{
          required(:ref) => String.t(),
          required(:source) => atom(),
          required(:classification) => :public | :internal | :confidential | :restricted
        }
  @type action_contract :: %{
          required(:ref) => String.t(),
          required(:source) => atom()
        }

  @doc "Returns the only descriptor schema version supported by this core release."
  @spec schema_version() :: pos_integer()
  def schema_version, do: @schema_version

  @doc "Derives a descriptor from a contract-controlled Ash resource and allowlist."
  @spec derive(module(), contract()) :: {:ok, descriptor()} | {:error, term()}
  def derive(resource, contract) when is_atom(resource) and is_map(contract) do
    with :ok <- validate_resource(resource),
         :ok <- validate_contract(contract),
         {:ok, fields} <- derive_fields(resource, contract.fields),
         {:ok, actions} <- derive_actions(resource, contract.actions),
         :ok <- validate_distinct_public_refs(fields, actions) do
      payload = %{
        "actions" => actions,
        "fields" => fields,
        "model_version" => contract.model_version,
        "resource_ref" => contract.resource_ref,
        "schema_version" => @schema_version,
        "tenant_scope" => tenant_scope(resource.__chimwemwe_resource_ownership__())
      }

      {:ok, Map.put(payload, "revision", revision(payload))}
    end
  end

  def derive(_resource, _contract), do: {:error, :invalid_descriptor_contract}

  @doc "Encodes a descriptor with recursively sorted object keys."
  @spec encode!(descriptor()) :: String.t()
  def encode!(descriptor) when is_map(descriptor) do
    descriptor
    |> canonicalize()
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  defp validate_resource(resource) do
    case ResourceContract.validate_resource(resource) do
      :ok -> :ok
      {:error, violations} -> {:error, {:resource_contract_invalid, violations}}
    end
  end

  defp validate_contract(contract) do
    with true <- exact_keys?(contract, @contract_keys),
         true <- contract.schema_version == @schema_version,
         true <- positive_integer?(contract.model_version),
         true <- valid_resource_ref?(contract.resource_ref),
         true <- non_empty_list?(contract.fields),
         true <- non_empty_list?(contract.actions),
         :ok <- validate_field_contracts(contract.fields, contract.resource_ref),
         :ok <- validate_action_contracts(contract.actions, contract.resource_ref),
         :ok <- validate_unique_sources(contract.fields, :field),
         :ok <- validate_unique_sources(contract.actions, :action) do
      :ok
    else
      false -> {:error, :invalid_descriptor_contract}
      {:error, _reason} = error -> error
    end
  end

  defp validate_field_contracts(contracts, resource_ref) do
    validate_entries(contracts, fn contract ->
      cond do
        not (is_map(contract) and exact_keys?(contract, @field_keys)) ->
          {:error, :invalid_field_contract}

        not valid_member_ref?(contract.ref, resource_ref) ->
          {:error, {:invalid_field_reference, contract.ref}}

        not is_atom(contract.source) ->
          {:error, {:invalid_field_source, contract.ref}}

        contract.classification not in @classifications ->
          {:error, {:invalid_field_classification, contract.ref}}

        true ->
          :ok
      end
    end)
  end

  defp validate_action_contracts(contracts, resource_ref) do
    validate_entries(contracts, fn contract ->
      cond do
        not (is_map(contract) and exact_keys?(contract, @action_keys)) ->
          {:error, :invalid_action_contract}

        not valid_member_ref?(contract.ref, resource_ref) ->
          {:error, {:invalid_action_reference, contract.ref}}

        not is_atom(contract.source) ->
          {:error, {:invalid_action_source, contract.ref}}

        true ->
          :ok
      end
    end)
  end

  defp validate_entries(entries, validator) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      case validator.(entry) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_unique_sources(contracts, kind) do
    sources = Enum.map(contracts, & &1.source)

    if Enum.uniq(sources) == sources do
      :ok
    else
      {:error, {:duplicate_source, kind}}
    end
  end

  defp derive_fields(resource, contracts) do
    contracts
    |> reduce_contracts(&derive_field(resource, &1))
    |> sort_result_by_ref()
  end

  defp derive_field(resource, contract) do
    with %{public?: true} = attribute <- Info.attribute(resource, contract.source),
         {:ok, type} <- type_ref(attribute.type) do
      {:ok,
       %{
         "allow_nil" => attribute.allow_nil?,
         "classification" => Atom.to_string(contract.classification),
         "constraints" => constraints(attribute.constraints, type),
         "primary_key" => attribute.primary_key?,
         "ref" => contract.ref,
         "type" => type
       }}
    else
      nil -> {:error, {:field_not_available, contract.ref}}
      %{public?: false} -> {:error, {:field_not_available, contract.ref}}
      :error -> {:error, {:field_type_not_supported, contract.ref}}
    end
  end

  defp derive_actions(resource, contracts) do
    contracts
    |> reduce_contracts(&derive_action(resource, &1))
    |> sort_result_by_ref()
  end

  defp derive_action(resource, contract) do
    action = Info.action(resource, contract.source)

    with %{public?: true, type: type} <- action,
         true <- type in @action_types,
         false <- generic_mutation_ref?(contract.ref, type),
         {:ok, arguments} <- derive_arguments(action.arguments) do
      descriptor = %{
        "arguments" => arguments,
        "kind" => action_kind(type),
        "ref" => contract.ref
      }

      {:ok, maybe_add_pagination(descriptor, action)}
    else
      nil -> {:error, {:action_not_available, contract.ref}}
      %{public?: false} -> {:error, {:action_not_available, contract.ref}}
      false -> {:error, {:action_type_not_supported, contract.ref}}
      true -> {:error, {:generic_mutation_reference, contract.ref}}
      {:error, _reason} = error -> error
    end
  end

  defp derive_arguments(arguments) do
    arguments
    |> Enum.filter(& &1.public?)
    |> reduce_contracts(&derive_argument/1)
    |> sort_result_by_ref()
  end

  defp derive_argument(argument) do
    case type_ref(argument.type) do
      {:ok, type} ->
        {:ok,
         %{
           "allow_nil" => argument.allow_nil?,
           "constraints" => constraints(argument.constraints, type),
           "ref" => Atom.to_string(argument.name),
           "type" => type
         }}

      :error ->
        {:error, {:argument_type_not_supported, argument.name}}
    end
  end

  defp validate_distinct_public_refs(fields, actions) do
    refs = Enum.map(fields ++ actions, & &1["ref"])

    if Enum.uniq(refs) == refs do
      :ok
    else
      {:error, :duplicate_stable_reference}
    end
  end

  defp reduce_contracts(contracts, fun) do
    Enum.reduce_while(contracts, {:ok, []}, fn contract, {:ok, values} ->
      case fun.(contract) do
        {:ok, value} -> {:cont, {:ok, [value | values]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp sort_result_by_ref({:ok, values}) do
    {:ok, Enum.sort_by(values, & &1["ref"])}
  end

  defp sort_result_by_ref({:error, _reason} = error), do: error

  defp type_ref(Ash.Type.UUID), do: {:ok, "uuid"}
  defp type_ref(Ash.Type.String), do: {:ok, "string"}
  defp type_ref(Ash.Type.Atom), do: {:ok, "enum"}
  defp type_ref(Ash.Type.Integer), do: {:ok, "integer"}
  defp type_ref(_type), do: :error

  defp constraints(constraints, "string") do
    selected_constraints(constraints, [:allow_empty?, :max_length, :min_length, :trim?])
  end

  defp constraints(constraints, "enum") do
    constraints
    |> selected_constraints([:one_of])
    |> Map.update("one_of", [], &Enum.map(&1, fn value -> to_string(value) end))
  end

  defp constraints(constraints, "integer") do
    selected_constraints(constraints, [:max, :min])
  end

  defp constraints(_constraints, "uuid"), do: %{}

  defp selected_constraints(constraints, allowed) do
    constraints
    |> Keyword.take(allowed)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp action_kind(:read), do: "read"
  defp action_kind(_mutation), do: "mutation"

  defp maybe_add_pagination(descriptor, %{type: :read, pagination: pagination})
       when is_map(pagination) do
    Map.put(descriptor, "pagination", %{
      "default_limit" => pagination.default_limit,
      "keyset" => pagination.keyset?,
      "max_page_size" => pagination.max_page_size,
      "required" => pagination.required?
    })
  end

  defp maybe_add_pagination(descriptor, _action), do: descriptor

  defp tenant_scope(:tenant_owned), do: %{"kind" => "tenant_owned", "required" => true}

  defp tenant_scope(:global_reference),
    do: %{"kind" => "global_reference", "required" => false}

  defp generic_mutation_ref?(ref, type) when type in @mutation_types do
    List.last(String.split(ref, ".")) in @generic_mutation_refs
  end

  defp generic_mutation_ref?(_ref, _type), do: false

  defp exact_keys?(map, keys), do: MapSet.new(Map.keys(map)) == MapSet.new(keys)
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_empty_list?(value), do: is_list(value) and value != []

  defp valid_resource_ref?(ref),
    do: is_binary(ref) and Regex.match?(@resource_ref_pattern, ref)

  defp valid_member_ref?(ref, resource_ref) do
    is_binary(ref) and Regex.match?(@member_ref_pattern, ref) and
      String.starts_with?(ref, resource_ref <> ".")
  end

  defp revision(payload) do
    digest =
      payload
      |> canonicalize()
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    "sha256:#{digest}"
  end

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonicalize(nested)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value
end
