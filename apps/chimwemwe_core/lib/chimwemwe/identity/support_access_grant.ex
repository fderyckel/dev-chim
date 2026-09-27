defmodule Chimwemwe.Identity.SupportAccessGrant do
  @moduledoc """
  Closed tenant-owned approval for bounded, non-impersonating support access.

  The code-owned support boundary validates every capability on every use. This
  record is never a tenant membership, role assignment, or reusable background
  credential.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "identity_support_access_grants"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "identity_support_access_grants_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :support_actor_id, :status, :expires_at],
        name: "identity_support_access_grants_actor_status_index",
        all_tenants?: true
      )
    end

    references do
      reference(:session,
        name: "identity_support_access_grants_session_tenant_fkey",
        on_delete: :restrict,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(:status, "identity_support_access_grants_status_allowed",
        check: "status IN ('approved', 'active', 'revoked', 'ended')"
      )

      check_constraint(:lock_version, "identity_support_access_grants_lock_version_positive",
        check: "lock_version >= 1"
      )

      check_constraint(:capability_scope, "identity_support_access_grants_scope_nonempty",
        check: "cardinality(capability_scope) BETWEEN 1 AND 8"
      )

      check_constraint(
        [:inserted_at, :expires_at],
        "identity_support_access_grants_maximum_lifetime",
        check: "expires_at > inserted_at AND expires_at <= inserted_at + INTERVAL '60 minutes'"
      )

      check_constraint(
        [:support_actor_id, :grantor_actor_id],
        "identity_support_access_grants_independent_approval",
        check: "support_actor_id <> grantor_actor_id"
      )

      check_constraint(
        [:status, :session_id, :activated_at],
        "identity_support_access_grants_activation_consistent",
        check: """
        (status = 'approved' AND session_id IS NULL AND activated_at IS NULL) OR
        (status = 'active' AND session_id IS NOT NULL AND activated_at IS NOT NULL) OR
        (status IN ('revoked', 'ended'))
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
    belongs_to :session, Chimwemwe.Identity.ApplicationSession do
      source_attribute :session_id
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

    attribute :support_actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :grantor_actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :session_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :purpose, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 240
    end

    attribute :ticket_reference, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120
    end

    attribute :capability_scope, {:array, :string} do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 8, items: [min_length: 3, max_length: 120]
    end

    attribute :assurance_required, :string do
      allow_nil? false
      public? false
      default "mfa"
      constraints min_length: 1, max_length: 120
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :approved
      constraints one_of: [:approved, :active, :revoked, :ended]
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :activated_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :ended_at, :utc_datetime_usec do
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
