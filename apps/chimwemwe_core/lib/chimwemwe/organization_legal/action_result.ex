defmodule Chimwemwe.OrganizationLegal.ActionResult do
  @moduledoc """
  Stable minimal result for legal-entity state transitions.

  Profile values are deliberately omitted. A caller that may read the entity
  follows the transition with the exact named read; audit and outbox payloads
  therefore do not need to duplicate legal profile data to support replay.
  """

  @enforce_keys [:id, :status, :lock_version, :audit_reference, :event_id]
  defstruct [:id, :status, :lock_version, :audit_reference, :event_id]

  @type t :: %__MODULE__{
          id: String.t(),
          status: :active,
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
