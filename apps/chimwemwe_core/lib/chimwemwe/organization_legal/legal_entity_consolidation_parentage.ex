defmodule Chimwemwe.OrganizationLegal.LegalEntityConsolidationParentage do
  @moduledoc """
  One explicit primary management-reporting parent for a legal entity.

  This is bounded navigation input, not a statutory or accounting-framework
  consolidation conclusion. It never implies ownership, control, or authority.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_entity_consolidation_parentages"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_consolidation_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :child_legal_entity_id],
        name: "organization_legal_consolidation_active_child_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :parent_legal_entity_id, :child_legal_entity_id],
        name: "organization_legal_consolidation_parent_index",
        all_tenants?: true
      )
    end

    references do
      reference(:child_legal_entity,
        name: "organization_legal_consolidation_child_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:parent_legal_entity,
        name: "organization_legal_consolidation_parent_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(
        [:child_legal_entity_id, :parent_legal_entity_id],
        "organization_legal_consolidation_distinct_entities",
        check: "child_legal_entity_id <> parent_legal_entity_id"
      )

      check_constraint(:reporting_basis, "organization_legal_consolidation_basis_allowed",
        check: "reporting_basis IN ('management_reporting')"
      )

      check_constraint(:status, "organization_legal_consolidation_status_allowed",
        check: "status IN ('active')"
      )

      check_constraint(:lock_version, "organization_legal_consolidation_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(
        :evidence_reference,
        "organization_legal_consolidation_evidence_reference_length",
        check: "char_length(evidence_reference) BETWEEN 1 AND 120"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :child_legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :child_legal_entity_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :parent_legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :parent_legal_entity_id
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

    attribute :child_legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :parent_legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :reporting_basis, :atom do
      allow_nil? false
      default :management_reporting
      public? false
      constraints one_of: [:management_reporting]
    end

    attribute :effective_from, :date do
      allow_nil? false
      public? false
    end

    attribute :evidence_reference, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120, trim?: true
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
