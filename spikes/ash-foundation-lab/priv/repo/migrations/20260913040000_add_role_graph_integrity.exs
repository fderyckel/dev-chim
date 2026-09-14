defmodule AshFoundationLab.Repo.Migrations.AddRoleGraphIntegrity do
  use Ecto.Migration

  def change do
    alter table(:roles) do
      add :lock_version, :bigint, null: false, default: 1
    end

    create constraint(:roles, :role_lock_version_must_be_positive,
             check: "lock_version >= 1"
           )

    create table(:role_administration_events, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :role_administration_events_role_tenant_fkey
          ),
          null: false

      add :related_role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            on_delete: :restrict,
            name: :role_administration_events_related_role_tenant_fkey
          )

      add :actor_id,
          references(:actors,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :restrict,
            name: :role_administration_events_actor_tenant_fkey
          ),
          null: false

      add :action_reference, :uuid, null: false
      add :correlation_id, :uuid, null: false
      add :channel, :text, null: false
      add :event_type, :text, null: false
      add :classification, :text, null: false
      add :payload, :map, null: false
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:role_administration_events, [:id, :tenant_id])

    create unique_index(:role_administration_events, [
             :tenant_id,
             :action_reference,
             :channel
           ])

    create index(:role_administration_events, [:tenant_id, :inserted_at, :id])
    create index(:role_administration_events, [:tenant_id, :role_id])

    create constraint(:role_administration_events, :role_administration_channel_must_be_known,
             check: "channel IN ('audit', 'outbox')"
           )

    create constraint(
             :role_administration_events,
             :role_administration_event_type_must_be_known,
             check: "event_type IN ('role.renamed', 'role.inclusion_added')"
           )

    create constraint(
             :role_administration_events,
             :role_administration_classification_must_be_internal,
             check: "classification = 'internal'"
           )

    create constraint(:role_administration_events, :role_administration_payload_must_be_an_object,
             check: "jsonb_typeof(payload) = 'object'"
           )

    execute(
      """
      CREATE FUNCTION enforce_role_inclusion_acyclicity()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        PERFORM pg_advisory_xact_lock(
          hashtextextended('role-inclusions:' || NEW.tenant_id::text, 0)
        );

        IF EXISTS (
          WITH RECURSIVE descendants(role_id) AS (
            SELECT NEW.included_role_id

            UNION

            SELECT role_inclusions.included_role_id
            FROM public.role_inclusions
            JOIN descendants
              ON descendants.role_id = role_inclusions.role_id
            WHERE role_inclusions.tenant_id = NEW.tenant_id
              AND role_inclusions.id <> NEW.id
          )
          SELECT 1
          FROM descendants
          WHERE descendants.role_id = NEW.role_id
        ) THEN
          RAISE EXCEPTION USING
            ERRCODE = '23514',
            CONSTRAINT = 'role_inclusions_acyclic',
            MESSAGE = 'role inclusion would create a cycle';
        END IF;

        RETURN NEW;
      END;
      $$
      """,
      "DROP FUNCTION enforce_role_inclusion_acyclicity()"
    )

    execute(
      """
      CREATE TRIGGER role_inclusions_enforce_acyclicity
      BEFORE INSERT OR UPDATE OF tenant_id, role_id, included_role_id
      ON role_inclusions
      FOR EACH ROW
      EXECUTE FUNCTION enforce_role_inclusion_acyclicity()
      """,
      "DROP TRIGGER role_inclusions_enforce_acyclicity ON role_inclusions"
    )
  end
end
