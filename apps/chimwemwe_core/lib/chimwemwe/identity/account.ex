defmodule Chimwemwe.Identity.Account do
  @moduledoc """
  A global authenticated account.

  A record here represents an authenticated person or service identity. It is
  not an educational role and confers no tenant access by itself. Tenant access
  is established later through the authority and membership boundary.
  """

  use Ash.Resource,
    otp_app: :chimwemwe_core,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("identity_accounts")
    repo(Chimwemwe.Repo)

    check_constraints do
      check_constraint(:status, "identity_accounts_status_allowed",
        check: "status IN ('pending_first_login', 'active', 'suspended')"
      )

      check_constraint(:temporary_password_expires_at, "identity_accounts_temporary_state",
        check:
          "(status = 'pending_first_login' AND temporary_password_expires_at IS NOT NULL) OR (status <> 'pending_first_login' AND temporary_password_expires_at IS NULL)"
      )

      check_constraint(:failed_attempt_count, "identity_accounts_failed_attempt_count",
        check: "failed_attempt_count >= 0"
      )

      check_constraint(:lock_version, "identity_accounts_lock_version",
        check: "lock_version >= 1"
      )

      check_constraint(:email, "identity_accounts_normalized_email",
        check: "email = lower(btrim(email))"
      )
    end
  end

  authentication do
    subject_name(:account)
    domain(Chimwemwe.Identity)

    tokens do
      enabled?(true)
      token_resource(Chimwemwe.Identity.Token)
      signing_secret(Chimwemwe.Identity.Secrets)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)
      token_lifetime({8, :hours})
    end

    strategies do
      password :local_demo do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        registration_enabled?(false)
        confirmation_required?(false)
      end
    end

    add_ons do
      log_out_everywhere do
        apply_on_password_change?(false)
      end
    end
  end

  actions do
    create :bootstrap_local_account do
      description("Creates the explicit loopback demonstration account.")

      accept([
        :actor_id,
        :email,
        :hashed_password,
        :status,
        :temporary_password_expires_at,
        :password_changed_at
      ])
    end

    create :provision_local_account do
      description("Creates one administrator-provisioned local account in first-login state.")

      accept([
        :actor_id,
        :email,
        :hashed_password,
        :temporary_password_expires_at
      ])

      change(set_attribute(:status, :pending_first_login))
    end

    read :get_by_subject do
      description("Loads an account from the subject in a validated authentication token.")
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end

    read :lookup_local_demo_account do
      description("Locates the explicitly configured loopback demonstration account.")

      argument :email, :string do
        allow_nil?(false)
      end

      prepare(build(filter: [email: arg(:email)]))
    end

    read :lookup_local_account do
      description("Locates one normalized local account for server-owned authentication.")

      argument :email, :string do
        allow_nil?(false)
      end

      get?(true)
      prepare(build(filter: [email: arg(:email)]))
    end

    read :list_local_accounts do
      description("Lists local accounts for the guarded administration proof.")
      prepare(build(sort: [inserted_at: :asc, id: :asc]))
    end

    read :get_local_account do
      description("Loads one exact local account for a server-owned credential action.")

      argument :id, :uuid do
        allow_nil?(false)
      end

      get?(true)
      prepare(build(filter: [id: arg(:id)]))
    end

    read :sign_in_with_password do
      description("Attempts password sign-in and returns a short-lived authentication token.")
      get?(true)

      argument :email, :string do
        allow_nil?(false)
      end

      argument :password, :string do
        allow_nil?(false)
        sensitive?(true)
      end

      prepare(build(filter: [status: :active]))

      prepare({AshAuthentication.Strategy.Password.SignInPreparation, strategy_name: :local_demo})

      metadata :token, :string do
        allow_nil?(false)
      end
    end

    read :sign_in_with_token do
      description("Exchanges a short-lived form token for a session token.")
      get?(true)

      argument :token, :string do
        allow_nil?(false)
        sensitive?(true)
      end

      prepare(AshAuthentication.Strategy.Password.SignInWithTokenPreparation)

      metadata :token, :string do
        allow_nil?(false)
      end
    end

    update :rotate_local_demo_password do
      description("Rotates the loopback demonstration account password at startup.")

      accept([
        :actor_id,
        :hashed_password,
        :status,
        :temporary_password_expires_at,
        :password_changed_at,
        :failed_attempt_count,
        :locked_until
      ])

      change(optimistic_lock(:lock_version))
      require_atomic?(false)
    end

    update :reissue_temporary_password do
      description("Replaces a local credential with a new expiring first-login password.")

      accept([
        :hashed_password,
        :temporary_password_expires_at
      ])

      change(set_attribute(:status, :pending_first_login))
      change(set_attribute(:password_changed_at, nil))
      change(set_attribute(:failed_attempt_count, 0))
      change(set_attribute(:locked_until, nil))
      change(optimistic_lock(:lock_version))
      require_atomic?(false)
    end

    update :activate_permanent_password do
      description("Consumes first-login state and activates the user-selected password.")

      accept([
        :hashed_password,
        :password_changed_at
      ])

      change(set_attribute(:status, :active))
      change(set_attribute(:temporary_password_expires_at, nil))
      change(set_attribute(:failed_attempt_count, 0))
      change(set_attribute(:locked_until, nil))
      change(optimistic_lock(:lock_version))
      require_atomic?(false)
    end

    update :suspend_local_account do
      description("Suspends one local credential without changing school records or authority.")
      accept([])
      change(set_attribute(:status, :suspended))
      change(set_attribute(:temporary_password_expires_at, nil))
      change(set_attribute(:failed_attempt_count, 0))
      change(set_attribute(:locked_until, nil))
      change(optimistic_lock(:lock_version))
      require_atomic?(false)
    end

    update :record_failed_password_attempt do
      description("Atomically records one denied local-password attempt and applies lockout.")

      change(
        atomic_update(:failed_attempt_count, expr(failed_attempt_count + 1), cast_atomic?: false)
      )

      change(
        atomic_update(
          :locked_until,
          expr(
            if failed_attempt_count + 1 >= 5,
              do: datetime_add(now(), 15, :minute),
              else: locked_until
          )
        )
      )

      require_atomic?(false)
    end

    update :clear_failed_password_attempts do
      description("Clears local-password denial state after successful credential verification.")
      change(atomic_update(:failed_attempt_count, expr(0), cast_atomic?: false))
      change(atomic_update(:locked_until, expr(nil)))
      require_atomic?(false)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  identities do
    identity(:unique_email, [:email])
    identity(:unique_actor, [:actor_id])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :actor_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :email, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 3, max_length: 320, trim?: true)
    end

    attribute :hashed_password, :string do
      allow_nil?(false)
      sensitive?(true)
      public?(false)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:pending_first_login)
      public?(false)
      constraints(one_of: [:pending_first_login, :active, :suspended])
    end

    attribute :temporary_password_expires_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(false)
    end

    attribute :password_changed_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(false)
    end

    attribute :failed_attempt_count, :integer do
      allow_nil?(false)
      default(0)
      public?(false)
      constraints(min: 0)
    end

    attribute :locked_until, :utc_datetime_usec do
      allow_nil?(true)
      public?(false)
    end

    attribute :lock_version, :integer do
      allow_nil?(false)
      default(1)
      public?(false)
      constraints(min: 1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end
end
