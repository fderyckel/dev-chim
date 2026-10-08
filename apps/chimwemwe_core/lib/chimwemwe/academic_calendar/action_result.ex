defmodule Chimwemwe.AcademicCalendar.ActionResult do
  @moduledoc "Minimal stable result for an authoritative calendar transition."

  @enforce_keys [:id, :kind, :status, :lock_version, :audit_reference, :event_id]
  defstruct [
    :id,
    :kind,
    :status,
    :lock_version,
    :candidate_revision,
    :audit_reference,
    :event_id
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          kind: :calendar | :academic_year,
          status: :active | :draft | :published,
          lock_version: pos_integer(),
          candidate_revision: String.t() | nil,
          audit_reference: String.t(),
          event_id: String.t()
        }
end
