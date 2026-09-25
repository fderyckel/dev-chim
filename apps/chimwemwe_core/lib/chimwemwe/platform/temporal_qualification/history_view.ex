defmodule Chimwemwe.Platform.TemporalQualification.HistoryView do
  @moduledoc """
  Bounded ordered history returned by the qualification read boundary.
  """

  alias Chimwemwe.Platform.TemporalQualification.RevisionView

  @enforce_keys [:aggregate_id, :revisions, :truncated?]
  defstruct [:aggregate_id, :revisions, :truncated?]

  @type t :: %__MODULE__{
          aggregate_id: String.t(),
          revisions: [RevisionView.t()],
          truncated?: boolean()
        }
end
