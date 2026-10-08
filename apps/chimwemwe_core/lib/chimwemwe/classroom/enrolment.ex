defmodule Chimwemwe.Classroom.Enrolment do
  @moduledoc "Private synthetic Enrolment; only named classroom actions expose access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Classroom,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "classroom_enrolments"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "classroom_enrolments_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :participation_id, :academic_year_id],
        name: "classroom_enrolments_scope_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:participation,
        name: "classroom_enrolments_participation_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:academic_year,
        name: "classroom_enrolments_academic_year_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:lock_version, "classroom_enrolments_version",
        check: "lock_version IN (1, 2)"
      )

      check_constraint(:effective_until, "classroom_enrolments_interval",
        check: "effective_until > effective_from"
      )

      check_constraint(:calendar_revision, "classroom_enrolments_revision",
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
    belongs_to :participation, Chimwemwe.People.Participation do
      source_attribute :participation_id
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

    attribute :participation_id, :uuid do
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

    attribute :effective_from, :date do
      allow_nil? false
      public? false
    end

    attribute :effective_until, :date do
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
