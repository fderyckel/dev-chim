defmodule Chimwemwe.Platform.Authority.AssignmentOptions do
  @moduledoc """
  Read-only assignment preparation result for the local UI-1A interface.

  The result deliberately omits actor, tenant, capability, placement, routing,
  and repository identifiers.
  """

  alias Chimwemwe.Platform.Authority.AssignmentOption

  @enforce_keys [:contract_version, :memberships, :roles]
  defstruct [:contract_version, :memberships, :roles]

  @type t :: %__MODULE__{
          contract_version: pos_integer(),
          memberships: [AssignmentOption.t()],
          roles: [AssignmentOption.t()]
        }
end
