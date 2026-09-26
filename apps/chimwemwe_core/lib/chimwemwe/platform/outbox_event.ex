defmodule Chimwemwe.Platform.OutboxEvent do
  @moduledoc """
  Immutable, tenant-owned event fact committed with authoritative state.

  This resource defines the accepted ADR 0007 envelope for production-core writes.
  Slice 1J-A may lease the immutable fact to a code-declared internal consumer.
  Slice 1J-B adds database-local execution with durable receipts and exact
  governed dead-letter replay. Retention, replay ranges/cursors, external
  publication, and wider operational qualification remain deferred.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_outbox_events"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_outbox_events_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :audit_reference],
        name: "platform_outbox_events_audit_reference_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :occurred_at, :id],
        name: "platform_outbox_events_dispatch_index",
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_type, :aggregate_id],
        name: "platform_outbox_events_aggregate_index",
        all_tenants?: true
      )
    end

    references do
      reference(:audit_event,
        name: "platform_outbox_events_audit_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:aggregate_type, "platform_outbox_aggregate_must_not_be_empty",
        check: "char_length(aggregate_type) BETWEEN 1 AND 120"
      )

      check_constraint(:event_type, "platform_outbox_event_type_must_not_be_empty",
        check: "char_length(event_type) BETWEEN 1 AND 160"
      )

      check_constraint(:schema_version, "platform_outbox_schema_version_must_be_positive",
        check: "schema_version >= 1"
      )

      check_constraint(:routing_version, "platform_outbox_routing_version_must_be_positive",
        check: "routing_version >= 1"
      )

      check_constraint(:classification, "platform_outbox_classification_must_be_internal",
        check: "classification = 'internal'"
      )

      check_constraint(:payload, "platform_outbox_payload_must_be_an_object",
        check: "jsonb_typeof(payload) = 'object'"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :audit_event, Chimwemwe.Platform.Authority.AuditEvent do
      source_attribute :audit_reference
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

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :aggregate_type, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120
    end

    attribute :aggregate_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :event_type, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160
    end

    attribute :schema_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :routing_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
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
