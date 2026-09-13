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

    custom_indexes do
      index [:tenant_id], name: "actors_tenant_id_index", all_tenants?: true

      index [:id, :tenant_id],
        name: "actors_id_tenant_id_index",
        unique: true,
        all_tenants?: true
    end

    references do
      reference :tenant,
        name: "actors_tenant_id_fkey",
        on_delete: :restrict
    end

    check_constraints do
      check_constraint :name, "actor_name_must_not_be_empty", check: "char_length(name) > 0"

      check_constraint :kind, "actor_kind_must_be_known", check: "kind IN ('human', 'service')"
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :tenant, AshFoundationLab.Tenant do
      source_attribute :tenant_id
      destination_attribute :id
      define_attribute? false
      public? false
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

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:human, :service]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
