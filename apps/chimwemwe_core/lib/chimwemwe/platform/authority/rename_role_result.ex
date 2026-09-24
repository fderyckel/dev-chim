defmodule Chimwemwe.Platform.Authority.RenameRoleResult do
  @moduledoc """
  Stable result of the tenant-authority role-rename action.

  Exact idempotent retries return the same values. The audit and event references
  are opaque evidence identifiers; they do not grant access to either record.
  """

  @enforce_keys [:id, :name, :lock_version, :audit_reference, :event_id]
  defstruct [:id, :name, :lock_version, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
