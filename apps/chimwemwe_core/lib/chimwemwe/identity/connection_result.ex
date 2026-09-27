defmodule Chimwemwe.Identity.ConnectionResult do
  @moduledoc "Stable result for a provider-neutral identity-connection action."

  @enforce_keys [
    :id,
    :status,
    :configuration_version,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          status: :draft | :qualified | :active | :suspended | :retired,
          configuration_version: pos_integer(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
