defmodule Chimwemwe.InstitutionalStructure.InstitutionalUnit do
  @moduledoc "Private synthetic CF-1 InstitutionalUnit resource; named Foundation actions own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.InstitutionalStructure,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "institutional_units"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "institutional_units_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:classification, "institutional_units_classification",
        check: "classification = 'institution'"
      )

      check_constraint(:display_name, "institutional_units_name",
        check: "char_length(btrim(display_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:time_zone, "institutional_units_zone",
        check: "char_length(time_zone) BETWEEN 1 AND 100"
      )

      check_constraint(:status, "institutional_units_state",
        check:
          "(status = 'draft' AND lock_version IN (1, 2)) OR (status = 'published' AND lock_version = 3)"
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

    attribute :display_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 200, trim?: true
    end

    attribute :classification, :atom do
      allow_nil? false
      public? false
      default :institution
      constraints one_of: [:institution]
    end

    attribute :time_zone, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 100
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
  end
end
