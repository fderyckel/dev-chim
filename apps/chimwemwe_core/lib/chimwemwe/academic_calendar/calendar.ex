defmodule Chimwemwe.AcademicCalendar.Calendar do
  @moduledoc """
  Stable tenant-qualified identity for one calendar owned by one exact institutional unit.

  The owner relationship selects neither authority nor an ancestor/default calendar. All access
  remains private to the named calendar foundation actions.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.AcademicCalendar,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "academic_calendars"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "academic_calendars_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :institutional_unit_id, :code],
        name: "academic_calendars_owner_code_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:institutional_unit,
        name: "academic_calendars_institutional_unit_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:code, "academic_calendars_code", check: "code ~ '^[a-z][a-z0-9_]{0,79}$'")

      check_constraint(:status, "academic_calendars_status", check: "status = 'active'")

      check_constraint(:lock_version, "academic_calendars_lock_version",
        check: "lock_version >= 1"
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

    attribute :code, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :active
      constraints one_of: [:active]
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
