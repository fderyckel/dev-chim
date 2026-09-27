defmodule Chimwemwe.Identity.SupportGrantResult do
  @moduledoc "Stable result for a bounded support-grant state change."

  @enforce_keys [
    :id,
    :support_actor_id,
    :status,
    :capability_scope,
    :purpose,
    :expires_at,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          support_actor_id: String.t(),
          status: :approved | :active | :revoked | :ended,
          capability_scope: [String.t()],
          purpose: String.t(),
          expires_at: DateTime.t(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
