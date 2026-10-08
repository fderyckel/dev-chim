defmodule Chimwemwe.Classroom.ClassRegister do
  @moduledoc "Private synthetic ClassRegister; only named classroom actions expose access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Classroom,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "classroom_classes"
    repo(Chimwemwe.Repo)

    custom_statements do
      statement :classroom_record_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up("""
        CREATE FUNCTION classroom_record_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
          yr academic_years%ROWTYPE;
          cal academic_calendars%ROWTYPE;
          cls classroom_classes%ROWTYPE;
          enr classroom_enrolments%ROWTYPE;
          part people_participations%ROWTYPE;
          local_day date;
        BEGIN
          IF current_setting('transaction_isolation') <> 'read committed' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'classroom writes require read committed isolation';
          END IF;
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'classroom history is retained';
          END IF;
          IF TG_TABLE_NAME = 'people_participations' THEN
            IF NEW.effective_until IS NOT NULL AND (
              EXISTS (SELECT 1 FROM classroom_enrolments WHERE tenant_id = NEW.tenant_id AND participation_id = NEW.id AND effective_until > NEW.effective_until)
              OR EXISTS (SELECT 1 FROM classroom_teaching_assignments WHERE tenant_id = NEW.tenant_id AND participation_id = NEW.id AND effective_until > NEW.effective_until)) THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'end dependent classroom intervals first';
            END IF;
            RETURN NEW;
          END IF;
          IF TG_OP = 'INSERT' AND NEW.lock_version <> 1 THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid initial classroom version';
          END IF;
          IF TG_TABLE_NAME = 'classroom_classes' THEN
            IF TG_OP = 'UPDATE' THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'class identity is immutable';
            END IF;
            SELECT * INTO yr FROM academic_years WHERE id = NEW.academic_year_id AND tenant_id = NEW.tenant_id FOR SHARE;
            SELECT * INTO cal FROM academic_calendars WHERE id = yr.calendar_id AND tenant_id = NEW.tenant_id FOR SHARE;
            IF yr.id IS NULL OR cal.id IS NULL OR yr.status <> 'published' OR cal.status <> 'active'
              OR NEW.calendar_revision <> yr.candidate_revision OR NEW.calendar_id <> cal.id
              OR NEW.institutional_unit_id <> cal.institutional_unit_id THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'exact published classroom year required';
            END IF;
          ELSE
            IF TG_TABLE_NAME IN ('classroom_enrolments', 'classroom_teaching_assignments') THEN
              SELECT * INTO part FROM people_participations WHERE tenant_id = NEW.tenant_id AND id = NEW.participation_id FOR UPDATE;
              IF part.id IS NULL OR NEW.effective_from < part.effective_from
                OR (part.effective_until IS NOT NULL AND NEW.effective_until > part.effective_until) THEN
                RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'classroom interval requires matching participation';
              END IF;
            END IF;
            IF TG_TABLE_NAME = 'classroom_enrolments' THEN
              SELECT * INTO yr FROM academic_years WHERE id = NEW.academic_year_id AND tenant_id = NEW.tenant_id FOR SHARE;
              SELECT * INTO cal FROM academic_calendars WHERE id = yr.calendar_id AND tenant_id = NEW.tenant_id FOR SHARE;
              IF part.kind <> 'student' OR yr.id IS NULL OR cal.id IS NULL OR yr.status <> 'published' OR cal.status <> 'active'
                OR NEW.calendar_revision <> yr.candidate_revision OR part.institutional_unit_id <> cal.institutional_unit_id THEN
                RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'student and published institution year required';
              END IF;
              IF TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM classroom_placements WHERE tenant_id = NEW.tenant_id AND enrolment_id = NEW.id AND effective_until > NEW.effective_until) THEN
                RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'end placements before enrolment';
              END IF;
            ELSE
              IF TG_TABLE_NAME = 'classroom_placements' THEN
                SELECT * INTO enr FROM classroom_enrolments WHERE tenant_id = NEW.tenant_id AND id = NEW.enrolment_id FOR UPDATE;
                IF enr.id IS NULL OR NEW.effective_from < enr.effective_from OR NEW.effective_until > enr.effective_until THEN
                  RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'placement requires effective enrolment';
                END IF;
              END IF;
              SELECT * INTO cls FROM classroom_classes WHERE tenant_id = NEW.tenant_id AND id = NEW.class_id FOR SHARE;
              SELECT * INTO yr FROM academic_years WHERE id = cls.academic_year_id AND tenant_id = NEW.tenant_id FOR SHARE;
              SELECT * INTO cal FROM academic_calendars WHERE id = yr.calendar_id AND tenant_id = NEW.tenant_id FOR SHARE;
              IF cls.id IS NULL OR yr.id IS NULL OR cal.id IS NULL OR yr.status <> 'published' OR cal.status <> 'active' OR cls.calendar_revision <> yr.candidate_revision
                OR cls.calendar_id <> cal.id OR cls.institutional_unit_id <> cal.institutional_unit_id THEN
                RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'matching class publication required';
              END IF;
              IF TG_TABLE_NAME = 'classroom_teaching_assignments' THEN
                IF part.kind <> 'staff' OR part.institutional_unit_id <> cls.institutional_unit_id OR EXISTS (
                  SELECT 1 FROM classroom_teaching_assignments WHERE tenant_id = NEW.tenant_id AND participation_id = NEW.participation_id AND class_id = NEW.class_id AND id <> NEW.id
                    AND effective_from < NEW.effective_until AND NEW.effective_from < effective_until) THEN
                  RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid or overlapping teaching assignment';
                END IF;
              ELSIF enr.academic_year_id <> cls.academic_year_id OR enr.calendar_revision <> cls.calendar_revision OR EXISTS (
                SELECT 1 FROM classroom_placements WHERE tenant_id = NEW.tenant_id AND enrolment_id = NEW.enrolment_id AND id <> NEW.id
                  AND effective_from < NEW.effective_until AND NEW.effective_from < effective_until) THEN
                RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid or overlapping class placement';
              END IF;
            END IF;
            IF NEW.effective_from < yr.start_on OR NEW.effective_until > yr.end_on + 1 THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'classroom interval outside year';
            END IF;
            local_day := (statement_timestamp() AT TIME ZONE yr.time_zone)::date;
            IF TG_OP = 'UPDATE' AND (
              (to_jsonb(NEW) - ARRAY['effective_until','lock_version']) IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['effective_until','lock_version'])
              OR OLD.lock_version <> 1 OR NEW.lock_version <> 2
              OR NEW.effective_until >= OLD.effective_until OR NEW.effective_until < local_day) THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid classroom ending';
            END IF;
          END IF;
          PERFORM 1 FROM institutional_units WHERE id = cal.institutional_unit_id AND tenant_id = NEW.tenant_id AND status = 'published' FOR SHARE;
          IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'published institution required';
          END IF;
          RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION classroom_record_guard();")
      end

      statement :classroom_classes_classroom_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up(
          "CREATE TRIGGER classroom_classes_classroom_guard BEFORE INSERT OR UPDATE OR DELETE ON classroom_classes FOR EACH ROW EXECUTE FUNCTION classroom_record_guard();"
        )

        down("DROP TRIGGER classroom_classes_classroom_guard ON classroom_classes;")
      end

      statement :classroom_enrolments_classroom_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up(
          "CREATE TRIGGER classroom_enrolments_classroom_guard BEFORE INSERT OR UPDATE OR DELETE ON classroom_enrolments FOR EACH ROW EXECUTE FUNCTION classroom_record_guard();"
        )

        down("DROP TRIGGER classroom_enrolments_classroom_guard ON classroom_enrolments;")
      end

      statement :classroom_teaching_assignments_classroom_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up(
          "CREATE TRIGGER classroom_teaching_assignments_classroom_guard BEFORE INSERT OR UPDATE OR DELETE ON classroom_teaching_assignments FOR EACH ROW EXECUTE FUNCTION classroom_record_guard();"
        )

        down(
          "DROP TRIGGER classroom_teaching_assignments_classroom_guard ON classroom_teaching_assignments;"
        )
      end

      statement :classroom_placements_classroom_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up(
          "CREATE TRIGGER classroom_placements_classroom_guard BEFORE INSERT OR UPDATE OR DELETE ON classroom_placements FOR EACH ROW EXECUTE FUNCTION classroom_record_guard();"
        )

        down("DROP TRIGGER classroom_placements_classroom_guard ON classroom_placements;")
      end

      statement :people_participations_classroom_guard do
        global? true

        after_tables([
          "classroom_classes",
          "classroom_enrolments",
          "classroom_teaching_assignments",
          "classroom_placements"
        ])

        up(
          "CREATE TRIGGER people_participations_classroom_guard BEFORE UPDATE OF effective_until ON people_participations FOR EACH ROW EXECUTE FUNCTION classroom_record_guard();"
        )

        down("DROP TRIGGER people_participations_classroom_guard ON people_participations;")
      end
    end

    custom_indexes do
      index([:id, :tenant_id],
        name: "classroom_classes_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :academic_year_id, :code],
        name: "classroom_classes_scope_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:institutional_unit,
        name: "classroom_classes_institutional_unit_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:calendar,
        name: "classroom_classes_calendar_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:academic_year,
        name: "classroom_classes_academic_year_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:lock_version, "classroom_classes_version", check: "lock_version = 1")
      check_constraint(:code, "classroom_classes_code", check: "code ~ '^[a-z][a-z0-9_]{0,79}$'")

      check_constraint(:label, "classroom_classes_label",
        check: "char_length(btrim(label)) BETWEEN 1 AND 160"
      )

      check_constraint(:calendar_revision, "classroom_classes_revision",
        check: "calendar_revision ~ '^[0-9a-f]{64}$'"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :institutional_unit, Chimwemwe.InstitutionalStructure.InstitutionalUnit do
      source_attribute :institutional_unit_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :calendar, Chimwemwe.AcademicCalendar.Calendar do
      source_attribute :calendar_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :academic_year, Chimwemwe.AcademicCalendar.AcademicYear do
      source_attribute :academic_year_id
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

    attribute :institutional_unit_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :calendar_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :academic_year_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :calendar_revision, :string do
      allow_nil? false
      public? false
    end

    attribute :code, :string do
      allow_nil? false
      public? false
    end

    attribute :label, :string do
      allow_nil? false
      public? false
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
