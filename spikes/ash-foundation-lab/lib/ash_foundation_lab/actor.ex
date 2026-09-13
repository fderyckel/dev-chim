defmodule AshFoundationLab.Actor do
  @moduledoc """
  Synthetic human or service actor used to exercise policy decisions in the spike.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "actors"
    repo AshFoundationLab.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
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

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:human, :service]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
