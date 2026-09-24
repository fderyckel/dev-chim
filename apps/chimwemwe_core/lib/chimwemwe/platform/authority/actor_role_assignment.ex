defmodule Chimwemwe.Platform.Authority.ActorRoleAssignment do
  @moduledoc """
  Tenant-qualified assignment from one membership to one tenant-defined role.

  `assign_role` is private. Callers enter through
  `Chimwemwe.Platform.Authority.assign_role/3`, which owns trusted context,
  persistence routing, stable results, and stable errors.
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

    check_constraints do
      check_constraint(:lock_version, "platform_actor_role_assignment_version_must_be_positive",
        check: "lock_version >= 1"
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
    action :assign_role, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.Authority.AssignRoleResult

      argument :membership_id, :uuid do
        allow_nil? false
      end

      argument :role_id, :uuid do
        allow_nil? false
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.Authority.AssignRole
    end
  end

  policies do
    policy action(:assign_role) do
      forbid_unless actor_present()

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

    attribute :membership_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? false
      constraints min: 1
    end

    create_timestamp :inserted_at
  end
end
