defmodule Chimwemwe.OrganizationLegal.LegalEntityRelationship do
  @moduledoc """
  One explicit, direct legal-entity relationship accepted by ADR 0031.

  The relationship never implies transitive ownership, accounting
  consolidation, primary operation, authority, or access. Evidence content
  remains outside this table; only a bounded non-sensitive reference is kept.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_entity_relationships"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_relationships_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index(
        [
          :tenant_id,
          :source_legal_entity_id,
          :target_legal_entity_id,
          :relationship_type,
          :effective_from
        ],
        name: "organization_legal_relationships_direct_fact_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :source_legal_entity_id, :relationship_type, :id],
        name: "organization_legal_relationships_source_index",
        all_tenants?: true
      )

      index([:tenant_id, :target_legal_entity_id, :relationship_type, :id],
        name: "organization_legal_relationships_target_index",
        all_tenants?: true
      )
    end

    references do
      reference(:source_legal_entity,
        name: "organization_legal_relationships_source_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:target_legal_entity,
        name: "organization_legal_relationships_target_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(
        :relationship_type,
        "organization_legal_relationships_type_allowed",
        check: """
        relationship_type IN (
          'equity_interest',
          'governing_body_appointment',
          'statutory_control',
          'contractual_control'
        )
        """
      )

      check_constraint(
        [:relationship_type, :interest_bps],
        "organization_legal_relationships_interest_consistent",
        check: """
        (relationship_type = 'equity_interest' AND interest_bps BETWEEN 1 AND 10000) OR
        (relationship_type <> 'equity_interest' AND interest_bps IS NULL)
        """
      )

      check_constraint(
        [:relationship_type, :basis_key],
        "organization_legal_relationships_basis_consistent",
        check: """
        (relationship_type = 'equity_interest' AND basis_key = 'registered_equity') OR
        (relationship_type = 'governing_body_appointment' AND basis_key = 'governing_instrument') OR
        (relationship_type = 'statutory_control' AND basis_key = 'statute') OR
        (relationship_type = 'contractual_control' AND basis_key = 'contract')
        """
      )

      check_constraint(
        [:source_legal_entity_id, :target_legal_entity_id],
        "organization_legal_relationships_distinct_endpoints",
        check: "source_legal_entity_id <> target_legal_entity_id"
      )

      check_constraint(:status, "organization_legal_relationships_status_allowed",
        check: "status IN ('active')"
      )

      check_constraint(:lock_version, "organization_legal_relationships_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(
        :evidence_reference,
        "organization_legal_relationships_evidence_reference_length",
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
    belongs_to :source_legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :source_legal_entity_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :target_legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :target_legal_entity_id
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

    attribute :source_legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :target_legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :relationship_type, :atom do
      allow_nil? false
      public? false

      constraints one_of: [
                    :equity_interest,
                    :governing_body_appointment,
                    :statutory_control,
                    :contractual_control
                  ]
    end

    attribute :basis_key, :atom do
      allow_nil? false
      public? false

      constraints one_of: [
                    :registered_equity,
                    :governing_instrument,
                    :statute,
                    :contract
                  ]
    end

    attribute :interest_bps, :integer do
      allow_nil? true
      public? false
      constraints min: 1, max: 10_000
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
