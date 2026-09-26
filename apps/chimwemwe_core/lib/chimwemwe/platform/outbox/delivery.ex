defmodule Chimwemwe.Platform.Outbox.Delivery do
  @moduledoc """
  Closed tenant-owned delivery state for one outbox event and code-owned consumer.

  The immutable outbox event remains the envelope. This resource records only
  operational lease, retry, dead-letter, completion, and optimistic-version state.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_outbox_deliveries"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_outbox_deliveries_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:event_id, :tenant_id, :consumer_key],
        name: "platform_outbox_deliveries_event_consumer_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :consumer_key, :status, :available_at, :event_id],
        name: "platform_outbox_deliveries_dispatch_index",
        all_tenants?: true
      )
    end

    references do
      reference(:event,
        name: "platform_outbox_deliveries_event_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:consumer_key, "platform_outbox_delivery_consumer_must_be_stable",
        check: "consumer_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'"
      )

      check_constraint(:status, "platform_outbox_delivery_status_must_be_known",
        check: "status IN ('available', 'leased', 'completed', 'dead_letter')"
      )

      check_constraint(:attempt_count, "platform_outbox_delivery_attempts_must_be_positive",
        check: "attempt_count >= 1"
      )

      check_constraint(:lock_version, "platform_outbox_delivery_version_must_be_positive",
        check: "lock_version >= 1"
      )

      check_constraint(:failure_code, "platform_outbox_delivery_failure_must_be_known",
        check:
          "failure_code IS NULL OR failure_code IN ('consumer_rejected', 'invalid_contract', 'retryable_dependency')"
      )

      check_constraint(:status, "platform_outbox_delivery_state_must_be_consistent",
        check: """
        (status = 'leased' AND lease_token IS NOT NULL AND lease_expires_at IS NOT NULL AND
          completed_at IS NULL AND failure_code IS NULL) OR
        (status = 'available' AND lease_token IS NULL AND lease_expires_at IS NULL AND
          completed_at IS NULL AND failure_code IS NOT NULL) OR
        (status = 'completed' AND lease_token IS NULL AND lease_expires_at IS NULL AND
          completed_at IS NOT NULL AND failure_code IS NULL) OR
        (status = 'dead_letter' AND lease_token IS NULL AND lease_expires_at IS NULL AND
          completed_at IS NULL AND failure_code IS NOT NULL)
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

    attribute :status, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:available, :leased, :completed, :dead_letter]
    end

    attribute :attempt_count, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :lease_token, :uuid do
      allow_nil? true
      public? false
    end

    attribute :last_lease_token, :uuid do
      allow_nil? false
      public? false
    end

    attribute :lease_expires_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :available_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :failure_code, :atom do
      allow_nil? true
      public? false
      constraints one_of: [:consumer_rejected, :invalid_contract, :retryable_dependency]
    end

    attribute :first_claimed_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :last_claimed_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :completed_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
