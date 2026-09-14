defmodule AshFoundationLab.ActionIdempotency do
  @moduledoc """
  Internal persistence manifest for Phase 0 named-action idempotency evidence.

  The resource intentionally exposes no actions or generated routes. The named
  transition owns access through its authorized transactional change.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "action_idempotency_keys"
    repo AshFoundationLab.Repo

    custom_indexes do
      index [:tenant_id, :action_name, :idempotency_key],
        name: "action_idempotency_keys_tenant_action_key_index",
        unique: true,
        all_tenants?: true

      index [:tenant_id, :inserted_at, :id],
        name: "action_idempotency_keys_tenant_inserted_id_index",
        all_tenants?: true

      index [:tenant_id, :aggregate_type, :aggregate_id],
        name: "action_idempotency_keys_tenant_aggregate_index",
        all_tenants?: true
    end

    references do
      reference :tenant,
        name: "action_idempotency_keys_tenant_id_fkey",
        on_delete: :restrict

      reference :actor,
        name: "action_idempotency_keys_actor_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full

      reference :foundation_record,
        name: "action_idempotency_keys_aggregate_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
    end

    check_constraints do
      check_constraint :action_name, "action_idempotency_action_name_must_not_be_empty",
        check: "char_length(action_name) > 0"

      check_constraint :aggregate_type, "action_idempotency_aggregate_type_must_not_be_empty",
        check: "char_length(aggregate_type) > 0"

      check_constraint :request_hash, "action_idempotency_request_hash_must_be_sha256",
        check: "octet_length(request_hash) = 32"

      check_constraint :status, "action_idempotency_status_must_be_known",
        check: "status IN ('started', 'completed')"

      check_constraint [:status, :result_lock_version, :result_audit_reference, :completed_at],
                       "action_idempotency_completion_must_be_consistent",
                       check: """
                       (status = 'started' AND result_lock_version IS NULL AND
                         result_audit_reference IS NULL AND completed_at IS NULL) OR
                       (status = 'completed' AND result_lock_version IS NOT NULL AND
                         result_audit_reference IS NOT NULL AND completed_at IS NOT NULL)
                       """

      check_constraint :result_lock_version,
                       "action_idempotency_result_lock_version_must_be_positive",
                       check: "result_lock_version IS NULL OR result_lock_version >= 1"
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

  actions do
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
    end

    attribute :idempotency_key, :uuid do
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

    attribute :result_lock_version, :integer do
      allow_nil? true
      public? false
      constraints min: 1
    end

    attribute :result_audit_reference, :uuid do
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
