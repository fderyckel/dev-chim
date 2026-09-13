defmodule AshFoundationLab.Repo.Migrations.AddTransactionalOutbox do
  use Ecto.Migration

  def change do
    alter table(:foundation_records) do
      add :audit_reference, :uuid
    end

    create unique_index(:foundation_records, [:tenant_id, :audit_reference],
             where: "audit_reference IS NOT NULL"
           )

    create constraint(:foundation_records, :submitted_record_requires_audit_reference,
             check: "status <> 'in_review' OR audit_reference IS NOT NULL"
           )

    create table(:outbox_events, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :actor_id,
          references(:actors,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :outbox_events_actor_tenant_fkey
          ),
          null: false

      add :aggregate_type, :text, null: false

      add :aggregate_id,
          references(:foundation_records,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :outbox_events_aggregate_tenant_fkey
          ),
          null: false

      add :event_type, :text, null: false
      add :schema_version, :integer, null: false
      add :correlation_id, :uuid, null: false
      add :causation_id, :uuid, null: false
      add :audit_reference, :uuid, null: false
      add :classification, :text, null: false
      add :payload, :map, null: false
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:outbox_events, [:tenant_id, :audit_reference])
    create index(:outbox_events, [:tenant_id, :occurred_at, :id])
    create index(:outbox_events, [:tenant_id, :aggregate_type, :aggregate_id])

    create constraint(:outbox_events, :outbox_aggregate_type_must_not_be_empty,
             check: "char_length(aggregate_type) > 0"
           )

    create constraint(:outbox_events, :outbox_event_type_must_not_be_empty,
             check: "char_length(event_type) > 0"
           )

    create constraint(:outbox_events, :outbox_schema_version_must_be_positive,
             check: "schema_version >= 1"
           )

    create constraint(:outbox_events, :outbox_classification_must_be_internal,
             check: "classification = 'internal'"
           )

    create constraint(:outbox_events, :outbox_payload_must_be_an_object,
             check: "jsonb_typeof(payload) = 'object'"
           )
  end
end
