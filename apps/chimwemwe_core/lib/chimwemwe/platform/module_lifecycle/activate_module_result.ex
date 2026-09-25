defmodule Chimwemwe.Platform.ModuleLifecycle.ActivateModuleResult do
  @moduledoc """
  Stable result of one initial tenant module activation.

  Exact idempotent retries return the same activation and evidence references.
  The result does not grant actor authority.
  """

  @enforce_keys [
    :id,
    :module_key,
    :module_version,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct [:id, :module_key, :module_version, :lock_version, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          id: String.t(),
          module_key: String.t(),
          module_version: String.t(),
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
