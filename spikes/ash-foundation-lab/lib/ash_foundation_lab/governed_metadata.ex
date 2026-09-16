defmodule AshFoundationLab.GovernedMetadata do
  @moduledoc """
  Validates tenant-owned view and report definitions against a resource descriptor.

  Definitions may arrange approved references. They cannot create fields, policy,
  tenancy, executable code, SQL, or action authority. Report execution re-enters
  the allowlisted Ash read action with the real trusted actor and tenant.
  """

  alias AshFoundationLab.ResourceDescriptor

  @common_keys ~w(
    definition_id
    descriptor_revision
    kind
    resource_ref
    revision
    tenant_id
    title
    updated_by
  )
  @view_keys @common_keys ++ ~w(dataset_ref fields filters labels order primary_action)
  @report_keys @common_keys ++ ~w(columns dataset_ref filters group_by labels)
  @executable_keys ~w(code eval expression function module query sql)
  @authority_keys ~w(
    authorization
    authorize
    capability
    permissions
    policy
    repository
    tenant_scope
  )
  @filter_keys ~w(field operator value)
  @filter_operators ~w(eq not_eq)

  @type trusted_context :: %{
          required(:tenant_id) => String.t(),
          required(:actor) => %{required(:id) => String.t(), required(:tenant_id) => String.t()}
        }

  @doc "Validates a new or changed definition and binds attribution to the trusted actor."
  @spec validate_for_write(map(), map(), trusted_context()) ::
          {:ok, map()} | {:error, atom()}
  def validate_for_write(definition, descriptor, context) do
    with :ok <- validate_trusted_context(context),
         :ok <- validate_tenant(definition, context),
         :ok <- validate_attribution(definition, context),
         :ok <- validate_descriptor(definition, descriptor),
         :ok <- reject_authority_or_executable_content(definition),
         :ok <- validate_definition(definition, descriptor) do
      {:ok, definition}
    end
  end

  @doc "Validates a stored definition for execution under the current trusted context."
  @spec validate_for_execution(map(), map(), trusted_context()) ::
          {:ok, map()} | {:error, atom()}
  def validate_for_execution(definition, descriptor, context) do
    with :ok <- validate_trusted_context(context),
         :ok <- validate_tenant(definition, context),
         :ok <- validate_descriptor(definition, descriptor),
         :ok <- reject_authority_or_executable_content(definition),
         :ok <- validate_definition(definition, descriptor) do
      {:ok, definition}
    end
  end

  @doc "Revalidates stable references and advances a definition to a new descriptor revision."
  @spec upgrade_definition(map(), map(), map(), trusted_context()) ::
          {:ok, map()} | {:error, atom()}
  def upgrade_definition(definition, previous_descriptor, next_descriptor, context) do
    with {:ok, _definition} <-
           validate_for_write(definition, previous_descriptor, context),
         :ok <- compatible_descriptor_family(previous_descriptor, next_descriptor) do
      upgraded = %{
        definition
        | "descriptor_revision" => next_descriptor["revision"],
          "revision" => definition["revision"] + 1,
          "updated_by" => context.actor.id
      }

      validate_for_write(upgraded, next_descriptor, context)
    end
  end

  @doc "Executes an approved report dataset through the existing Ash policy boundary."
  @spec run_report(map(), map(), trusted_context()) :: {:ok, [struct()]} | {:error, term()}
  def run_report(definition, descriptor, context) do
    with {:ok, %{"kind" => "report"} = definition} <-
           validate_for_execution(definition, descriptor, context),
         {:ok, {resource, action}} <-
           ResourceDescriptor.execution_target(descriptor, definition["dataset_ref"]),
         query <-
           resource
           |> Ash.Query.for_read(action)
           |> Ash.Query.set_tenant(context.tenant_id),
         {:ok, query} <-
           ResourceDescriptor.apply_filters(
             query,
             descriptor,
             definition["dataset_ref"],
             definition["filters"]
           ),
         {:ok, result} <- Ash.read(query, actor: context.actor, page: [limit: 3]) do
      {:ok, Map.get(result, :results, result)}
    end
  end

  defp validate_trusted_context(%{
         tenant_id: tenant_id,
         actor: %{id: actor_id, tenant_id: actor_tenant_id}
       })
       when is_binary(tenant_id) and tenant_id != "" and is_binary(actor_id) and actor_id != "" and
              actor_tenant_id == tenant_id,
       do: :ok

  defp validate_trusted_context(_context), do: {:error, :missing_trusted_context}

  defp validate_tenant(%{"tenant_id" => tenant_id}, %{tenant_id: tenant_id}), do: :ok
  defp validate_tenant(_definition, _context), do: {:error, :tenant_mismatch}

  defp validate_attribution(%{"updated_by" => actor_id}, %{actor: %{id: actor_id}}), do: :ok
  defp validate_attribution(_definition, _context), do: {:error, :actor_mismatch}

  defp validate_descriptor(definition, descriptor) do
    if is_map(definition) and is_map(descriptor) and
         definition["resource_ref"] == descriptor["resource_ref"] and
         definition["descriptor_revision"] == descriptor["revision"] do
      :ok
    else
      {:error, :incompatible_descriptor}
    end
  end

  defp reject_authority_or_executable_content(definition) do
    keys = nested_keys(definition)

    cond do
      Enum.any?(keys, &(&1 in @executable_keys)) -> {:error, :executable_content_not_allowed}
      Enum.any?(keys, &(&1 in @authority_keys)) -> {:error, :authority_not_allowed}
      true -> :ok
    end
  end

  defp validate_definition(%{"kind" => "view"} = definition, descriptor) do
    with :ok <- validate_common(definition, @view_keys),
         {:ok, dataset} <- fetch_dataset(descriptor, definition["dataset_ref"]),
         :ok <- validate_reference_list(definition["fields"], dataset["fields"]),
         :ok <- validate_same_references(definition["order"], definition["fields"]),
         :ok <- validate_labels(definition["labels"], definition["fields"]),
         :ok <- validate_filters(definition["filters"], dataset) do
      validate_action(descriptor, definition["primary_action"], "mutation")
    end
  end

  defp validate_definition(%{"kind" => "report"} = definition, descriptor) do
    with :ok <- validate_common(definition, @report_keys),
         {:ok, dataset} <- fetch_dataset(descriptor, definition["dataset_ref"]),
         :ok <- validate_reference_list(definition["columns"], dataset["fields"]),
         :ok <- validate_reference_list(definition["group_by"], dataset["group_fields"], true),
         :ok <- validate_labels(definition["labels"], definition["columns"]) do
      validate_filters(definition["filters"], dataset)
    end
  end

  defp validate_definition(_definition, _descriptor), do: {:error, :invalid_definition}

  defp validate_common(definition, allowed_keys) do
    required_values = [
      definition["definition_id"],
      definition["descriptor_revision"],
      definition["resource_ref"],
      definition["tenant_id"],
      definition["title"],
      definition["updated_by"]
    ]

    valid? =
      Enum.all?(Map.keys(definition), &(&1 in allowed_keys)) and
        Enum.all?(required_values, &(is_binary(&1) and &1 != "")) and
        is_integer(definition["revision"]) and definition["revision"] > 0

    if valid?, do: :ok, else: {:error, :invalid_definition}
  end

  defp fetch_dataset(descriptor, dataset_ref) when is_binary(dataset_ref) do
    case Enum.find(descriptor["datasets"], &(&1["ref"] == dataset_ref)) do
      nil -> {:error, :reference_not_allowed}
      dataset -> {:ok, dataset}
    end
  end

  defp fetch_dataset(_descriptor, _dataset_ref), do: {:error, :reference_not_allowed}

  defp validate_action(descriptor, action_ref, expected_kind) when is_binary(action_ref) do
    case Enum.find(descriptor["actions"], &(&1["ref"] == action_ref)) do
      %{"kind" => ^expected_kind} -> :ok
      _not_allowed -> {:error, :reference_not_allowed}
    end
  end

  defp validate_action(_descriptor, _action_ref, _kind), do: {:error, :reference_not_allowed}

  defp validate_reference_list(references, allowed, allow_empty? \\ false)

  defp validate_reference_list(references, allowed, allow_empty?) when is_list(references) do
    valid_size? = allow_empty? or references != []

    if valid_size? and Enum.uniq(references) == references and
         Enum.all?(references, &(is_binary(&1) and &1 in allowed)) do
      :ok
    else
      {:error, :reference_not_allowed}
    end
  end

  defp validate_reference_list(_references, _allowed, _allow_empty?),
    do: {:error, :reference_not_allowed}

  defp validate_same_references(left, right) when is_list(left) and is_list(right) do
    if Enum.sort(left) == Enum.sort(right), do: :ok, else: {:error, :reference_not_allowed}
  end

  defp validate_same_references(_left, _right), do: {:error, :reference_not_allowed}

  defp validate_labels(labels, allowed_fields) when is_map(labels) do
    if Enum.all?(labels, fn {field, label} ->
         field in allowed_fields and is_binary(label) and label != ""
       end) do
      :ok
    else
      {:error, :reference_not_allowed}
    end
  end

  defp validate_labels(_labels, _allowed_fields), do: {:error, :reference_not_allowed}

  defp validate_filters(filters, dataset) when is_list(filters) do
    valid? =
      Enum.all?(filters, fn filter ->
        is_map(filter) and Enum.sort(Map.keys(filter)) == Enum.sort(@filter_keys) and
          filter["field"] in dataset["filter_fields"] and
          filter["operator"] in @filter_operators and
          valid_filter_value?(filter["value"])
      end)

    if valid?, do: :ok, else: {:error, :reference_not_allowed}
  end

  defp validate_filters(_filters, _dataset), do: {:error, :reference_not_allowed}

  defp valid_filter_value?(value)
       when is_binary(value) or is_integer(value) or is_float(value) or is_boolean(value) or
              is_nil(value),
       do: true

  defp valid_filter_value?(_value), do: false

  defp compatible_descriptor_family(previous, next) do
    if previous["schema_version"] == next["schema_version"] and
         previous["resource_ref"] == next["resource_ref"] and
         is_binary(next["revision"]) and previous["revision"] != next["revision"] do
      :ok
    else
      {:error, :incompatible_descriptor}
    end
  end

  defp nested_keys(value) when is_map(value) do
    Enum.flat_map(value, fn {key, nested} -> [key | nested_keys(nested)] end)
  end

  defp nested_keys(value) when is_list(value), do: Enum.flat_map(value, &nested_keys/1)
  defp nested_keys(_value), do: []
end
