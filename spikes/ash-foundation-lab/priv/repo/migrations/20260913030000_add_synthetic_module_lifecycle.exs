defmodule AshFoundationLab.Repo.Migrations.AddSyntheticModuleLifecycle do
  use Ecto.Migration

  def change do
    create table(:synthetic_module_instances, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)
      add(:module_key, :text, null: false)
      add(:installed_version, :text)
      add(:entitled, :boolean, null: false, default: false)
      add(:activation_state, :text, null: false, default: "inactive")
      add(:dependency_ready, :boolean, null: false, default: false)
      add(:active_dependents, :integer, null: false, default: 0)
      add(:lifecycle_version, :bigint, null: false, default: 1)
      add(:event_cursor, :bigint, null: false, default: 0)
      add(:replay_from_cursor, :bigint)
      add(:projection_version, :bigint, null: false, default: 0)
      add(:projection_ready, :boolean, null: false, default: false)
      add(:reconciliation_required, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:synthetic_module_instances, [:id, :tenant_id])
    create unique_index(:synthetic_module_instances, [:tenant_id, :module_key])

    create constraint(:synthetic_module_instances, :synthetic_module_key_must_not_be_empty,
             check: "char_length(module_key) > 0"
           )

    create constraint(
             :synthetic_module_instances,
             :synthetic_module_activation_state_must_be_known,
             check: "activation_state IN ('inactive', 'active')"
           )

    create constraint(
             :synthetic_module_instances,
             :synthetic_module_lifecycle_version_must_be_positive,
             check: "lifecycle_version >= 1"
           )

    create constraint(:synthetic_module_instances, :synthetic_module_cursors_must_be_valid,
             check:
               "event_cursor >= 0 AND (replay_from_cursor IS NULL OR replay_from_cursor >= 0)"
           )

    create constraint(
             :synthetic_module_instances,
             :synthetic_module_projection_version_must_be_non_negative,
             check: "projection_version >= 0"
           )

    create constraint(
             :synthetic_module_instances,
             :synthetic_module_active_dependents_must_be_non_negative,
             check: "active_dependents >= 0"
           )

    create table(:synthetic_module_records, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(
        :module_instance_id,
        references(:synthetic_module_instances,
          type: :uuid,
          with: [tenant_id: :tenant_id],
          match: :full,
          on_delete: :restrict,
          name: :synthetic_module_records_instance_tenant_fkey
        ),
        null: false
      )

      add(:label, :text, null: false)
      add(:retained, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:synthetic_module_records, [:id, :tenant_id])
    create index(:synthetic_module_records, [:tenant_id, :module_instance_id])

    create constraint(:synthetic_module_records, :synthetic_module_record_label_must_not_be_empty,
             check: "char_length(label) > 0"
           )

    create table(:synthetic_module_work_items, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(
        :module_instance_id,
        references(:synthetic_module_instances,
          type: :uuid,
          with: [tenant_id: :tenant_id],
          match: :full,
          on_delete: :restrict,
          name: :synthetic_module_work_items_instance_tenant_fkey
        ),
        null: false
      )

      add(:work_kind, :text, null: false)
      add(:status, :text, null: false)
      add(:replay_cursor, :bigint)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:synthetic_module_work_items, [:id, :tenant_id])

    create index(:synthetic_module_work_items, [:tenant_id, :module_instance_id, :status],
             name: :synthetic_module_work_status_index
           )

    create constraint(:synthetic_module_work_items, :synthetic_module_work_kind_must_be_known,
             check: "work_kind IN ('ordinary', 'mandatory')"
           )

    create constraint(:synthetic_module_work_items, :synthetic_module_work_status_must_be_known,
             check: "status IN ('queued', 'running', 'parked', 'completed')"
           )

    create constraint(:synthetic_module_work_items, :synthetic_module_replay_cursor_must_be_valid,
             check: "replay_cursor IS NULL OR replay_cursor >= 0"
           )

    create table(:synthetic_module_lifecycle_events, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false)

      add(
        :module_instance_id,
        references(:synthetic_module_instances,
          type: :uuid,
          with: [tenant_id: :tenant_id],
          match: :full,
          on_delete: :restrict,
          name: :synthetic_module_events_instance_tenant_fkey
        ),
        null: false
      )

      add(
        :actor_id,
        references(:actors,
          type: :uuid,
          with: [tenant_id: :tenant_id],
          match: :full,
          on_delete: :restrict,
          name: :synthetic_module_events_actor_tenant_fkey
        ),
        null: false
      )

      add(:channel, :text, null: false)
      add(:event_type, :text, null: false)
      add(:lifecycle_version, :bigint, null: false)
      add(:correlation_id, :uuid, null: false)
      add(:classification, :text, null: false)
      add(:payload, :map, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(
             :synthetic_module_lifecycle_events,
             [
               :tenant_id,
               :module_instance_id,
               :inserted_at,
               :id
             ], name: :synthetic_module_event_order_index)

    create unique_index(
             :synthetic_module_lifecycle_events,
             [:tenant_id, :correlation_id, :channel, :event_type],
             name: :synthetic_module_events_correlation_channel_type_index
           )

    create constraint(:synthetic_module_lifecycle_events, :synthetic_module_channel_must_be_known,
             check: "channel IN ('audit', 'outbox')"
           )

    create constraint(
             :synthetic_module_lifecycle_events,
             :synthetic_module_event_type_must_not_be_empty,
             check: "char_length(event_type) > 0"
           )

    create constraint(
             :synthetic_module_lifecycle_events,
             :synthetic_module_event_version_must_be_positive,
             check: "lifecycle_version >= 1"
           )

    create constraint(
             :synthetic_module_lifecycle_events,
             :synthetic_module_event_classification_must_be_internal,
             check: "classification = 'internal'"
           )

    create constraint(
             :synthetic_module_lifecycle_events,
             :synthetic_module_event_payload_must_be_an_object,
             check: "jsonb_typeof(payload) = 'object'"
           )
  end
end
