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
    table "identity_accounts"
    repo(Chimwemwe.Repo)

    check_constraints do
      check_constraint(:status, "identity_accounts_status_allowed",
        check: "status IN ('active', 'suspended')"
      )
    end
  end

  authentication do
    subject_name :account
    domain Chimwemwe.Identity

    tokens do
      enabled? true
      token_resource Chimwemwe.Identity.Token
      signing_secret Chimwemwe.Identity.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
      token_lifetime {8, :hours}
    end

    strategies do
      password :local_demo do
        identity_field :email
        hashed_password_field :hashed_password
        registration_enabled? false
        confirmation_required? false
      end
    end
  end

  actions do
    create :bootstrap_local_account do
      description "Creates the explicit loopback demonstration account."
      accept [:email, :hashed_password, :status]
    end

    read :get_by_subject do
      description "Loads an account from the subject in a validated authentication token."
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :lookup_local_demo_account do
      description "Locates the explicitly configured loopback demonstration account."

      argument :email, :string do
        allow_nil? false
      end

      prepare build(filter: [email: arg(:email)])
    end

    read :sign_in_with_password do
      description "Attempts password sign-in and returns a short-lived authentication token."
      get? true

      argument :email, :string do
        allow_nil? false
      end

      argument :password, :string do
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      description "Exchanges a short-lived form token for a session token."
      get? true

      argument :token, :string do
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        allow_nil? false
      end
    end

    update :rotate_local_demo_password do
      description "Rotates the loopback demonstration account password at startup."
      accept [:hashed_password]
      require_atomic? false
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
      constraints min_length: 3, max_length: 320, trim?: true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :status, :atom do
      allow_nil? false
      default :active
      public? false
      constraints one_of: [:active, :suspended]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
