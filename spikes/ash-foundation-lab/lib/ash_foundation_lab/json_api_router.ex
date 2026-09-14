defmodule AshFoundationLab.JsonApiRouter do
  @moduledoc """
  Generated JSON:API router for the disposable Phase 0 pressure-test.

  Authentication and tenant placement belong to an upstream trusted pipeline.
  This router consumes the actor and tenant stored in the Plug connection's
  private Ash context and fails closed when either is absent.
  """

  use AshJsonApi.Router,
    domains: [AshFoundationLab.Foundation],
    before_dispatch: {AshFoundationLab.JsonApiContract, :before_dispatch, []},
    modify_open_api: {AshFoundationLab.JsonApiContract, :modify_open_api, []},
    open_api: "/api/v1/openapi.json",
    open_api_title: "Ash Foundation Lab API",
    open_api_version: "1.0.0",
    open_api_servers: ["/"]
end
