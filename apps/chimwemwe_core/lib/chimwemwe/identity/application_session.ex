defmodule Chimwemwe.Identity.ApplicationSession do
  @moduledoc """
  Closed tenant-owned opaque application session.

  PostgreSQL retains only a one-way token digest. Provider access, refresh, and
  assertion material are outside this model and must never be persisted here.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "identity_application_sessions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "identity_application_sessions_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:token_digest],
        name: "identity_application_sessions_token_digest_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :actor_id, :status, :absolute_expires_at],
        name: "identity_application_sessions_actor_status_index",
        all_tenants?: true
      )
    end

    references do
      reference(:membership,
        name: "identity_application_sessions_membership_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:external_identity_link,
        name: "identity_application_sessions_external_link_fkey",
        on_delete: :restrict,
        match_type: :simple
      )

      reference(:rotated_to_session,
        name: "identity_application_sessions_rotated_to_fkey",
        on_delete: :restrict,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(:token_digest, "identity_application_sessions_token_digest_sha256",
        check: "octet_length(token_digest) = 32"
      )

      check_constraint(:status, "identity_application_sessions_status_allowed",
        check: "status IN ('active', 'rotated', 'logged_out', 'revoked')"
      )

      check_constraint(:lock_version, "identity_application_sessions_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(
        [:inserted_at, :idle_expires_at, :absolute_expires_at],
        "identity_application_sessions_expiry_order",
        check: """
        idle_expires_at > inserted_at AND
        absolute_expires_at > idle_expires_at AND
        absolute_expires_at <= inserted_at + INTERVAL '12 hours'
        """
      )

      check_constraint(
        [:status, :rotated_to_session_id],
        "identity_application_sessions_rotation_consistent",
        check: """
        (status = 'rotated' AND rotated_to_session_id IS NOT NULL) OR
        (status IN ('active', 'logged_out', 'revoked') AND rotated_to_session_id IS NULL)
        """
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :membership, Chimwemwe.Platform.Authority.Membership do
      source_attribute :membership_id
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

    belongs_to :rotated_to_session, __MODULE__ do
      source_attribute :rotated_to_session_id
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

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :membership_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :external_identity_link_id, :uuid do
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
      default :active
      constraints one_of: [:active, :rotated, :logged_out, :revoked]
    end

    attribute :assurance, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120
    end

    attribute :assurance_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :idle_expires_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :absolute_expires_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :last_seen_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :rotated_to_session_id, :uuid do
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
