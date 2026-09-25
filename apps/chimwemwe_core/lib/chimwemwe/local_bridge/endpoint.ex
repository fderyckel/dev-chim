defmodule Chimwemwe.LocalBridge.Endpoint do
  @moduledoc """
  Loopback-only Phoenix endpoint for the guarded UI-1A qualification runtime.
  """

  use Phoenix.Endpoint, otp_app: :chimwemwe_core

  plug(Plug.RequestId)
  plug(Chimwemwe.LocalBridge.Router)
end
