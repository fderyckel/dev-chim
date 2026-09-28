defmodule Chimwemwe.Identity.SupportSessionView do
  @moduledoc "Safe visible state for one currently valid elevated support session."

  @enforce_keys [:grant_id, :support_actor_id, :purpose, :expires_at, :capability_scope]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          grant_id: String.t(),
          support_actor_id: String.t(),
          purpose: String.t(),
          expires_at: DateTime.t(),
          capability_scope: [String.t()]
        }
end
