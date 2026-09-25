defmodule Chimwemwe.LocalBridge.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Chimwemwe.LocalBridge.SessionPlug)
  end

  scope "/api/v1", Chimwemwe.LocalBridge do
    pipe_through :api

    get("/authority/assignment-options", AssignmentOptionsController, :index)
  end
end
