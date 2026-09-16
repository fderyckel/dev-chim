defmodule AshFoundationLab.ResourceAuthoringTest.RenameV1 do
  @moduledoc false

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    read :list_records
    update :submit_for_review
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

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :in_review]
    end
  end
end

defmodule AshFoundationLab.ResourceAuthoringTest.RenameV2 do
  @moduledoc false

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    read :list_records
    update :submit_for_review
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

    attribute :display_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 120
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :in_review]
    end
  end
end
