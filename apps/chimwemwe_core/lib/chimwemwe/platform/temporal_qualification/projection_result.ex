defmodule Chimwemwe.Platform.TemporalQualification.ProjectionResult do
  @moduledoc false

  @enforce_keys [
    :aggregate_id,
    :revision_id,
    :projection_version,
    :segment_count,
    :converged,
    :refreshed_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          aggregate_id: String.t(),
          revision_id: String.t(),
          projection_version: pos_integer(),
          segment_count: non_neg_integer(),
          converged: boolean(),
          refreshed_at: NaiveDateTime.t()
        }
end
