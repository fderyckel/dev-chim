defmodule AshFoundationLab.ResourceDescriptor do
  @moduledoc """
  Derives a small Chimwemwe-owned descriptor from an allowlisted Ash resource surface.

  This is disposable Phase 0 evidence. The contract maps stable references to Ash
  fields and actions in code; runtime metadata cannot add model or policy authority.
  """

  alias Ash.Resource.Info

  @foundation_contract %{
    schema_version: 1,
    model_version: 1,
    resource_ref: "foundation_record",
    fields: [
      %{ref: "foundation_record.id", source: :id, classification: "internal"},
      %{ref: "foundation_record.name", source: :name, classification: "internal"},
      %{ref: "foundation_record.status", source: :status, classification: "internal"},
      %{
        ref: "foundation_record.lock_version",
        source: :lock_version,
        classification: "internal"
      }
    ],
    actions: [
      %{ref: "foundation_record.list", source: :list_paginated},
      %{ref: "foundation_record.submit_for_review", source: :submit_for_review}
    ],
    datasets: [
      %{
        ref: "foundation_records.list",
        action_ref: "foundation_record.list",
        fields: [
          "foundation_record.id",
          "foundation_record.name",
          "foundation_record.status",
          "foundation_record.lock_version"
        ],
        filter_fields: ["foundation_record.status"],
        group_fields: ["foundation_record.status"]
      }
    ]
  }

  @foundation_execution_targets %{
    "foundation_records.list" => {AshFoundationLab.FoundationRecord, :list_paginated}
  }

  @foundation_filter_inputs %{
    "foundation_records.list" => %{
      "foundation_record.status" => "status"
    }
  }

  @filter_operators ~w(eq not_eq)

  @type descriptor :: map()
  @type contract :: %{
          required(:schema_version) => pos_integer(),
          required(:model_version) => pos_integer(),
          required(:resource_ref) => String.t(),
          required(:fields) => [map()],
          required(:actions) => [map()],
          required(:datasets) => [map()]
        }

  @doc "Derives the checked descriptor for the real synthetic FoundationRecord resource."
  @spec foundation_record() :: {:ok, descriptor()} | {:error, term()}
  def foundation_record do
    derive(AshFoundationLab.FoundationRecord, @foundation_contract)
  end

  @doc "Derives the checked descriptor and raises when the code-owned contract drifts."
  @spec foundation_record!() :: descriptor()
  def foundation_record! do
    case foundation_record() do
      {:ok, descriptor} -> descriptor
      {:error, reason} -> raise "foundation descriptor derivation failed: #{inspect(reason)}"
    end
  end

  @doc "Derives a descriptor from a resource and an explicit code-owned allowlist."
  @spec derive(module(), contract()) :: {:ok, descriptor()} | {:error, term()}
  def derive(resource, contract) when is_atom(resource) and is_map(contract) do
    with :ok <- validate_resource_boundary(resource),
         :ok <- validate_contract_shape(contract),
         {:ok, fields} <- derive_fields(resource, contract.fields),
         {:ok, actions} <- derive_actions(resource, contract.actions),
         {:ok, datasets} <- derive_datasets(contract.datasets, fields, actions) do
      payload = %{
        "actions" => actions,
        "datasets" => datasets,
        "fields" => fields,
        "model_version" => contract.model_version,
        "resource_ref" => contract.resource_ref,
        "schema_version" => contract.schema_version,
        "tenant_scope" => %{"kind" => "tenant_owned", "required" => true}
      }

      {:ok, Map.put(payload, "revision", revision(payload))}
    end
  end

  def derive(_resource, _contract), do: {:error, :invalid_descriptor_contract}

  @doc "Encodes a descriptor with recursively sorted object keys for stable drift checks."
  @spec encode!(descriptor()) :: String.t()
  def encode!(descriptor) do
    descriptor
    |> canonicalize()
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  @doc "Resolves a validated descriptor dataset through a code-owned execution registry."
  @spec execution_target(descriptor(), String.t()) ::
          {:ok, {module(), atom()}} | {:error, :incompatible_descriptor | :reference_not_allowed}
  def execution_target(descriptor, dataset_ref) do
    current = foundation_record!()

    cond do
      descriptor["revision"] != current["revision"] ->
        {:error, :incompatible_descriptor}

      descriptor["resource_ref"] != current["resource_ref"] ->
        {:error, :incompatible_descriptor}

      true ->
        case Map.fetch(@foundation_execution_targets, dataset_ref) do
          {:ok, target} -> {:ok, target}
          :error -> {:error, :reference_not_allowed}
        end
    end
  end

  @doc "Applies allowlisted descriptor filters as sanitized Ash filter input."
  @spec apply_filters(Ash.Query.t(), descriptor(), String.t(), [map()]) ::
          {:ok, Ash.Query.t()} | {:error, :incompatible_descriptor | :reference_not_allowed}
  def apply_filters(query, descriptor, dataset_ref, filters) when is_list(filters) do
    with {:ok, {resource, _action}} <- execution_target(descriptor, dataset_ref),
         %Ash.Query{resource: ^resource} <- query,
         {:ok, field_inputs} <- Map.fetch(@foundation_filter_inputs, dataset_ref) do
      Enum.reduce_while(filters, {:ok, query}, &apply_filter(&1, &2, field_inputs))
    else
      :error -> {:error, :reference_not_allowed}
      _invalid -> {:error, :reference_not_allowed}
    end
  end

  def apply_filters(_query, _descriptor, _dataset_ref, _filters),
    do: {:error, :reference_not_allowed}

  defp validate_resource_boundary(resource) do
    cond do
      not (Code.ensure_loaded?(resource) and Info.resource?(resource)) ->
        {:error, :not_an_ash_resource}

      Ash.Policy.Authorizer not in Info.authorizers(resource) ->
        {:error, :missing_policy_authorizer}

      Info.multitenancy_strategy(resource) != :attribute or
        Info.multitenancy_attribute(resource) != :tenant_id or
          Info.multitenancy_global?(resource) != false ->
        {:error, :invalid_tenant_contract}

      true ->
        :ok
    end
  end

  defp filter_input(
         %{"field" => field_ref, "operator" => operator, "value" => value} = filter,
         field_inputs
       ) do
    with 3 <- map_size(filter),
         {:ok, source_field} <- Map.fetch(field_inputs, field_ref),
         true <- operator in @filter_operators do
      {:ok, %{source_field => %{operator => value}}}
    else
      _invalid -> :error
    end
  end

  defp filter_input(_filter, _field_inputs), do: :error

  defp apply_filter(filter, {:ok, query}, field_inputs) do
    case filter_input(filter, field_inputs) do
      {:ok, input} -> {:cont, {:ok, Ash.Query.filter_input(query, input)}}
      :error -> {:halt, {:error, :reference_not_allowed}}
    end
  end

  defp validate_contract_shape(contract) do
    valid? =
      positive_integer?(contract[:schema_version]) and
        positive_integer?(contract[:model_version]) and
        non_blank?(contract[:resource_ref]) and
        non_empty_list?(contract[:fields]) and
        non_empty_list?(contract[:actions]) and
        non_empty_list?(contract[:datasets])

    if valid?, do: :ok, else: {:error, :invalid_descriptor_contract}
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_blank?(value), do: is_binary(value) and value != ""
  defp non_empty_list?(value), do: is_list(value) and value != []

  defp derive_fields(resource, field_contracts) do
    reduce_contracts(field_contracts, fn field_contract ->
      attribute = Info.attribute(resource, field_contract[:source])

      with true <- is_binary(field_contract[:ref]) and field_contract[:ref] != "",
           true <- field_contract[:classification] in ~w(public internal restricted),
           %{public?: true} <- attribute,
           {:ok, type} <- type_ref(attribute.type) do
        {:ok,
         %{
           "allow_nil" => attribute.allow_nil?,
           "classification" => field_contract.classification,
           "constraints" => constraints(attribute.constraints, type),
           "primary_key" => attribute.primary_key?,
           "ref" => field_contract.ref,
           "type" => type
         }}
      else
        _invalid -> {:error, {:field_not_available, field_contract[:ref]}}
      end
    end)
  end

  defp derive_actions(resource, action_contracts) do
    reduce_contracts(action_contracts, fn action_contract ->
      action = Info.action(resource, action_contract[:source])

      with true <- is_binary(action_contract[:ref]) and action_contract[:ref] != "",
           %{type: type} <- action,
           true <- type in [:read, :create, :update, :destroy],
           {:ok, arguments} <- derive_arguments(action.arguments) do
        descriptor = %{
          "arguments" => arguments,
          "kind" => action_kind(type),
          "ref" => action_contract.ref
        }

        {:ok, maybe_add_pagination(descriptor, action)}
      else
        _invalid -> {:error, {:action_not_available, action_contract[:ref]}}
      end
    end)
  end

  defp derive_arguments(arguments) do
    arguments
    |> Enum.filter(& &1.public?)
    |> reduce_contracts(fn argument ->
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
    end)
  end

  defp derive_datasets(dataset_contracts, fields, actions) do
    field_refs = MapSet.new(fields, & &1["ref"])
    action_kinds = Map.new(actions, &{&1["ref"], &1["kind"]})

    reduce_contracts(dataset_contracts, fn dataset ->
      all_field_refs = dataset.fields ++ dataset.filter_fields ++ dataset.group_fields

      valid? =
        is_binary(dataset[:ref]) and dataset[:ref] != "" and
          action_kinds[dataset[:action_ref]] == "read" and
          dataset.fields != [] and
          Enum.all?(all_field_refs, &MapSet.member?(field_refs, &1)) and
          Enum.uniq(dataset.fields) == dataset.fields and
          Enum.uniq(dataset.filter_fields) == dataset.filter_fields and
          Enum.uniq(dataset.group_fields) == dataset.group_fields

      if valid? do
        classification =
          fields
          |> Enum.filter(&(&1["ref"] in dataset.fields))
          |> Enum.map(& &1["classification"])
          |> highest_classification()

        {:ok,
         %{
           "action_ref" => dataset.action_ref,
           "classification" => classification,
           "fields" => dataset.fields,
           "filter_fields" => dataset.filter_fields,
           "group_fields" => dataset.group_fields,
           "ref" => dataset.ref
         }}
      else
        {:error, {:dataset_invalid, dataset[:ref]}}
      end
    end)
  end

  defp reduce_contracts(contracts, fun) do
    Enum.reduce_while(contracts, {:ok, []}, fn contract, {:ok, values} ->
      case fun.(contract) do
        {:ok, value} -> {:cont, {:ok, values ++ [value]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

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

  defp highest_classification(classifications) do
    Enum.max_by(classifications, &classification_rank/1, fn -> "public" end)
  end

  defp classification_rank("public"), do: 0
  defp classification_rank("internal"), do: 1
  defp classification_rank("restricted"), do: 2

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
