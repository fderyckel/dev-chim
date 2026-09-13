defmodule AshFoundationLab.JsonApiRouter do
  @moduledoc """
  Generated JSON:API router for the disposable Phase 0 pressure-test.

  Authentication and tenant placement belong to an upstream trusted pipeline.
  This router consumes the actor and tenant stored in the Plug connection's
  private Ash context and fails closed when either is absent.
  """

  use AshJsonApi.Router,
    domains: [AshFoundationLab.Foundation],
    before_dispatch: {AshFoundationLab.Telemetry, :before_json_api_dispatch, []}
end
