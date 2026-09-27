defmodule Chimwemwe.Identity.Invitation do
  @moduledoc """
  Closed tenant-owned, single-use invitation to link one pre-approved actor.

  Only the SHA-256 token digest is retained. The raw token is returned once by
  the issue action and never appears in audit or outbox evidence.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "identity_invitations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "identity_invitations_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:token_digest],
        name: "identity_invitations_token_digest_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :membership_id, :status, :expires_at],
        name: "identity_invitations_membership_status_index",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:token_digest, "identity_invitations_token_digest_sha256",
        check: "octet_length(token_digest) = 32"
      )

      check_constraint(:status, "identity_invitations_status_allowed",
        check: "status IN ('pending', 'accepted', 'revoked')"
      )

      check_constraint(:lock_version, "identity_invitations_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(
        [:status, :accepted_at, :external_identity_link_id],
        "identity_invitations_acceptance_consistent",
        check: """
        (status = 'accepted' AND accepted_at IS NOT NULL AND external_identity_link_id IS NOT NULL) OR
        (status IN ('pending', 'revoked') AND accepted_at IS NULL AND external_identity_link_id IS NULL)
        """
      )

      check_constraint([:inserted_at, :expires_at], "identity_invitations_maximum_lifetime",
        check: "expires_at > inserted_at AND expires_at <= inserted_at + INTERVAL '30 minutes'"
      )
    end

    references do
      reference(:membership,
        name: "identity_invitations_membership_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:role,
        name: "identity_invitations_role_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:connection,
        name: "identity_invitations_connection_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:external_identity_link,
        name: "identity_invitations_external_link_fkey",
        on_delete: :restrict,
        match_type: :simple
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

  relationships do
    belongs_to :membership, Chimwemwe.Platform.Authority.Membership do
      source_attribute :membership_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :role, Chimwemwe.Platform.Authority.Role do
      source_attribute :role_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :connection, Chimwemwe.Identity.IdentityConnection do
      source_attribute :connection_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :external_identity_link, Chimwemwe.Identity.ExternalIdentityLink do
      source_attribute :external_identity_link_id
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

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :membership_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :connection_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :token_digest, :binary do
      allow_nil? false
      public? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :pending
      constraints one_of: [:pending, :accepted, :revoked]
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :accepted_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :external_identity_link_id, :uuid do
      allow_nil? true
      public? false
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
