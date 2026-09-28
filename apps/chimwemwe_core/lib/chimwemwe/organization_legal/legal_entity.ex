defmodule Chimwemwe.OrganizationLegal.LegalEntity do
  @moduledoc """
  Stable tenant-qualified identity for one legally accountable organization.

  Slice 2.1-B keeps only identity, lifecycle state, and optimistic version on
  this record. Names live in immutable profile revisions so renaming never
  replaces the entity UUID. Registration, jurisdiction, relationships,
  ownership, consolidation, and corporate-unit meaning remain deferred.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.OrganizationLegal,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "organization_legal_entities"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "organization_legal_entities_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :status, :id],
        name: "organization_legal_entities_status_index",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:status, "organization_legal_entities_status_allowed",
        check: "status IN ('active')"
      )

      check_constraint(:lock_version, "organization_legal_entities_lock_version_positive",
        check: "lock_version >= 1"
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
