defmodule AshFoundationLab.Tenant do
  @moduledoc """
  Synthetic tenant root used to make generated migration ownership explicit.

  It exposes no Ash actions; tenant creation remains fixture-only in this lab.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tenants"
    repo AshFoundationLab.Repo

    check_constraints do
      check_constraint :name, "tenant_name_must_not_be_empty", check: "char_length(name) > 0"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
