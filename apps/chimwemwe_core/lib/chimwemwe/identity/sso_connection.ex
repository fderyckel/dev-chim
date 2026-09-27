defmodule Chimwemwe.Identity.SsoConnection do
  @moduledoc """
  Tenant-scoped metadata for one institutional sign-in connection.

  The `secret_reference` points to a deployment-managed secret. Raw client
  secrets, certificates, refresh tokens, and access tokens are deliberately not
  accepted by this resource and are never stored in PostgreSQL.
  """

  use Ash.Resource,
    otp_app: :chimwemwe_core,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "identity_sso_connections"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:tenant_id, :name],
        name: "identity_sso_connections_tenant_name_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:provider, "identity_sso_connections_provider_allowed",
        check: "provider IN ('google', 'microsoft', 'oidc', 'saml')"
      )

      check_constraint(:connection_status, "identity_sso_connections_status_allowed",
        check: "connection_status IN ('draft', 'active', 'disabled')"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    read :list_for_institution do
      description "Lists the current institution's SSO connection metadata."
      public? true
      prepare build(sort: [inserted_at: :asc, id: :asc])
    end

    create :register_connection do
      description "Registers a draft institutional SSO connection."
      accept [:name, :provider, :issuer_url, :client_id, :secret_reference, :allowed_domains]
    end

    update :activate_connection do
      description "Marks a previously verified SSO connection active."
      require_atomic? false
      change set_attribute(:connection_status, :active)
    end

    update :disable_connection do
      description "Stops new sign-ins through this SSO connection."
      require_atomic? false
      change set_attribute(:connection_status, :disabled)
    end
  end

  policies do
    policy always() do
      forbid_unless actor_present()
      authorize_if always()
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
      public? true
      constraints min_length: 3, max_length: 120, trim?: true
    end

    attribute :provider, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:google, :microsoft, :oidc, :saml]
    end

    attribute :issuer_url, :string do
      allow_nil? false
      public? true
      constraints min_length: 8, max_length: 500, trim?: true
    end

    attribute :client_id, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 500, trim?: true
    end

    attribute :secret_reference, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 500, trim?: true
    end

    attribute :allowed_domains, :string do
      allow_nil? false
      default ""
      public? true
      constraints max_length: 1_000, trim?: true
    end

    attribute :connection_status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :active, :disabled]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
