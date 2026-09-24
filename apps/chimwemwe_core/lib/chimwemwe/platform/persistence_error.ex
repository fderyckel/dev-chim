defmodule Chimwemwe.Platform.PersistenceError do
  @moduledoc """
  A non-disclosing failure from trusted placement and repository resolution.

  Route failures deliberately do not reveal whether a tenant, placement,
  routing version, or repository exists.
  """

  @enforce_keys [:code]
  defexception [:code]

  @type code :: :route_not_available | :retryable_dependency
  @type t :: %__MODULE__{code: code()}

  @impl true
  def message(%__MODULE__{code: code}), do: "trusted persistence failed: #{code}"
end
