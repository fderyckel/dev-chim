defmodule Chimwemwe.Repo.Migrations.OutboxSupervisedConsumptionAndReplay do
  @moduledoc """
  Adds durable internal-consumer receipts and governed dead-letter replay state.

  AshPostgres generated the resource-shaped changes. Review added the exact
  receipt-to-delivery tenant/consumer foreign key and a retained-evidence guard
  that refuses destructive rollback after consumption or replay evidence exists.
  """

  use Ecto.Migration

  def up do
    create table(:platform_outbox_consumer_receipts, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :event_id,
        references(:platform_outbox_events,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "platform_outbox_consumer_receipts_event_tenant_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:consumer_key, :text, null: false)
      add(:handler_revision, :bigint, null: false)
      add(:event_type, :text, null: false)
      add(:schema_version, :bigint, null: false)
      add(:routing_version, :bigint, null: false)
      add(:result_digest, :binary, null: false)
      add(:processed_at, :utc_datetime_usec, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_consumer_must_be_stable,
             check: """
               consumer_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
             """
           )

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_handler_revision_must_be_positive,
             check: """
               handler_revision >= 1
             """
           )

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_event_type_must_not_be_empty,
             check: """
               char_length(event_type) BETWEEN 1 AND 160
             """
           )

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_schema_version_must_be_positive,
             check: """
               schema_version >= 1
             """
           )

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_routing_version_must_be_positive,
             check: """
               routing_version >= 1
             """
           )

    create constraint(
             :platform_outbox_consumer_receipts,
             :platform_outbox_receipt_digest_must_be_sha256,
             check: """
               octet_length(result_digest) = 32
             """
           )

    create index(:platform_outbox_consumer_receipts, [:id, :tenant_id],
             name: "platform_outbox_consumer_receipts_id_tenant_index",
             unique: true
           )

    create index(:platform_outbox_consumer_receipts, [:event_id, :tenant_id, :consumer_key],
             name: "platform_outbox_consumer_receipts_event_consumer_index",
             unique: true
           )

    create index(:platform_outbox_consumer_receipts, [:tenant_id, :processed_at, :id],
             name: "platform_outbox_consumer_receipts_retention_index"
           )

    execute("""
    ALTER TABLE platform_outbox_consumer_receipts
      ADD CONSTRAINT platform_outbox_consumer_receipts_delivery_tenant_fkey
      FOREIGN KEY (event_id, tenant_id, consumer_key)
      REFERENCES platform_outbox_deliveries (event_id, tenant_id, consumer_key)
      MATCH FULL
      ON DELETE RESTRICT
    """)

    alter table(:platform_outbox_deliveries) do
      add(:replay_count, :bigint, null: false, default: 0)
    end

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_attempts_must_be_positive)
    )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_attempts_must_be_non_negative,
             check: """
               attempt_count >= 0
             """
           )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_replays_must_be_non_negative,
             check: """
               replay_count >= 0
             """
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM platform_outbox_consumer_receipts LIMIT 1) OR
         EXISTS (
           SELECT 1
             FROM platform_outbox_deliveries
            WHERE replay_count > 0 OR attempt_count = 0
            LIMIT 1
         ) OR
         EXISTS (
           SELECT 1
             FROM platform_authority_audit_events
            WHERE action_name = 'platform.outbox.delivery.replay'
            LIMIT 1
         ) OR
         EXISTS (
           SELECT 1
             FROM platform_authority_action_idempotency
            WHERE action_name = 'platform.outbox.delivery.replay'
            LIMIT 1
         ) THEN
        RAISE EXCEPTION
          'cannot roll back outbox supervised consumption after receipt or replay evidence is retained';
      END IF;
    END
    $$
    """)

    drop_if_exists(
      constraint(
        :platform_outbox_deliveries,
        :platform_outbox_delivery_replays_must_be_non_negative
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_deliveries,
        :platform_outbox_delivery_attempts_must_be_non_negative
      )
    )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_attempts_must_be_positive,
             check: """
               attempt_count >= 1
             """
           )

    alter table(:platform_outbox_deliveries) do
      remove(:replay_count)
    end

    drop(
      constraint(
        :platform_outbox_consumer_receipts,
        "platform_outbox_consumer_receipts_delivery_tenant_fkey"
      )
    )

    drop_if_exists(
      index(:platform_outbox_consumer_receipts, [:tenant_id, :processed_at, :id],
        name: "platform_outbox_consumer_receipts_retention_index"
      )
    )

    drop_if_exists(
      index(:platform_outbox_consumer_receipts, [:event_id, :tenant_id, :consumer_key],
        name: "platform_outbox_consumer_receipts_event_consumer_index"
      )
    )

    drop_if_exists(
      index(:platform_outbox_consumer_receipts, [:id, :tenant_id],
        name: "platform_outbox_consumer_receipts_id_tenant_index"
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_digest_must_be_sha256
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_routing_version_must_be_positive
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_schema_version_must_be_positive
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_event_type_must_not_be_empty
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_handler_revision_must_be_positive
      )
    )

    drop_if_exists(
      constraint(
        :platform_outbox_consumer_receipts,
        :platform_outbox_receipt_consumer_must_be_stable
      )
    )

    drop(
      constraint(
        :platform_outbox_consumer_receipts,
        "platform_outbox_consumer_receipts_event_tenant_fkey"
      )
    )

    drop(table(:platform_outbox_consumer_receipts))
  end
end
