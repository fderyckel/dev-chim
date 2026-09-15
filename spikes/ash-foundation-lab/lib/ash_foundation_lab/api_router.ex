defmodule AshFoundationLab.ApiRouter do
  @moduledoc """
  Public HTTP edge for the disposable Phase 0 generated-interface evidence.

  The wrapper is intentionally thin. It records the page-limit enforcement and
  transient-failure response headers that the evaluated generated adapter does
  not own before handing accepted requests to the generated router.
  """

  use Plug.Builder

  plug(AshFoundationLab.JsonApiFailureHeaders)
  plug(AshFoundationLab.JsonApiPageLimit)
  plug(AshFoundationLab.JsonApiRouter)
end
