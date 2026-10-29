defmodule Chimwemwe.Classroom.AttendanceCorrection do
  @moduledoc "Append-only attendance correction storage; access only through ADR 0041 actions."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Classroom,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table("classroom_attendance_corrections")
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "classroom_attendance_corrections_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :submission_id],
        name: "classroom_attendance_corrections_submission_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :submission_id, :correction_number],
        name: "classroom_attendance_correction_number_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :submission_id, :recorded_at, :id],
        name: "classroom_attendance_correction_history_idx",
        all_tenants?: true
      )
    end

    references do
      reference(:submission,
        name: "classroom_attendance_correction_submission_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:previous_correction,
        name: "classroom_attendance_correction_predecessor_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(
        [:correction_number, :previous_correction_id],
        "classroom_attendance_correction_predecessor_shape",
        check: """
        (correction_number = 1 AND previous_correction_id IS NULL) OR
        (correction_number BETWEEN 2 AND 10 AND previous_correction_id IS NOT NULL)
        """
      )

      check_constraint(:reason_code, "classroom_attendance_correction_reason",
        check: "reason_code = 'marking_error'"
      )

      check_constraint(:marks, "classroom_attendance_correction_marks",
        check: "jsonb_typeof(marks) = 'object'"
      )
    end

    custom_statements do
      statement :attendance_correction_guard_function do
        global?(true)
        after_tables(["classroom_attendance_corrections"])

        up("""
        CREATE FUNCTION guard_classroom_attendance_correction()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'classroom_attendance_correction_delete_forbidden',
              MESSAGE = 'attendance correction deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'classroom_attendance_correction_immutable',
              MESSAGE = 'attendance corrections are immutable';
          END IF;

          PERFORM pg_advisory_xact_lock(
            hashtextextended(
              'classroom-attendance-correction:' ||
                NEW.tenant_id::text || ':' || NEW.submission_id::text,
              0
            )
          );

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NEW.correction_number = 1 THEN
            IF EXISTS (
              SELECT 1 FROM classroom_attendance_corrections
              WHERE tenant_id = NEW.tenant_id AND submission_id = NEW.submission_id
            ) THEN
              RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'classroom_attendance_correction_chain',
                MESSAGE = 'attendance correction baseline already exists';
            END IF;
          ELSIF NOT EXISTS (
            SELECT 1 FROM classroom_attendance_corrections
            WHERE id = NEW.previous_correction_id
              AND tenant_id = NEW.tenant_id
              AND submission_id = NEW.submission_id
              AND correction_number = NEW.correction_number - 1
          ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'classroom_attendance_correction_chain',
              MESSAGE = 'attendance correction predecessor is not consecutive';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_classroom_attendance_correction();")
      end

      statement :attendance_correction_guard_trigger do
        global?(true)
        after_tables(["classroom_attendance_corrections"])

        up("""
        CREATE TRIGGER classroom_attendance_correction_guard
        BEFORE INSERT OR UPDATE OR DELETE ON classroom_attendance_corrections
        FOR EACH ROW EXECUTE FUNCTION guard_classroom_attendance_correction();
        """)

        down(
          "DROP TRIGGER classroom_attendance_correction_guard ON classroom_attendance_corrections;"
        )
      end
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:tenant_id)
    global?(false)
  end

  relationships do
    belongs_to :submission, Chimwemwe.Classroom.AttendanceSubmission do
      source_attribute(:submission_id)
      destination_attribute(:id)
      define_attribute?(false)
      public?(false)
    end

    belongs_to :previous_correction, __MODULE__ do
      source_attribute(:previous_correction_id)
      destination_attribute(:id)
      define_attribute?(false)
      public?(false)
    end
  end

  actions do
  end

  policies do
    policy always() do
      forbid_if(always())
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :tenant_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :submission_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :previous_correction_id, :uuid do
      allow_nil?(true)
      public?(false)
    end

    attribute :correction_number, :integer do
      allow_nil?(false)
      public?(false)
      constraints(min: 1, max: 10)
    end

    attribute :reason_code, :string do
      allow_nil?(false)
      public?(false)
      constraints(min_length: 1, max_length: 80)
    end

    attribute :marks, :map do
      allow_nil?(false)
      public?(false)
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(false)
    end
  end
end
