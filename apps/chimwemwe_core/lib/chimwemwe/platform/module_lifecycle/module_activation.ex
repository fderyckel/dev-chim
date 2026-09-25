defmodule Chimwemwe.Platform.ModuleLifecycle.ModuleActivation do
  @moduledoc """
  Tenant-owned activation of one entitled module version.

  The initial `activate_module` action is private. Callers enter through
  `Chimwemwe.Platform.ModuleLifecycle.activate/4`, which owns trusted release,
  context, persistence, stable-result, and stable-error handling.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_module_activations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_module_activations_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :entitlement_id],
        name: "platform_module_activations_entitlement_index",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:entitlement,
        name: "platform_module_activations_entitlement_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:module_version, "platform_module_activation_version_must_be_valid",
        check:
          "char_length(module_version) BETWEEN 5 AND 80 AND module_version ~ '^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$'"
      )

      check_constraint(:state, "platform_module_activation_state_must_be_active",
        check: "state = 'active'"
      )

      check_constraint(:lock_version, "platform_module_activation_lock_version_must_be_positive",
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
    belongs_to :entitlement, Chimwemwe.Platform.ModuleLifecycle.ModuleEntitlement do
      source_attribute :entitlement_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  actions do
    action :activate_module, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.ModuleLifecycle.ActivateModuleResult

      argument :module_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
      end

      argument :expected_version, :integer do
        allow_nil? false
        constraints min: 0, max: 0
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.ModuleLifecycle.ActivateModule
    end
  end

  policies do
    policy action(:activate_module) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.modules.activate"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :entitlement_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :module_version, :string do
      allow_nil? false
      public? false
      constraints min_length: 5, max_length: 80
    end

    attribute :state, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:active]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :activated_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
