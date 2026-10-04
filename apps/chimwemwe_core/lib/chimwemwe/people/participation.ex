defmodule Chimwemwe.People.Participation do
  @moduledoc "Private tenant-owned Participation; named People.Foundation operations own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.People,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "people_participations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "people_participations_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:person_id, :institutional_unit_id, :kind, :tenant_id],
        name: "people_participations_subject_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:person,
        name: "people_participations_person_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:institutional_unit,
        name: "people_participations_institutional_unit_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:kind, "people_participations_kind", check: "kind IN ('student', 'staff')")

      check_constraint(:effective_until, "people_participations_interval",
        check: "effective_until IS NULL OR effective_until > effective_from"
      )

      check_constraint(:lock_version, "people_participations_version",
        check: "lock_version IN (1, 2)"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :person, Chimwemwe.People.Person do
      source_attribute :person_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

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

    attribute :person_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :institutional_unit_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :kind, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:student, :staff]
    end

    attribute :effective_from, :date do
      allow_nil? false
      public? false
    end

    attribute :effective_until, :date do
      allow_nil? true
      public? false
    end

    attribute :source_reference, :uuid do
      allow_nil? false
      public? false
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
  end
end
