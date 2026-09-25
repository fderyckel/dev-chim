defmodule Chimwemwe.Platform.TemporalQualification.RevisionView do
  @moduledoc """
  Authorized immutable revision returned by the neutral temporal read boundary.
  """

  alias Chimwemwe.Platform.TemporalQualification.SegmentView

  @enforce_keys [
    :aggregate_id,
    :revision_id,
    :operation_id,
    :aggregate_revision,
    :reason_code,
    :recorded_at,
    :segments
  ]
  defstruct [
    :aggregate_id,
    :revision_id,
    :operation_id,
    :aggregate_revision,
    :predecessor_revision_id,
    :reason_code,
    :recorded_at,
    :segments
  ]

  @type t :: %__MODULE__{
          aggregate_id: String.t(),
          revision_id: String.t(),
          operation_id: String.t(),
          aggregate_revision: pos_integer(),
          predecessor_revision_id: String.t() | nil,
          reason_code: String.t(),
          recorded_at: NaiveDateTime.t(),
          segments: [SegmentView.t()]
        }
end
