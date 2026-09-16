defmodule Chimwemwe.Platform.ResourceContractTest.ValidTenantResource do
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
    read :list_records

    update :rename_record do
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
    end
  end
end

defmodule Chimwemwe.Platform.ResourceContractTest.ValidGlobalReference do
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
  end
end

defmodule Chimwemwe.Platform.ResourceContractTest.UnsafeTenantResource do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :tenant_owned

  actions do
    update :update do
      accept []
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
      allow_nil? true
      public? true
    end
  end
end

defmodule Chimwemwe.Platform.ResourceContractTest.UnownedResource do
  @moduledoc false

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  actions do
    read :list_records
  end

  attributes do
    uuid_primary_key :id
  end
end

defmodule Chimwemwe.Platform.ResourceContractTest.MissingPoliciesResource do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :global_reference

  actions do
    read :list_reference_values
  end

  attributes do
    uuid_primary_key :id
  end
end

defmodule Chimwemwe.Platform.ResourceContractTest.UnsafeGlobalReference do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    ownership: :global_reference

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

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

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end
  end
end
