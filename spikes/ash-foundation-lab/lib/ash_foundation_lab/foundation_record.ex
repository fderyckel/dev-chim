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
  end

  policies do
    policy always() do
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
      constraints min_length: 1, max_length: 120
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
