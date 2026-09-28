defmodule Chimwemwe.PublicApi.Endpoint do
  @moduledoc """
  Explicit Phoenix endpoint for the accepted same-origin production candidate.

  No application child starts this endpoint until a deployment supplies the
  reviewed runtime, verifier, origin, keys, TLS/edge, and operating controls.
  """

  use Phoenix.Endpoint, otp_app: :chimwemwe_core

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 32_768
  )

  plug(Chimwemwe.PublicApi.Router)
end
