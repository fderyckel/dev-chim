defmodule Chimwemwe.Platform.Policy.HasCapability do
  @moduledoc """
  Fail-closed Ash policy check for a code-owned capability requirement.

  Persistent actions using this check must already be inside the trusted writer
  boundary so the process-local repository is the current tenant placement.
  """

  use Ash.Policy.SimpleCheck

  alias Chimwemwe.Platform.Authority

  @impl true
  def describe(options), do: "actor has capability #{Keyword.fetch!(options, :capability)}"

  @impl true
  def match?(actor, _context, options) do
    Authority.actor_has_capability?(actor, Keyword.fetch!(options, :capability))
  end
end
