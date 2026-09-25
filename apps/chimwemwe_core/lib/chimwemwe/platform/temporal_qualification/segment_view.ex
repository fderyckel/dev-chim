defmodule Chimwemwe.Platform.TemporalQualification.SegmentView do
  @moduledoc """
  Immutable segment returned by a governed temporal qualification action or read.
  """

  @enforce_keys [:id, :effective_from, :effective_until, :value]
  defstruct [:id, :effective_from, :effective_until, :value]

  @type t :: %__MODULE__{
          id: String.t(),
          effective_from: Date.t(),
          effective_until: Date.t(),
          value: String.t()
        }
end
