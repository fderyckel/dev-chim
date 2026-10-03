defmodule Chimwemwe.InstitutionalStructure.InstitutionPublication do
  @moduledoc "Private synthetic CF-1 InstitutionPublication resource; named Foundation actions own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.InstitutionalStructure,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "institution_publications"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "institution_publications_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:institutional_unit_id, :tenant_id],
        name: "institution_publications_unit_idx",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:institutional_unit,
        name: "institution_publications_institutional_unit_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:operator_assignment,
        name: "institution_publications_operator_assignment_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
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

    belongs_to :operator_assignment, Chimwemwe.InstitutionalStructure.InitialOperatorAssignment do
      source_attribute :operator_assignment_id
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

    attribute :operator_assignment_id, :uuid do
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
