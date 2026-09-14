defmodule AshFoundationLab.Foundation do
  @moduledoc """
  Disposable domain used to pressure-test foundation framework behaviour.
  """

  use Ash.Domain,
    otp_app: :ash_foundation_lab,
    extensions: [AshJsonApi.Domain]

  json_api do
    authorize? true
    error_handler {AshFoundationLab.JsonApiContract, :handle_error, []}

    routes do
      base_route "/api/v1/foundation-records", AshFoundationLab.FoundationRecord do
        index :list_paginated
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
