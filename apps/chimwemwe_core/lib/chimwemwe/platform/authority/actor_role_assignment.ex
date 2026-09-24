defmodule Chimwemwe.Platform.Authority.ActorRoleAssignment do
  @moduledoc """
  Tenant-qualified assignment from one membership to one tenant-defined role.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_actor_role_assignments"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_actor_role_assignments_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :membership_id, :role_id],
        name: "platform_actor_role_assignments_unique_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :role_id],
        name: "platform_actor_role_assignments_role_index",
        all_tenants?: true
      )
    end

    references do
      reference(:membership,
        name: "actor_role_assignments_membership_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:role,
        name: "actor_role_assignments_role_tenant_fkey",
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
    belongs_to :membership, Chimwemwe.Platform.Authority.Membership do
      source_attribute :membership_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :role, Chimwemwe.Platform.Authority.Role do
      source_attribute :role_id
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

    attribute :membership_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
