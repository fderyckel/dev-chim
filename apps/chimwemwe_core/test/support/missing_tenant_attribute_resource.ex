defmodule Chimwemwe.Platform.ResourceContractTest.MissingTenantAttributeResource do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :tenant_owned

  actions do
    read :list_records
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
  end
end
