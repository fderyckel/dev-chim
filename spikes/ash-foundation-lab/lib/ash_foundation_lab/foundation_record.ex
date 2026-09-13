defmodule AshFoundationLab.FoundationRecord do
  @moduledoc """
  Neutral, synthetic tenant-owned record used only by the Phase 0 spike.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "foundation_records"
    repo AshFoundationLab.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name]
    end

    update :submit_for_review do
      accept []
      require_atomic? false

      validate attribute_equals(:status, :draft) do
        message "record must be in draft state"
      end

      change set_attribute(:status, :in_review)
      change optimistic_lock(:lock_version)
    end
  end

  policies do
    policy always() do
      forbid_unless actor_present()
      forbid_unless AshFoundationLab.Policy.TenantMatchesActor
      authorize_if always()
    end

    policy action(:read) do
      authorize_if {AshFoundationLab.Policy.HasCapability, capability: "foundation_record.read"}
    end

    policy action(:create) do
      authorize_if {AshFoundationLab.Policy.HasCapability, capability: "foundation_record.create"}
    end

    policy action(:submit_for_review) do
      authorize_if {AshFoundationLab.Policy.HasCapability,
                    capability: "foundation_record.submit_for_review"}
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
      constraints min_length: 1, max_length: 120
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :in_review]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? true
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
