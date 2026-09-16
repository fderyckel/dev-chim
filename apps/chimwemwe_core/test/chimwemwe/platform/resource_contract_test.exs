defmodule Chimwemwe.Platform.ResourceContractTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.Platform.ResourceContract

  alias __MODULE__.{
    MissingTenantAttributeResource,
    MissingPoliciesResource,
    UnownedResource,
    UnsafeGlobalReference,
    UnsafeTenantResource,
    ValidGlobalReference,
    ValidTenantResource
  }

  test "the production domain passes the authoring contract while resource-empty" do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.Platform)
  end

  test "accepts explicit tenant-owned and global-reference resource shapes" do
    assert :ok = ResourceContract.validate_resource(ValidTenantResource)
    assert :ok = ResourceContract.validate_resource(ValidGlobalReference)
  end

  test "rejects unsafe tenant shape and a generic state-changing action" do
    assert {:error, violations} =
             ResourceContract.validate_resource(UnsafeTenantResource)

    assert :tenant_multitenancy_not_attribute in violations
    assert :tenant_multitenancy_attribute_not_tenant_id in violations
    assert :tenant_multitenancy_allows_global in violations
    assert :tenant_attribute_nullable in violations
    assert :tenant_attribute_public in violations
    assert {:generic_mutation_action, :update} in violations
  end

  test "rejects a resource that bypasses the code-owned base" do
    assert {:error, violations} = ResourceContract.validate_resource(UnownedResource)

    assert :missing_resource_contract in violations
    assert :missing_policy_authorizer in violations
    assert :missing_resource_policies in violations
  end

  test "rejects a tenant-owned resource without its tenant attribute" do
    assert {:error, violations} =
             ResourceContract.validate_resource(MissingTenantAttributeResource)

    assert :tenant_attribute_missing in violations
  end

  test "rejects a base resource without explicit policies" do
    assert {:error, [:missing_resource_policies]} =
             ResourceContract.validate_resource(MissingPoliciesResource)
  end

  test "rejects global reference data that silently carries tenant scope" do
    assert {:error, violations} =
             ResourceContract.validate_resource(UnsafeGlobalReference)

    assert :global_reference_uses_multitenancy in violations
    assert :global_reference_has_tenant_attribute in violations
  end

  test "detects registration in the wrong domain" do
    assert {:error, [{:wrong_domain, nil}]} =
             ResourceContract.validate_resource(ValidTenantResource, Chimwemwe.Platform)
  end
end
