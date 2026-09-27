defmodule Chimwemwe.Application do
  @moduledoc false

  use Application

  alias Chimwemwe.AuthDemo.Config, as: AuthDemoConfig
  alias Chimwemwe.LocalBridge.Config, as: LocalBridgeConfig

  @impl true
  def start(_type, _args) do
    with {:ok, local_bridge_children} <- LocalBridgeConfig.application_children(),
         {:ok, auth_demo_children} <- AuthDemoConfig.application_children() do
      children = local_bridge_children ++ auth_demo_children
      Supervisor.start_link(children, strategy: :one_for_one, name: Chimwemwe.Supervisor)
    end
  end
end
