defmodule Chimwemwe.Platform.Outbox.ConsumerReceipt do
  @moduledoc """
  Closed tenant-owned proof that one code-owned consumer processed one event.

  The receipt is inserted in the same writer transaction as the database-local
  consumer effect. Its event, consumer, handler, and contract pins make an
  acknowledgement crash safe to redeliver without executing the effect twice.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_outbox_consumer_receipts"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_outbox_consumer_receipts_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:event_id, :tenant_id, :consumer_key],
        name: "platform_outbox_consumer_receipts_event_consumer_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :processed_at, :id],
        name: "platform_outbox_consumer_receipts_retention_index",
        all_tenants?: true
      )
    end

    references do
      reference(:event,
        name: "platform_outbox_consumer_receipts_event_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:consumer_key, "platform_outbox_receipt_consumer_must_be_stable",
        check: "consumer_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'"
      )

      check_constraint(
        :handler_revision,
        "platform_outbox_receipt_handler_revision_must_be_positive",
        check: "handler_revision >= 1"
      )

      check_constraint(:event_type, "platform_outbox_receipt_event_type_must_not_be_empty",
        check: "char_length(event_type) BETWEEN 1 AND 160"
      )

      check_constraint(:schema_version, "platform_outbox_receipt_schema_version_must_be_positive",
        check: "schema_version >= 1"
      )

      check_constraint(
        :routing_version,
        "platform_outbox_receipt_routing_version_must_be_positive",
        check: "routing_version >= 1"
      )

      check_constraint(:result_digest, "platform_outbox_receipt_digest_must_be_sha256",
        check: "octet_length(result_digest) = 32"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :event, Chimwemwe.Platform.OutboxEvent do
      source_attribute :event_id
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

    attribute :event_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :consumer_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 160
    end

    attribute :handler_revision, :integer do
      allow_nil? false
      public? false
      constraints min: 1
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

    attribute :result_digest, :binary do
      allow_nil? false
      public? false
    end

    attribute :processed_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
