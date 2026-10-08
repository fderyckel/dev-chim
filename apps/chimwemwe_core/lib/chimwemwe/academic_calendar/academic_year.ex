defmodule Chimwemwe.AcademicCalendar.AcademicYear do
  @moduledoc """
  One complete immutable-first draft definition under an exact calendar.

  The first persistent increment writes the definition once as `draft`. A later named publication
  action may transition it to `published`; no generic resource action can mutate either state.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.AcademicCalendar,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "academic_years"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "academic_years_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :calendar_id],
        name: "academic_years_identity_calendar_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :calendar_id, :code],
        name: "academic_years_calendar_code_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:calendar,
        name: "academic_years_calendar_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:code, "academic_years_code", check: "code ~ '^[a-z][a-z0-9_]{0,79}$'")

      check_constraint(:label, "academic_years_label",
        check: "char_length(btrim(label)) BETWEEN 1 AND 160"
      )

      check_constraint(:start_on, "academic_years_date_range",
        check: "end_on >= start_on AND (end_on - start_on) < 731"
      )

      check_constraint(:time_zone, "academic_years_time_zone",
        check: "char_length(time_zone) BETWEEN 3 AND 80"
      )

      check_constraint(:instructional_weekdays, "academic_years_instructional_weekdays",
        check: "cardinality(instructional_weekdays) BETWEEN 1 AND 7"
      )

      check_constraint(:candidate_revision, "academic_years_candidate_revision",
        check: "candidate_revision ~ '^[0-9a-f]{64}$'"
      )

      check_constraint(:status, "academic_years_status",
        check: "status IN ('draft', 'published')"
      )

      check_constraint(:lock_version, "academic_years_lock_version", check: "lock_version >= 1")
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :calendar, Chimwemwe.AcademicCalendar.Calendar do
      source_attribute :calendar_id
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

    attribute :calendar_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :code, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :label, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160, trim?: true
    end

    attribute :start_on, :date do
      allow_nil? false
      public? false
    end

    attribute :end_on, :date do
      allow_nil? false
      public? false
    end

    attribute :time_zone, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 80
    end

    attribute :instructional_weekdays, {:array, :integer} do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 7, items: [min: 1, max: 7]
    end

    attribute :candidate_revision, :string do
      allow_nil? false
      public? false
      constraints min_length: 64, max_length: 64, match: ~r/^[0-9a-f]{64}$/
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :draft
      constraints one_of: [:draft, :published]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
