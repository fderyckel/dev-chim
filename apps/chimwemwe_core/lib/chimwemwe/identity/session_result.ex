defmodule Chimwemwe.Identity.SessionResult do
  @moduledoc "Stable redacted result for an opaque application-session action."

  @enforce_keys [
    :id,
    :token,
    :tenant_id,
    :actor_id,
    :membership_id,
    :assurance,
    :assurance_at,
    :idle_expires_at,
    :absolute_expires_at,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          token: String.t(),
          tenant_id: String.t(),
          actor_id: String.t(),
          membership_id: String.t(),
          assurance: String.t(),
          assurance_at: DateTime.t(),
          idle_expires_at: DateTime.t(),
          absolute_expires_at: DateTime.t(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
