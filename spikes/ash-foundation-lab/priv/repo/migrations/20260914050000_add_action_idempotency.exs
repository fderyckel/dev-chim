defmodule AshFoundationLab.Repo.Migrations.AddActionIdempotency do
  use Ecto.Migration

  def change do
    create table(:action_idempotency_keys, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :actor_id,
          references(:actors,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :action_idempotency_keys_actor_tenant_fkey
          ),
          null: false

      add :action_name, :text, null: false
      add :idempotency_key, :uuid, null: false
      add :aggregate_type, :text, null: false

      add :aggregate_id,
          references(:foundation_records,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :action_idempotency_keys_aggregate_tenant_fkey
          ),
          null: false

      add :request_hash, :binary, null: false
      add :status, :text, null: false, default: "started"
      add :result_lock_version, :bigint
      add :result_audit_reference, :uuid
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :action_idempotency_keys,
             [:tenant_id, :action_name, :idempotency_key],
             name: :action_idempotency_keys_tenant_action_key_index
           )

    create index(:action_idempotency_keys, [:tenant_id, :inserted_at, :id],
             name: :action_idempotency_keys_tenant_inserted_id_index
           )

    create index(
             :action_idempotency_keys,
             [:tenant_id, :aggregate_type, :aggregate_id],
             name: :action_idempotency_keys_tenant_aggregate_index
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_action_name_must_not_be_empty,
             check: "char_length(action_name) > 0"
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_aggregate_type_must_not_be_empty,
             check: "char_length(aggregate_type) > 0"
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_request_hash_must_be_sha256,
             check: "octet_length(request_hash) = 32"
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_status_must_be_known,
             check: "status IN ('started', 'completed')"
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_completion_must_be_consistent,
             check: """
             (status = 'started' AND result_lock_version IS NULL AND
               result_audit_reference IS NULL AND completed_at IS NULL) OR
             (status = 'completed' AND result_lock_version IS NOT NULL AND
               result_audit_reference IS NOT NULL AND completed_at IS NOT NULL)
             """
           )

    create constraint(
             :action_idempotency_keys,
             :action_idempotency_result_lock_version_must_be_positive,
             check: "result_lock_version IS NULL OR result_lock_version >= 1"
           )
  end
end
