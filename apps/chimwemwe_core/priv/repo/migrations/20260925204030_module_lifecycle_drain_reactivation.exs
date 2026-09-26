defmodule Chimwemwe.Repo.Migrations.ModuleLifecycleDrainReactivation do
  @moduledoc """
  Expands the module activation aggregate for controlled drain and reactivation.

  The migration preserves every Slice 1H-A activation, adds queue-neutral work
  state, and refuses rollback once any Slice 1H-B transition or durable evidence
  exists. It never drops retained tenant data as a lifecycle operation.
  """

  use Ecto.Migration

  def up do
    drop_if_exists(
      constraint(:platform_module_activations, :platform_module_activation_state_must_be_active)
    )

    alter table(:platform_module_activations) do
      add(:deactivated_at, :utc_datetime_usec)
      add(:reactivated_at, :utc_datetime_usec)
      add(:consumer_cursor, :bigint, null: false, default: 0)
      add(:replay_from_cursor, :bigint)
      add(:last_reconciled_cursor, :bigint, null: false, default: 0)
      add(:projection_version, :bigint, null: false, default: 1)
      add(:projection_ready, :boolean, null: false, default: true)
      add(:reconciliation_required, :boolean, null: false, default: false)
      add(:retained_data_state, :text, null: false, default: "retained")
    end

    create constraint(
             :platform_module_activations,
             :platform_module_activation_state_must_be_known,
             check: "state IN ('active', 'inactive')"
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_cursors_must_be_nonnegative,
             check: """
             consumer_cursor >= 0 AND
               (replay_from_cursor IS NULL OR replay_from_cursor >= 0) AND
               last_reconciled_cursor >= 0
             """
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_projection_version_must_be_positive,
             check: "projection_version >= 1"
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_retained_data_must_remain_owned,
             check: "retained_data_state = 'retained'"
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_state_must_be_consistent,
             check: """
             (state = 'active' AND replay_from_cursor IS NULL AND projection_ready = true AND
               reconciliation_required = false) OR
             (state = 'inactive' AND replay_from_cursor IS NOT NULL AND projection_ready = false AND
               reconciliation_required = true AND deactivated_at IS NOT NULL)
             """
           )

    create table(:platform_module_work_items, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :activation_id,
        references(:platform_module_activations,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "platform_module_work_items_activation_tenant_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:work_kind, :text, null: false)
      add(:status, :text, null: false)
      add(:replay_cursor, :bigint)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(
             :platform_module_work_items,
             :platform_module_work_item_kind_must_be_known,
             check: """
             work_kind IN ('ordinary', 'audit', 'outbox', 'retention', 'legal_hold', 'reconciliation')
             """
           )

    create constraint(
             :platform_module_work_items,
             :platform_module_work_item_status_must_be_known,
             check: "status IN ('queued', 'running', 'parked', 'completed')"
           )

    create constraint(
             :platform_module_work_items,
             :platform_module_work_item_parking_must_be_ordinary,
             check: "status <> 'parked' OR work_kind = 'ordinary'"
           )

    create constraint(
             :platform_module_work_items,
             :platform_module_work_item_cursor_must_be_nonnegative,
             check: "replay_cursor IS NULL OR replay_cursor >= 0"
           )

    create index(:platform_module_work_items, [:id, :tenant_id],
             name: "platform_module_work_items_id_tenant_index",
             unique: true
           )

    create index(:platform_module_work_items, [:tenant_id, :activation_id, :status, :id],
             name: "platform_module_work_items_drain_index"
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM platform_module_work_items)
         OR EXISTS (
           SELECT 1
           FROM platform_module_activations
           WHERE state <> 'active'
              OR lock_version <> 1
              OR consumer_cursor <> 0
              OR replay_from_cursor IS NOT NULL
              OR last_reconciled_cursor <> 0
              OR projection_version <> 1
              OR projection_ready <> true
              OR reconciliation_required <> false
              OR retained_data_state <> 'retained'
              OR deactivated_at IS NOT NULL
              OR reactivated_at IS NOT NULL
         )
         OR EXISTS (
           SELECT 1
           FROM platform_authority_audit_events
           WHERE action_name IN (
             'platform.module_lifecycle.deactivate',
             'platform.module_lifecycle.complete_mandatory_work',
             'platform.module_lifecycle.reactivate'
           )
         )
         OR EXISTS (
           SELECT 1
           FROM platform_outbox_events
           WHERE event_type IN (
             'platform.module.deactivated',
             'platform.module.mandatory_work_completed',
             'platform.module.reactivated'
           )
         )
         OR EXISTS (
           SELECT 1
           FROM platform_authority_action_idempotency
           WHERE action_name IN (
             'platform.module_lifecycle.deactivate',
             'platform.module_lifecycle.complete_mandatory_work',
             'platform.module_lifecycle.reactivate'
           )
         )
      THEN
        RAISE EXCEPTION
          'module lifecycle drain rollback requires empty 1H-B work and durable evidence state';
      END IF;
    END
    $$;
    """)

    drop_if_exists(
      index(:platform_module_work_items, [:tenant_id, :activation_id, :status, :id],
        name: "platform_module_work_items_drain_index"
      )
    )

    drop_if_exists(
      index(:platform_module_work_items, [:id, :tenant_id],
        name: "platform_module_work_items_id_tenant_index"
      )
    )

    drop(table(:platform_module_work_items))

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_state_must_be_consistent
      )
    )

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_retained_data_must_remain_owned
      )
    )

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_projection_version_must_be_positive
      )
    )

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_cursors_must_be_nonnegative
      )
    )

    drop_if_exists(
      constraint(:platform_module_activations, :platform_module_activation_state_must_be_known)
    )

    alter table(:platform_module_activations) do
      remove(:deactivated_at)
      remove(:reactivated_at)
      remove(:consumer_cursor)
      remove(:replay_from_cursor)
      remove(:last_reconciled_cursor)
      remove(:projection_version)
      remove(:projection_ready)
      remove(:reconciliation_required)
      remove(:retained_data_state)
    end

    create constraint(
             :platform_module_activations,
             :platform_module_activation_state_must_be_active,
             check: "state = 'active'"
           )
  end
end
