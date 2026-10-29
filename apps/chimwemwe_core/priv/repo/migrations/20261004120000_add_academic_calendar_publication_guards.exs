defmodule Chimwemwe.Repo.Migrations.AddAcademicCalendarPublicationGuards do
  @moduledoc "Database invariants for the private CF-2B calendar publication writer."

  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    execute("""
    ALTER TABLE academic_years
    ADD CONSTRAINT academic_years_published_dates_exclusion
    EXCLUDE USING gist (
      tenant_id WITH =,
      calendar_id WITH =,
      daterange(start_on, end_on, '[]') WITH &&
    ) WHERE (status = 'published')
    """)

    execute("""
    CREATE FUNCTION academic_calendar_identity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'academic calendar deletion forbidden';
      END IF;

      IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'academic calendar identity is immutable';
      END IF;

      IF NEW.status <> 'active' OR NEW.lock_version <> 1 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid initial academic calendar';
      END IF;

      PERFORM 1
      FROM institutional_units u
      JOIN institution_publications p
        ON p.tenant_id = u.tenant_id AND p.institutional_unit_id = u.id
      JOIN institution_initial_operator_assignments a
        ON a.tenant_id = p.tenant_id AND a.id = p.operator_assignment_id
       AND a.institutional_unit_id = p.institutional_unit_id
      WHERE u.tenant_id = NEW.tenant_id AND u.id = NEW.institutional_unit_id
        AND u.classification = 'institution' AND u.status = 'published'
      FOR SHARE OF u, p, a;

      IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'calendar owner is not eligible';
      END IF;

      RETURN NEW;
    END $$;
    """)

    execute("""
    CREATE FUNCTION academic_year_lifecycle_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      weekday_count integer;
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'academic year deletion forbidden';
      END IF;

      SELECT count(DISTINCT weekday) INTO weekday_count
      FROM unnest(NEW.instructional_weekdays) AS weekday;

      IF weekday_count <> cardinality(NEW.instructional_weekdays)
         OR NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.time_zone) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid academic year definition';
      END IF;

      IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'draft' OR NEW.lock_version <> 1 THEN
          RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid initial academic year';
        END IF;

        RETURN NEW;
      END IF;

      IF ROW(NEW.id, NEW.tenant_id, NEW.calendar_id, NEW.inserted_at)
         IS DISTINCT FROM ROW(OLD.id, OLD.tenant_id, OLD.calendar_id, OLD.inserted_at)
         OR OLD.status <> 'draft'
         OR NEW.lock_version <> OLD.lock_version + 1 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid academic year transition';
      END IF;

      IF NEW.status = 'published' THEN
        IF ROW(NEW.code, NEW.label, NEW.start_on, NEW.end_on, NEW.time_zone,
               NEW.instructional_weekdays, NEW.candidate_revision)
           IS DISTINCT FROM
           ROW(OLD.code, OLD.label, OLD.start_on, OLD.end_on, OLD.time_zone,
               OLD.instructional_weekdays, OLD.candidate_revision) THEN
          RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'publication cannot rewrite definition';
        END IF;

        IF EXISTS (
          SELECT 1 FROM academic_years other
          WHERE other.tenant_id = NEW.tenant_id
            AND other.calendar_id = NEW.calendar_id
            AND other.id <> NEW.id
            AND other.status = 'published'
            AND daterange(other.start_on, other.end_on, '[]') &&
                daterange(NEW.start_on, NEW.end_on, '[]')
        ) THEN
          RAISE EXCEPTION USING ERRCODE = '23P01', MESSAGE = 'published academic years overlap';
        END IF;
      ELSIF NEW.status <> 'draft' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid academic year state';
      END IF;

      RETURN NEW;
    END $$;
    """)

    execute("""
    CREATE FUNCTION academic_year_child_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      parent academic_years%ROWTYPE;
      child_year_id uuid;
      child_tenant_id uuid;
    BEGIN
      IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'calendar definition children are replace-only';
      END IF;

      IF TG_OP = 'DELETE' THEN
        child_year_id := OLD.academic_year_id;
        child_tenant_id := OLD.tenant_id;
      ELSE
        child_year_id := NEW.academic_year_id;
        child_tenant_id := NEW.tenant_id;
      END IF;

      SELECT * INTO STRICT parent
      FROM academic_years
      WHERE id = child_year_id AND tenant_id = child_tenant_id
      FOR SHARE;

      IF parent.status <> 'draft' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'published calendar definition is immutable';
      END IF;

      IF TG_OP = 'INSERT' THEN
        IF TG_TABLE_NAME = 'academic_periods' THEN
          IF NEW.start_on < parent.start_on OR NEW.end_on > parent.end_on OR EXISTS (
            SELECT 1 FROM academic_periods other
            WHERE other.tenant_id = NEW.tenant_id
              AND other.academic_year_id = NEW.academic_year_id
              AND other.id <> NEW.id
              AND daterange(other.start_on, other.end_on, '[]') &&
                  daterange(NEW.start_on, NEW.end_on, '[]')
          ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid academic period';
          END IF;
        ELSIF TG_TABLE_NAME = 'academic_calendar_closures' THEN
          IF NEW.date < parent.start_on OR NEW.date > parent.end_on THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid academic closure';
          END IF;
        END IF;
      END IF;

      IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
    END $$;
    """)

    execute("""
    CREATE FUNCTION academic_calendar_evidence_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      v_action_name text;
      v_aggregate_type text;
      v_aggregate_id uuid;
      v_expected_before bigint;
      v_expected_after bigint;
    BEGIN
      v_aggregate_id := NEW.id;
      v_expected_after := NEW.lock_version;

      IF TG_TABLE_NAME = 'academic_calendars' THEN
        v_action_name := 'academics.calendar.register_academic_calendar';
        v_aggregate_type := 'academics.calendar.calendar';
        v_expected_before := 0;
      ELSIF TG_OP = 'INSERT' THEN
        v_action_name := 'academics.calendar.define_draft_academic_year';
        v_aggregate_type := 'academics.calendar.academic_year';
        v_expected_before := 0;
      ELSIF NEW.status = 'published' THEN
        v_action_name := 'academics.calendar.publish_academic_year';
        v_aggregate_type := 'academics.calendar.academic_year';
        v_expected_before := OLD.lock_version;
      ELSE
        v_action_name := 'academics.calendar.replace_draft_calendar_definition';
        v_aggregate_type := 'academics.calendar.academic_year';
        v_expected_before := OLD.lock_version;
      END IF;

      IF NOT EXISTS (
        SELECT 1
        FROM platform_authority_audit_events audit
        JOIN platform_outbox_events event
          ON event.tenant_id = audit.tenant_id
         AND event.audit_reference = audit.id
         AND event.aggregate_type = v_aggregate_type
         AND event.aggregate_id = v_aggregate_id
         AND event.event_type = v_action_name || '.completed'
        JOIN platform_authority_action_idempotency idem
          ON idem.tenant_id = audit.tenant_id
         AND idem.action_name = v_action_name
         AND idem.idempotency_key = audit.idempotency_key
         AND idem.aggregate_id = v_aggregate_id
         AND idem.audit_reference = audit.id
         AND idem.event_id = event.id
         AND idem.status = 'completed'
        WHERE audit.tenant_id = NEW.tenant_id
          AND audit.action_name = v_action_name
          AND audit.aggregate_type = v_aggregate_type
          AND audit.aggregate_id = v_aggregate_id
          AND audit.before_version = v_expected_before
          AND audit.after_version = v_expected_after
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'calendar transition lacks atomic evidence';
      END IF;

      IF TG_TABLE_NAME = 'academic_years' AND NOT EXISTS (
        SELECT 1 FROM academic_periods period
        WHERE period.tenant_id = NEW.tenant_id AND period.academic_year_id = NEW.id
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'academic year needs a primary period';
      END IF;

      RETURN NEW;
    END $$;
    """)

    execute("""
    CREATE TRIGGER academic_calendar_identity_before
    BEFORE INSERT OR UPDATE OR DELETE ON academic_calendars
    FOR EACH ROW EXECUTE FUNCTION academic_calendar_identity_guard();
    """)

    execute("""
    CREATE TRIGGER academic_year_lifecycle_before
    BEFORE INSERT OR UPDATE OR DELETE ON academic_years
    FOR EACH ROW EXECUTE FUNCTION academic_year_lifecycle_guard();
    """)

    execute("""
    CREATE TRIGGER academic_period_guard_before
    BEFORE INSERT OR UPDATE OR DELETE ON academic_periods
    FOR EACH ROW EXECUTE FUNCTION academic_year_child_guard();
    """)

    execute("""
    CREATE TRIGGER academic_closure_guard_before
    BEFORE INSERT OR UPDATE OR DELETE ON academic_calendar_closures
    FOR EACH ROW EXECUTE FUNCTION academic_year_child_guard();
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER academic_calendar_evidence_after
    AFTER INSERT OR UPDATE ON academic_calendars
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION academic_calendar_evidence_guard();
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER academic_year_evidence_after
    AFTER INSERT OR UPDATE ON academic_years
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION academic_calendar_evidence_guard();
    """)
  end

  def down do
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM academic_calendars)
         OR EXISTS (
           SELECT 1 FROM platform_authority_audit_events
           WHERE action_name LIKE 'academics.calendar.%'
         )
         OR EXISTS (
           SELECT 1 FROM platform_outbox_events
           WHERE aggregate_type LIKE 'academics.calendar.%'
         )
         OR EXISTS (
           SELECT 1 FROM platform_authority_action_idempotency
           WHERE action_name LIKE 'academics.calendar.%'
         ) THEN
        RAISE EXCEPTION 'retained academic calendar authority cannot be rolled back';
      END IF;
    END $$;
    """)

    execute("DROP TRIGGER academic_year_evidence_after ON academic_years")
    execute("DROP TRIGGER academic_calendar_evidence_after ON academic_calendars")
    execute("DROP TRIGGER academic_closure_guard_before ON academic_calendar_closures")
    execute("DROP TRIGGER academic_period_guard_before ON academic_periods")
    execute("DROP TRIGGER academic_year_lifecycle_before ON academic_years")
    execute("DROP TRIGGER academic_calendar_identity_before ON academic_calendars")
    execute("DROP FUNCTION academic_calendar_evidence_guard()")
    execute("DROP FUNCTION academic_year_child_guard()")
    execute("DROP FUNCTION academic_year_lifecycle_guard()")
    execute("DROP FUNCTION academic_calendar_identity_guard()")
    execute("ALTER TABLE academic_years DROP CONSTRAINT academic_years_published_dates_exclusion")
  end
end
