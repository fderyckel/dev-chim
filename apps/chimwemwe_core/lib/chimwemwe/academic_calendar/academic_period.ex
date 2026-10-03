defmodule Chimwemwe.AcademicCalendar.AcademicPeriod do
  @moduledoc "One immutable primary instructional period in an academic-year definition."

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.AcademicCalendar,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "academic_periods"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "academic_periods_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :academic_year_id, :sequence],
        name: "academic_periods_year_sequence_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :academic_year_id, :start_on, :end_on],
        name: "academic_periods_year_dates_idx",
        all_tenants?: true
      )
    end

    references do
      reference(:academic_year,
        name: "academic_periods_year_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:period_type_key, "academic_periods_type_key",
        check: "period_type_key ~ '^[a-z][a-z0-9_]{0,79}$'"
      )

      check_constraint(:label, "academic_periods_label",
        check: "char_length(btrim(label)) BETWEEN 1 AND 160"
      )

      check_constraint(:sequence, "academic_periods_sequence", check: "sequence >= 1")

      check_constraint(:start_on, "academic_periods_date_range", check: "end_on >= start_on")
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

    attribute :period_type_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :label, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160, trim?: true
    end

    attribute :sequence, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :start_on, :date do
      allow_nil? false
      public? false
    end

    attribute :end_on, :date do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
