defmodule Chimwemwe.Repo.Migrations.TenantAuthorityFoundation do
  @moduledoc """
  Creates the first persistent, tenant-qualified authority graph.

  Ash generated the resource operations and snapshots. This reviewed artifact
  orders the tables and compound foreign keys explicitly so every referenced
  tenant-qualified index exists before its dependants.
  """

  use Ecto.Migration

  def change do
    create table(:platform_tenant_memberships, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:platform_tenant_memberships, [:id, :tenant_id],
             name: :platform_tenant_memberships_id_tenant_index
           )

    create unique_index(:platform_tenant_memberships, [:tenant_id, :actor_id],
             name: :platform_tenant_memberships_tenant_actor_index
           )

    create table(:platform_roles, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:name, :text, null: false)
      add(:lock_version, :bigint, null: false, default: 1)

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:platform_roles, :platform_role_name_must_not_be_empty,
             check: "char_length(name) BETWEEN 1 AND 120"
           )

    create constraint(:platform_roles, :platform_role_lock_version_must_be_positive,
             check: "lock_version >= 1"
           )

    create unique_index(:platform_roles, [:id, :tenant_id], name: :platform_roles_id_tenant_index)

    create unique_index(:platform_roles, [:tenant_id, :name],
             name: :platform_roles_tenant_name_index
           )

    create table(:platform_capabilities, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:key, :text, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:platform_capabilities, :platform_capability_key_must_be_stable,
             check: "octet_length(key) <= 120 AND key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'"
           )

    create unique_index(:platform_capabilities, [:id, :tenant_id],
             name: :platform_capabilities_id_tenant_index
           )

    create unique_index(:platform_capabilities, [:tenant_id, :key],
             name: :platform_capabilities_tenant_key_index
           )

    create table(:platform_actor_role_assignments, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :membership_id,
        references(:platform_tenant_memberships,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :actor_role_assignments_membership_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :role_id,
        references(:platform_roles,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :actor_role_assignments_role_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(
             :platform_actor_role_assignments,
             [:id, :tenant_id],
             name: :platform_actor_role_assignments_id_tenant_index
           )

    create unique_index(
             :platform_actor_role_assignments,
             [:tenant_id, :membership_id, :role_id],
             name: :platform_actor_role_assignments_unique_index
           )

    create index(:platform_actor_role_assignments, [:tenant_id, :role_id],
             name: :platform_actor_role_assignments_role_index
           )

    create table(:platform_role_capability_grants, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :role_id,
        references(:platform_roles,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :role_capability_grants_role_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :capability_id,
        references(:platform_capabilities,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :role_capability_grants_capability_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:platform_role_capability_grants, [:id, :tenant_id],
             name: :platform_role_capability_grants_id_tenant_index
           )

    create unique_index(
             :platform_role_capability_grants,
             [:tenant_id, :role_id, :capability_id],
             name: :platform_role_capability_grants_unique_index
           )

    create index(:platform_role_capability_grants, [:tenant_id, :capability_id],
             name: :platform_role_capability_grants_capability_index
           )

    create table(:platform_role_inclusions, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :role_id,
        references(:platform_roles,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :role_inclusions_role_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :included_role_id,
        references(:platform_roles,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: :role_inclusions_included_role_tenant_fkey,
          type: :uuid,
          on_delete: :restrict
        ),
        null: false
      )

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:platform_role_inclusions, :platform_role_cannot_include_itself,
             check: "role_id <> included_role_id"
           )

    create unique_index(:platform_role_inclusions, [:id, :tenant_id],
             name: :platform_role_inclusions_id_tenant_index
           )

    create unique_index(
             :platform_role_inclusions,
             [:tenant_id, :role_id, :included_role_id],
             name: :platform_role_inclusions_unique_index
           )

    create index(:platform_role_inclusions, [:tenant_id, :included_role_id],
             name: :platform_role_inclusions_included_role_index
           )

    execute(
      """
      CREATE FUNCTION enforce_platform_role_inclusion_acyclicity()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        PERFORM pg_advisory_xact_lock(
          hashtextextended('platform-role-inclusions:' || NEW.tenant_id::text, 0)
        );

        IF EXISTS (
          WITH RECURSIVE descendants(role_id) AS (
            SELECT NEW.included_role_id

            UNION

            SELECT inclusion.included_role_id
            FROM platform_role_inclusions AS inclusion
            JOIN descendants
              ON descendants.role_id = inclusion.role_id
            WHERE inclusion.tenant_id = NEW.tenant_id
              AND inclusion.id <> NEW.id
          )
          SELECT 1
          FROM descendants
          WHERE descendants.role_id = NEW.role_id
        ) THEN
          RAISE EXCEPTION USING
            ERRCODE = '23514',
            CONSTRAINT = 'platform_role_inclusions_acyclic',
            MESSAGE = 'role inclusion would create a cycle';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION enforce_platform_role_inclusion_acyclicity();"
    )

    execute(
      """
      CREATE TRIGGER platform_role_inclusions_enforce_acyclicity
      BEFORE INSERT OR UPDATE OF tenant_id, role_id, included_role_id
      ON platform_role_inclusions
      FOR EACH ROW
      EXECUTE FUNCTION enforce_platform_role_inclusion_acyclicity();
      """,
      "DROP TRIGGER platform_role_inclusions_enforce_acyclicity ON platform_role_inclusions;"
    )
  end
end
