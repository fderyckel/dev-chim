defmodule Chimwemwe.Platform.ResourceContract do
  @moduledoc """
  Audits production Ash domains and resources against Chimwemwe's base contract.

  This structural audit makes unsafe defaults visible in the required test suite.
  It does not replace resource-specific policy, constraint, migration, or negative
  authorization review.
  """

  alias Ash.Domain.Info, as: DomainInfo
  alias Ash.Policy.Info, as: PolicyInfo
  alias Ash.Resource.Info, as: ResourceInfo

  @type resource_violation ::
          :global_reference_has_tenant_attribute
          | :global_reference_uses_multitenancy
          | :missing_policy_authorizer
          | :missing_resource_contract
          | :missing_resource_policies
          | :not_an_ash_resource
          | :tenant_attribute_missing
          | :tenant_attribute_nullable
          | :tenant_attribute_public
          | :tenant_multitenancy_allows_global
          | :tenant_multitenancy_attribute_not_tenant_id
          | :tenant_multitenancy_not_attribute
          | :unexpected_resource_ownership
          | {:generic_mutation_action, atom()}
          | {:wrong_domain, module() | nil}

  @type domain_violation ::
          :domain_actor_not_required
          | :domain_authorization_not_always
          | {:resource, module(), resource_violation()}

  @spec validate_domain(module()) :: :ok | {:error, [domain_violation()]}
  def validate_domain(domain) do
    violations =
      domain_violations(domain) ++
        Enum.flat_map(DomainInfo.resources(domain), fn resource ->
          Enum.map(resource_violations(resource, domain), &{:resource, resource, &1})
        end)

    validation_result(violations)
  end

  @spec validate_resource(module(), module() | nil) ::
          :ok | {:error, [resource_violation()]}
  def validate_resource(resource, expected_domain \\ nil) do
    resource
    |> resource_violations(expected_domain)
    |> validation_result()
  end

  defp domain_violations(domain) do
    []
    |> add_unless(DomainInfo.authorize(domain) == :always, :domain_authorization_not_always)
    |> add_unless(DomainInfo.require_actor?(domain), :domain_actor_not_required)
  end

  defp resource_violations(resource, expected_domain) do
    if Code.ensure_loaded?(resource) and ResourceInfo.resource?(resource) do
      ash_resource_violations(resource, expected_domain)
    else
      [:not_an_ash_resource]
    end
  end

  defp ash_resource_violations(resource, expected_domain) do
    ownership = resource_ownership(resource)

    []
    |> add_unless(ownership in [:tenant_owned, :global_reference], ownership_violation(ownership))
    |> add_unless(
      Ash.Policy.Authorizer in ResourceInfo.authorizers(resource),
      :missing_policy_authorizer
    )
    |> add_unless(PolicyInfo.policies(resource) != [], :missing_resource_policies)
    |> add_wrong_domain(resource, expected_domain)
    |> add_generic_mutation_actions(resource)
    |> add_ownership_violations(resource, ownership)
  end

  defp resource_ownership(resource) do
    with {:module, _module} <- Code.ensure_loaded(resource),
         true <- function_exported?(resource, :__chimwemwe_resource_ownership__, 0) do
      resource.__chimwemwe_resource_ownership__()
    else
      _unavailable -> nil
    end
  end

  defp ownership_violation(nil), do: :missing_resource_contract
  defp ownership_violation(_ownership), do: :unexpected_resource_ownership

  defp add_wrong_domain(violations, _resource, nil), do: violations

  defp add_wrong_domain(violations, resource, expected_domain) do
    add_unless(
      violations,
      ResourceInfo.domain(resource) == expected_domain,
      {:wrong_domain, ResourceInfo.domain(resource)}
    )
  end

  defp add_generic_mutation_actions(violations, resource) do
    ResourceInfo.actions(resource)
    |> Enum.filter(&(&1.type in [:create, :update, :destroy] and &1.name == &1.type))
    |> Enum.reduce(violations, fn action, current ->
      current ++ [{:generic_mutation_action, action.name}]
    end)
  end

  defp add_ownership_violations(violations, resource, :tenant_owned) do
    tenant_attribute = ResourceInfo.attribute(resource, :tenant_id)

    violations
    |> add_unless(
      ResourceInfo.multitenancy_strategy(resource) == :attribute,
      :tenant_multitenancy_not_attribute
    )
    |> add_unless(
      ResourceInfo.multitenancy_attribute(resource) == :tenant_id,
      :tenant_multitenancy_attribute_not_tenant_id
    )
    |> add_unless(
      ResourceInfo.multitenancy_global?(resource) == false,
      :tenant_multitenancy_allows_global
    )
    |> add_tenant_attribute_violations(tenant_attribute)
  end

  defp add_ownership_violations(violations, resource, :global_reference) do
    violations
    |> add_unless(
      is_nil(ResourceInfo.multitenancy_strategy(resource)),
      :global_reference_uses_multitenancy
    )
    |> add_unless(
      is_nil(ResourceInfo.attribute(resource, :tenant_id)),
      :global_reference_has_tenant_attribute
    )
  end

  defp add_ownership_violations(violations, _resource, _ownership), do: violations

  defp add_tenant_attribute_violations(violations, nil) do
    violations ++ [:tenant_attribute_missing]
  end

  defp add_tenant_attribute_violations(violations, tenant_attribute) do
    violations
    |> add_unless(tenant_attribute.allow_nil? == false, :tenant_attribute_nullable)
    |> add_unless(tenant_attribute.public? == false, :tenant_attribute_public)
  end

  defp add_unless(violations, true, _violation), do: violations
  defp add_unless(violations, false, violation), do: violations ++ [violation]

  defp validation_result([]), do: :ok
  defp validation_result(violations), do: {:error, violations}
end
