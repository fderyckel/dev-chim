defmodule Chimwemwe.InstitutionalStructure.InitialOperatorAssignment do
  @moduledoc "Private synthetic CF-1 InitialOperatorAssignment resource; named Foundation actions own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.InstitutionalStructure,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "institution_initial_operator_assignments"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "institution_initial_operator_assignments_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:institutional_unit_id, :tenant_id],
        name: "institution_initial_operator_assignments_unit_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:institutional_unit,
        name: "institution_initial_operator_assignments_institutional_unit_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:legal_entity,
        name: "institution_initial_operator_assignments_legal_entity_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:legal_entity_version, "institution_operator_legal_version",
        check: "legal_entity_version >= 1"
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

    belongs_to :legal_entity, Chimwemwe.OrganizationLegal.LegalEntity do
      source_attribute :legal_entity_id
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

    attribute :legal_entity_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :legal_entity_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :evidence_reference, :uuid do
      allow_nil? false
      public? false
    end

    attribute :effective_from, :date do
      allow_nil? false
      public? false
    end

    attribute :verification, :map do
      allow_nil? false
      public? false
    end

    attribute :recorded_by_actor_id, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
