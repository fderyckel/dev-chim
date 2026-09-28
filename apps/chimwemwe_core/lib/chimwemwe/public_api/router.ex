defmodule Chimwemwe.PublicApi.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :callback do
    plug(:accepts, ["json"])
    plug(Chimwemwe.PublicApi.SecurityHeadersPlug)
  end

  pipeline :authenticated do
    plug(:accepts, ["json"])
    plug(:fetch_cookies)
    plug(Chimwemwe.PublicApi.SecurityHeadersPlug)
    plug(Chimwemwe.PublicApi.SessionPlug)
  end

  pipeline :unsafe do
    plug(Chimwemwe.PublicApi.OriginCsrfPlug)
  end

  scope "/auth", Chimwemwe.PublicApi do
    pipe_through :callback

    get("/callback", CallbackController, :show)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through :authenticated

    get("/session", SessionController, :show)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through [:authenticated, :unsafe]

    post("/session/logout", SessionController, :logout)
    post("/session/support/elevate", SessionController, :elevate)
  end
end
