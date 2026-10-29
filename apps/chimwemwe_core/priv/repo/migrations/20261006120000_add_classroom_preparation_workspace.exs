defmodule Chimwemwe.Repo.Migrations.AddClassroomPreparationWorkspace do
  @moduledoc """
  Adds the exact, session-bound workspace for the disabled local classroom
  preparation proof. This is an adapter scope, not a general class catalogue.
  """

  use Ecto.Migration

  def up do
    create table(:classroom_preparation_workspaces, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)

      add(
        :membership_id,
        references(:platform_tenant_memberships,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "classroom_preparation_membership_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :institutional_unit_id,
        references(:institutional_units,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "classroom_preparation_institution_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :calendar_id,
        references(:academic_calendars,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "classroom_preparation_calendar_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :academic_year_id,
        references(:academic_years,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "classroom_preparation_year_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(:calendar_revision, :text, null: false)

      add(
        :educator_participation_id,
        references(:people_participations,
          column: :id,
          with: [tenant_id: :tenant_id],
          match: :full,
          name: "classroom_preparation_educator_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        ),
        null: false
      )

      add(
        :class_id,
        references(:classroom_classes,
          column: :id,
          with: [tenant_id: :tenant_id],
          name: "classroom_preparation_class_fk",
          type: :uuid,
          prefix: "public",
          on_delete: :restrict
        )
      )

      add(:lock_version, :bigint, null: false, default: 1)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create constraint(:classroom_preparation_workspaces, :classroom_preparation_revision,
             check: "calendar_revision ~ '^[0-9a-f]{64}$'"
           )

    create constraint(:classroom_preparation_workspaces, :classroom_preparation_state,
             check:
               "(lock_version = 1 AND class_id IS NULL) OR (lock_version = 2 AND class_id IS NOT NULL)"
           )

    create index(:classroom_preparation_workspaces, [:id, :tenant_id],
             name: "classroom_preparation_id_tenant_idx",
             unique: true
           )

    create index(:classroom_preparation_workspaces, [:tenant_id, :actor_id, :membership_id],
             name: "classroom_preparation_actor_scope_idx",
             unique: true
           )

    execute("""
    CREATE FUNCTION classroom_preparation_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      member_actor uuid;
      staff_row people_participations%ROWTYPE;
      year_row academic_years%ROWTYPE;
      calendar_row academic_calendars%ROWTYPE;
      class_row classroom_classes%ROWTYPE;
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'classroom preparation scope is retained';
      END IF;

      IF TG_OP = 'UPDATE' AND (
        NEW.class_id IS NULL OR OLD.class_id IS NOT NULL OR NEW.lock_version <> 2 OR OLD.lock_version <> 1 OR
        (to_jsonb(NEW) - ARRAY['class_id','lock_version']) IS DISTINCT FROM
          (to_jsonb(OLD) - ARRAY['class_id','lock_version'])
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid classroom preparation transition';
      END IF;

      SELECT actor_id INTO STRICT member_actor
      FROM platform_tenant_memberships
      WHERE id = NEW.membership_id AND tenant_id = NEW.tenant_id
      FOR SHARE;

      IF member_actor <> NEW.actor_id THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'workspace membership actor mismatch';
      END IF;

      SELECT * INTO STRICT staff_row
      FROM people_participations
      WHERE id = NEW.educator_participation_id AND tenant_id = NEW.tenant_id
      FOR SHARE;

      IF staff_row.kind <> 'staff' OR staff_row.institutional_unit_id <> NEW.institutional_unit_id THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'workspace educator mismatch';
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM people_staff_account_associations account
        WHERE account.tenant_id = NEW.tenant_id
          AND account.participation_id = NEW.educator_participation_id
          AND account.membership_id = NEW.membership_id
          AND account.verification->>'actor_id' = NEW.actor_id::text
          AND account.revoked_at IS NULL
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'current staff account binding required';
      END IF;

      SELECT * INTO STRICT calendar_row
      FROM academic_calendars
      WHERE id = NEW.calendar_id AND tenant_id = NEW.tenant_id
      FOR SHARE;

      SELECT * INTO STRICT year_row
      FROM academic_years
      WHERE id = NEW.academic_year_id AND tenant_id = NEW.tenant_id
      FOR SHARE;

      IF calendar_row.institutional_unit_id <> NEW.institutional_unit_id OR calendar_row.status <> 'active'
        OR year_row.calendar_id <> NEW.calendar_id OR year_row.status <> 'published'
        OR year_row.candidate_revision <> NEW.calendar_revision
        OR NOT EXISTS (
          SELECT 1 FROM institutional_units unit
          WHERE unit.id = NEW.institutional_unit_id AND unit.tenant_id = NEW.tenant_id
            AND unit.status = 'published'
        ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'exact published calendar scope required';
      END IF;

      IF NEW.class_id IS NOT NULL THEN
        SELECT * INTO STRICT class_row
        FROM classroom_classes
        WHERE id = NEW.class_id AND tenant_id = NEW.tenant_id
        FOR SHARE;

        IF class_row.institutional_unit_id <> NEW.institutional_unit_id
          OR class_row.calendar_id <> NEW.calendar_id
          OR class_row.academic_year_id <> NEW.academic_year_id
          OR class_row.calendar_revision <> NEW.calendar_revision
          OR NOT EXISTS (
            SELECT 1 FROM classroom_teaching_assignments assignment
            WHERE assignment.tenant_id = NEW.tenant_id
              AND assignment.class_id = NEW.class_id
              AND assignment.participation_id = NEW.educator_participation_id
          ) THEN
          RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'prepared class binding mismatch';
        END IF;
      END IF;

      RETURN NEW;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'incomplete classroom preparation scope';
    END;
    $$;

    """)

    execute("""
    CREATE TRIGGER classroom_preparation_guard
      BEFORE INSERT OR UPDATE OR DELETE ON classroom_preparation_workspaces
      FOR EACH ROW EXECUTE FUNCTION classroom_preparation_guard()
    """)
  end

  def down do
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM classroom_preparation_workspaces) THEN
        RAISE EXCEPTION 'retained classroom preparation scope requires forward repair';
      END IF;
    END $$;
    """)

    execute("DROP TRIGGER classroom_preparation_guard ON classroom_preparation_workspaces")
    execute("DROP FUNCTION classroom_preparation_guard()")
    drop(table(:classroom_preparation_workspaces))
  end
end
