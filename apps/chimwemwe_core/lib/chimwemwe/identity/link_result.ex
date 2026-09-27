defmodule Chimwemwe.Identity.LinkResult do
  @moduledoc "Stable result returned by single-use invitation acceptance."

  @enforce_keys [:id, :invitation_id, :actor_id, :audit_reference, :event_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          invitation_id: String.t(),
          actor_id: String.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
