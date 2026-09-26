defmodule Chimwemwe.Repo.Migrations.OutboxDeliveryLease do
  @moduledoc """
  Adds closed tenant-owned outbox delivery state for Slice 1J-A.

  AshPostgres generated the table, constraints, indexes, and tenant-qualified
  foreign key. This reviewed artifact refuses destructive rollback after any
  delivery attempt has been retained.
  """

  use Ecto.Migration

  def up do
    create table(:platform_outbox_deliveries, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :event_id,
        references(:platform_outbox_events,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "platform_outbox_deliveries_event_tenant_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:consumer_key, :text, null: false)
      add(:status, :text, null: false)
      add(:attempt_count, :bigint, null: false)
      add(:lock_version, :bigint, null: false)
      add(:lease_token, :uuid)
      add(:last_lease_token, :uuid, null: false)
      add(:lease_expires_at, :utc_datetime_usec)
      add(:available_at, :utc_datetime_usec, null: false)
      add(:failure_code, :text)
      add(:first_claimed_at, :utc_datetime_usec, null: false)
      add(:last_claimed_at, :utc_datetime_usec, null: false)
      add(:completed_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_consumer_must_be_stable,
             check: """
               consumer_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
             """
           )

    create constraint(:platform_outbox_deliveries, :platform_outbox_delivery_status_must_be_known,
             check: """
               status IN ('available', 'leased', 'completed', 'dead_letter')
             """
           )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_attempts_must_be_positive,
             check: """
               attempt_count >= 1
             """
           )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_version_must_be_positive,
             check: """
               lock_version >= 1
             """
           )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_failure_must_be_known,
             check: """
               failure_code IS NULL OR failure_code IN ('consumer_rejected', 'invalid_contract', 'retryable_dependency')
             """
           )

    create constraint(
             :platform_outbox_deliveries,
             :platform_outbox_delivery_state_must_be_consistent,
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

    create index(:platform_outbox_deliveries, [:id, :tenant_id],
             name: "platform_outbox_deliveries_id_tenant_index",
             unique: true
           )

    create index(:platform_outbox_deliveries, [:event_id, :tenant_id, :consumer_key],
             name: "platform_outbox_deliveries_event_consumer_index",
             unique: true
           )

    create index(
             :platform_outbox_deliveries,
             [:tenant_id, :consumer_key, :status, :available_at, :event_id],
             name: "platform_outbox_deliveries_dispatch_index"
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM platform_outbox_deliveries LIMIT 1) THEN
        RAISE EXCEPTION
          'cannot roll back outbox delivery lease state after a delivery attempt is retained';
      END IF;
    END
    $$
    """)

    drop_if_exists(
      index(
        :platform_outbox_deliveries,
        [:tenant_id, :consumer_key, :status, :available_at, :event_id],
        name: "platform_outbox_deliveries_dispatch_index"
      )
    )

    drop_if_exists(
      index(:platform_outbox_deliveries, [:event_id, :tenant_id, :consumer_key],
        name: "platform_outbox_deliveries_event_consumer_index"
      )
    )

    drop_if_exists(
      index(:platform_outbox_deliveries, [:id, :tenant_id],
        name: "platform_outbox_deliveries_id_tenant_index"
      )
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_state_must_be_consistent)
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_failure_must_be_known)
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_version_must_be_positive)
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_attempts_must_be_positive)
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_status_must_be_known)
    )

    drop_if_exists(
      constraint(:platform_outbox_deliveries, :platform_outbox_delivery_consumer_must_be_stable)
    )

    drop(constraint(:platform_outbox_deliveries, "platform_outbox_deliveries_event_tenant_fkey"))

    drop(table(:platform_outbox_deliveries))
  end
end
