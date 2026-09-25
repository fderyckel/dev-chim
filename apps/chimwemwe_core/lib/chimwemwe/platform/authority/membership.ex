defmodule Chimwemwe.Platform.Authority.Membership do
  @moduledoc """
  Tenant-owned membership binding an authenticated actor identity to one tenant.

  UI-1A exposes one public, capability-protected read for assignment preparation.
  Membership mutation remains closed.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_tenant_memberships"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_tenant_memberships_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :actor_id],
        name: "platform_tenant_memberships_tenant_actor_index",
        unique: true,
        all_tenants?: true
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    read :assignment_candidates do
      public? true
      prepare build(sort: [inserted_at: :asc, id: :asc])
    end
  end

  policies do
    policy always() do
      forbid_unless actor_present()
      authorize_if always()
    end

    policy action(:assignment_candidates) do
      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.authority.assignments.create"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
