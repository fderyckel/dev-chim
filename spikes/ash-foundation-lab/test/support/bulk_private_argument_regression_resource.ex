defmodule AshFoundationLab.BulkPrivateArgumentRegressionResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshFoundationLab.BulkPrivateArgumentRegressionDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :audit_note, :string do
      public? true
    end
  end

  actions do
    default_accept :*
    defaults [:read, :create]

    update :relabel do
      require_atomic? false

      argument :internal_reason, :string do
        public? false
      end

      change set_attribute(:audit_note, arg(:internal_reason))
    end

    destroy :archive do
      require_atomic? false

      argument :internal_reason, :string do
        public? false
      end

      change set_attribute(:audit_note, arg(:internal_reason))
    end
  end
end

defmodule AshFoundationLab.BulkPrivateArgumentRegressionDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshFoundationLab.BulkPrivateArgumentRegressionResource
  end
end
