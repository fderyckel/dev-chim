defmodule Chimwemwe.Identity.SessionView do
  @moduledoc "Redacted current-session view returned by writer validation."

  @enforce_keys [
    :id,
    :tenant_id,
    :actor_id,
    :membership_id,
    :assurance,
    :assurance_at,
    :idle_expires_at,
    :absolute_expires_at,
    :lock_version
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          actor_id: String.t(),
          membership_id: String.t(),
          assurance: String.t(),
          assurance_at: DateTime.t(),
          idle_expires_at: DateTime.t(),
          absolute_expires_at: DateTime.t(),
          lock_version: pos_integer()
        }
end
