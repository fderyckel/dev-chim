defmodule Chimwemwe.Platform.TemporalQualification.RevisionResult do
  @moduledoc """
  Exact committed result of a neutral publication or correction action.

  Exact idempotent retries return every identifier and segment unchanged. Audit
  and event references are evidence identifiers and do not grant read access.
  """

  alias Chimwemwe.Platform.TemporalQualification.SegmentView

  @enforce_keys [
    :aggregate_id,
    :revision_id,
    :operation_id,
    :aggregate_revision,
    :reason_code,
    :recorded_at,
    :segments,
    :audit_reference,
    :event_id
  ]
  defstruct [
    :aggregate_id,
    :revision_id,
    :operation_id,
    :aggregate_revision,
    :predecessor_revision_id,
    :reason_code,
    :recorded_at,
    :segments,
    :audit_reference,
    :event_id
  ]

  @type t :: %__MODULE__{
          aggregate_id: String.t(),
          revision_id: String.t(),
          operation_id: String.t(),
          aggregate_revision: pos_integer(),
          predecessor_revision_id: String.t() | nil,
          reason_code: String.t(),
          recorded_at: NaiveDateTime.t(),
          segments: [SegmentView.t()],
          audit_reference: String.t(),
          event_id: String.t()
        }
end
