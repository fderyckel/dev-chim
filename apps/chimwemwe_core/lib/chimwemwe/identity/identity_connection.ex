defmodule Chimwemwe.Identity.IdentityConnection do
  @moduledoc """
  Closed tenant-owned configuration for one provider-neutral identity connection.

  State changes enter through named functions on `Chimwemwe.Identity.Foundation`.
  Raw credentials and provider tokens are never accepted by this resource.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "identity_connections"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "identity_connections_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :name],
        name: "identity_connections_tenant_name_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:protocol, "identity_connections_protocol_allowed",
        check: "protocol IN ('oidc', 'saml')"
      )

      check_constraint(:status, "identity_connections_status_allowed",
        check: "status IN ('draft', 'qualified', 'active', 'suspended', 'retired')"
      )

      check_constraint(
        :configuration_version,
        "identity_connections_configuration_version_positive",
        check: "configuration_version >= 1"
      )

      check_constraint(:lock_version, "identity_connections_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(:assurance_mapping, "identity_connections_assurance_mapping_object",
        check: "jsonb_typeof(assurance_mapping) = 'object'"
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

    attribute :name, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120, trim?: true
    end

    attribute :protocol, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:oidc, :saml]
    end

    attribute :issuer, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 500, trim?: true
    end

    attribute :application_identifier, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 500, trim?: true
    end

    attribute :secret_reference, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 500, trim?: true
    end

    attribute :assurance_mapping, :map do
      allow_nil? false
      public? false
      default %{}
    end

    attribute :configuration_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :draft
      constraints one_of: [:draft, :qualified, :active, :suspended, :retired]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    attribute :qualified_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
