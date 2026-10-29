defmodule Chimwemwe.AcademicCalendar.CalendarClosure do
  @moduledoc "One immutable named closure within an academic-year definition."

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.AcademicCalendar,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "academic_calendar_closures"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "academic_calendar_closures_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :academic_year_id, :date],
        name: "academic_calendar_closures_year_date_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:academic_year,
        name: "academic_calendar_closures_year_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:reason_key, "academic_calendar_closures_reason_key",
        check: "reason_key ~ '^[a-z][a-z0-9_]{0,79}$'"
      )

      check_constraint(:label, "academic_calendar_closures_label",
        check: "char_length(btrim(label)) BETWEEN 1 AND 160"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
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

    attribute :academic_year_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :date, :date do
      allow_nil? false
      public? false
    end

    attribute :reason_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :label, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160, trim?: true
    end

    create_timestamp :inserted_at
  end
end
