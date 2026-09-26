defmodule Chimwemwe.Platform.ModuleLifecycle.ModuleWorkItem do
  @moduledoc """
  Closed tenant-owned lifecycle state for modeled module work.

  Slice 1H-B records only the queue-neutral state contract. It does not add a
  scheduler, dispatcher, consumer, or public work-enqueueing surface.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_module_work_items"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_module_work_items_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :activation_id, :status, :id],
        name: "platform_module_work_items_drain_index",
        all_tenants?: true
      )
    end

    references do
      reference(:activation,
        name: "platform_module_work_items_activation_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:work_kind, "platform_module_work_item_kind_must_be_known",
        check:
          "work_kind IN ('ordinary', 'audit', 'outbox', 'retention', 'legal_hold', 'reconciliation')"
      )

      check_constraint(:status, "platform_module_work_item_status_must_be_known",
        check: "status IN ('queued', 'running', 'parked', 'completed')"
      )

      check_constraint(
        [:work_kind, :status],
        "platform_module_work_item_parking_must_be_ordinary",
        check: "status <> 'parked' OR work_kind = 'ordinary'"
      )

      check_constraint(:replay_cursor, "platform_module_work_item_cursor_must_be_nonnegative",
        check: "replay_cursor IS NULL OR replay_cursor >= 0"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :activation, Chimwemwe.Platform.ModuleLifecycle.ModuleActivation do
      source_attribute :activation_id
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

    attribute :activation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :work_kind, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:ordinary, :audit, :outbox, :retention, :legal_hold, :reconciliation]
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:queued, :running, :parked, :completed]
    end

    attribute :replay_cursor, :integer do
      allow_nil? true
      public? false
      constraints min: 0
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
