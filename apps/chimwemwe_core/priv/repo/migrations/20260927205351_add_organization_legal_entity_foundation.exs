defmodule Chimwemwe.Repo.Migrations.AddOrganizationLegalEntityFoundation do
  @moduledoc """
  Adds the minimal tenant-owned legal-entity and immutable profile history.

  AshPostgres generated the tables, indexes, checks, and compound reference.
  Manual review corrected the generated table order so the tenant-qualified
  destination exists before its foreign key, and added the immutable-identity
  and immutable-history guards required by ADR 0025 C25-01.
  """

  use Ecto.Migration

  def up do
    create table(:organization_legal_entities, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:status, :text, null: false, default: "active")
      add(:lock_version, :bigint, null: false, default: 1)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(:organization_legal_entities, :organization_legal_entities_status_allowed,
             check: """
               status IN ('active')
             """
           )

    create constraint(
             :organization_legal_entities,
             :organization_legal_entities_lock_version_positive,
             check: """
               lock_version >= 1
             """
           )

    create index(:organization_legal_entities, [:id, :tenant_id],
             name: "organization_legal_entities_id_tenant_index",
             unique: true
           )

    create index(:organization_legal_entities, [:tenant_id, :status, :id],
             name: "organization_legal_entities_status_index"
           )

    create table(:organization_legal_entity_profile_revisions, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)

      add(
        :legal_entity_id,
        references(:organization_legal_entities,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "organization_legal_entity_profiles_entity_tenant_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:revision_number, :bigint, null: false)
      add(:official_name, :text, null: false)
      add(:display_name, :text, null: false)
      add(:recorded_by_actor_id, :uuid, null: false)
      add(:recorded_at, :utc_datetime_usec, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create index(:organization_legal_entity_profile_revisions, [:id, :tenant_id],
             name: "organization_legal_entity_profiles_id_tenant_index",
             unique: true
           )

    create index(
             :organization_legal_entity_profile_revisions,
             [:tenant_id, :legal_entity_id, :revision_number],
             name: "organization_legal_entity_profiles_revision_index",
             unique: true
           )

    create constraint(
             :organization_legal_entity_profile_revisions,
             :organization_legal_entity_profiles_revision_positive,
             check: """
               revision_number >= 1
             """
           )

    create constraint(
             :organization_legal_entity_profile_revisions,
             :organization_legal_entity_profiles_official_name_length,
             check: """
               char_length(official_name) BETWEEN 1 AND 200
             """
           )

    create constraint(
             :organization_legal_entity_profile_revisions,
             :organization_legal_entity_profiles_display_name_length,
             check: """
               char_length(display_name) BETWEEN 1 AND 200
             """
           )

    execute("""
    CREATE FUNCTION organization_legal_reject_identity_change()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.id <> OLD.id OR NEW.tenant_id <> OLD.tenant_id THEN
        RAISE EXCEPTION USING
          ERRCODE = '23514',
          MESSAGE = 'legal entity identity and tenant are immutable';
      END IF;

      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER organization_legal_entities_identity_immutable
    BEFORE UPDATE OF id, tenant_id
    ON organization_legal_entities
    FOR EACH ROW
    EXECUTE FUNCTION organization_legal_reject_identity_change();
    """)

    execute("""
    CREATE FUNCTION organization_legal_reject_profile_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'legal entity profile revisions are immutable';
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER organization_legal_entity_profiles_immutable
    BEFORE UPDATE OR DELETE
    ON organization_legal_entity_profile_revisions
    FOR EACH ROW
    EXECUTE FUNCTION organization_legal_reject_profile_mutation();
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM organization_legal_entities)
         OR EXISTS (SELECT 1 FROM organization_legal_entity_profile_revisions)
         OR EXISTS (
           SELECT 1
           FROM platform_authority_audit_events
           WHERE action_name IN (
             'organization.legal.entity.register',
             'organization.legal.entity.profile.revise'
           )
         )
         OR EXISTS (
           SELECT 1
           FROM platform_outbox_events
           WHERE aggregate_type = 'organization.legal.entity'
         )
         OR EXISTS (
           SELECT 1
           FROM platform_authority_action_idempotency
           WHERE action_name IN (
             'organization.legal.entity.register',
             'organization.legal.entity.profile.revise'
           )
         )
      THEN
        RAISE EXCEPTION
          'organization.legal rollback requires empty entity, history, and durable evidence state';
      END IF;
    END
    $$;
    """)

    execute(
      "DROP TRIGGER IF EXISTS organization_legal_entity_profiles_immutable ON organization_legal_entity_profile_revisions"
    )

    execute("DROP FUNCTION IF EXISTS organization_legal_reject_profile_mutation()")

    execute(
      "DROP TRIGGER IF EXISTS organization_legal_entities_identity_immutable ON organization_legal_entities"
    )

    execute("DROP FUNCTION IF EXISTS organization_legal_reject_identity_change()")

    drop(table(:organization_legal_entity_profile_revisions))

    drop_if_exists(
      index(:organization_legal_entities, [:tenant_id, :status, :id],
        name: "organization_legal_entities_status_index"
      )
    )

    drop_if_exists(
      index(:organization_legal_entities, [:id, :tenant_id],
        name: "organization_legal_entities_id_tenant_index"
      )
    )

    drop_if_exists(
      constraint(:organization_legal_entities, :organization_legal_entities_lock_version_positive)
    )

    drop_if_exists(
      constraint(:organization_legal_entities, :organization_legal_entities_status_allowed)
    )

    drop(table(:organization_legal_entities))
  end
end
