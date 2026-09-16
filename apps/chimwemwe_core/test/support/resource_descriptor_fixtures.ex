defmodule Chimwemwe.Platform.ResourceDescriptorTest.NeutralTenantResource do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :tenant_owned

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    read :list_records do
      argument :status, :atom do
        allow_nil? true
        constraints one_of: [:draft, :in_review]
      end

      argument :internal_probe, :string do
        public? false
      end

      pagination keyset?: true, required?: false, default_limit: 25, max_page_size: 100
    end

    read :private_records do
      public? false
    end

    update :submit_for_review do
      accept [:status]

      argument :note, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 240
      end
    end

    update :submit_with_payload do
      accept []
      argument :payload, :map, allow_nil?: false
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
      constraints allow_empty?: false, min_length: 1, max_length: 120, trim?: true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :in_review]
    end

    attribute :rank, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 10
    end

    attribute :audit_reference, :string do
      public? false
    end

    attribute :payload, :map do
      public? true
    end
  end
end

defmodule Chimwemwe.Platform.ResourceDescriptorTest.NeutralGlobalReference do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :global_reference

  actions do
    read :list_reference_values
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
    end
  end
end

defmodule Chimwemwe.Platform.ResourceDescriptorTest.RenameV1 do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :global_reference

  actions do
    read :list_records
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 120
    end
  end
end

defmodule Chimwemwe.Platform.ResourceDescriptorTest.RenameV2 do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :global_reference

  actions do
    read :list_records
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :display_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 120
    end
  end
end
