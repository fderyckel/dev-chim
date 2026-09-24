defmodule Chimwemwe.Repo.Migrations.AuthorityRoleRename do
  @moduledoc """
  Adds the closed audit, outbox, and idempotency manifests for role rename.

  AshPostgres generated the schema operations and resource snapshots. This
  reviewed artifact creates tenant-qualified destinations before their compound
  foreign keys and keeps rollback in the inverse dependency order.
  """

  use Ecto.Migration

  def change do
    create table(:platform_authority_audit_events, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)
      add(:action_name, :text, null: false)
      add(:aggregate_type, :text, null: false)
      add(:aggregate_id, :uuid, null: false)
      add(:idempotency_key, :uuid, null: false)
      add(:correlation_id, :uuid, null: false)
      add(:causation_id, :uuid, null: false)
      add(:before_version, :bigint, null: false)
      add(:after_version, :bigint, null: false)
      add(:change_summary, :map, null: false)
      add(:occurred_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(
             :platform_authority_audit_events,
             :platform_authority_audit_action_must_not_be_empty,
             check: "char_length(action_name) BETWEEN 1 AND 160"
           )

    create constraint(
             :platform_authority_audit_events,
             :platform_authority_audit_aggregate_must_not_be_empty,
             check: "char_length(aggregate_type) BETWEEN 1 AND 120"
           )

    create constraint(
             :platform_authority_audit_events,
             :platform_authority_audit_versions_must_be_consecutive,
             check: "before_version >= 1 AND after_version = before_version + 1"
           )

    create constraint(
             :platform_authority_audit_events,
             :platform_authority_audit_change_must_be_an_object,
             check: "jsonb_typeof(change_summary) = 'object'"
           )

    create unique_index(:platform_authority_audit_events, [:id, :tenant_id],
             name: :platform_authority_audit_events_id_tenant_index
           )

    create index(
             :platform_authority_audit_events,
             [:tenant_id, :aggregate_type, :aggregate_id, :occurred_at, :id],
             name: :platform_authority_audit_events_aggregate_index
           )

    create table(:platform_outbox_events, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)
      add(:aggregate_type, :text, null: false)
      add(:aggregate_id, :uuid, null: false)
      add(:event_type, :text, null: false)
      add(:schema_version, :bigint, null: false)
      add(:routing_version, :bigint, null: false)
      add(:correlation_id, :uuid, null: false)
      add(:causation_id, :uuid, null: false)

      add(
        :audit_reference,
        references(:platform_authority_audit_events,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :platform_outbox_events_audit_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      add(:classification, :text, null: false)
      add(:payload, :map, null: false)
      add(:occurred_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:platform_outbox_events, :platform_outbox_aggregate_must_not_be_empty,
             check: "char_length(aggregate_type) BETWEEN 1 AND 120"
           )

    create constraint(:platform_outbox_events, :platform_outbox_event_type_must_not_be_empty,
             check: "char_length(event_type) BETWEEN 1 AND 160"
           )

    create constraint(:platform_outbox_events, :platform_outbox_schema_version_must_be_positive,
             check: "schema_version >= 1"
           )

    create constraint(
             :platform_outbox_events,
             :platform_outbox_routing_version_must_be_positive,
             check: "routing_version >= 1"
           )

    create constraint(:platform_outbox_events, :platform_outbox_classification_must_be_internal,
             check: "classification = 'internal'"
           )

    create constraint(:platform_outbox_events, :platform_outbox_payload_must_be_an_object,
             check: "jsonb_typeof(payload) = 'object'"
           )

    create unique_index(:platform_outbox_events, [:id, :tenant_id],
             name: :platform_outbox_events_id_tenant_index
           )

    create unique_index(:platform_outbox_events, [:tenant_id, :audit_reference],
             name: :platform_outbox_events_audit_reference_index
           )

    create index(:platform_outbox_events, [:tenant_id, :occurred_at, :id],
             name: :platform_outbox_events_dispatch_index
           )

    create index(:platform_outbox_events, [:tenant_id, :aggregate_type, :aggregate_id],
             name: :platform_outbox_events_aggregate_index
           )

    create table(:platform_authority_action_idempotency, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)
      add(:action_name, :text, null: false)
      add(:idempotency_key, :uuid, null: false)
      add(:aggregate_type, :text, null: false)
      add(:aggregate_id, :uuid, null: false)
      add(:request_hash, :binary, null: false)
      add(:status, :text, null: false, default: "started")
      add(:result_name, :text)
      add(:result_lock_version, :bigint)

      add(
        :audit_reference,
        references(:platform_authority_audit_events,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :simple,
          name: :platform_authority_action_idempotency_audit_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        )
      )

      add(
        :event_id,
        references(:platform_outbox_events,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :simple,
          name: :platform_authority_action_idempotency_outbox_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        )
      )

      add(:completed_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_action_must_not_be_empty,
             check: "char_length(action_name) BETWEEN 1 AND 160"
           )

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_aggregate_must_not_be_empty,
             check: "char_length(aggregate_type) BETWEEN 1 AND 120"
           )

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_hash_must_be_sha256,
             check: "octet_length(request_hash) = 32"
           )

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_status_must_be_known,
             check: "status IN ('started', 'completed')"
           )

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_completion_must_be_consistent,
             check: """
             (status = 'started' AND result_name IS NULL AND result_lock_version IS NULL AND
               audit_reference IS NULL AND event_id IS NULL AND completed_at IS NULL) OR
             (status = 'completed' AND result_name IS NOT NULL AND
               result_lock_version IS NOT NULL AND audit_reference IS NOT NULL AND
               event_id IS NOT NULL AND completed_at IS NOT NULL)
             """
           )

    create constraint(
             :platform_authority_action_idempotency,
             :platform_authority_idempotency_result_version_must_be_positive,
             check: "result_lock_version IS NULL OR result_lock_version >= 1"
           )

    create unique_index(:platform_authority_action_idempotency, [:id, :tenant_id],
             name: :platform_authority_action_idempotency_id_tenant_index
           )

    create unique_index(
             :platform_authority_action_idempotency,
             [:tenant_id, :action_name, :idempotency_key],
             name: :platform_authority_action_idempotency_key_index
           )

    create index(
             :platform_authority_action_idempotency,
             [:tenant_id, :aggregate_type, :aggregate_id],
             name: :platform_authority_action_idempotency_aggregate_index
           )

    create index(:platform_authority_action_idempotency, [:tenant_id, :inserted_at, :id],
             name: :platform_authority_action_idempotency_retention_index
           )
  end
end
