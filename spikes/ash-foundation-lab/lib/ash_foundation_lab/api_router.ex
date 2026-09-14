defmodule AshFoundationLab.ApiRouter do
  @moduledoc """
  Public HTTP edge for the disposable Phase 0 generated-interface evidence.

  The wrapper is intentionally thin. It records the page-limit enforcement that
  the evaluated AshJsonApi version does not apply before handing accepted
  requests to the generated router.
  """

  use Plug.Builder

  plug(AshFoundationLab.JsonApiPageLimit)
  plug(AshFoundationLab.JsonApiRouter)
end
