defmodule Chimwemwe.OrganizationLegal.CorporateUnit do
  @moduledoc """
  Stable identity for one internal unit of exactly one legal entity.

  Canonical parentage stays inside that legal entity and carries no authority,
  reporting, configuration, module, placement, ledger, or educational meaning.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_corporate_units"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_corporate_units_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :legal_entity_id],
        name: "organization_legal_corporate_units_identity_owner_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :legal_entity_id, :parent_corporate_unit_id, :id],
        name: "organization_legal_corporate_units_parent_index",
        all_tenants?: true
      )
    end

    references do
      reference(:legal_entity,
        name: "organization_legal_corporate_units_entity_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:parent_corporate_unit,
        name: "organization_legal_corporate_units_parent_owner_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_with: [legal_entity_id: :legal_entity_id],
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(
        [:id, :parent_corporate_unit_id],
        "organization_legal_corporate_units_not_self_parented",
        check: "parent_corporate_unit_id IS NULL OR id <> parent_corporate_unit_id"
      )

      check_constraint(:status, "organization_legal_corporate_units_status_allowed",
        check: "status IN ('active')"
      )

      check_constraint(:lock_version, "organization_legal_corporate_units_lock_version_positive",
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
    belongs_to :legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :legal_entity_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :parent_corporate_unit, __MODULE__ do
      source_attribute :parent_corporate_unit_id
      destination_attribute :id
      define_attribute? false
      allow_nil? true
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

    attribute :legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :parent_corporate_unit_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :status, :atom do
      allow_nil? false
      default :active
      public? false
      constraints one_of: [:active]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? false
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
