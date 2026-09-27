defmodule Chimwemwe.Identity.InvitationResult do
  @moduledoc "Stable result returned when one account-link invitation is issued."

  @enforce_keys [:id, :token, :expires_at, :audit_reference, :event_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          token: String.t(),
          expires_at: DateTime.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
