defmodule Chimwemwe.OrganizationLegal.LegalEntityRelationshipTermination do
  @moduledoc """
  Immutable exclusive end boundary for one direct legal-entity relationship.

  The referenced relationship fact remains unchanged. This record does not
  correct, replace, reactivate, or reinterpret that fact.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_entity_relationship_terminations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_relationship_terminations_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :relationship_id],
        name: "organization_legal_relationship_terminations_relationship_index",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:relationship,
        name: "org_legal_rel_terminations_relationship_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(
        :evidence_reference,
        "org_legal_rel_terminations_evidence_reference_length",
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
    belongs_to :relationship, Chimwemwe.OrganizationLegal.LegalEntityRelationship do
      source_attribute :relationship_id
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

    attribute :relationship_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :effective_until, :date do
      allow_nil? false
      public? false
    end

    attribute :evidence_reference, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120, trim?: true
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
