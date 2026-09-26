defmodule Chimwemwe.Platform.ModuleLifecycle.ModuleActivation do
  @moduledoc """
  Tenant-owned lifecycle state for one entitled module version.

  Every lifecycle action is private. Callers enter through
  `Chimwemwe.Platform.ModuleLifecycle`, which owns trusted release, context,
  persistence, stable-result, and stable-error handling.
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

      check_constraint(:state, "platform_module_activation_state_must_be_known",
        check: "state IN ('active', 'inactive')"
      )

      check_constraint(:lock_version, "platform_module_activation_lock_version_must_be_positive",
        check: "lock_version >= 1"
      )

      check_constraint(
        [:consumer_cursor, :replay_from_cursor, :last_reconciled_cursor],
        "platform_module_activation_cursors_must_be_nonnegative",
        check: """
        consumer_cursor >= 0 AND
          (replay_from_cursor IS NULL OR replay_from_cursor >= 0) AND
          last_reconciled_cursor >= 0
        """
      )

      check_constraint(
        :projection_version,
        "platform_module_activation_projection_version_must_be_positive",
        check: "projection_version >= 1"
      )

      check_constraint(
        :retained_data_state,
        "platform_module_activation_retained_data_must_remain_owned",
        check: "retained_data_state = 'retained'"
      )

      check_constraint(
        [
          :state,
          :replay_from_cursor,
          :projection_ready,
          :reconciliation_required,
          :deactivated_at
        ],
        "platform_module_activation_state_must_be_consistent",
        check: """
        (state = 'active' AND replay_from_cursor IS NULL AND projection_ready = true AND
          reconciliation_required = false) OR
        (state = 'inactive' AND replay_from_cursor IS NOT NULL AND projection_ready = false AND
          reconciliation_required = true AND deactivated_at IS NOT NULL)
        """
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

    action :deactivate_module, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.ModuleLifecycle.TransitionResult

      argument :module_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
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

      run {Chimwemwe.Platform.ModuleLifecycle.Transition, operation: :deactivate}
    end

    action :complete_mandatory_work, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.ModuleLifecycle.TransitionResult

      argument :module_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
      end

      argument :work_item_id, :uuid do
        allow_nil? false
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

      run {Chimwemwe.Platform.ModuleLifecycle.Transition, operation: :complete_mandatory_work}
    end

    action :reactivate_module, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.ModuleLifecycle.TransitionResult

      argument :module_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
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

      run {Chimwemwe.Platform.ModuleLifecycle.Transition, operation: :reactivate}
    end
  end

  policies do
    policy action(:activate_module) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.modules.activate"}
    end

    policy action(:deactivate_module) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.modules.deactivate"}
    end

    policy action(:complete_mandatory_work) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.modules.mandatory_work.complete"}
    end

    policy action(:reactivate_module) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.modules.reactivate"}
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
      constraints one_of: [:active, :inactive]
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

    attribute :deactivated_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :reactivated_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :consumer_cursor, :integer do
      allow_nil? false
      default 0
      public? false
      constraints min: 0
    end

    attribute :replay_from_cursor, :integer do
      allow_nil? true
      public? false
      constraints min: 0
    end

    attribute :last_reconciled_cursor, :integer do
      allow_nil? false
      default 0
      public? false
      constraints min: 0
    end

    attribute :projection_version, :integer do
      allow_nil? false
      default 1
      public? false
      constraints min: 1
    end

    attribute :projection_ready, :boolean do
      allow_nil? false
      default true
      public? false
    end

    attribute :reconciliation_required, :boolean do
      allow_nil? false
      default false
      public? false
    end

    attribute :retained_data_state, :atom do
      allow_nil? false
      default :retained
      public? false
      constraints one_of: [:retained]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
