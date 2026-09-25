defmodule Chimwemwe.Platform.ModuleLifecycle.ModuleEntitlement do
  @moduledoc """
  Closed tenant-owned fact that a tenant is entitled to one code-owned module key.

  Slice 1H-A deliberately provides no entitlement mutation API. Real commercial
  contract integration and entitlement expiry remain later boundaries.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_module_entitlements"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_module_entitlements_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :module_key],
        name: "platform_module_entitlements_tenant_module_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:module_key, "platform_module_entitlement_key_must_be_valid",
        check:
          "char_length(module_key) BETWEEN 3 AND 120 AND module_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :module_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120
    end

    create_timestamp :inserted_at
  end
end
