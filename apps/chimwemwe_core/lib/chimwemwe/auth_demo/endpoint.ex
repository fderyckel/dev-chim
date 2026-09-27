defmodule Chimwemwe.AuthDemo.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint,
    otp_app: :chimwemwe_core,
    render_errors: [formats: [html: Chimwemwe.AuthDemo.ErrorHTML], layout: false]

  @session_options [
    store: :cookie,
    key: "_chimwemwe_auth_demo",
    signing_salt: "identity-demo-signing",
    encryption_salt: "identity-demo-encryption",
    same_site: "Lax",
    http_only: true,
    secure: false
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(Chimwemwe.AuthDemo.Router)
end
