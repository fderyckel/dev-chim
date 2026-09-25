defmodule Chimwemwe.Platform.Authority.Role do
  @moduledoc """
  Renameable tenant-defined role identified by an immutable UUID, never by its label.

  `rename_role` is the first private Slice 1G action. Callers must enter it through
  `Chimwemwe.Platform.Authority.rename_role/3`, which owns trusted context,
  persistence routing, stable results, and stable errors.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_roles"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_roles_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :name],
        name: "platform_roles_tenant_name_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:name, "platform_role_name_must_not_be_empty",
        check: "char_length(name) BETWEEN 1 AND 120"
      )

      check_constraint(:lock_version, "platform_role_lock_version_must_be_positive",
        check: "lock_version >= 1"
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
      prepare build(sort: [name: :asc, id: :asc])
    end

    action :rename_role, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.Authority.RenameRoleResult

      argument :role_id, :uuid do
        allow_nil? false
      end

      argument :name, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 120, trim?: true
      end

      argument :expected_version, :integer do
        allow_nil? false
        constraints min: 1
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.Authority.RenameRole
    end
  end

  policies do
    policy action(:assignment_candidates) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.authority.assignments.create"}
    end

    policy action(:rename_role) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.authority.roles.rename"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120, trim?: true
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? false
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
