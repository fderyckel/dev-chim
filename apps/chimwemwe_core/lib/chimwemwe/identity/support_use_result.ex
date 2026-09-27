defmodule Chimwemwe.Identity.SupportUseResult do
  @moduledoc "Minimized receipt for one allowed synthetic support use."

  @enforce_keys [:grant_id, :support_actor_id, :capability, :purpose, :audit_reference, :event_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          grant_id: String.t(),
          support_actor_id: String.t(),
          capability: String.t(),
          purpose: String.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
