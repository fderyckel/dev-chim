defmodule Chimwemwe.Platform.TemporalQualification.CurrentProjection do
  @moduledoc "Disposable neutral current-revision projection used for recovery convergence proof."

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_current_projections"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_current_projections_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_id],
        name: "platform_temporal_current_projections_aggregate_index",
        unique: true,
        all_tenants?: true
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    action :rebuild_current, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ProjectionResult
      argument :aggregate_id, :uuid, allow_nil?: false
      argument :module_key, :string, allow_nil?: false
      run Chimwemwe.Platform.TemporalQualification.RebuildCurrentProjection
    end
  end

  policies do
    policy action(:rebuild_current) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.projections.rebuild"}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :tenant_id, :uuid, allow_nil?: false, public?: false
    attribute :aggregate_id, :uuid, allow_nil?: false, public?: false
    attribute :revision_id, :uuid, allow_nil?: false, public?: false

    attribute :projection_version, :integer,
      allow_nil?: false,
      public?: false,
      constraints: [min: 1]

    attribute :segment_count, :integer, allow_nil?: false, public?: false, constraints: [min: 0]
    attribute :refreshed_at, :utc_datetime_usec, allow_nil?: false, public?: false
  end
end
