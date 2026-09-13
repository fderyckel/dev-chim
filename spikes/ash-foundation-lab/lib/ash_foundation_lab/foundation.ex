defmodule AshFoundationLab.Foundation do
  @moduledoc """
  Disposable domain used to pressure-test foundation framework behaviour.
  """

  use Ash.Domain,
    otp_app: :ash_foundation_lab,
    extensions: [AshJsonApi.Domain]

  json_api do
    authorize? true

    routes do
      base_route "/foundation-records", AshFoundationLab.FoundationRecord do
        patch :submit_for_review, route: "/:id/submit-for-review"
      end
    end
  end

  resources do
    resource AshFoundationLab.Tenant
    resource AshFoundationLab.Actor
    resource AshFoundationLab.FoundationRecord
    resource AshFoundationLab.OutboxEvent
  end
end
