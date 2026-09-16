defmodule Chimwemwe.Platform.ActionInvocation do
  @moduledoc """
  Invokes public named Ash reads from a validated execution context.

  This boundary owns all Ash execution options. Callers provide only a trusted
  context, a code-known resource and action, and ordinary action input. Write
  invocation is intentionally outside this slice.
  """

  alias Ash.Domain.Info, as: DomainInfo
  alias Ash.Resource.Info, as: ResourceInfo

  alias Chimwemwe.Platform.{
    ExecutionContext,
    InvocationError,
    ResourceContract,
    TrustedActor
  }

  @reserved_input_keys ~w(
    actor
    actor_id
    authorize
    authorize?
    cache_namespace
    cell
    context
    correlation_id
    database
    domain
    locale
    placement
    placement_ref
    projection_namespace
    purpose
    queue_namespace
    repository
    routing_version
    scope
    storage_namespace
    tenant
    tenant_id
  )

  @doc "Invokes one public named read with actor and tenant derived from trusted context."
  @spec read(term(), module(), atom(), map()) :: {:ok, term()} | {:error, term()}
  def read(context, resource, action, input \\ %{}) do
    ExecutionContext.with_validated(context, fn validated_context ->
      with :ok <- validate_input(input),
           {:ok, domain} <- validate_resource(resource),
           :ok <- validate_read_action(resource, action) do
        invoke_read(validated_context, domain, resource, action, input)
      end
    end)
  end

  defp validate_input(input) when is_map(input) and not is_struct(input) do
    keys = input |> Map.keys() |> Enum.map(&input_key/1)

    case Enum.any?(keys, &is_nil/1) or Enum.any?(keys, &(&1 in @reserved_input_keys)) do
      true -> invocation_error(:invalid_input)
      false -> :ok
    end
  end

  defp validate_input(_input), do: invocation_error(:invalid_input)

  defp validate_resource(resource) when is_atom(resource) do
    with true <- Code.ensure_loaded?(resource),
         true <- ResourceInfo.resource?(resource),
         domain when is_atom(domain) and not is_nil(domain) <- ResourceInfo.domain(resource),
         true <- Code.ensure_loaded?(domain),
         true <- function_exported?(domain, :domain?, 0) and domain.domain?(),
         true <- resource in DomainInfo.resources(domain),
         :ok <- ResourceContract.validate_domain(domain) do
      {:ok, domain}
    else
      _invalid -> invocation_error(:resource_not_available)
    end
  end

  defp validate_resource(_resource), do: invocation_error(:resource_not_available)

  defp validate_read_action(resource, action) when is_atom(action) do
    case ResourceInfo.action(resource, action) do
      %{public?: true, type: :read} -> :ok
      _private_missing_or_wrong_type -> invocation_error(:read_action_not_available)
    end
  end

  defp validate_read_action(_resource, _action),
    do: invocation_error(:read_action_not_available)

  defp invoke_read(context, domain, resource, action, input) do
    options = invocation_options(context, domain, resource)
    query = Ash.Query.for_read(resource, action, input, options)

    Ash.read(query, Keyword.drop(options, [:context]))
  end

  defp invocation_options(context, domain, resource) do
    options = [
      actor: context.actor,
      authorize?: true,
      context: action_context(context),
      domain: domain
    ]

    case resource.__chimwemwe_resource_ownership__() do
      :tenant_owned -> Keyword.put(options, :tenant, TrustedActor.tenant_id(context.actor))
      :global_reference -> options
    end
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

  defp input_key(key) when is_atom(key), do: Atom.to_string(key)
  defp input_key(key) when is_binary(key), do: key
  defp input_key(_key), do: nil

  defp invocation_error(code), do: {:error, %InvocationError{code: code}}
end
