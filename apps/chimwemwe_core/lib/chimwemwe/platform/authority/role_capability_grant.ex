defmodule Chimwemwe.Platform.Authority.RoleCapabilityGrant do
  @moduledoc """
  Tenant-qualified grant from one role to one tenant-owned capability identifier.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_role_capability_grants"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_role_capability_grants_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :role_id, :capability_id],
        name: "platform_role_capability_grants_unique_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :capability_id],
        name: "platform_role_capability_grants_capability_index",
        all_tenants?: true
      )
    end

    references do
      reference(:role,
        name: "role_capability_grants_role_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:capability,
        name: "role_capability_grants_capability_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :role, Chimwemwe.Platform.Authority.Role do
      source_attribute :role_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :capability, Chimwemwe.Platform.Authority.Capability do
      source_attribute :capability_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
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

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :capability_id, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
