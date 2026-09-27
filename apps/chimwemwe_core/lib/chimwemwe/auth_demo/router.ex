defmodule Chimwemwe.AuthDemo.Router do
  @moduledoc false

  use Phoenix.Router
  use AshAuthentication.Phoenix.Router

  import Phoenix.LiveView.Router

  alias Chimwemwe.AuthDemo.{AdminController, AuthController}
  alias Chimwemwe.Identity.Account

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:load_from_session)
  end

  scope "/" do
    pipe_through :browser

    sign_in_route(path: "/sign-in", auth_routes_prefix: "/auth", resources: [Account])
    sign_out_route(AuthController, "/sign-out")
    auth_routes(AuthController, Account, path: "/auth")

    get("/", AdminController, :index)
    post("/connections", AdminController, :create)
    post("/connections/:id/activate", AdminController, :activate)
    post("/connections/:id/disable", AdminController, :disable)
  end
end
