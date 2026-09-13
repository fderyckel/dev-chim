defmodule AshFoundationLab.Policy.HasCapability do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias AshFoundationLab.AccessControl

  @impl true
  def describe(opts), do: "actor has capability #{Keyword.fetch!(opts, :capability)}"

  @impl true
  def match?(actor, _context, opts) do
    AccessControl.actor_has_capability?(actor, Keyword.fetch!(opts, :capability))
  end
end
