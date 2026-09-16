defmodule Chimwemwe.Platform.ActionInvocationTest.TrustedReadPolicy do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias Chimwemwe.Platform.TrustedActor

  @impl true
  def describe(_opts), do: "trusted context and actor are present for the read"

  @impl true
  def match?(
        %TrustedActor{assurance: "mfa", tenant_id: actor_tenant_id},
        %{
          subject: %Ash.Query{
            context: %{
              chimwemwe: %{
                correlation_id: correlation_id,
                locale: locale,
                purpose: purpose,
                routing_version: routing_version
              }
            },
            resource: resource,
            tenant: tenant
          }
        },
        _opts
      ) do
    valid_context? =
      is_binary(correlation_id) and is_binary(locale) and is_binary(purpose) and
        is_integer(routing_version) and routing_version > 0

    valid_tenant? =
      case resource.__chimwemwe_resource_ownership__() do
        :tenant_owned -> tenant == actor_tenant_id
        :global_reference -> is_nil(tenant)
      end

    valid_context? and valid_tenant?
  end

  def match?(_actor, _context, _opts), do: false
end

defmodule Chimwemwe.Platform.ActionInvocationTest.TenantRecord do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform.ActionInvocationTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    ownership: :tenant_owned

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    create :seed_record do
      accept [:name]
    end

    read :list_records

    read :private_records do
      public? false
    end
  end

  policies do
    policy action(:seed_record) do
      authorize_if always()
    end

    policy action(:list_records) do
      authorize_if Chimwemwe.Platform.ActionInvocationTest.TrustedReadPolicy
    end

    policy action(:private_records) do
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

defmodule Chimwemwe.Platform.ActionInvocationTest.GlobalReference do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform.ActionInvocationTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    ownership: :global_reference

  actions do
    create :seed_reference do
      accept [:code]
    end

    read :list_reference_values
  end

  policies do
    policy action(:seed_reference) do
      authorize_if always()
    end

    policy action(:list_reference_values) do
      authorize_if Chimwemwe.Platform.ActionInvocationTest.TrustedReadPolicy
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

defmodule Chimwemwe.Platform.ActionInvocationTest.Domain do
  @moduledoc false

  use Ash.Domain,
    otp_app: :chimwemwe_core,
    validate_config_inclusion?: false

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.Platform.ActionInvocationTest.TenantRecord
    resource Chimwemwe.Platform.ActionInvocationTest.GlobalReference
  end
end
