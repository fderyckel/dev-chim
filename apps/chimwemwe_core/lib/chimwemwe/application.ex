defmodule Chimwemwe.Application do
  @moduledoc false

  use Application

  alias Chimwemwe.LocalBridge.Config

  @impl true
  def start(_type, _args) do
    with {:ok, children} <- Config.application_children() do
      Supervisor.start_link(children, strategy: :one_for_one, name: Chimwemwe.Supervisor)
    end
  end
end
