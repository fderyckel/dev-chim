defmodule Chimwemwe.Repo.Migrations.ModuleLifecycleActivation do
  @moduledoc """
  Creates the first production module-lifecycle gate state.

  Ash generated the resource operations and snapshots. This reviewed artifact
  creates the tenant-qualified entitlement destination and supporting index
  before the activation table and its compound foreign key.
  """

  use Ecto.Migration

  def up do
    create table(:platform_module_entitlements, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:module_key, :text, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(
             :platform_module_entitlements,
             :platform_module_entitlement_key_must_be_valid,
             check: """
               char_length(module_key) BETWEEN 3 AND 120 AND module_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'
             """
           )

    create index(:platform_module_entitlements, [:id, :tenant_id],
             name: "platform_module_entitlements_id_tenant_index",
             unique: true
           )

    create index(:platform_module_entitlements, [:tenant_id, :module_key],
             name: "platform_module_entitlements_tenant_module_index",
             unique: true
           )

    create table(:platform_module_activations, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :entitlement_id,
        references(:platform_module_entitlements,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "platform_module_activations_entitlement_tenant_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:module_version, :text, null: false)
      add(:state, :text, null: false)
      add(:lock_version, :bigint, null: false)
      add(:activated_at, :utc_datetime_usec, null: false)

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
             :platform_module_activations,
             :platform_module_activation_version_must_be_valid,
             check: """
               char_length(module_version) BETWEEN 5 AND 80 AND module_version ~ '^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$'
             """
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_state_must_be_active,
             check: """
               state = 'active'
             """
           )

    create constraint(
             :platform_module_activations,
             :platform_module_activation_lock_version_must_be_positive,
             check: """
               lock_version >= 1
             """
           )

    create index(:platform_module_activations, [:id, :tenant_id],
             name: "platform_module_activations_id_tenant_index",
             unique: true
           )

    create index(:platform_module_activations, [:tenant_id, :entitlement_id],
             name: "platform_module_activations_entitlement_index",
             unique: true
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM platform_module_activations)
         OR EXISTS (SELECT 1 FROM platform_module_entitlements)
         OR EXISTS (
           SELECT 1
           FROM platform_authority_audit_events
           WHERE action_name = 'platform.module_lifecycle.activate'
         )
         OR EXISTS (
           SELECT 1
           FROM platform_outbox_events
           WHERE event_type = 'platform.module.activated'
         )
         OR EXISTS (
           SELECT 1
           FROM platform_authority_action_idempotency
           WHERE action_name = 'platform.module_lifecycle.activate'
         )
      THEN
        RAISE EXCEPTION
          'module lifecycle rollback requires empty activation, entitlement, and durable evidence state';
      END IF;
    END
    $$;
    """)

    drop_if_exists(
      index(:platform_module_activations, [:tenant_id, :entitlement_id],
        name: "platform_module_activations_entitlement_index"
      )
    )

    drop_if_exists(
      index(:platform_module_activations, [:id, :tenant_id],
        name: "platform_module_activations_id_tenant_index"
      )
    )

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_lock_version_must_be_positive
      )
    )

    drop_if_exists(
      constraint(:platform_module_activations, :platform_module_activation_state_must_be_active)
    )

    drop_if_exists(
      constraint(
        :platform_module_activations,
        :platform_module_activation_version_must_be_valid
      )
    )

    drop(table(:platform_module_activations))

    drop_if_exists(
      index(:platform_module_entitlements, [:tenant_id, :module_key],
        name: "platform_module_entitlements_tenant_module_index"
      )
    )

    drop_if_exists(
      index(:platform_module_entitlements, [:id, :tenant_id],
        name: "platform_module_entitlements_id_tenant_index"
      )
    )

    drop_if_exists(
      constraint(:platform_module_entitlements, :platform_module_entitlement_key_must_be_valid)
    )

    drop(table(:platform_module_entitlements))
  end
end
