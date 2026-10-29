defmodule Chimwemwe.Classroom.AttendanceExposure do
  @moduledoc "Private attendance storage; access only through named session-bound actions."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Classroom,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "classroom_attendance_exposures"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:tenant_id, :actor_id, :day],
        unique: true,
        all_tenants?: true,
        name: "classroom_attendance_exposure_day_idx"
      )
    end

    check_constraints do
      check_constraint(:class_ids, "classroom_attendance_class_budget",
        check: "cardinality(class_ids) <= 12"
      )

      check_constraint(:person_ids, "classroom_attendance_person_budget",
        check: "cardinality(person_ids) <= 720"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
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

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :day, :date do
      allow_nil? false
      public? false
    end

    attribute :class_ids, {:array, :uuid} do
      allow_nil? false
      public? false
    end

    attribute :person_ids, {:array, :uuid} do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
