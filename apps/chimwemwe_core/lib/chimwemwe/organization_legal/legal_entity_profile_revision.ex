defmodule Chimwemwe.OrganizationLegal.LegalEntityProfileRevision do
  @moduledoc """
  Immutable attributable legal-entity profile revision.

  The first slice records only official and display names. Registration,
  jurisdiction, contact details, and document evidence require the domain and
  records reviews retained by ADR 0025 and are not guessed here.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_entity_profile_revisions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_entity_profiles_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :legal_entity_id, :revision_number],
        name: "organization_legal_entity_profiles_revision_index",
        unique: true,
        all_tenants?: true
      )
    end

    references do
      reference(:legal_entity,
        name: "organization_legal_entity_profiles_entity_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:revision_number, "organization_legal_entity_profiles_revision_positive",
        check: "revision_number >= 1"
      )

      check_constraint(:official_name, "organization_legal_entity_profiles_official_name_length",
        check: "char_length(official_name) BETWEEN 1 AND 200"
      )

      check_constraint(:display_name, "organization_legal_entity_profiles_display_name_length",
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

    attribute :legal_entity_id, :uuid do
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
