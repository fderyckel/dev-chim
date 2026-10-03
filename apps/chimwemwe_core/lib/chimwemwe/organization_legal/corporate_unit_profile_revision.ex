defmodule Chimwemwe.OrganizationLegal.CorporateUnitProfileRevision do
  @moduledoc """
  Immutable attributable name revision for one corporate unit.

  Slice 2.1-C2a can append successor name revisions. It does not infer a unit
  type, cost centre, authority scope, educational meaning, or financial
  reporting behavior.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_corporate_unit_profile_revisions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_corporate_unit_profiles_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :corporate_unit_id, :revision_number],
        name: "organization_legal_corporate_unit_profiles_revision_index",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:corporate_unit,
        name: "organization_legal_corporate_unit_profiles_unit_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(
        :revision_number,
        "organization_legal_corporate_unit_profiles_revision_positive",
        check: "revision_number >= 1"
      )

      check_constraint(
        :official_name,
        "organization_legal_corporate_unit_profiles_official_name_length",
        check: "char_length(official_name) BETWEEN 1 AND 200"
      )

      check_constraint(
        :display_name,
        "organization_legal_corporate_unit_profiles_display_name_length",
        check: "char_length(display_name) BETWEEN 1 AND 200"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :corporate_unit, Chimwemwe.OrganizationLegal.CorporateUnit do
      source_attribute :corporate_unit_id
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

    attribute :corporate_unit_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :revision_number, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :official_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 200, trim?: true
    end

    attribute :display_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 200, trim?: true
    end

    attribute :recorded_by_actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
