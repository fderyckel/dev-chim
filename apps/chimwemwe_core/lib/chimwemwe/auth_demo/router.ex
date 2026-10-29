defmodule Chimwemwe.AuthDemo.Router do
  @moduledoc false

  use Phoenix.Router
  use AshAuthentication.Phoenix.Router

  import Phoenix.LiveView.Router

  alias Chimwemwe.AuthDemo.{AdminController, AuthController, FirstLoginController}

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:load_from_session)
  end

  scope "/" do
    pipe_through(:browser)

    get("/", AuthController, :home)
    get("/sign-in", AuthController, :new)
    post("/sign-in", AuthController, :create)
    post("/sign-out", AuthController, :sign_out)

    get("/first-login/password", FirstLoginController, :edit)
    post("/first-login/password", FirstLoginController, :update)

    get("/admin", AdminController, :index)
    post("/admin/accounts", AdminController, :create_account)
    post("/admin/accounts/:id/reissue", AdminController, :reissue_account)
    post("/admin/accounts/:id/suspend", AdminController, :suspend_account)
    post("/admin/connections", AdminController, :create_connection)
    post("/admin/connections/:id/activate", AdminController, :activate_connection)
    post("/admin/connections/:id/disable", AdminController, :disable_connection)
  end
end
