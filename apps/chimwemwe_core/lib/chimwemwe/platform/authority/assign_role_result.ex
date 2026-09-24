defmodule Chimwemwe.Platform.Authority.AssignRoleResult do
  @moduledoc """
  Stable result of assigning one tenant membership to one tenant-defined role.

  Exact idempotent retries return the same values. The audit and event references
  are opaque evidence identifiers; they do not grant access to either record.
  """

  @enforce_keys [
    :id,
    :membership_id,
    :role_id,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct [:id, :membership_id, :role_id, :lock_version, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          id: String.t(),
          membership_id: String.t(),
          role_id: String.t(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
