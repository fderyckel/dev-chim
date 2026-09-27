defmodule Chimwemwe.Identity.ExternalIdentityLink do
  @moduledoc """
  Closed global link from one protocol-qualified external identity to one actor.

  The normalized protocol, issuer/entity ID, and subject/NameID form the only
  external identity key. Provider profile fields cannot mutate this record.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :global_reference

  postgres do
    table "identity_external_identity_links"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:protocol, :issuer, :subject],
        name: "identity_external_identity_links_external_key_index",
        unique: true
      )

      index([:actor_id], name: "identity_external_identity_links_actor_index")
    end

    check_constraints do
      check_constraint(:protocol, "identity_external_identity_links_protocol_allowed",
        check: "protocol IN ('oidc', 'saml')"
      )

      check_constraint(:status, "identity_external_identity_links_status_allowed",
        check: "status IN ('active', 'revoked')"
      )

      check_constraint(:lock_version, "identity_external_identity_links_lock_version_positive",
        check: "lock_version >= 1"
      )
    end

    references do
      reference(:connection,
        name: "identity_external_identity_links_connection_fkey",
        on_delete: :restrict,
        match_type: :simple
      )
    end
  end

  actions do
  end

  relationships do
    belongs_to :connection, Chimwemwe.Identity.IdentityConnection do
      source_attribute :connection_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :origin_tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :connection_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :protocol, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:oidc, :saml]
    end

    attribute :issuer, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 500
    end

    attribute :subject, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 500
    end

    attribute :connection_configuration_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :active
      constraints one_of: [:active, :revoked]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
