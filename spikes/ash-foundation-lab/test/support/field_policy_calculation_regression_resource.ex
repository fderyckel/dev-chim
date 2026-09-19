defmodule AshFoundationLab.FieldPolicyCalculationRegressionResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshFoundationLab.FieldPolicyCalculationRegressionDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults [:read, create: [:public_label, :restricted_value]]
  end

  policies do
    policy always() do
      forbid_unless actor_present()
      authorize_if always()
    end
  end

  field_policies do
    field_policy [:restricted_value, :restricted_calculation] do
      authorize_if actor_attribute_equals(:may_read_restricted, true)
    end

    field_policy :* do
      authorize_if always()
    end
  end

  calculations do
    calculate :restricted_calculation, :string, expr(restricted_value) do
      public? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :public_label, :string do
      allow_nil? false
      public? true
    end

    attribute :restricted_value, :string do
      allow_nil? false
      public? true
    end
  end
end

defmodule AshFoundationLab.FieldPolicyCalculationRegressionDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshFoundationLab.FieldPolicyCalculationRegressionResource
  end
end
