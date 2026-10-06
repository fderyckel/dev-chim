defmodule Chimwemwe.Classroom.AttendanceSubmission do
  @moduledoc "Private attendance storage; access only through named session-bound actions."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Classroom,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "classroom_attendance_submissions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:tenant_id, :class_id, :local_date],
        unique: true,
        all_tenants?: true,
        name: "classroom_attendance_day_idx"
      )
    end

    references do
      reference(:class_register, on_delete: :restrict, match_tenant?: true, match_type: :full)
    end

    check_constraints do
      check_constraint(:roster_basis, "classroom_attendance_basis",
        check: "roster_basis ~ '^[0-9a-f]{64}$'"
      )

      check_constraint(:calendar_revision, "classroom_attendance_revision",
        check: "calendar_revision ~ '^[0-9a-f]{64}$'"
      )

      check_constraint(:roster, "classroom_attendance_roster",
        check:
          "jsonb_typeof(roster->'students') = 'array' AND jsonb_array_length(roster->'students') BETWEEN 1 AND 60"
      )

      check_constraint(:marks, "classroom_attendance_marks",
        check: "jsonb_typeof(marks) = 'object'"
      )
    end

    custom_statements do
      statement :attendance_immutable do
        global? true
        after_tables(["classroom_attendance_submissions"])

        up("""
        DO $migration$ BEGIN
        CREATE FUNCTION classroom_attendance_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'attendance is retained and immutable';
        END $$;
        CREATE TRIGGER classroom_attendance_immutable BEFORE UPDATE OR DELETE ON classroom_attendance_submissions
          FOR EACH ROW EXECUTE FUNCTION classroom_attendance_immutable();
        END $migration$;
        """)

        down(
          "DO $migration$ BEGIN DROP TRIGGER classroom_attendance_immutable ON classroom_attendance_submissions; DROP FUNCTION classroom_attendance_immutable(); END $migration$;"
        )
      end
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :class_register, Chimwemwe.Classroom.ClassRegister do
      source_attribute :class_id
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

    attribute :class_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :local_date, :date do
      allow_nil? false
      public? false
    end

    attribute :calendar_revision, :string do
      allow_nil? false
      public? false
    end

    attribute :roster_basis, :string do
      allow_nil? false
      public? false
    end

    attribute :roster, :map do
      allow_nil? false
      public? false
    end

    attribute :marks, :map do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
