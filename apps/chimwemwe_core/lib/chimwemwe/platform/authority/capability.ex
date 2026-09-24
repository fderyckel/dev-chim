defmodule Chimwemwe.Platform.Authority.Capability do
  @moduledoc """
  Tenant-owned capability identifier. A key grants nothing unless platform code
  explicitly requires the same key at a named action boundary.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_capabilities"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_capabilities_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :key],
        name: "platform_capabilities_tenant_key_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:key, "platform_capability_key_must_be_stable",
        check: "octet_length(key) <= 120 AND key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'"
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

    attribute :key, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120, trim?: true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
