defmodule AshFoundationLab.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [AshFoundationLab.Repo]
    Supervisor.start_link(children, strategy: :one_for_one, name: AshFoundationLab.Supervisor)
  end
end
