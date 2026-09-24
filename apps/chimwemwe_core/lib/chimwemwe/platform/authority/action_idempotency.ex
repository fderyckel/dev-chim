defmodule Chimwemwe.Platform.Authority.ActionIdempotency do
  @moduledoc """
  Private transaction manifest for tenant-authority action idempotency.

  The action owns claim creation, completion, and exact-result replay. This
  resource exposes no direct action and is not caller-selected persistence.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_authority_action_idempotency"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_authority_action_idempotency_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :action_name, :idempotency_key],
        name: "platform_authority_action_idempotency_key_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_type, :aggregate_id],
        name: "platform_authority_action_idempotency_aggregate_index",
        all_tenants?: true
      )

      index([:tenant_id, :inserted_at, :id],
        name: "platform_authority_action_idempotency_retention_index",
        all_tenants?: true
      )
    end

    references do
      reference(:audit_event,
        name: "platform_authority_action_idempotency_audit_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )

      reference(:outbox_event,
        name: "platform_authority_action_idempotency_outbox_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(:action_name, "platform_authority_idempotency_action_must_not_be_empty",
        check: "char_length(action_name) BETWEEN 1 AND 160"
      )

      check_constraint(
        :aggregate_type,
        "platform_authority_idempotency_aggregate_must_not_be_empty",
        check: "char_length(aggregate_type) BETWEEN 1 AND 120"
      )

      check_constraint(:request_hash, "platform_authority_idempotency_hash_must_be_sha256",
        check: "octet_length(request_hash) = 32"
      )

      check_constraint(:status, "platform_authority_idempotency_status_must_be_known",
        check: "status IN ('started', 'completed')"
      )

      check_constraint(
        [
          :status,
          :result_name,
          :result_lock_version,
          :result_payload,
          :audit_reference,
          :event_id,
          :completed_at
        ],
        "platform_authority_idempotency_completion_must_be_consistent",
        check: """
        (status = 'started' AND result_name IS NULL AND result_lock_version IS NULL AND
          result_payload IS NULL AND
          audit_reference IS NULL AND event_id IS NULL AND completed_at IS NULL) OR
        (status = 'completed' AND audit_reference IS NOT NULL AND event_id IS NOT NULL AND
          completed_at IS NOT NULL AND (
            (result_payload IS NULL AND result_name IS NOT NULL AND result_lock_version IS NOT NULL) OR
            (result_payload IS NOT NULL AND result_name IS NULL AND result_lock_version IS NULL)
          ))
        """
      )

      check_constraint(
        :result_lock_version,
        "platform_authority_idempotency_result_version_must_be_positive",
        check: "result_lock_version IS NULL OR result_lock_version >= 1"
      )

      check_constraint(
        :result_payload,
        "platform_authority_idempotency_payload_must_be_an_object",
        check: "result_payload IS NULL OR jsonb_typeof(result_payload) = 'object'"
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

    belongs_to :outbox_event, Chimwemwe.Platform.OutboxEvent do
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

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :action_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160
    end

    attribute :idempotency_key, :uuid do
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

    attribute :request_hash, :binary do
      allow_nil? false
      public? false
    end

    attribute :status, :atom do
      allow_nil? false
      default :started
      public? false
      constraints one_of: [:started, :completed]
    end

    attribute :result_name, :string do
      allow_nil? true
      public? false
      constraints min_length: 1, max_length: 120
    end

    attribute :result_lock_version, :integer do
      allow_nil? true
      public? false
      constraints min: 1
    end

    attribute :result_payload, :map do
      allow_nil? true
      public? false
    end

    attribute :audit_reference, :uuid do
      allow_nil? true
      public? false
    end

    attribute :event_id, :uuid do
      allow_nil? true
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
