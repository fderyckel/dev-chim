defmodule AshFoundationLab.OutboxEvent do
  @moduledoc """
  Immutable, tenant-owned event fact used only by the Phase 0 transaction spike.

  It intentionally exposes no Ash actions; dispatch and replay remain later-phase work.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "outbox_events"
    repo AshFoundationLab.Repo

    custom_indexes do
      index [:tenant_id, :audit_reference],
        name: "outbox_events_tenant_id_audit_reference_index",
        unique: true,
        all_tenants?: true

      index [:tenant_id, :occurred_at, :id],
        name: "outbox_events_tenant_id_occurred_at_id_index",
        all_tenants?: true

      index [:tenant_id, :aggregate_type, :aggregate_id],
        name: "outbox_events_tenant_id_aggregate_type_aggregate_id_index",
        all_tenants?: true
    end

    references do
      reference :tenant,
        name: "outbox_events_tenant_id_fkey",
        on_delete: :restrict

      reference :actor,
        name: "outbox_events_actor_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full

      reference :foundation_record,
        name: "outbox_events_aggregate_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
    end

    check_constraints do
      check_constraint :aggregate_type, "outbox_aggregate_type_must_not_be_empty",
        check: "char_length(aggregate_type) > 0"

      check_constraint :event_type, "outbox_event_type_must_not_be_empty",
        check: "char_length(event_type) > 0"

      check_constraint :schema_version, "outbox_schema_version_must_be_positive",
        check: "schema_version >= 1"

      check_constraint :classification, "outbox_classification_must_be_internal",
        check: "classification = 'internal'"

      check_constraint :payload, "outbox_payload_must_be_an_object",
        check: "jsonb_typeof(payload) = 'object'"
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :tenant, AshFoundationLab.Tenant do
      source_attribute :tenant_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :actor, AshFoundationLab.Actor do
      source_attribute :actor_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :foundation_record, AshFoundationLab.FoundationRecord do
      source_attribute :aggregate_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :aggregate_type, :string do
      allow_nil? false
      public? false
    end

    attribute :aggregate_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :event_type, :string do
      allow_nil? false
      public? false
    end

    attribute :schema_version, :integer do
      allow_nil? false
      public? false
    end

    attribute :correlation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :causation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :audit_reference, :uuid do
      allow_nil? false
      public? false
    end

    attribute :classification, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:internal]
    end

    attribute :payload, :map do
      allow_nil? false
      public? false
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
